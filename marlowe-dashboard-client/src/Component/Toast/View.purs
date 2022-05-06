module Component.Toast.View (render) where

import Prologue hiding (div)

import Component.Icons (Icon(..), icon, icon_)
import Component.Toast.Types
  ( Action(..)
  , State
  , ToastEntry
  , ToastMessage
  , indexRef
  )
import Css as Css
import Data.Lens (preview)
import Data.List (List(..), (:))
import Data.List as List
import Data.Maybe (fromMaybe)
import Data.Tuple.Nested (type (/\), (/\))
import Halogen (AttrName(..), ElemName(..), RefLabel(..))
import Halogen.Css (classNames)
import Halogen.HTML (HTML, a, attr, div, div_, span, text)
import Halogen.HTML.Elements.Keyed as HK
import Halogen.HTML.Events.Extra (onClick_)
import Halogen.HTML.Properties (id, ref)
import Halogen.HTML.Properties.ARIA (describedBy, labelledBy, role)

render
  :: forall p
   . State
  -> HTML p Action
render state = case state.toasts of
  Nil -> div_ []
  toasts ->
    let
      renderedToasts = renderToast <$> List.toUnfoldable toasts
    in
      HK.div
        [ classNames
            [ "fixed"
            , "bottom-3"
            , "left-0"
            , "right-0"
            , "flex"
            , "flex-col"
            , "items-center"
            , "z-50"
            ]
        ]
        renderedToasts

renderToast
  :: forall p
   . ToastEntry
  -> String /\ HTML p Action
renderToast { index, message: toast } =
  let
    readMore = case toast.longDescription of
      Nothing -> div_ []
      Just _ ->
        div
          [ classNames [ "ml-4", "font-semibold", "underline", "flex-shrink-0" ]
          ]
          [ a
              [ onClick_ $ ExpandToast index ]
              [ text "Read more" ]
          ]
  in
    (indexRef "toast-message" index) /\ div
      [ classNames
          [ "px-4"
          , "py-2"
          , "mb-3"
          , "md:mb-6"
          , "rounded"
          , "shadow-lg"
          , "min-w-90pc"
          , "max-w-90pc"
          , "sm:min-w-sm"
          , "flex"
          , "justify-between"
          , toast.bgColor
          , toast.textColor
          ]
      , ref $ RefLabel $ indexRef "toast-message" index
      , attr (AttrName "data-custom-ref") $ indexRef "toast-message" index
      , role $ show toast.role
      , labelledBy $ indexRef "toast-short-message" index
      ]
      [ div [ classNames [ "flex-grow", "flex", "overflow-hidden" ] ]
          [ icon toast.icon [ "mr-2", toast.iconColor ]
          , span
              [ classNames
                  [ "font-semibold"
                  , "overflow-ellipsis"
                  , "whitespace-nowrap"
                  , "overflow-hidden"
                  ]
              , id "toast-short-message"
              ]
              [ text toast.shortDescription ]
          ]
      , readMore
      , a
          [ classNames [ "ml-2", "leading-none", toast.textColor ]
          , onClick_ $ AnimateCloseToast index
          ]
          [ icon_ Close ]
      ]

-- FIXME: Delete
renderExpanded
  :: forall p
   . ToastEntry
  -> HTML p Action
renderExpanded { index: toastIndex, message: toast } =
  div
    [ classNames $ Css.cardOverlay true ]
    [ div
        [ classNames (Css.card true)
        , role $ show toast.role
        , labelledBy "toast-short-message"
        , describedBy "toast-long-message"
        ]
        [ a
            [ classNames [ "absolute", "top-4", "right-4", toast.textColor ]
            , onClick_ $ CloseToast toastIndex
            ]
            [ icon_ Close ]
        , div
            [ classNames
                [ "flex"
                , "font-semibold"
                , "px-5"
                , "py-4"
                , toast.bgColor
                , toast.textColor
                ]
            ]
            [ icon toast.icon [ "mr-2", toast.iconColor ]
            , span [ id "toast-short-message" ] [ text toast.shortDescription ]
            ]
        , div
            [ classNames [ "px-5", "pb-6", "pt-3", "md:pb-8" ]
            , id "toast-long-message"
            ]
            [ text $ fromMaybe "" toast.longDescription
            ]
        ]
    ]

-- FIXME: Delete
renderCollapsed
  :: forall p
   . ToastEntry
  -> HTML p Action
renderCollapsed { index: toastIndex, message: toast } =
  let
    readMore = case toast.longDescription of
      Nothing -> div_ []
      Just _ ->
        div
          [ classNames [ "ml-4", "font-semibold", "underline", "flex-shrink-0" ]
          ]
          [ a
              [ onClick_ $ ExpandToast toastIndex ]
              [ text "Read more" ]
          ]
  in
    div
      [ classNames
          [ "fixed"
          , "bottom-6"
          , "md:bottom-10"
          , "left-0"
          , "right-0"
          , "flex"
          , "justify-center"
          , "z-50"
          ]
      ]
      [ div
          [ classNames
              [ "px-4"
              , "py-2"
              , "rounded"
              , "shadow-lg"
              , "min-w-90pc"
              , "max-w-90pc"
              , "sm:min-w-sm"
              , "flex"
              , "justify-between"
              , "animate-from-below"
              , toast.bgColor
              , toast.textColor
              ]
          , ref $ RefLabel "collapsed-toast"
          , role $ show toast.role
          , labelledBy "toast-short-message"
          ]
          [ div [ classNames [ "flex", "overflow-hidden" ] ]
              [ icon toast.icon [ "mr-2", toast.iconColor ]
              , span
                  [ classNames
                      [ "font-semibold"
                      , "overflow-ellipsis"
                      , "whitespace-nowrap"
                      , "overflow-hidden"
                      ]
                  , id "toast-short-message"
                  ]
                  [ text toast.shortDescription ]
              ]
          , readMore
          ]
      ]