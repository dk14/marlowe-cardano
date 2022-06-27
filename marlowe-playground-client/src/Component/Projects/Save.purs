module Component.Projects.Save where

import Prelude

import Component.Projects.Types (Storage(..))
import Data.Lens (_Just, view)
import Data.Lens.Iso.Newtype (_Newtype)
import Data.Maybe (fromMaybe, maybe)
import Data.Newtype (un)
import Data.Tuple.Nested ((/\))
import Halogen (Component)
import Halogen.Classes
  ( border
  , borderBlue300
  , btn
  , btnSecondary
  , fontSemibold
  , fullWidth
  , modalContent
  , noMargins
  , spaceBottom
  , spaceLeft
  , spaceRight
  , spaceTop
  , textBase
  , textRight
  , textSm
  , uppercase
  )
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HH
import Halogen.Hooks (component) as H
import Halogen.Hooks.Extra.Hooks (usePutState)
import Halogen.Hooks.Hook (bind, pure) as H
import Halogen.Store.Select (selectEq)
import Halogen.Store.UseSelector (useSelector)
import Marlowe.Project.Types (ProjectName(..), _projectName)
import Safe.Coerce (coerce)
import Store (_projectState)
import Store.Handlers (loginRequired)
import Store.Hooks (useIsAuthenticated)
import Store.ProjectState (_project)
import Type.Constraints (class MonadAffAjaxStore)

data Step
  = ChooseStorage
  | Save Storage

component
  :: forall t6 t7 t9 m
   . MonadAffAjaxStore m
  => Component t6 t7 t9 m
component = H.component \_ _ -> H.do
  step /\ putStep <- usePutState ChooseStorage

  authenticated <- fromMaybe false <$> useIsAuthenticated

  projectName <- useSelector
    ( selectEq $ view $ _projectState <<< _Just <<< _project <<< _projectName
        <<< _Newtype
    )
  let
    renderStorageChoice _ = HH.div_
      [ HH.div_ [ HH.text $ show authenticated ]
      , HH.input
          [ HH.classes [ spaceBottom, fullWidth, textSm, border, borderBlue300 ]
          , HH.value $ fromMaybe "" projectName
          -- , HH.onValueInput ChangeInput
          , HH.placeholder "Type a name for your project"
          ]
      , HH.button [ HE.onClick $ const $ putStep (Save FS) ] [ HH.text "FS" ]
      , HH.button
          [ HE.onClick $ const $ loginRequired
              (putStep ChooseStorage)
              (const $ putStep (Save GistPlatform))
          ]
          [ HH.text "GistPlatform" ]
      ]
  H.pure $ case step of
    ChooseStorage -> renderStorageChoice unit
    Save FS -> HH.text $ "Saving to local file system..."
    Save GistPlatform ->
      if authenticated then HH.text $ "Saving to github"
      else renderStorageChoice unit

-- | FIXME: paluh
-- | Migrate to this template
-- render :: forall m. MonadAff m => State -> ComponentHTML Action ChildSlots m
-- render state =
--   div [ classes if isFailure' then [ ClassName "modal-error" ] else [] ]
--     [ div [ classes [ spaceTop, spaceLeft ] ]
--         [ h2 [ classes [ textBase, fontSemibold, noMargins ] ]
--             [ text "Save as" ]
--         ]
--     , div [ classes [ modalContent, ClassName "save-as-modal" ] ]
--         [ input
--             [ classes [ spaceBottom, fullWidth, textSm, border, borderBlue300 ]
--             , value (state ^. _projectName)
--             , onValueInput ChangeInput
--             , placeholder "Type a name for your project"
--             ]
--         , div [ classes [ textRight ] ]
--             [ button
--                 [ classes [ btn, btnSecondary, uppercase, spaceRight ]
--                 , onClick $ const Cancel
--                 ]
--                 [ text "Cancel" ]
--             , button
--                 [ classes [ btn, uppercase ]
--                 , disabled $ isEmpty || isLoading'
--                 , onClick $ const SaveProject
--                 ]
--                 if isLoading' then [ icon Spinner ] else [ text "Save" ]
--             ]
--         , renderError (state ^. _status)
--         ]
--     ]
--   where
--   isLoading' = isLoading $ (state ^. _status)
--
--   isFailure' = isFailure $ (state ^. _status)
--
--   renderError = case _ of
--     (Failure err) -> div [ class_ (ClassName "error") ] [ text err ]
--     _ -> text ""
--
--   isEmpty = state ^. _projectName == ""
