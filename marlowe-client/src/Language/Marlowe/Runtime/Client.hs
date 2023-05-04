{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}

module Language.Marlowe.Runtime.Client
  ( module Control.Monad.Trans.Marlowe
  , module Control.Monad.Trans.Marlowe.Class
  , connectToMarloweRuntime
  , connectToMarloweRuntimeTraced
  ) where

import Control.Monad.Event.Class
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Trans.Marlowe
import Control.Monad.Trans.Marlowe.Class
import Language.Marlowe.Protocol.Client (marloweRuntimeClientPeer, marloweRuntimeClientPeerTraced)
import Language.Marlowe.Protocol.Types (MarloweRuntime)
import Network.Protocol.Driver (TcpClientSelector, tcpClient, tcpClientTraced)
import Network.Protocol.Handshake.Client (handshakeClientConnector, handshakeClientConnectorTraced)
import Network.Protocol.Handshake.Types (Handshake)
import Network.Protocol.Peer.Trace (HasSpanContext)
import Network.Socket (HostName, PortNumber)
import Observe.Event (InjectSelector)

connectToMarloweRuntimeTraced
  :: (MonadEvent r s m, MonadIO m, MonadFail m, HasSpanContext r)
  => InjectSelector (TcpClientSelector (Handshake MarloweRuntime)) s
  -> HostName
  -> PortNumber
  -> MarloweTracedT r TcpClientSelector s m a
  -> m a
connectToMarloweRuntimeTraced inj host port action = runMarloweTracedT action inj
  $ handshakeClientConnectorTraced
  $ tcpClientTraced inj host port marloweRuntimeClientPeerTraced

connectToMarloweRuntime :: (MonadIO m, MonadFail m) => HostName -> PortNumber -> MarloweT m a -> m a
connectToMarloweRuntime host port action = runMarloweT action
  $ handshakeClientConnector
  $ tcpClient host port marloweRuntimeClientPeer
