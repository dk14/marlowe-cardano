-- File auto generated by purescript-bridge! --
module Plutus.Contract.StateMachine where

import Prelude

import Control.Lazy (defer)
import Data.Argonaut (encodeJson, jsonNull)
import Data.Argonaut.Decode (class DecodeJson)
import Data.Argonaut.Decode.Aeson ((</$\>), (</*\>), (</\>))
import Data.Argonaut.Encode (class EncodeJson)
import Data.Argonaut.Encode.Aeson ((>$<), (>/\<))
import Data.Generic.Rep (class Generic)
import Data.Lens (Iso', Lens', Prism', iso, prism')
import Data.Lens.Iso.Newtype (_Newtype)
import Data.Lens.Record (prop)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap)
import Data.Show.Generic (genericShow)
import Data.Tuple.Nested ((/\))
import Plutus.Contract.StateMachine.OnChain (State)
import Type.Proxy (Proxy(Proxy))
import Wallet.Types (ContractError)
import Data.Argonaut.Decode.Aeson as D
import Data.Argonaut.Encode.Aeson as E
import Data.Map as Map

newtype InvalidTransition a b = InvalidTransition
  { tfState :: Maybe (State a)
  , tfInput :: b
  }

derive instance (Eq a, Eq b) => Eq (InvalidTransition a b)

instance (Show a, Show b) => Show (InvalidTransition a b) where
  show a = genericShow a

instance (EncodeJson a, EncodeJson b) => EncodeJson (InvalidTransition a b) where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { tfState: (E.maybe E.value) :: _ (Maybe (State a))
        , tfInput: E.value :: _ b
        }
    )

instance (DecodeJson a, DecodeJson b) => DecodeJson (InvalidTransition a b) where
  decodeJson = defer \_ -> D.decode $
    ( InvalidTransition <$> D.record "InvalidTransition"
        { tfState: (D.maybe D.value) :: _ (Maybe (State a))
        , tfInput: D.value :: _ b
        }
    )

derive instance Generic (InvalidTransition a b) _

derive instance Newtype (InvalidTransition a b) _

--------------------------------------------------------------------------------

_InvalidTransition
  :: forall a b
   . Iso' (InvalidTransition a b) { tfState :: Maybe (State a), tfInput :: b }
_InvalidTransition = _Newtype

--------------------------------------------------------------------------------

data SMContractError
  = ChooserError String
  | UnableToExtractTransition
  | SMCContractError ContractError

derive instance Eq SMContractError

instance Show SMContractError where
  show a = genericShow a

instance EncodeJson SMContractError where
  encodeJson = defer \_ -> case _ of
    ChooserError a -> E.encodeTagged "ChooserError" a E.value
    UnableToExtractTransition -> encodeJson
      { tag: "UnableToExtractTransition", contents: jsonNull }
    SMCContractError a -> E.encodeTagged "SMCContractError" a E.value

instance DecodeJson SMContractError where
  decodeJson = defer \_ -> D.decode
    $ D.sumType "SMContractError"
    $ Map.fromFoldable
        [ "ChooserError" /\ D.content (ChooserError <$> D.value)
        , "UnableToExtractTransition" /\ pure UnableToExtractTransition
        , "SMCContractError" /\ D.content (SMCContractError <$> D.value)
        ]

derive instance Generic SMContractError _

--------------------------------------------------------------------------------

_ChooserError :: Prism' SMContractError String
_ChooserError = prism' ChooserError case _ of
  (ChooserError a) -> Just a
  _ -> Nothing

_UnableToExtractTransition :: Prism' SMContractError Unit
_UnableToExtractTransition = prism' (const UnableToExtractTransition) case _ of
  UnableToExtractTransition -> Just unit
  _ -> Nothing

_SMCContractError :: Prism' SMContractError ContractError
_SMCContractError = prism' SMCContractError case _ of
  (SMCContractError a) -> Just a
  _ -> Nothing
