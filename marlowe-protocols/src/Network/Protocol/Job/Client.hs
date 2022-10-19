{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}

-- | A generic client for the job protocol. Includes a function for
-- interpreting a server as a typed-protocols peer that can be executed with a
-- driver and a codec.

module Network.Protocol.Job.Client
  where

import Data.Void (Void, absurd)
import Network.Protocol.Job.Types
import Network.Protocol.SchemaVersion (SchemaVersion)
import Network.TypedProtocol

-- | A generic client for the job protocol.
newtype JobClient cmd m a = JobClient { runJobClient :: m (ClientStInit cmd m a) }

-- | In the 'StInit' protocol state, the client has agency. It must send a
-- handshake request message.
data ClientStInit cmd m a
  = SendMsgRequestHandshake SchemaVersion (ClientStHandshake cmd m a)

-- | In the 'StHandshake' protocol state, the client does not have agency.
-- Instead, it must be prepared to handle either:
--
-- * a handshake rejection message
-- * a handshake confirmation message
data ClientStHandshake cmd m a = ClientStHandshake
  { recvMsgHandshakeRejected  :: SchemaVersion -> m a
  , recvMsgHandshakeConfirmed :: m (ClientStIdle cmd m a)
  }

-- | In the 'StInit' state, the client has agency. It can send:
--
-- * An exec message
-- * An attach message
data ClientStIdle cmd m a where

  -- | Tell the server to execute a command in a new job.
  SendMsgExec
    :: cmd status err result
    -> ClientStCmd cmd status err result m a
    -> ClientStIdle cmd m a

  -- | Ask to attach to an existing job.
  SendMsgAttach
    :: JobId cmd status err result
    -> ClientStAttach cmd status err result m a
    -> ClientStIdle cmd m a

deriving instance Functor m => Functor (ClientStIdle cmd m)

-- | In the 'StCmd' state, the server has agency. The client must be prepared
-- to handle either:
--
-- * A failure message with an error
-- * A success message with a result
-- * An await message with the current status and job ID
data ClientStCmd cmd status err result m a = ClientStCmd
  { recvMsgFail    :: err -> m a
  , recvMsgSucceed :: result -> m a
  , recvMsgAwait   :: status -> JobId cmd status err result -> m (ClientStAwait cmd status err result m a)
  }

deriving instance Functor m => Functor (ClientStCmd cmd status err result m)

-- | In the 'StAttach' state, the server has agency. The client must be prepared
-- to handle either:
--
-- * An attach failed message.
-- * An attached message.
data ClientStAttach cmd status err result m a = ClientStAttach
  { recvMsgAttachFailed :: m a
  , recvMsgAttached     :: m (ClientStCmd cmd status err result m a)
  }

deriving instance Functor m => Functor (ClientStAttach cmd status err result m)

-- | In the 'StAwait' state, the client has agency. It can send either:
--
-- * A poll message
-- * A detach message
data ClientStAwait cmd status err result m a where
  -- | Poll the current status of the job and handle the response.
  SendMsgPoll :: ClientStCmd cmd status err result m a -> ClientStAwait cmd status err result m a

  -- | Detach from the current job and return a result.
  SendMsgDetach :: a -> ClientStAwait cmd status err result m a

deriving instance Functor m => Functor (ClientStAwait cmd status err result m)

-- | Change the underlying monad type a server runs in with a natural
-- transformation.
hoistJobClient
  :: forall cmd m n a
   . Functor m
  => (forall x. m x -> n x)
  -> JobClient cmd m a
  -> JobClient cmd n a
hoistJobClient phi = JobClient . phi . fmap hoistInit . runJobClient
  where
  hoistInit :: ClientStInit cmd m a -> ClientStInit cmd n a
  hoistInit (SendMsgRequestHandshake v idle) = SendMsgRequestHandshake v $ hoistHandshake idle

  hoistHandshake :: ClientStHandshake cmd m a -> ClientStHandshake cmd n a
  hoistHandshake ClientStHandshake{..} = ClientStHandshake
    { recvMsgHandshakeRejected = phi <$> recvMsgHandshakeRejected
    , recvMsgHandshakeConfirmed = phi $ hoistIdle <$> recvMsgHandshakeConfirmed
    }

  hoistIdle = \case
    SendMsgExec cmd stCmd        -> SendMsgExec cmd $ hoistCmd stCmd
    SendMsgAttach jobId stAttach -> SendMsgAttach jobId $ hoistAttach stAttach

  hoistAttach
    :: ClientStAttach cmd status err result m a
    -> ClientStAttach cmd status err result n a
  hoistAttach ClientStAttach{..} = ClientStAttach
    { recvMsgAttachFailed = phi recvMsgAttachFailed
    , recvMsgAttached = phi $ hoistCmd <$> recvMsgAttached
    }

  hoistCmd
    :: ClientStCmd cmd status err result m a
    -> ClientStCmd cmd status err result n a
  hoistCmd ClientStCmd{..} = ClientStCmd
    { recvMsgFail = phi . recvMsgFail
    , recvMsgSucceed = phi . recvMsgSucceed
    , recvMsgAwait = \status -> phi . fmap hoistAwait . recvMsgAwait status
    }

  hoistAwait
    :: ClientStAwait cmd status err result m a
    -> ClientStAwait cmd status err result n a
  hoistAwait = \case
    SendMsgPoll stCmd -> SendMsgPoll $ hoistCmd stCmd
    SendMsgDetach a   -> SendMsgDetach a

-- | Interpret a client as a typed-protocols peer.
jobClientPeer
  :: forall cmd m a
   . (Monad m, Command cmd)
  => JobClient cmd m a
  -> Peer (Job cmd) 'AsClient 'StInit m a
jobClientPeer JobClient{..} =
  Effect $ peerInit <$> runJobClient
  where
  peerInit
    :: ClientStInit cmd m a
    -> Peer (Job cmd) 'AsClient 'StInit m a
  peerInit (SendMsgRequestHandshake schemaVersion handshake) =
    Yield (ClientAgency TokInit) (MsgRequestHandshake schemaVersion) $ peerHandshake handshake

  peerHandshake
    :: ClientStHandshake cmd m a
    -> Peer (Job cmd) 'AsClient 'StHandshake m a
  peerHandshake ClientStHandshake{..} =
    Await (ServerAgency TokHandshake) \case
      MsgRejectHandshake version -> Effect $ Done TokFault <$> recvMsgHandshakeRejected version
      MsgConfirmHandshake         -> peerIdle  recvMsgHandshakeConfirmed

  peerIdle
    :: m (ClientStIdle cmd m a)
    -> Peer (Job cmd) 'AsClient 'StIdle m a
  peerIdle = Effect . fmap peerIdle_

  peerIdle_
    :: ClientStIdle cmd m a
    -> Peer (Job cmd) 'AsClient 'StIdle m a
  peerIdle_ = \case
    SendMsgExec cmd stCmd     -> Yield (ClientAgency TokIdle) (MsgExec cmd) $ peerCmd (tagFromCommand cmd) stCmd
    SendMsgAttach jobId stAttach -> Yield (ClientAgency TokIdle) (MsgAttach jobId) $ peerAttach (tagFromJobId jobId) stAttach

  peerCmd
    :: Tag cmd status err result
    -> ClientStCmd cmd status err result m a
    -> Peer (Job cmd) 'AsClient ('StCmd status err result) m a
  peerCmd tag ClientStCmd{..} =
    Await (ServerAgency (TokCmd tag)) $ Effect . \case
      MsgFail err           -> Done TokDone <$> recvMsgFail err
      MsgSucceed result     -> Done TokDone <$> recvMsgSucceed result
      MsgAwait status jobId -> peerAwait tag <$> recvMsgAwait status jobId

  peerAttach
    :: Tag cmd status err result
    -> ClientStAttach cmd status err result m a
    -> Peer (Job cmd) 'AsClient ('StAttach status err result) m a
  peerAttach tag ClientStAttach{..} =
    Await (ServerAgency (TokAttach tag)) $ Effect . \case
      MsgAttachFailed -> Done TokDone <$> recvMsgAttachFailed
      MsgAttached     -> peerCmd tag <$> recvMsgAttached

  peerAwait
    :: Tag cmd status err result
    -> ClientStAwait cmd status err result m a
    -> Peer (Job cmd) 'AsClient ('StAwait status err result) m a
  peerAwait tag = \case
    SendMsgPoll stCmd -> Yield (ClientAgency (TokAwait tag)) MsgPoll $ peerCmd tag stCmd
    SendMsgDetach a   -> Yield (ClientAgency (TokAwait tag)) MsgDetach $ Done TokDone a

-- | Create a client that runs a command that cannot await to completion and
-- returns the result.
liftCommand :: Monad m => SchemaVersion -> (SchemaVersion -> err) -> cmd Void err result -> JobClient cmd m (Either err result)
liftCommand version handshakeRejected cmd = JobClient . pure . SendMsgRequestHandshake version $ ClientStHandshake
  { recvMsgHandshakeRejected = \version' -> pure . Left . handshakeRejected $ version'
  , recvMsgHandshakeConfirmed = pure stInit
  }
  where
    stInit = SendMsgExec cmd stCmd
    stCmd = ClientStCmd
      { recvMsgAwait = absurd
      , recvMsgFail = pure . Left
      , recvMsgSucceed = pure . Right
      }

