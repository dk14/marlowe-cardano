{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TemplateHaskell #-}

module Language.Marlowe.Runtime.Web.Server.SyncClient
  where

import Control.Arrow (arr)
import Control.Concurrent.Component
import Control.Concurrent.STM (STM, atomically)
import Control.Error (note)
import Control.Monad (guard, mfilter)
import Control.Monad.IO.Class (liftIO)
import Data.List (uncons)
import Language.Marlowe.Protocol.Query.Client
  (MarloweQueryClient, getContractHeaders, getContractState, getTransaction, getTransactions)
import Language.Marlowe.Protocol.Query.Types (SomeContractState, SomeTransaction(..), SomeTransactions(..))
import qualified Language.Marlowe.Protocol.Query.Types as Query
import Language.Marlowe.Runtime.ChainSync.Api (TxId)
import Language.Marlowe.Runtime.Core.Api (ContractId, MarloweVersion(MarloweV1), MarloweVersionTag(..), Transaction(..))
import Language.Marlowe.Runtime.Discovery.Api (ContractHeader)
import Language.Marlowe.Runtime.Transaction.Api (ContractCreated, InputsApplied(..))
import Language.Marlowe.Runtime.Web.Server.TxClient (TempTx(..))
import Language.Marlowe.Runtime.Web.Server.Util (applyRangeToAscList)
import Servant.Pagination

data SyncClientDependencies r = SyncClientDependencies
  { runMarloweQueryClient :: forall a. MarloweQueryClient IO a -> IO a
  , lookupTempContract :: ContractId -> STM (Maybe (TempTx ContractCreated))
  , lookupTempTransaction :: ContractId -> TxId -> STM (Maybe (TempTx InputsApplied))
  }

-- | Signature for a delegate that loads a list of contract headers.
type LoadContractHeaders m
   = Query.Range ContractId
  -> m (Maybe (Query.Page ContractId ContractHeader)) -- ^ Nothing if the initial ID is not found

-- | Signature for a delegate that loads the state of a single contract.
type LoadContract r m
   = ContractId               -- ^ ID of the contract to load
  -> m (Maybe (Either (TempTx ContractCreated) SomeContractState)) -- ^ Nothing if the ID is not found

data LoadTxError
  = ContractNotFound
  | TxNotFound

-- | Signature for a delegate that loads a list of transactions for a contract.
type LoadTransactions r m
   = ContractId -- ^ ID of the contract to load transactions for.
  -> Query.Range TxId -- ^ The range of transactions to load.
  -> m (Either LoadTxError (Query.Page TxId (Transaction 'V1)))

-- | Signature for a delegate that loads a transaction for a contract.
type LoadTransaction r m
   = ContractId -- ^ ID of the contract to load transactions for.
  -> TxId -- ^ ID of the transaction to load.
  -> m (Maybe (Either (TempTx InputsApplied) SomeTransaction))

-- | Public API of the SyncClient
data SyncClient r = SyncClient
  { loadContract :: LoadContract r IO
  , loadTransactions :: LoadTransactions r IO
  , loadTransaction :: LoadTransaction r IO
  , loadContractHeaders :: LoadContractHeaders IO
  }

syncClient :: Component IO (SyncClientDependencies r) (SyncClient r)
syncClient = arr \SyncClientDependencies{..} -> SyncClient
  { loadContractHeaders = runMarloweQueryClient . getContractHeaders
  , loadContract = \contractId -> runMarloweQueryClient do
      result <- getContractState contractId
      case result of
        Nothing -> liftIO $ atomically $ fmap Left <$> lookupTempContract contractId
        Just contract -> pure $ Just $ Right contract
  , loadTransaction = \contractId txId -> runMarloweQueryClient do
      result <- getTransaction txId
      let matchesContract (SomeTransaction _ _ _ Transaction{contractId=cid}) = cid == contractId
      case mfilter matchesContract result of
        Nothing -> liftIO $ atomically $ fmap Left <$> lookupTempTransaction contractId txId
        Just contract -> pure $ Just $ Right contract
  , loadTransactions = \contractId Query.Range{..} -> runMarloweQueryClient do
      mTxs <- getTransactions contractId
      pure do
        SomeTransactions MarloweV1 txs <- note ContractNotFound mTxs
        let totalCount = length txs
        let
          direction = case rangeDirection of
            Query.Ascending -> RangeAsc
            Query.Descending -> RangeDesc
        items <- note TxNotFound $ applyRangeToAscList transactionId rangeStart rangeLimit rangeOffset direction txs
        pure Query.Page
          { items
          , nextRange = do
              guard $ length items == rangeLimit
              (Transaction{transactionId}, _) <- uncons $ reverse items
              pure $ Query.Range
                { rangeStart = Just transactionId
                , ..
                }
          , totalCount
          }
  }
