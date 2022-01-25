-- File auto generated by purescript-bridge! --
module Control.Monad.Freer.Extras.Pagination where

import Prelude

import Control.Lazy (defer)
import Data.Argonaut.Core (jsonNull)
import Data.Argonaut.Decode (class DecodeJson)
import Data.Argonaut.Decode.Aeson ((</$\>), (</*\>), (</\>))
import Data.Argonaut.Decode.Aeson as D
import Data.Argonaut.Encode (class EncodeJson, encodeJson)
import Data.Argonaut.Encode.Aeson ((>$<), (>/\<))
import Data.Argonaut.Encode.Aeson as E
import Data.Generic.Rep (class Generic)
import Data.Lens (Iso', Lens', Prism', iso, prism')
import Data.Lens.Iso.Newtype (_Newtype)
import Data.Lens.Record (prop)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap)
import Data.Show.Generic (genericShow)
import Data.Tuple.Nested ((/\))
import Type.Proxy (Proxy(Proxy))

newtype Page a = Page
  { currentPageQuery :: PageQuery a
  , nextPageQuery :: Maybe (PageQuery a)
  , pageItems :: Array a
  }

derive instance eqPage :: (Eq a) => Eq (Page a)

instance showPage :: (Show a) => Show (Page a) where
  show a = genericShow a

instance encodeJsonPage :: (EncodeJson a) => EncodeJson (Page a) where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { currentPageQuery: E.value :: _ (PageQuery a)
        , nextPageQuery: (E.maybe E.value) :: _ (Maybe (PageQuery a))
        , pageItems: E.value :: _ (Array a)
        }
    )

instance decodeJsonPage :: (DecodeJson a) => DecodeJson (Page a) where
  decodeJson = defer \_ -> D.decode $
    ( Page <$> D.record "Page"
        { currentPageQuery: D.value :: _ (PageQuery a)
        , nextPageQuery: (D.maybe D.value) :: _ (Maybe (PageQuery a))
        , pageItems: D.value :: _ (Array a)
        }
    )

derive instance genericPage :: Generic (Page a) _

derive instance newtypePage :: Newtype (Page a) _

--------------------------------------------------------------------------------

_Page
  :: forall a
   . Iso' (Page a)
       { currentPageQuery :: PageQuery a
       , nextPageQuery :: Maybe (PageQuery a)
       , pageItems :: Array a
       }
_Page = _Newtype

--------------------------------------------------------------------------------

newtype PageQuery a = PageQuery
  { pageQuerySize :: PageSize
  , pageQueryLastItem :: Maybe a
  }

derive instance eqPageQuery :: (Eq a) => Eq (PageQuery a)

instance showPageQuery :: (Show a) => Show (PageQuery a) where
  show a = genericShow a

instance encodeJsonPageQuery :: (EncodeJson a) => EncodeJson (PageQuery a) where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { pageQuerySize: E.value :: _ PageSize
        , pageQueryLastItem: (E.maybe E.value) :: _ (Maybe a)
        }
    )

instance decodeJsonPageQuery :: (DecodeJson a) => DecodeJson (PageQuery a) where
  decodeJson = defer \_ -> D.decode $
    ( PageQuery <$> D.record "PageQuery"
        { pageQuerySize: D.value :: _ PageSize
        , pageQueryLastItem: (D.maybe D.value) :: _ (Maybe a)
        }
    )

derive instance genericPageQuery :: Generic (PageQuery a) _

derive instance newtypePageQuery :: Newtype (PageQuery a) _

--------------------------------------------------------------------------------

_PageQuery
  :: forall a
   . Iso' (PageQuery a)
       { pageQuerySize :: PageSize, pageQueryLastItem :: Maybe a }
_PageQuery = _Newtype

--------------------------------------------------------------------------------

newtype PageSize = PageSize { getPageSize :: Int }

derive instance eqPageSize :: Eq PageSize

instance showPageSize :: Show PageSize where
  show a = genericShow a

instance encodeJsonPageSize :: EncodeJson PageSize where
  encodeJson = defer \_ -> E.encode $ unwrap >$<
    ( E.record
        { getPageSize: E.value :: _ Int }
    )

instance decodeJsonPageSize :: DecodeJson PageSize where
  decodeJson = defer \_ -> D.decode $
    (PageSize <$> D.record "PageSize" { getPageSize: D.value :: _ Int })

derive instance genericPageSize :: Generic PageSize _

derive instance newtypePageSize :: Newtype PageSize _

--------------------------------------------------------------------------------

_PageSize :: Iso' PageSize { getPageSize :: Int }
_PageSize = _Newtype