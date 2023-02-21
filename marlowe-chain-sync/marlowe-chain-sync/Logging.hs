{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}

module Logging
  ( RootSelector(..)
  , getRootSelectorConfig
  ) where

import Language.Marlowe.Runtime.ChainSync.Api (ChainSyncCommand, ChainSyncQuery, RuntimeChainSeek)
import Network.Protocol.Driver (ConnectorSelector, getConnectorSelectorConfig)
import Network.Protocol.Handshake.Types (Handshake)
import Network.Protocol.Job.Types (Job)
import Network.Protocol.Query.Types (Query)
import Observe.Event.Component
  (ConfigWatcherSelector(..), GetSelectorConfig, SelectorConfig(..), prependKey, singletonFieldConfig)

data RootSelector f where
  ChainSeekServer :: ConnectorSelector (Handshake RuntimeChainSeek) f -> RootSelector f
  QueryServer :: ConnectorSelector (Handshake (Query ChainSyncQuery)) f -> RootSelector f
  JobServer :: ConnectorSelector (Handshake (Job ChainSyncCommand)) f -> RootSelector f
  ConfigWatcher :: ConfigWatcherSelector f -> RootSelector f

-- TODO automate this boilerplate with Template Haskell
getRootSelectorConfig :: GetSelectorConfig RootSelector
getRootSelectorConfig = \case
  ChainSeekServer sel -> prependKey "chain-sync" $ getConnectorSelectorConfig True False sel
  QueryServer sel -> prependKey "query" $ getConnectorSelectorConfig True True sel
  JobServer sel -> prependKey "job" $ getConnectorSelectorConfig True True sel
  ConfigWatcher ReloadConfig -> SelectorConfig "reload-log-config" True
    $ singletonFieldConfig "config" True
