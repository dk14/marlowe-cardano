-- File auto generated by purescript-bridge! --
module Plutus.Contract.Resumable where

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
import Data.Map (Map)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap)
import Data.Show.Generic (genericShow)
import Data.Tuple (Tuple)
import Data.Tuple.Nested ((/\))
import Type.Proxy (Proxy(Proxy))
import Data.Argonaut.Decode.Aeson as D
import Data.Argonaut.Encode.Aeson as E
import Data.Map as Map

newtype IterationID = IterationID Int

derive instance Eq IterationID

derive instance Ord IterationID

instance Show IterationID where
  show a = genericShow a

instance EncodeJson IterationID where
  encodeJson = defer \_ -> E.encode $ unwrap >$< E.value

instance DecodeJson IterationID where
  decodeJson = defer \_ -> D.decode $ (IterationID <$> D.value)

derive instance Generic IterationID _

derive instance Newtype IterationID _

--------------------------------------------------------------------------------

_IterationID :: Iso' IterationID Int
_IterationID = _Newtype

--------------------------------------------------------------------------------

newtype Request a = Request
  { rqID :: RequestID
  , itID :: IterationID
  , rqRequest :: a
  }

derive instance (Eq a) => Eq (Request a)

instance (Show a) => Show (Request a) where
  show a = genericShow a

instance (EncodeJson a) => EncodeJson (Request a) where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { rqID: E.value :: _ RequestID
        , itID: E.value :: _ IterationID
        , rqRequest: E.value :: _ a
        }
    )

instance (DecodeJson a) => DecodeJson (Request a) where
  decodeJson = defer \_ -> D.decode $
    ( Request <$> D.record "Request"
        { rqID: D.value :: _ RequestID
        , itID: D.value :: _ IterationID
        , rqRequest: D.value :: _ a
        }
    )

derive instance Generic (Request a) _

derive instance Newtype (Request a) _

--------------------------------------------------------------------------------

_Request
  :: forall a
   . Iso' (Request a) { rqID :: RequestID, itID :: IterationID, rqRequest :: a }
_Request = _Newtype

--------------------------------------------------------------------------------

newtype RequestID = RequestID Int

derive instance Eq RequestID

derive instance Ord RequestID

instance Show RequestID where
  show a = genericShow a

instance EncodeJson RequestID where
  encodeJson = defer \_ -> E.encode $ unwrap >$< E.value

instance DecodeJson RequestID where
  decodeJson = defer \_ -> D.decode $ (RequestID <$> D.value)

derive instance Generic RequestID _

derive instance Newtype RequestID _

--------------------------------------------------------------------------------

_RequestID :: Iso' RequestID Int
_RequestID = _Newtype

--------------------------------------------------------------------------------

newtype Response a = Response
  { rspRqID :: RequestID
  , rspItID :: IterationID
  , rspResponse :: a
  }

derive instance (Eq a) => Eq (Response a)

instance (Show a) => Show (Response a) where
  show a = genericShow a

instance (EncodeJson a) => EncodeJson (Response a) where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { rspRqID: E.value :: _ RequestID
        , rspItID: E.value :: _ IterationID
        , rspResponse: E.value :: _ a
        }
    )

instance (DecodeJson a) => DecodeJson (Response a) where
  decodeJson = defer \_ -> D.decode $
    ( Response <$> D.record "Response"
        { rspRqID: D.value :: _ RequestID
        , rspItID: D.value :: _ IterationID
        , rspResponse: D.value :: _ a
        }
    )

derive instance Generic (Response a) _

derive instance Newtype (Response a) _

--------------------------------------------------------------------------------

_Response
  :: forall a
   . Iso' (Response a)
       { rspRqID :: RequestID, rspItID :: IterationID, rspResponse :: a }
_Response = _Newtype

--------------------------------------------------------------------------------

newtype Responses a = Responses
  { unResponses :: Map (Tuple IterationID RequestID) a }

derive instance (Eq a) => Eq (Responses a)

instance (Show a) => Show (Responses a) where
  show a = genericShow a

instance (EncodeJson a) => EncodeJson (Responses a) where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { unResponses:
            (E.dictionary (E.tuple (E.value >/\< E.value)) E.value) :: _
              (Map (Tuple IterationID RequestID) a)
        }
    )

instance (DecodeJson a) => DecodeJson (Responses a) where
  decodeJson = defer \_ -> D.decode $
    ( Responses <$> D.record "Responses"
        { unResponses:
            (D.dictionary (D.tuple (D.value </\> D.value)) D.value) :: _
              (Map (Tuple IterationID RequestID) a)
        }
    )

derive instance Generic (Responses a) _

derive instance Newtype (Responses a) _

--------------------------------------------------------------------------------

_Responses
  :: forall a
   . Iso' (Responses a) { unResponses :: Map (Tuple IterationID RequestID) a }
_Responses = _Newtype
