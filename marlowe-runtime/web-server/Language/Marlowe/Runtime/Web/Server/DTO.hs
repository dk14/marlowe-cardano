{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}

-- | This module defines the data-transfer object (DTO) translation layer for
-- the web server. DTOs are the types served by the API, which notably include
-- no cardano-api dependencies and have nice JSON representations. This module
-- describes how they are mapped to the internal API types of the runtime.

module Language.Marlowe.Runtime.Web.Server.DTO
  where

import Language.Marlowe.Runtime.Discovery.Api

import Cardano.Api
  ( AsType(AsTxBody)
  , IsCardanoEra(cardanoEra)
  , TextEnvelope(..)
  , TextEnvelopeType(..)
  , TxBody
  , deserialiseFromTextEnvelope
  , metadataValueToJsonNoSchema
  , serialiseToTextEnvelope
  )
import Cardano.Api.SerialiseTextEnvelope (TextEnvelopeDescr(..))
import Control.Arrow (second)
import Control.Error.Util (hush)
import Control.Monad ((<=<))
import Control.Monad.Except (MonadError, throwError)
import Data.Aeson (ToJSON(toJSON))
import Data.Bifunctor (bimap)
import Data.Coerce (coerce)
import Data.List.NonEmpty (NonEmpty(..))
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Maybe (fromMaybe)
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Word (Word16, Word64)
import qualified Language.Marlowe.Core.V1.Semantics as Sem
import qualified Language.Marlowe.Core.V1.Semantics.Types as Sem
import Language.Marlowe.Runtime.Cardano.Api (cardanoEraToAsType, toCardanoMetadata)
import qualified Language.Marlowe.Runtime.ChainSync.Api as Chain
import Language.Marlowe.Runtime.Core.Api
  ( ContractId(..)
  , MarloweVersion(..)
  , SomeMarloweVersion(..)
  , Transaction(..)
  , TransactionOutput(..)
  , TransactionScriptOutput(..)
  )
import Language.Marlowe.Runtime.History.Api (CreateStep(..))
import Language.Marlowe.Runtime.Plutus.V2.Api (fromPlutusCurrencySymbol)
import Language.Marlowe.Runtime.Transaction.Api (Mint(..), NFTMetadata, RoleTokensConfig(..), mkMint, mkNFTMetadata)
import qualified Language.Marlowe.Runtime.Web as Web

-- | A class that states a type has a DTO representation.
class HasDTO a where
  -- | The type used in the API to represent this type.
  type DTO a :: *

-- | States that a type can be encoded as a DTO.
class HasDTO a => ToDTO a where
  toDTO :: a -> DTO a

-- | States that a type can be decoded from a DTO.
class HasDTO a => FromDTO a where
  fromDTO :: DTO a -> Maybe a

fromDTOThrow :: (MonadError e m, FromDTO a) => e -> DTO a -> m a
fromDTOThrow e = maybe (throwError e) pure . fromDTO

instance HasDTO (Map k a) where
  type DTO (Map k a) = Map k (DTO a)

instance FromDTO a => FromDTO (Map k a) where
  fromDTO = traverse fromDTO

instance ToDTO a => ToDTO (Map k a) where
  toDTO = fmap toDTO

instance HasDTO [a] where
  type DTO [a] = [DTO a]

instance FromDTO a => FromDTO [a] where
  fromDTO = traverse fromDTO

instance ToDTO a => ToDTO [a] where
  toDTO = fmap toDTO

instance HasDTO (a, b) where
  type DTO (a, b) = (DTO a, DTO b)

instance (FromDTO a, FromDTO b) => FromDTO (a, b) where
  fromDTO (a, b) = (,) <$> fromDTO a <*> fromDTO b

instance (ToDTO a, ToDTO b) => ToDTO (a, b) where
  toDTO (a, b) = (toDTO a, toDTO b)

instance HasDTO (Maybe a) where
  type DTO (Maybe a) = Maybe (DTO a)

instance ToDTO a => ToDTO (Maybe a) where
  toDTO = fmap toDTO

instance FromDTO a => FromDTO (Maybe a) where
  fromDTO = traverse fromDTO

instance HasDTO ContractHeader where
  type DTO ContractHeader = Web.ContractHeader

instance ToDTO ContractHeader where
  toDTO ContractHeader{..} = Web.ContractHeader
    { contractId = toDTO contractId
    , roleTokenMintingPolicyId = toDTO rolesCurrency
    , version = toDTO marloweVersion
    , metadata = toDTO metadata
    , status = Web.Confirmed
    , block = Just $ toDTO blockHeader
    }

instance HasDTO Chain.BlockHeader where
  type DTO Chain.BlockHeader = Web.BlockHeader

instance ToDTO Chain.BlockHeader where
  toDTO Chain.BlockHeader{..} = Web.BlockHeader
    { slotNo = toDTO slotNo
    , blockNo = toDTO blockNo
    , blockHeaderHash = toDTO headerHash
    }

instance HasDTO ContractId where
  type DTO ContractId = Web.TxOutRef

instance ToDTO ContractId where
  toDTO = toDTO . unContractId

instance FromDTO ContractId where
  fromDTO = fmap ContractId . fromDTO

instance HasDTO SomeMarloweVersion where
  type DTO SomeMarloweVersion = Web.MarloweVersion

instance ToDTO SomeMarloweVersion where
  toDTO (SomeMarloweVersion MarloweV1) = Web.V1

instance FromDTO SomeMarloweVersion where
  fromDTO Web.V1 = pure $ SomeMarloweVersion MarloweV1

instance HasDTO Chain.TxOutRef where
  type DTO Chain.TxOutRef = Web.TxOutRef

instance ToDTO Chain.TxOutRef where
  toDTO Chain.TxOutRef{..} = Web.TxOutRef
    { txId = toDTO txId
    , txIx = toDTO txIx
    }

instance FromDTO Chain.TxOutRef where
  fromDTO Web.TxOutRef{..} = Chain.TxOutRef
    <$> fromDTO txId
    <*> fromDTO txIx

instance HasDTO Chain.TxId where
  type DTO Chain.TxId = Web.TxId

instance ToDTO Chain.TxId where
  toDTO = coerce

instance FromDTO Chain.TxId where
  fromDTO = pure . coerce

instance HasDTO Chain.PolicyId where
  type DTO Chain.PolicyId = Web.PolicyId

instance ToDTO Chain.PolicyId where
  toDTO = coerce

instance FromDTO Chain.PolicyId where
  fromDTO = Just . coerce

instance HasDTO Chain.TxIx where
  type DTO Chain.TxIx = Word16

instance ToDTO Chain.TxIx where
  toDTO = coerce

instance FromDTO Chain.TxIx where
  fromDTO = pure . coerce

instance HasDTO Chain.Metadata where
  type DTO Chain.Metadata = Web.Metadata

instance ToDTO Chain.Metadata where
  toDTO = Web.Metadata . metadataValueToJsonNoSchema . toCardanoMetadata

instance FromDTO Chain.Metadata where
  fromDTO = Chain.fromJSONEncodedMetadata . Web.unMetadata

instance HasDTO Chain.TransactionMetadata where
  type DTO Chain.TransactionMetadata = Map Word64 Web.Metadata

instance ToDTO Chain.TransactionMetadata where
  toDTO = toDTO . Chain.unTransactionMetadata

instance FromDTO Chain.TransactionMetadata where
  fromDTO = fmap Chain.TransactionMetadata . fromDTO

instance HasDTO Chain.SlotNo where
  type DTO Chain.SlotNo = Word64

instance ToDTO Chain.SlotNo where
  toDTO = coerce

instance HasDTO Chain.BlockNo where
  type DTO Chain.BlockNo = Word64

instance ToDTO Chain.BlockNo where
  toDTO = coerce

instance HasDTO Chain.BlockHeaderHash where
  type DTO Chain.BlockHeaderHash = Web.Base16

instance ToDTO Chain.BlockHeaderHash where
  toDTO = coerce

data ContractRecord = forall v. ContractRecord
  (MarloweVersion v)
  ContractId
  Chain.BlockHeader
  (CreateStep v)
  (Maybe (TransactionScriptOutput v))

data SomeTransaction = forall v. SomeTransaction
  (MarloweVersion v)
  (Transaction v)

instance HasDTO ContractRecord where
  type DTO ContractRecord = Web.ContractState

instance ToDTO ContractRecord where
  toDTO (ContractRecord MarloweV1 contractId block CreateStep{..} output) =
    Web.ContractState
      { contractId = toDTO contractId
      , roleTokenMintingPolicyId = toDTO
          $ fromPlutusCurrencySymbol
          $ Sem.rolesCurrency
          $ Sem.marloweParams
          $ datum createOutput
      , version = Web.V1
      , metadata = mempty -- TODO
      , status = Web.Confirmed
      , block = Just $ toDTO block
      , initialContract = Sem.marloweContract $ datum createOutput
      , currentContract = maybe Sem.Close (Sem.marloweContract . datum) output
      , state = Sem.marloweState . datum <$> output
      , utxo = toDTO . utxo <$> output
      }

instance HasDTO SomeTransaction where
  type DTO SomeTransaction = Web.TxHeader

instance ToDTO SomeTransaction where
  toDTO (SomeTransaction MarloweV1 Transaction{..}) =
    Web.TxHeader
      { contractId = toDTO contractId
      , transactionId = toDTO transactionId
      , status = Web.Confirmed
      , block = Just $ toDTO blockHeader
      , utxo = toDTO . utxo <$> scriptOutput output
      }

instance HasDTO Chain.Address where
  type DTO Chain.Address = Web.Address

instance ToDTO Chain.Address where
  toDTO address = Web.Address $ fromMaybe (T.pack $ show address) $ Chain.toBech32 address

instance FromDTO Chain.Address where
  fromDTO = Chain.fromBech32 . Web.unAddress

instance HasDTO (TxBody era) where
  type DTO (TxBody era) = Web.TextEnvelope

instance IsCardanoEra era => ToDTO (TxBody era) where
  toDTO = toDTO . serialiseToTextEnvelope Nothing

instance IsCardanoEra era => FromDTO (TxBody era) where
  fromDTO = hush . deserialiseFromTextEnvelope asType <=< fromDTO
    where
      asType = AsTxBody $ cardanoEraToAsType $ cardanoEra @era

instance HasDTO TextEnvelope where
  type DTO TextEnvelope = Web.TextEnvelope

instance ToDTO TextEnvelope where
  toDTO TextEnvelope
    { teType = TextEnvelopeType teType
    , teDescription = TextEnvelopeDescr teDescription
    , teRawCBOR
    } = Web.TextEnvelope
      { teType = T.pack teType
      , teDescription = T.pack teDescription
      , teCborHex = Web.Base16 teRawCBOR
      }

instance FromDTO TextEnvelope where
  fromDTO Web.TextEnvelope
    { teType
    , teDescription
    , teCborHex
    } = Just TextEnvelope
      { teType = TextEnvelopeType $ T.unpack teType
      , teDescription = TextEnvelopeDescr $ T.unpack teDescription
      , teRawCBOR = Web.unBase16 teCborHex
      }

instance HasDTO RoleTokensConfig where
  type DTO RoleTokensConfig = Maybe Web.RolesConfig

instance FromDTO RoleTokensConfig where
  fromDTO = \case
    Nothing -> pure RoleTokensNone
    Just (Web.UsePolicy policy) -> RoleTokensUsePolicy <$> fromDTO policy
    Just (Web.Mint mint) -> RoleTokensMint <$> fromDTO mint

instance HasDTO Mint where
  type DTO Mint = Map Text Web.RoleTokenConfig

instance FromDTO Mint where
  fromDTO = fmap mkMint
    . traverse (sequence . bimap tokenNameToText convertConfig)
    <=< toNonEmpty
    . Map.toList
    where
      convertConfig = \case
        Web.RoleTokenSimple address -> (,Left 1) <$> fromDTO address
        Web.RoleTokenAdvanced address metadata -> curry (second $ Right . Just)
          <$> fromDTO address
          <*> fromDTO metadata

instance HasDTO NFTMetadata where
  type DTO NFTMetadata = Web.TokenMetadata

instance FromDTO NFTMetadata where
  fromDTO = mkNFTMetadata <=< Chain.fromJSONEncodedMetadata . toJSON

tokenNameToText :: Text -> Chain.TokenName
tokenNameToText = Chain.TokenName . fromString . T.unpack

toNonEmpty :: [a] -> Maybe (NonEmpty a)
toNonEmpty [] = Nothing
toNonEmpty (a : as) = Just $ a :| as
