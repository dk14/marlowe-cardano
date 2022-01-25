module Component.ContractSetupForm where

import Prologue

import Component.Template.Types as Template
import Data.Address (Address)
import Data.AddressBook (AddressBook)
import Data.AddressBook as AddressBook
import Data.ContractNickname (ContractNickname)
import Data.ContractNickname as CN
import Data.ContractTimeout (ContractTimeout)
import Data.ContractTimeout as CT
import Data.ContractValue (ContractValue)
import Data.ContractValue as CV
import Data.Either (note)
import Data.Lens (Lens')
import Data.Lens.Record (prop)
import Data.Map (Map)
import Data.Map as Map
import Data.Set (Set)
import Data.Set as Set
import Data.Validation.Semigroup (V(..))
import Data.WalletNickname as WN
import Effect.Aff.Class (class MonadAff)
import Forms (InputSlots)
import Forms as Forms
import Halogen as H
import Halogen.Form (Form, subform)
import Halogen.Form as Form
import Halogen.Form.Component as FC
import Halogen.HTML as HH
import Halogen.Hooks as Hooks
import Marlowe.Semantics (TokenName)
import Polyform.Validator (liftFnV)
import Type.Proxy (Proxy(..))

type Input =
  { roles :: Set TokenName
  , timeouts :: Set String
  , values :: Set String
  , addressBook :: AddressBook
  }

type ContractInput =
  { nickname :: String
  , roles :: Map TokenName String
  , timeouts :: Map String String
  , values :: Map String String
  }

_nickname :: Lens' ContractInput String
_nickname = prop (Proxy :: _ "nickname")

_roles :: Lens' ContractInput (Map TokenName String)
_roles = prop (Proxy :: _ "roles")

_timeouts :: Lens' ContractInput (Map String String)
_timeouts = prop (Proxy :: _ "timeouts")

_values :: Lens' ContractInput (Map String String)
_values = prop (Proxy :: _ "values")

data ContractParams =
  ContractParams
    ContractNickname
    (Map TokenName Address)
    (Map String ContractTimeout)
    (Map String ContractValue)

derive instance Eq ContractParams

type Component q m =
  H.Component q Input Template.Action m

contractNicknameForm
  :: forall parentAction s m
   . Monad m
  => Form parentAction (InputSlots s) m String ContractNickname
contractNicknameForm =
  Form.mkForm
    { validator: CN.validator
    , render: Forms.input "contract-nickname" "Contract title" case _ of
        CN.Empty -> "Required."
    }

roleAssignmentForm
  :: forall s m
   . Monad m
  => AddressBook
  -> TokenName
  -> Form Template.Action (InputSlots s) m String Address
roleAssignmentForm addressBook roleName =
  Form.mkForm
    { validator
    , render: Forms.input ("role-input-" <> roleName) roleName case _ of
        WN.Empty -> "Required."
        WN.Exists -> "Already exists."
        WN.DoesNotExist -> "Not found."
        WN.ContainsNonAlphaNumeric -> "Can only contain letters and digits."
    }
  where
  validator =
    liftFnV $
      V <<<
        ( note WN.DoesNotExist <<< flip AddressBook.lookupAddress addressBook
            <=< WN.fromString
        )

roleForms
  :: forall s m
   . Monad m
  => AddressBook
  -> Form
       Template.Action
       (InputSlots s)
       m
       (Map TokenName String)
       (Map TokenName Address)
roleForms addressBook =
  Form.multiWithIndex $ roleAssignmentForm $ addressBook

timeoutForm
  :: forall parentAction s m
   . Monad m
  => String
  -> Form parentAction (InputSlots s) m String ContractTimeout
timeoutForm name =
  Form.mkForm
    { validator: CT.validator
    , render: Forms.input ("slot-input-" <> name) name case _ of
        CT.Empty -> "Required."
        CT.Past -> "Must be in the future."
        CT.Invalid -> "Must be a number of slots from contract start."
    }

valueForm
  :: forall parentAction s m
   . Monad m
  => String
  -> Form parentAction (InputSlots s) m String ContractValue
valueForm name =
  Form.mkForm
    { validator: CV.validator
    , render: Forms.input ("value-input-" <> name) name case _ of
        CV.Empty -> "Required."
        CV.Negative -> "Must by positive."
        CV.Invalid -> "Must by a number."
    }

component :: forall q m. MonadAff m => Component q m
component = Hooks.component \{ outputToken } input -> Hooks.do
  let { addressBook, roles, timeouts, values } = input
  Tuple _result resultId <- Hooks.useState Nothing
  form <- Hooks.captures { addressBook } Hooks.useMemo \_ ->
    FC.component
      { form:
          ContractParams
            <$> subform _nickname contractNicknameForm
            <*> subform _roles (roleForms addressBook)
            <*> subform _timeouts (Form.multiWithIndex timeoutForm)
            <*> subform _values (Form.multiWithIndex valueForm)
      , formClasses: []
      }
  let
    initialInput =
      { nickname: ""
      , roles: Map.fromFoldable $ Set.map (flip Tuple "") roles
      , timeouts: Map.fromFoldable $ Set.map (flip Tuple "") timeouts
      , values: Map.fromFoldable $ Set.map (flip Tuple "") values
      }
  Hooks.pure do
    HH.slot (Proxy :: _ "form") unit form initialInput case _ of
      FC.Updated res -> Hooks.put resultId res
      FC.Raised welcomeAction -> Hooks.raise outputToken welcomeAction