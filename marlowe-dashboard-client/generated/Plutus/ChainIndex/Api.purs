-- File auto generated by purescript-bridge! --
module Plutus.ChainIndex.Api where

import Prelude

import Control.Lazy (defer)
import Control.Monad.Freer.Extras.Pagination (Page)
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
import Plutus.ChainIndex.Types (Tip)
import Plutus.V1.Ledger.Tx (TxOutRef)
import Type.Proxy (Proxy(Proxy))
import Data.Argonaut.Decode.Aeson as D
import Data.Argonaut.Encode.Aeson as E
import Data.Map as Map

newtype IsUtxoResponse = IsUtxoResponse
  { currentTip :: Tip
  , isUtxo :: Boolean
  }

derive instance Eq IsUtxoResponse

instance Show IsUtxoResponse where
  show a = genericShow a

instance EncodeJson IsUtxoResponse where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { currentTip: E.value :: _ Tip
        , isUtxo: E.value :: _ Boolean
        }
    )

instance DecodeJson IsUtxoResponse where
  decodeJson = defer \_ -> D.decode $
    ( IsUtxoResponse <$> D.record "IsUtxoResponse"
        { currentTip: D.value :: _ Tip
        , isUtxo: D.value :: _ Boolean
        }
    )

derive instance Generic IsUtxoResponse _

derive instance Newtype IsUtxoResponse _

--------------------------------------------------------------------------------

_IsUtxoResponse :: Iso' IsUtxoResponse { currentTip :: Tip, isUtxo :: Boolean }
_IsUtxoResponse = _Newtype

--------------------------------------------------------------------------------

newtype TxosResponse = TxosResponse { paget :: Page TxOutRef }

derive instance Eq TxosResponse

instance Show TxosResponse where
  show a = genericShow a

instance EncodeJson TxosResponse where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { paget: E.value :: _ (Page TxOutRef) }
    )

instance DecodeJson TxosResponse where
  decodeJson = defer \_ -> D.decode $
    ( TxosResponse <$> D.record "TxosResponse"
        { paget: D.value :: _ (Page TxOutRef) }
    )

derive instance Generic TxosResponse _

derive instance Newtype TxosResponse _

--------------------------------------------------------------------------------

_TxosResponse :: Iso' TxosResponse { paget :: Page TxOutRef }
_TxosResponse = _Newtype

--------------------------------------------------------------------------------

newtype UtxosResponse = UtxosResponse
  { currentTip :: Tip
  , page :: Page TxOutRef
  }

derive instance Eq UtxosResponse

instance Show UtxosResponse where
  show a = genericShow a

instance EncodeJson UtxosResponse where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { currentTip: E.value :: _ Tip
        , page: E.value :: _ (Page TxOutRef)
        }
    )

instance DecodeJson UtxosResponse where
  decodeJson = defer \_ -> D.decode $
    ( UtxosResponse <$> D.record "UtxosResponse"
        { currentTip: D.value :: _ Tip
        , page: D.value :: _ (Page TxOutRef)
        }
    )

derive instance Generic UtxosResponse _

derive instance Newtype UtxosResponse _

--------------------------------------------------------------------------------

_UtxosResponse :: Iso' UtxosResponse
  { currentTip :: Tip, page :: Page TxOutRef }
_UtxosResponse = _Newtype
