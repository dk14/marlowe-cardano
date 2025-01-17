{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TupleSections #-}

module Language.Marlowe.CLI.Test.Runtime.Types
  where

import Cardano.Api (CardanoMode, LocalNodeConnectInfo, ScriptDataSupportedInEra)
import qualified Cardano.Api as C
import qualified Contrib.Data.List as List
import qualified Contrib.Data.Time.Units.Aeson as A
import Control.Concurrent.STM (TChan, TVar)
import Control.Lens (Lens', Traversal', makeLenses)
import Control.Monad.Except (MonadError)
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Reader.Class (MonadReader)
import Control.Monad.State.Class (MonadState)
import Data.Aeson (FromJSON)
import qualified Data.Aeson as A
import Data.Aeson.Types (ToJSON)
import Data.Map (Map)
import Data.Time.Units
import Data.Word (Word64)
import GHC.Generics (Generic)
import Language.Marlowe.CLI.Test.Contract (ContractNickname)
import qualified Language.Marlowe.CLI.Test.Contract as Contract
import Language.Marlowe.CLI.Test.Contract.ParametrizedMarloweJSON
import Language.Marlowe.CLI.Test.ExecutionMode (ExecutionMode)
import Language.Marlowe.CLI.Test.InterpreterError (InterpreterError)
import qualified Language.Marlowe.CLI.Test.Log as Log
import Language.Marlowe.CLI.Test.Operation.Aeson
  (ConstructorName(ConstructorName), NewPropName(NewPropName), OldPropName(OldPropName), rewriteProp, rewritePropWith)
import qualified Language.Marlowe.CLI.Test.Operation.Aeson as Operation
import Language.Marlowe.CLI.Test.Wallet.Types (Currencies, CurrencyNickname, WalletNickname, Wallets)
import qualified Language.Marlowe.CLI.Test.Wallet.Types as Wallet
import Language.Marlowe.Cardano.Thread (AnyMarloweThread, MarloweThread, anyMarloweThreadInputsApplied)
import qualified Language.Marlowe.Core.V1.Semantics.Types as M
import qualified Language.Marlowe.Protocol.Client as Marlowe.Protocol
import qualified Language.Marlowe.Protocol.Types as Marlowe.Protocol
import Language.Marlowe.Runtime.Core.Api (ContractId)
import Ledger.Orphans ()
import qualified Network.Protocol.Connection as Network.Protocol
import Network.Protocol.Handshake.Types (Handshake)

-- | We use TxId in the thread to perform awaits for a particular marlowe transaction.
type RuntimeMonitorTxInfo = C.TxId

type RuntimeMonitorMarloweThread = MarloweThread RuntimeMonitorTxInfo

type AnyRuntimeMonitorMarloweThread = AnyMarloweThread RuntimeMonitorTxInfo

anyRuntimeMonitorMarloweThreadInputsApplied
  :: C.TxId
  -> Maybe C.TxIx
  -> [M.Input]
  -> AnyRuntimeMonitorMarloweThread
  -> Maybe AnyRuntimeMonitorMarloweThread
anyRuntimeMonitorMarloweThreadInputsApplied txId possibleTxIx = do
  let
    possibleTxIn = C.TxIn txId <$> possibleTxIx
  anyMarloweThreadInputsApplied txId possibleTxIn

-- | To avoid confusion we have a separate type for submitted transaction
-- | in the main interpreter thread. We use these to await for runtime
-- | confirmations.
newtype RuntimeTxInfo = RuntimeTxInfo C.TxId
  deriving stock (Eq, Generic, Show)

type RuntimeInterpreterMarloweThread = MarloweThread RuntimeTxInfo

type AnyRuntimeInterpreterMarloweThread = AnyMarloweThread RuntimeTxInfo

anyRuntimeInterpreterMarloweThreadInputsApplied
  :: C.TxId
  -> Maybe C.TxIx
  -> [M.Input]
  -> AnyRuntimeInterpreterMarloweThread
  -> Maybe AnyRuntimeInterpreterMarloweThread
anyRuntimeInterpreterMarloweThreadInputsApplied txId possibleTxIx = do
  let
    possibleTxIn = C.TxIn txId <$> possibleTxIx
    txInfo = RuntimeTxInfo txId
  anyMarloweThreadInputsApplied txInfo possibleTxIn

data RuntimeError
  = RuntimeConnectionError
  | RuntimeExecutionFailure String
  | RuntimeContractNotFound ContractId
  | RuntimeRollbackError ContractNickname
  deriving stock (Eq, Generic, Show)
  deriving anyclass (A.ToJSON, A.FromJSON)

newtype RuntimeContractInfo =
  RuntimeContractInfo
    { _rcMarloweThread :: AnyRuntimeMonitorMarloweThread
    }

newtype RuntimeMonitorInput = RuntimeMonitorInput (TChan (ContractNickname, ContractId))

newtype RuntimeMonitorState = RuntimeMonitorState (TVar (Map ContractNickname RuntimeContractInfo))

newtype RuntimeMonitor = RuntimeMonitor { runMonitor :: IO RuntimeError }

defaultOperationTimeout :: Second
defaultOperationTimeout = 30

data RuntimeOperation
  = RuntimeAwaitTxsConfirmed
    {
      roContractNickname :: Maybe ContractNickname
    , roTimeout :: Maybe A.Second
    }
  | RuntimeAwaitClosed
    {
      roContractNickname :: Maybe ContractNickname
    , roTimeout :: Maybe A.Second
    }
  | RuntimeCreateContract
    {
      roContractNickname :: Maybe ContractNickname
    , roSubmitter :: Maybe WalletNickname
    -- ^ A wallet which gonna submit the initial transaction.
    , roMinLovelace :: Word64
    , roRoleCurrency :: Maybe CurrencyNickname
    -- ^ If contract uses roles then currency is required.
    , roContractSource :: Contract.Source
    -- ^ The Marlowe contract to be created.
    , roAwaitConfirmed :: Maybe A.Second
    -- ^ How long to wait for the transaction to be confirmed in the Runtime. By default we don't wait.
    }
  | RuntimeApplyInputs
    {
      roContractNickname :: Maybe ContractNickname
    , roInputs :: [ParametrizedMarloweJSON]
    -- ^ Inputs to the contract.
    , roSubmitter :: Maybe WalletNickname
    -- ^ A wallet which gonna submit the initial transaction.
    , roAwaitConfirmed :: Maybe A.Second
    -- ^ How long to wait for the transaction to be confirmed in the Runtime. By default we don't wait.
    }
  | RuntimeWithdraw
    {
      roContractNickname :: Maybe ContractNickname
    , roWallets :: Maybe [WalletNickname] -- ^ Wallets with role tokens. By default we find all the role tokens and use them.
    , roAwaitConfirmed :: Maybe A.Second -- ^ How long to wait for the transactions to be confirmed in the Runtime. By default we don't wait.
    }
  deriving stock (Eq, Generic, Show)

instance FromJSON RuntimeOperation where
  parseJSON = do
    let
      preprocess = do
        let
          rewriteCreate = do
            let
              constructorName = ConstructorName "RuntimeCreateContract"
              rewriteTemplate = rewritePropWith
                constructorName
                (OldPropName "template")
                (NewPropName "contractSource")
                (A.object . List.singleton . ("template",))
              rewriteContract = rewritePropWith
                constructorName
                (OldPropName "source")
                (NewPropName "contractSource")
                (A.object . List.singleton . ("inline",))
              rewriteContractNickname = rewriteProp
                constructorName
                (OldPropName "nickname")
                (NewPropName "contractNickname")
            rewriteTemplate <> rewriteContract <> rewriteContractNickname
          rewriteWithdraw = do
            let
              constructorName = ConstructorName "RuntimeWithdraw"
              rewriteWallet = rewritePropWith
                constructorName
                (OldPropName "wallet")
                (NewPropName "wallets")
                (A.toJSON . List.singleton)
            rewriteWallet
        rewriteCreate <> rewriteWithdraw
    Operation.parseConstructorBasedJSON "ro" preprocess

instance ToJSON RuntimeOperation where
  toJSON = Operation.toConstructorBasedJSON "ro"

data ContractInfo = ContractInfo
  { _ciContractId :: ContractId
  , _ciRoleCurrency :: Maybe CurrencyNickname
  -- ^ If the contract uses roles then currency is required.
  , _ciMarloweThread :: AnyRuntimeInterpreterMarloweThread
  }

makeLenses 'ContractInfo

class HasInterpretState st era | st -> era where
  knownContractsL :: Lens' st (Map ContractNickname ContractInfo)
  walletsL :: Lens' st (Wallets era)
  currenciesL :: Lens' st Currencies

class HasInterpretEnv env era | env -> era where
  runtimeMonitorStateT :: Traversal' env RuntimeMonitorState
  runtimeMonitorInputT :: Traversal' env RuntimeMonitorInput
  runtimeClientConnectorT :: Traversal' env (Network.Protocol.ClientConnector (Handshake Marlowe.Protocol.MarloweRuntime) Marlowe.Protocol.MarloweRuntimeClient IO)
  -- runtimeClientConnectorT :: Traversal' env (Network.Protocol.SomeClientConnector Marlowe.Protocol.MarloweRuntimeClient IO)
  executionModeL :: Lens' env ExecutionMode
  connectionT :: Traversal' env (LocalNodeConnectInfo CardanoMode)
  eraL :: Lens' env (ScriptDataSupportedInEra era)

type InterpretMonad env st m era =
  ( MonadState st m
  , HasInterpretState st era
  , MonadReader env m
  , HasInterpretEnv env era
  , Wallet.InterpretMonad env st m era
  , MonadError InterpreterError m
  , MonadIO m
  , Log.HasLogStore st
  )

makeLenses 'RuntimeContractInfo
