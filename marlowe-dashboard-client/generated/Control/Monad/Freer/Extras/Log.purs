-- File auto generated by purescript-bridge! --
module Control.Monad.Freer.Extras.Log where

import Prelude

import Control.Lazy (defer)
import Data.Argonaut (encodeJson, jsonNull)
import Data.Argonaut.Decode (class DecodeJson)
import Data.Argonaut.Decode.Aeson ((</$\>), (</*\>), (</\>))
import Data.Argonaut.Encode (class EncodeJson)
import Data.Argonaut.Encode.Aeson ((>$<), (>/\<))
import Data.Bounded.Generic (genericBottom, genericTop)
import Data.Enum (class Enum)
import Data.Enum.Generic (genericPred, genericSucc)
import Data.Generic.Rep (class Generic)
import Data.Lens (Iso', Lens', Prism', iso, prism')
import Data.Lens.Iso.Newtype (_Newtype)
import Data.Lens.Record (prop)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap)
import Data.Show.Generic (genericShow)
import Data.Tuple.Nested ((/\))
import Type.Proxy (Proxy(Proxy))
import Data.Argonaut.Decode.Aeson as D
import Data.Argonaut.Encode.Aeson as E
import Data.Map as Map

data LogLevel
  = Debug
  | Info
  | Notice
  | Warning
  | Error
  | Critical
  | Alert
  | Emergency

derive instance Eq LogLevel

derive instance Ord LogLevel

instance Show LogLevel where
  show a = genericShow a

instance EncodeJson LogLevel where
  encodeJson = defer \_ -> E.encode E.enum

instance DecodeJson LogLevel where
  decodeJson = defer \_ -> D.decode D.enum

derive instance Generic LogLevel _

instance Enum LogLevel where
  succ = genericSucc
  pred = genericPred

instance Bounded LogLevel where
  bottom = genericBottom
  top = genericTop

--------------------------------------------------------------------------------

_Debug :: Prism' LogLevel Unit
_Debug = prism' (const Debug) case _ of
  Debug -> Just unit
  _ -> Nothing

_Info :: Prism' LogLevel Unit
_Info = prism' (const Info) case _ of
  Info -> Just unit
  _ -> Nothing

_Notice :: Prism' LogLevel Unit
_Notice = prism' (const Notice) case _ of
  Notice -> Just unit
  _ -> Nothing

_Warning :: Prism' LogLevel Unit
_Warning = prism' (const Warning) case _ of
  Warning -> Just unit
  _ -> Nothing

_Error :: Prism' LogLevel Unit
_Error = prism' (const Error) case _ of
  Error -> Just unit
  _ -> Nothing

_Critical :: Prism' LogLevel Unit
_Critical = prism' (const Critical) case _ of
  Critical -> Just unit
  _ -> Nothing

_Alert :: Prism' LogLevel Unit
_Alert = prism' (const Alert) case _ of
  Alert -> Just unit
  _ -> Nothing

_Emergency :: Prism' LogLevel Unit
_Emergency = prism' (const Emergency) case _ of
  Emergency -> Just unit
  _ -> Nothing

--------------------------------------------------------------------------------

newtype LogMessage a = LogMessage
  { _logLevel :: LogLevel
  , _logMessageContent :: a
  }

derive instance (Eq a) => Eq (LogMessage a)

instance (Show a) => Show (LogMessage a) where
  show a = genericShow a

instance (EncodeJson a) => EncodeJson (LogMessage a) where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { _logLevel: E.value :: _ LogLevel
        , _logMessageContent: E.value :: _ a
        }
    )

instance (DecodeJson a) => DecodeJson (LogMessage a) where
  decodeJson = defer \_ -> D.decode $
    ( LogMessage <$> D.record "LogMessage"
        { _logLevel: D.value :: _ LogLevel
        , _logMessageContent: D.value :: _ a
        }
    )

derive instance Generic (LogMessage a) _

derive instance Newtype (LogMessage a) _

--------------------------------------------------------------------------------

_LogMessage
  :: forall a
   . Iso' (LogMessage a) { _logLevel :: LogLevel, _logMessageContent :: a }
_LogMessage = _Newtype

logLevel :: forall a. Lens' (LogMessage a) LogLevel
logLevel = _Newtype <<< prop (Proxy :: _ "_logLevel")

logMessageContent :: forall a. Lens' (LogMessage a) a
logMessageContent = _Newtype <<< prop (Proxy :: _ "_logMessageContent")
