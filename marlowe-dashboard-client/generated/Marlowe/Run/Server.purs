-- File auto generated by servant-purescript! --
module Marlowe.Run.Server where

import Prelude

import Affjax.RequestHeader (RequestHeader(..))
import Cardano.Wallet.Mock.Types (WalletInfo)
import Component.Contacts.Types (WalletId)
import Control.Monad.Except (ExceptT)
import Data.Argonaut (Json, JsonDecodeError)
import Data.Argonaut.Decode.Aeson ((</$\>), (</*\>), (</\>))
import Data.Argonaut.Encode.Aeson ((>$<), (>/\<))
import Data.Array (catMaybes)
import Data.Either (Either(..))
import Data.Foldable (fold)
import Data.HTTP.Method (Method(..))
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Marlowe.Run.Wallet.V1 (GetTotalFundsResponse)
import Marlowe.Run.Wallet.V1.CentralizedTestnet.Types
  ( CheckPostData
  , RestoreError
  , RestorePostData
  )
import Servant.PureScript
  ( class MonadAjax
  , flagQueryPairs
  , paramListQueryPairs
  , paramQueryPairs
  , request
  , toHeader
  , toPathSegment
  )
import URI (PathAbsolute(..), RelativePart(..), RelativeRef(..))
import URI.Path.Segment (segmentNZFromString)
import Affjax.RequestBody (json) as Request
import Data.Argonaut.Decode.Aeson as D
import Data.Argonaut.Encode.Aeson as E
import Data.String.NonEmpty as NES

data Api = Api

getApiVersion
  :: forall e m
   . MonadAjax Api JsonDecodeError Json e m
  => ExceptT e m String
getApiVersion =
  request Api req
  where
  req = { method, uri, headers, content, encode, decode }
  method = Left GET
  uri = RelativeRef relativePart query Nothing
  headers = catMaybes
    [
    ]
  content = Nothing
  encode = E.encode encoder
  decode = D.decode decoder
  encoder = E.null
  decoder = D.value
  relativePart = RelativePartNoAuth $ Just
    [ "api"
    , "version"
    ]
  query = Nothing

getApiWalletV1ByWalletidTotalfunds
  :: forall e m
   . MonadAjax Api JsonDecodeError Json e m
  => WalletId
  -> ExceptT e m GetTotalFundsResponse
getApiWalletV1ByWalletidTotalfunds wallet_id =
  request Api req
  where
  req = { method, uri, headers, content, encode, decode }
  method = Left GET
  uri = RelativeRef relativePart query Nothing
  headers = catMaybes
    [
    ]
  content = Nothing
  encode = E.encode encoder
  decode = D.decode decoder
  encoder = E.null
  decoder = D.value
  relativePart = RelativePartNoAuth $ Just
    [ "api"
    , "wallet"
    , "v1"
    , toPathSegment wallet_id
    , "total-funds"
    ]
  query = Nothing

postApiWalletV1CentralizedtestnetRestore
  :: forall e m
   . MonadAjax Api JsonDecodeError Json e m
  => RestorePostData
  -> ExceptT e m (Either RestoreError WalletInfo)
postApiWalletV1CentralizedtestnetRestore reqBody =
  request Api req
  where
  req = { method, uri, headers, content, encode, decode }
  method = Left POST
  uri = RelativeRef relativePart query Nothing
  headers = catMaybes
    [
    ]
  content = Just reqBody
  encode = E.encode encoder
  decode = D.decode decoder
  encoder = E.value
  decoder = (D.either D.value D.value)
  relativePart = RelativePartNoAuth $ Just
    [ "api"
    , "wallet"
    , "v1"
    , "centralized-testnet"
    , "restore"
    ]
  query = Nothing

postApiWalletV1CentralizedtestnetCheckmnemonic
  :: forall e m
   . MonadAjax Api JsonDecodeError Json e m
  => CheckPostData
  -> ExceptT e m Boolean
postApiWalletV1CentralizedtestnetCheckmnemonic reqBody =
  request Api req
  where
  req = { method, uri, headers, content, encode, decode }
  method = Left POST
  uri = RelativeRef relativePart query Nothing
  headers = catMaybes
    [
    ]
  content = Just reqBody
  encode = E.encode encoder
  decode = D.decode decoder
  encoder = E.value
  decoder = D.value
  relativePart = RelativePartNoAuth $ Just
    [ "api"
    , "wallet"
    , "v1"
    , "centralized-testnet"
    , "check-mnemonic"
    ]
  query = Nothing
