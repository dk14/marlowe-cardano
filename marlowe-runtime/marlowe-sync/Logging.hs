{-# LANGUAGE GADTs #-}

module Logging
  ( RootSelector(..)
  , getRootSelectorConfig
  ) where

import Language.Marlowe.Protocol.HeaderSync.Types (MarloweHeaderSync)
import Language.Marlowe.Protocol.Query.Types (MarloweQuery)
import Language.Marlowe.Protocol.Sync.Types (MarloweSync)
import Language.Marlowe.Runtime.Sync.Database (DatabaseSelector, getDatabaseSelectorConfig)
import Network.Protocol.Driver (ConnectorSelector, getConnectorSelectorConfig)
import Network.Protocol.Handshake.Types (Handshake)
import Observe.Event.Component
  (ConfigWatcherSelector(ReloadConfig), GetSelectorConfig, SelectorConfig(..), prependKey, singletonFieldConfig)

data RootSelector f where
  MarloweSyncServer :: ConnectorSelector (Handshake MarloweSync) f -> RootSelector f
  MarloweHeaderSyncServer :: ConnectorSelector (Handshake MarloweHeaderSync) f -> RootSelector f
  MarloweQueryServer :: ConnectorSelector (Handshake MarloweQuery) f -> RootSelector f
  Database :: DatabaseSelector f -> RootSelector f
  ConfigWatcher :: ConfigWatcherSelector f -> RootSelector f

getRootSelectorConfig :: GetSelectorConfig RootSelector
getRootSelectorConfig = \case
  MarloweSyncServer sel -> prependKey "marlowe-sync-server" $ getConnectorSelectorConfig True True sel
  MarloweHeaderSyncServer sel -> prependKey "marlowe-header-sync-server" $ getConnectorSelectorConfig True True sel
  MarloweQueryServer sel -> prependKey "marlowe-query-server" $ getConnectorSelectorConfig True True sel
  Database sel -> prependKey "database" $ getDatabaseSelectorConfig sel
  ConfigWatcher ReloadConfig -> SelectorConfig "reload-log-config" True
    $ singletonFieldConfig "config" True
