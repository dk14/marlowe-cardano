{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeFamilyDependencies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Language.Marlowe.Protocol.Load.Client
  where

import Data.Kind (Type)
import Language.Marlowe.Core.V1.Semantics.Types
import Language.Marlowe.Protocol.Load.Types
import Language.Marlowe.Runtime.ChainSync.Api (DatumHash)
import Network.TypedProtocol

newtype MarloweLoadClient m a = MarloweLoadClient
  { runMarloweLoadClient :: m (ClientStProcessing 'RootNode m a)
  }

newtype ClientStProcessing (node :: Node) m a = ClientStProcessing
  { recvMsgResume :: forall n. Nat ('S n) -> m (ClientStCanPush n node m a)
  }

type family ClientStPop (n :: N) (node :: Node) :: (Type -> Type) -> Type -> Type where
  ClientStPop n 'RootNode = ClientStComplete
  ClientStPop n ('PayNode node) = ClientStPop n node
  ClientStPop n ('IfLNode node) = ClientStPush n ('IfRNode node)
  ClientStPop n ('IfRNode node) = ClientStPop n node
  ClientStPop n ('WhenNode node) = ClientStPop n node
  ClientStPop n ('CaseNode node) = ClientStPush n ('WhenNode node)
  ClientStPop n ('LetNode node) = ClientStPop n node
  ClientStPop n ('AssertNode node) = ClientStPop n node

type family ClientStPush (n :: N) (node :: Node) = (c :: (Type -> Type) -> Type -> Type) | c -> n node where
  ClientStPush 'Z node = ClientStProcessing node
  ClientStPush ('S n) node = ClientStCanPush n node

data ClientStCanPush (n :: N) (node :: Node) m a where
  PushClose :: ClientStPop n node m a -> ClientStCanPush n node m a
  PushPay
    :: AccountId
    -> Payee
    -> Token
    -> Value Observation
    -> ClientStPush n ('PayNode node) m a
    -> ClientStCanPush n node m a
  PushIf
    :: Observation
    -> ClientStPush n ('IfLNode node) m a
    -> ClientStCanPush n node m a
  PushWhen
    :: Timeout
    -> ClientStPush n ('WhenNode node) m a
    -> ClientStCanPush n node m a
  PushCase
    :: Action
    -> m (ClientStPush n ('CaseNode node) m a)
    -> ClientStCanPush n ('WhenNode node) m a
  PushLet
    :: ValueId
    -> Value Observation
    -> ClientStPush n ('LetNode node) m a
    -> ClientStCanPush n node m a
  PushAssert
    :: Observation
    -> ClientStPush n ('AssertNode node) m a
    -> ClientStCanPush n node m a

newtype ClientStComplete m a = ClientStComplete
  { recvMsgComplete :: DatumHash -> m a
  }

marloweLoadClientPeer
  :: forall m a
   . Functor m
  => MarloweLoadClient m a
  -> Peer MarloweLoad 'AsClient ('StProcessing 'RootNode) m a
marloweLoadClientPeer = Effect . fmap (peerProcessing SRootNode) . runMarloweLoadClient
  where
  peerProcessing :: SNode node -> ClientStProcessing node m a -> Peer MarloweLoad 'AsClient ('StProcessing node) m a
  peerProcessing node ClientStProcessing{..} = Await (ServerAgency $ TokProcessing node) \case
    MsgResume (Succ n) -> Effect $ peerCanPush n node <$> recvMsgResume (Succ n)

  peerCanPush :: Nat n -> SNode node -> ClientStCanPush n node m a -> Peer MarloweLoad 'AsClient ('StCanPush n node) m a
  peerCanPush n node = \case
    PushClose next ->
      Yield tok MsgPushClose $ peerPop n node next
    PushPay payor payee token value next ->
      Yield tok (MsgPushPay payor payee token value) $ peerPush n (SPayNode node) next
    PushIf cond next ->
      Yield tok (MsgPushIf cond) $ peerPush n (SIfLNode node) next
    PushWhen timeout next ->
      Yield tok (MsgPushWhen timeout) $ peerPush n (SWhenNode node) next
    PushCase action next -> case node of
      SWhenNode node' -> Effect $ Yield tok (MsgPushCase action) . peerPush n (SCaseNode node') <$> next
    PushLet valueId value next ->
      Yield tok (MsgPushLet valueId value) $ peerPush n (SLetNode node) next
    PushAssert obs next ->
      Yield tok (MsgPushAssert obs) $ peerPush n (SAssertNode node) next
    where
      tok = ClientAgency $ TokCanPush n node

  peerPop
    :: Nat n
    -> SNode node
    -> ClientStPop n node m a
    -> Peer MarloweLoad 'AsClient (Pop n node) m a
  peerPop n node client = case node of
    SRootNode -> peerComplete client
    SPayNode node' -> peerPop n node' client
    SIfLNode node' -> peerPush n (SIfRNode node') client
    SIfRNode node' -> peerPop n node' client
    SWhenNode node' -> peerPop n node' client
    SCaseNode node' -> peerPush n (SWhenNode node') client
    SLetNode node' -> peerPop n node' client
    SAssertNode node' -> peerPop n node' client

  peerPush
    :: Nat n
    -> SNode node
    -> ClientStPush n node m a
    -> Peer MarloweLoad 'AsClient (Push n node) m a
  peerPush n node client = case n of
    Zero -> peerProcessing node client
    Succ n' -> peerCanPush n' node client

  peerComplete :: ClientStComplete m a -> Peer MarloweLoad 'AsClient 'StComplete m a
  peerComplete ClientStComplete{..} = Await (ServerAgency TokComplete) \case
    MsgComplete hash -> Effect $ Done TokDone <$> recvMsgComplete hash

-- | Load a contract into the runtime in a space-efficient way. Note: this
-- relies on the input contract being lazily evaluated and garbage collected as
-- it is processed. This means that the caller of this function should avoid holding
-- onto a reference to the input contract (e.g. in a let-binding). Preferably,
-- the return value of a function that generates the contract should be passed
-- directly to this function.
pushContract
  :: forall m
   . MonadFail m
  -- The unmerkleized contract to load.
  => Contract
  -- A client that loads the entire contract into the runtime, returning the hash
  -- of the merkleized contract.
  -> MarloweLoadClient m DatumHash
pushContract root = MarloweLoadClient $ pure $ ClientStProcessing \(Succ n) ->
  pure $ pushContract' n StateRoot root
  where
    pushContract'
      :: Nat n
      -> PeerState node
      -> Contract
      -> ClientStCanPush n node m DatumHash
    pushContract' n state = \case
      Close ->
        PushClose $ popState n state
      Pay payee payor token value next ->
        PushPay payee payor token value $ pushState n (StatePay state) next
      If obs tru fal ->
        PushIf obs $ pushState n (StateIfL fal state) tru
      When cases timeout fallback -> PushWhen timeout case cases of
        [] -> pushState n (StateWhen state) fallback
        (c : cs) -> pushCase n c cs fallback state
      Let valueId value next ->
        PushLet valueId value $ pushState n (StateLet state) next
      Assert obs next ->
        PushAssert obs $ pushState n (StateAssert state) next

    pushState :: Nat n -> PeerState node -> Contract -> ClientStPush n node m DatumHash
    pushState = \case
      Zero -> \state contract -> ClientStProcessing \(Succ n) -> pure $ pushContract' n state contract
      Succ n -> \state contract -> pushContract' n state contract

    popState :: Nat n -> PeerState node -> ClientStPop n node m DatumHash
    popState n = \case
      StateRoot -> ClientStComplete pure
      StatePay state -> popState n state
      StateIfL fal state -> pushState n (StateIfR state) fal
      StateIfR state -> popState n state
      StateWhen state -> popState n state
      StateCase [] fallback state -> pushState n (StateWhen state) fallback
      StateCase (c : cs) fallback state -> pushCase n c cs fallback state
      StateLet state -> popState n state
      StateAssert state -> popState n state

    pushCase
      :: Nat n
      -> Case Contract
      -> [Case Contract]
      -> Contract
      -> PeerState node
      -> ClientStPush n ('WhenNode node) m DatumHash
    pushCase n c cs fallback state = case n of
      Zero -> ClientStProcessing \(Succ n') -> pure $ pushCase' n' c cs fallback state
      Succ n' -> pushCase' n' c cs fallback state

    pushCase'
      :: Nat n
      -> Case Contract
      -> [Case Contract]
      -> Contract
      -> PeerState node
      -> ClientStCanPush n ('WhenNode node) m DatumHash
    pushCase' n c cs fallback state = case c of
      Case action next -> PushCase action $ pure $ pushState n (StateCase cs fallback state) next
      MerkleizedCase action _ -> PushCase action $ fail "merkleized contract detected"

data PeerState (node :: Node) where
  StateRoot :: PeerState 'RootNode
  StatePay :: PeerState node -> PeerState ('PayNode node)
  StateIfL :: Contract -> PeerState node -> PeerState ('IfLNode node)
  StateIfR :: PeerState node -> PeerState ('IfRNode node)
  StateWhen :: PeerState node -> PeerState ('WhenNode node)
  StateCase :: [Case Contract] -> Contract -> PeerState node -> PeerState ('CaseNode node)
  StateLet :: PeerState node -> PeerState ('LetNode node)
  StateAssert :: PeerState node -> PeerState ('AssertNode node)
