-- File auto generated by purescript-bridge! --
module Plutus.Contract.Checkpoint where

import Prelude

import Control.Lazy (defer)
import Data.Argonaut (encodeJson, jsonNull)
import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode (class DecodeJson)
import Data.Argonaut.Decode.Aeson ((</$\>), (</*\>), (</\>))
import Data.Argonaut.Decode.Aeson as D
import Data.Argonaut.Encode (class EncodeJson)
import Data.Argonaut.Encode.Aeson ((>$<), (>/\<))
import Data.Argonaut.Encode.Aeson as E
import Data.BigInt.Argonaut (BigInt)
import Data.Generic.Rep (class Generic)
import Data.Lens (Iso', Lens', Prism', iso, prism')
import Data.Lens.Iso.Newtype (_Newtype)
import Data.Lens.Record (prop)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap)
import Data.Show.Generic (genericShow)
import Data.Tuple.Nested ((/\))
import Type.Proxy (Proxy(Proxy))

newtype CheckpointError = JSONDecodeError String

derive instance Eq CheckpointError

instance Show CheckpointError where
  show a = genericShow a

instance EncodeJson CheckpointError where
  encodeJson = defer \_ -> E.encode $ unwrap >$< E.value

instance DecodeJson CheckpointError where
  decodeJson = defer \_ -> D.decode $ (JSONDecodeError <$> D.value)

derive instance Generic CheckpointError _

derive instance Newtype CheckpointError _

--------------------------------------------------------------------------------

_JSONDecodeError :: Iso' CheckpointError String
_JSONDecodeError = _Newtype

--------------------------------------------------------------------------------

newtype CheckpointKey = CheckpointKey BigInt

derive instance Eq CheckpointKey

derive instance Ord CheckpointKey

instance Show CheckpointKey where
  show a = genericShow a

instance EncodeJson CheckpointKey where
  encodeJson = defer \_ -> E.encode $ unwrap >$< E.value

instance DecodeJson CheckpointKey where
  decodeJson = defer \_ -> D.decode $ (CheckpointKey <$> D.value)

derive instance Generic CheckpointKey _

derive instance Newtype CheckpointKey _

--------------------------------------------------------------------------------

_CheckpointKey :: Iso' CheckpointKey BigInt
_CheckpointKey = _Newtype

--------------------------------------------------------------------------------

newtype CheckpointStore = CheckpointStore
  { unCheckpointStore :: Map CheckpointKey (CheckpointStoreItem Json) }

derive instance Eq CheckpointStore

instance EncodeJson CheckpointStore where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { unCheckpointStore:
            (E.dictionary E.value E.value)
              :: _ (Map CheckpointKey (CheckpointStoreItem Json))
        }
    )

instance DecodeJson CheckpointStore where
  decodeJson = defer \_ -> D.decode $
    ( CheckpointStore <$> D.record "CheckpointStore"
        { unCheckpointStore:
            (D.dictionary D.value D.value)
              :: _ (Map CheckpointKey (CheckpointStoreItem Json))
        }
    )

derive instance Generic CheckpointStore _

derive instance Newtype CheckpointStore _

--------------------------------------------------------------------------------

_CheckpointStore
  :: Iso' CheckpointStore
       { unCheckpointStore :: Map CheckpointKey (CheckpointStoreItem Json) }
_CheckpointStore = _Newtype

--------------------------------------------------------------------------------

newtype CheckpointStoreItem a = CheckpointStoreItem
  { csValue :: a
  , csNewKey :: CheckpointKey
  }

derive instance (Eq a) => Eq (CheckpointStoreItem a)

instance (Show a) => Show (CheckpointStoreItem a) where
  show a = genericShow a

instance (EncodeJson a) => EncodeJson (CheckpointStoreItem a) where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { csValue: E.value :: _ a
        , csNewKey: E.value :: _ CheckpointKey
        }
    )

instance (DecodeJson a) => DecodeJson (CheckpointStoreItem a) where
  decodeJson = defer \_ -> D.decode $
    ( CheckpointStoreItem <$> D.record "CheckpointStoreItem"
        { csValue: D.value :: _ a
        , csNewKey: D.value :: _ CheckpointKey
        }
    )

derive instance Generic (CheckpointStoreItem a) _

derive instance Newtype (CheckpointStoreItem a) _

--------------------------------------------------------------------------------

_CheckpointStoreItem
  :: forall a
   . Iso' (CheckpointStoreItem a) { csValue :: a, csNewKey :: CheckpointKey }
_CheckpointStoreItem = _Newtype