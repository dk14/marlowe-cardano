{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
module Language.Marlowe.Runtime.Integration.Common
  where

import Cardano.Api
  ( AsType(..)
  , BabbageEra
  , CardanoEra(..)
  , CtxTx
  , ShelleyWitnessSigningKey(..)
  , TxBody(..)
  , TxBodyContent(..)
  , TxOut(..)
  , getTxId
  , signShelleyTransaction
  )
import Cardano.Api.Byron (deserialiseFromTextEnvelope)
import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Reader (ReaderT, runReaderT)
import Control.Monad.Reader.Class (asks)
import Data.Aeson (FromJSON(..), Value(..), decodeFileStrict, eitherDecodeStrict)
import Data.Aeson.Types (parseFail)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.ByteString.Base16 (decodeBase16)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.String (fromString)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import qualified Data.Text.Encoding as T
import Data.Time (NominalDiffTime, diffUTCTime, getCurrentTime, secondsToNominalDiffTime)
import Data.Word (Word64)
import GHC.Generics (Generic)
import Language.Marlowe (ChoiceId(..), Input(..), InputContent(..), Party, Token)
import Language.Marlowe.Protocol.HeaderSync.Client (MarloweHeaderSyncClient, hoistMarloweHeaderSyncClient)
import qualified Language.Marlowe.Protocol.HeaderSync.Client as HeaderSync
import Language.Marlowe.Protocol.Query.Client (MarloweQueryClient, hoistMarloweQueryClient)
import Language.Marlowe.Protocol.Sync.Client (MarloweSyncClient, hoistMarloweSyncClient)
import qualified Language.Marlowe.Protocol.Sync.Client as MarloweSync
import Language.Marlowe.Runtime.Cardano.Api
  (fromCardanoAddressInEra, fromCardanoTxId, fromCardanoTxOutDatum, fromCardanoTxOutValue)
import Language.Marlowe.Runtime.ChainSync.Api
  ( Assets(..)
  , BlockHeader(..)
  , BlockHeaderHash(..)
  , BlockNo(..)
  , SlotNo(..)
  , TokenName
  , TransactionMetadata(..)
  , TxId
  , TxIx
  , TxOutRef(..)
  , fromBech32
  )
import Language.Marlowe.Runtime.Core.Api
  ( ContractId(..)
  , MarloweVersion(..)
  , MarloweVersionTag(..)
  , Payout(..)
  , SomeMarloweVersion(..)
  , Transaction(..)
  , TransactionOutput(..)
  , TransactionScriptOutput(..)
  , fromChainPayoutDatum
  )
import Language.Marlowe.Runtime.Discovery.Api (ContractHeader(..))
import Language.Marlowe.Runtime.History.Api (ContractStep, CreateStep(..))
import Language.Marlowe.Runtime.Transaction.Api
  (ContractCreated(..), InputsApplied(..), MarloweTxCommand(..), WalletAddresses(WalletAddresses))
import Network.Protocol.Driver (runSomeConnector)
import Network.Protocol.Job.Client (JobClient, hoistJobClient, liftCommand, liftCommandWait)
import qualified Plutus.V2.Ledger.Api as PV2
import Test.Hspec (shouldBe)
import Test.Integration.Marlowe (LocalTestnet(..), MarloweRuntime, PaymentKeyPair(..), SpoNode(..), execCli)
import qualified Test.Integration.Marlowe.Local as MarloweRuntime
import UnliftIO (MonadUnliftIO(withRunInIO), bracket_)
import UnliftIO.Environment (setEnv, unsetEnv)

type Integration = ReaderT MarloweRuntime IO

data Wallet = Wallet
  { addresses :: WalletAddresses
  , signingKeys :: [ShelleyWitnessSigningKey]
  }

runIntegrationTest :: Integration a -> MarloweRuntime -> IO a
runIntegrationTest = runReaderT

expectJust :: MonadFail m => String -> Maybe a -> m a
expectJust msg = \case
  Nothing -> fail msg
  Just a -> pure a

expectRight :: MonadFail m => Show a => String -> Either a b -> m b
expectRight msg = \case
  Left a -> fail $ msg <> ": " <> show a
  Right b -> pure b

runMarloweQueryClient :: MarloweQueryClient Integration a -> Integration a
runMarloweQueryClient client = do
  connector <- asks MarloweRuntime.marloweQueryConnector
  withRunInIO \runInIO -> runSomeConnector connector $ hoistMarloweQueryClient runInIO client

runMarloweSyncClient :: MarloweSyncClient Integration a -> Integration a
runMarloweSyncClient client = do
  connector <- asks MarloweRuntime.marloweSyncConnector
  withRunInIO \runInIO -> runSomeConnector connector $ hoistMarloweSyncClient runInIO client

runMarloweHeaderSyncClient :: MarloweHeaderSyncClient Integration a -> Integration a
runMarloweHeaderSyncClient client = do
  connector <- asks MarloweRuntime.marloweHeaderSyncConnector
  withRunInIO \runInIO -> runSomeConnector connector $ hoistMarloweHeaderSyncClient runInIO client

runTxJobClient :: JobClient MarloweTxCommand Integration a -> Integration a
runTxJobClient client = do
  connector <- asks MarloweRuntime.txJobConnector
  withRunInIO \runInIO -> runSomeConnector connector $ hoistJobClient runInIO client

testnet :: Integration LocalTestnet
testnet = asks MarloweRuntime.testnet

getGenesisWallet :: Int -> Integration Wallet
getGenesisWallet walletIx = do
  LocalTestnet{..} <- testnet
  let PaymentKeyPair{..} = wallets !! walletIx
  mAddress <- fromBech32 . fromString <$> execCli
    [ "address", "build"
    , "--verification-key-file", paymentVKey
    , "--testnet-magic", "1"
    ]
  address <- expectJust "Failed to decode address" mAddress
  mTextEnvelope <- liftIO $ decodeFileStrict paymentSKey
  textEnvelope <- expectJust "Failed to decode signing key text envelope" mTextEnvelope
  genesisUTxOKey <- expectRight  "failed to decode text envelope"
    $ deserialiseFromTextEnvelope (AsSigningKey AsGenesisUTxOKey) textEnvelope
  pure Wallet
    { addresses = WalletAddresses address mempty mempty
    , signingKeys = [WitnessGenesisUTxOKey genesisUTxOKey]
    }

newtype CliHash = CliHash { unCliHash :: ByteString }

instance FromJSON CliHash where
  parseJSON = \case
    String s -> either (parseFail . T.unpack) (pure . CliHash) $ decodeBase16 $ encodeUtf8 s
    _ -> parseFail "Expected a string"

data CliBlockHeader = CliBlockHeader
  { block :: Word64
  , hash :: CliHash
  , slot :: Word64
  }
  deriving (Generic, FromJSON)

getTip :: Integration BlockHeader
getTip = do
  LocalTestnet{..} <- testnet
  let SpoNode{..} = head spoNodes
  output <- bracket_ (setEnv "CARDANO_NODE_SOCKET_PATH" socket) (unsetEnv "CARDANO_NODE_SOCKET_PATH") $ liftIO $ execCli
    [ "query", "tip"
    , "--testnet-magic", show testnetMagic
    ]
  CliBlockHeader{..} <- expectRight "Failed to decode tip" $ eitherDecodeStrict $ T.encodeUtf8 $ T.pack output
  pure $ BlockHeader (SlotNo slot) (BlockHeaderHash $ unCliHash hash) (BlockNo block)

submit
  :: Wallet
  -> TxBody BabbageEra
  -> Integration BlockHeader
submit Wallet{..} txBody = do
  let tx = signShelleyTransaction txBody signingKeys
  submitResult <- runTxJobClient $ liftCommandWait $ Submit tx
  expectRight "failed to submit tx" $ first (tx,) submitResult

deposit
  :: Wallet
  -> ContractId
  -> Party
  -> Party
  -> Token
  -> Integer
  -> Integration (InputsApplied BabbageEra 'V1)
deposit Wallet{..} contractId intoAccount fromParty ofToken quantity = do
  result <- runTxJobClient $ liftCommand $ ApplyInputs
    MarloweV1
    addresses
    contractId
    mempty
    Nothing
    Nothing
    [NormalInput $ IDeposit intoAccount fromParty ofToken quantity]
  expectRight "Failed to create deposit transaction" result

choose
  :: Wallet
  -> ContractId
  -> PV2.BuiltinByteString
  -> Party
  -> Integer
  -> Integration (InputsApplied BabbageEra 'V1)
choose Wallet{..} contractId choice party chosenNum = do
  result <- runTxJobClient $ liftCommand $ ApplyInputs
    MarloweV1
    addresses
    contractId
    mempty
    Nothing
    Nothing
    [NormalInput $ IChoice (ChoiceId choice party) chosenNum]
  expectRight "Failed to create choice transaction" result

notify
  :: Wallet
  -> ContractId
  -> Integration (InputsApplied BabbageEra 'V1)
notify Wallet{..} contractId = do
  result <- runTxJobClient $ liftCommand $ ApplyInputs
    MarloweV1
    addresses
    contractId
    mempty
    Nothing
    Nothing
    [NormalInput INotify]
  expectRight "Failed to create notify transaction" result

withdraw
  :: Wallet
  -> ContractId
  -> TokenName
  -> Integration (TxBody BabbageEra)
withdraw Wallet{..} contractId role = do
  result <- runTxJobClient $ liftCommand $ Withdraw MarloweV1 addresses contractId role
  expectRight "Failed to create withdraw transaction" result

timeout :: NominalDiffTime
timeout = secondsToNominalDiffTime 2

retryDelayMicroSeconds :: Int
retryDelayMicroSeconds = 100_000

contractCreatedToCreateStep :: ContractCreated BabbageEra v -> CreateStep v
contractCreatedToCreateStep ContractCreated{..} = CreateStep
  { createOutput = TransactionScriptOutput
      { address = marloweScriptAddress
      , assets = Assets 2_000_000 mempty
      , utxo = unContractId contractId
      , datum
      }
  , metadata = mempty
  , payoutValidatorHash = payoutScriptHash
  }

inputsAppliedToTransaction :: BlockHeader -> InputsApplied BabbageEra v -> Transaction v
inputsAppliedToTransaction blockHeader InputsApplied{..} = Transaction
  { transactionId = fromCardanoTxId $ getTxId txBody
  , contractId
  , metadata = mempty
  , blockHeader
  , validityLowerBound = invalidBefore
  , validityUpperBound = invalidHereafter
  , inputs
  , output = TransactionOutput
      { payouts = foldMap (uncurry $ txOutToPayout version $ fromCardanoTxId $ getTxId txBody) case txBody of
          TxBody TxBodyContent{..} -> zip [0..] txOuts
      , scriptOutput = output
      }
  }

txOutToPayout :: MarloweVersion v -> TxId -> TxIx -> TxOut CtxTx BabbageEra -> Map TxOutRef (Payout v)
txOutToPayout version txId txIx (TxOut address value datum _) = case snd $ fromCardanoTxOutDatum datum of
  Just datum' -> case fromChainPayoutDatum version datum' of
    Just payoutDatum -> Map.singleton (TxOutRef txId txIx) Payout
      { address = fromCardanoAddressInEra BabbageEra address
      , assets = fromCardanoTxOutValue value
      , datum = payoutDatum
      }
    Nothing -> mempty
  Nothing -> mempty

contractCreatedToContractHeader :: BlockHeader -> ContractCreated BabbageEra v -> ContractHeader
contractCreatedToContractHeader blockHeader ContractCreated{..} = ContractHeader
  { contractId
  , rolesCurrency
  , metadata = TransactionMetadata metadata
  , marloweScriptHash
  , marloweScriptAddress
  , payoutScriptHash
  , marloweVersion = SomeMarloweVersion version
  , blockHeader
  }

headerSyncPollExpectWait
  :: MonadFail m
  => m (HeaderSync.ClientStWait m a)
  -> HeaderSync.ClientStWait m a
headerSyncPollExpectWait = HeaderSync.SendMsgPoll . headerSyncExpectWait

headerSyncRequestNextExpectWait
  :: MonadFail m
  => m (HeaderSync.ClientStWait m a)
  -> HeaderSync.ClientStIdle m a
headerSyncRequestNextExpectWait = HeaderSync.SendMsgRequestNext . headerSyncExpectWait

headerSyncPollExpectNewHeaders
  :: (MonadFail m, MonadIO m)
  => BlockHeader
  -> [ContractHeader]
  -> m (HeaderSync.ClientStIdle m a)
  -> m (HeaderSync.ClientStWait m a)
headerSyncPollExpectNewHeaders block headers next = HeaderSync.SendMsgPoll <$> headerSyncExpectNewHeaders \block' headers' -> do
  liftIO $ block' `shouldBe` block
  liftIO $ headers' `shouldBe` headers
  next

headerSyncRequestNextExpectNewHeaders
  :: (MonadFail m, MonadIO m)
  => BlockHeader
  -> [ContractHeader]
  -> m (HeaderSync.ClientStIdle m a)
  -> m (HeaderSync.ClientStIdle m a)
headerSyncRequestNextExpectNewHeaders block headers next = HeaderSync.SendMsgRequestNext <$> headerSyncExpectNewHeaders \block' headers' -> do
  liftIO $ block' `shouldBe` block
  liftIO $ headers' `shouldBe` headers
  next

headerSyncExpectWait
  :: MonadFail m
  => m (HeaderSync.ClientStWait m a)
  -> HeaderSync.ClientStNext m a
headerSyncExpectWait action = HeaderSync.ClientStNext
  { recvMsgNewHeaders = \_ _ -> fail "Expected wait, got new headers"
  , recvMsgRollBackward = \_ -> fail "Expected wait, got roll backward"
  , recvMsgWait = action
  }

headerSyncExpectNewHeaders
  :: (MonadIO m, MonadFail m)
  => (BlockHeader -> [ContractHeader] -> m (HeaderSync.ClientStIdle m a))
  -> m (HeaderSync.ClientStNext m a)
headerSyncExpectNewHeaders recvMsgNewHeaders = do
  startTime <- liftIO getCurrentTime
  let
    next = HeaderSync.ClientStNext
      { recvMsgNewHeaders
      , recvMsgRollBackward = \_ -> fail "Expected new headers, got roll backward"
      , recvMsgWait = do
          time <- liftIO getCurrentTime
          if (time `diffUTCTime` startTime) > timeout
            then fail "Expected new headers, got wait"
            else do
              liftIO $ threadDelay retryDelayMicroSeconds
              pure $ HeaderSync.SendMsgPoll next
      }
  pure next

marloweSyncExpectContractFound
  :: MonadFail m
  => (forall v. BlockHeader -> MarloweVersion v -> CreateStep v -> m (MarloweSync.ClientStIdle v m a))
  -> MarloweSync.ClientStFollow m a
marloweSyncExpectContractFound recvMsgContractFound = MarloweSync.ClientStFollow
  { recvMsgContractNotFound = fail "Expected contract found, got contract not found"
  , recvMsgContractFound
  }

marloweSyncExpectRollForward
  :: (MonadFail m, MonadIO m)
  => (BlockHeader -> [ContractStep v] -> m (MarloweSync.ClientStIdle v m a))
  -> m (MarloweSync.ClientStNext v m a)
marloweSyncExpectRollForward recvMsgRollForward = do
  startTime <- liftIO getCurrentTime
  let
    next = MarloweSync.ClientStNext
      { recvMsgRollBackCreation = fail "Expected roll forward, got roll back creation"
      , recvMsgRollBackward = \_ -> fail "Expected roll forward, got roll backward"
      , recvMsgWait = do
          time <- liftIO getCurrentTime
          if (time `diffUTCTime` startTime) > timeout
            then fail "Expected roll forward, got wait"
            else do
              liftIO $ threadDelay retryDelayMicroSeconds
              pure $ MarloweSync.SendMsgPoll next
      , recvMsgRollForward
      }
  pure next

headerSyncIntersectExpectNotFound :: [BlockHeader] -> Integration ()
headerSyncIntersectExpectNotFound points = runMarloweHeaderSyncClient
  $ HeaderSync.MarloweHeaderSyncClient
  $ pure
  $ HeaderSync.SendMsgIntersect points HeaderSync.ClientStIntersect
    { recvMsgIntersectNotFound = pure $ HeaderSync.SendMsgDone ()
    , recvMsgIntersectFound = \_ -> fail "Expected intersect not found, got intersect found"
    }

headerSyncIntersectExpectFound
  :: [BlockHeader]
  -> BlockHeader
  -> [BlockHeader]
  -> Integration ()
headerSyncIntersectExpectFound points expectedIntersection remainingPoints = runMarloweHeaderSyncClient
  $ HeaderSync.MarloweHeaderSyncClient
  $ pure
  $ HeaderSync.SendMsgIntersect points HeaderSync.ClientStIntersect
    { recvMsgIntersectNotFound = fail "Expected intersect found, got intersect not found"
    , recvMsgIntersectFound = \actualIntersection -> do
        liftIO $ actualIntersection `shouldBe` expectedIntersection
        expectRemainingPoints remainingPoints
    }
  where
    expectRemainingPoints [] = pure
      $ headerSyncRequestNextExpectWait
      $ pure
      $ HeaderSync.SendMsgCancel
      $ HeaderSync.SendMsgDone ()
    expectRemainingPoints (x : xs) = HeaderSync.SendMsgRequestNext <$> headerSyncExpectNewHeaders \block _ -> do
      liftIO $ block `shouldBe` x
      expectRemainingPoints xs

marloweSyncIntersectExpectNotFound :: ContractId -> [BlockHeader] -> Integration ()
marloweSyncIntersectExpectNotFound contractId points = runMarloweSyncClient
  $ MarloweSync.MarloweSyncClient
  $ pure
  $ MarloweSync.SendMsgIntersect contractId MarloweV1 points MarloweSync.ClientStIntersect
    { recvMsgIntersectNotFound = pure ()
    , recvMsgIntersectFound = \_ -> fail "Expected intersect not found, got intersect found"
    }

marloweSyncIntersectExpectFound
  :: ContractId
  -> [BlockHeader]
  -> BlockHeader
  -> [BlockHeader]
  -> Integration ()
marloweSyncIntersectExpectFound contractId points expectedIntersection remainingPoints = runMarloweSyncClient
  $ MarloweSync.MarloweSyncClient
  $ pure
  $ MarloweSync.SendMsgIntersect contractId MarloweV1 points MarloweSync.ClientStIntersect
    { recvMsgIntersectNotFound = fail "Expected intersect found, got intersect not found"
    , recvMsgIntersectFound = \actualIntersection -> do
        liftIO $ actualIntersection `shouldBe` expectedIntersection
        expectRemainingPoints remainingPoints
    }
  where
    expectRemainingPoints [] = pure
      $ marloweSyncRequestNextExpectWait
      $ pure
      $ MarloweSync.SendMsgCancel
      $ MarloweSync.SendMsgDone ()
    expectRemainingPoints (x : xs) = MarloweSync.SendMsgRequestNext <$> marloweSyncExpectRollForward \block _ -> do
      liftIO $ block `shouldBe` x
      expectRemainingPoints xs

marloweSyncPollExpectWait
  :: MonadFail m => m (MarloweSync.ClientStWait v m a)
  -> MarloweSync.ClientStWait v m a
marloweSyncPollExpectWait = MarloweSync.SendMsgPoll . marloweSyncExpectWait

marloweSyncPollExpectRollForward
  :: (Show (ContractStep v), Eq (ContractStep v), MonadIO m, MonadFail m)
  => BlockHeader
  -> [ContractStep v]
  -> m (MarloweSync.ClientStIdle v m a)
  -> m (MarloweSync.ClientStWait v m a)
marloweSyncPollExpectRollForward expectedBlock expectedSteps next =
  MarloweSync.SendMsgPoll <$> marloweSyncExpectRollForward \actualBlock actualSteps -> do
    liftIO $ actualBlock `shouldBe` expectedBlock
    liftIO $ actualSteps `shouldBe` expectedSteps
    next

marloweSyncRequestNextExpectWait
  :: MonadFail m => m (MarloweSync.ClientStWait v m a)
  -> MarloweSync.ClientStIdle v m a
marloweSyncRequestNextExpectWait = MarloweSync.SendMsgRequestNext . marloweSyncExpectWait

marloweSyncRequestNextExpectRollForward
  :: (Show (ContractStep v), Eq (ContractStep v), MonadIO m, MonadFail m)
  => BlockHeader
  -> [ContractStep v]
  -> m (MarloweSync.ClientStIdle v m a)
  -> m (MarloweSync.ClientStIdle v m a)
marloweSyncRequestNextExpectRollForward expectedBlock expectedSteps next =
  MarloweSync.SendMsgRequestNext <$> marloweSyncExpectRollForward \actualBlock actualSteps -> do
    liftIO $ actualBlock `shouldBe` expectedBlock
    liftIO $ actualSteps `shouldBe` expectedSteps
    next

marloweSyncExpectWait
  :: MonadFail m => m (MarloweSync.ClientStWait v m a)
  -> MarloweSync.ClientStNext v m a
marloweSyncExpectWait recvMsgWait = MarloweSync.ClientStNext
  { recvMsgRollBackCreation = fail "Expected wait, got roll back creation"
  , recvMsgRollBackward = \_ -> fail "Expected wait, got roll backward"
  , recvMsgWait
  , recvMsgRollForward = \_ _ -> fail "Expected wait, got roll forward"
  }
