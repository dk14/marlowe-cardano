module Language.Marlowe.Runtime.ChainSync.ApiSpec
  where

import Language.Marlowe.Runtime.ChainSync.Api
import Language.Marlowe.Runtime.ChainSync.Gen ()
import Network.Protocol.Codec.Spec (checkPropCodec)
import Network.Protocol.Job.Types (Job)
import Network.Protocol.Query.Types (Query)
import Test.Hspec
import Test.Hspec.QuickCheck (prop)

spec :: Spec
spec = describe "Language.Marlowe.Runtime.ChainSync.Api" do
  describe "ChainSeek protocol" do
    prop "It has a lawful codec" $ checkPropCodec @RuntimeChainSeek
  describe "ChainSyncQuery" do
    prop "It has a lawful Query protocol codec" $ checkPropCodec @(Query ChainSyncQuery)
  describe "ChainSyncCommand" do
    prop "It has a lawful Job protocol codec" $ checkPropCodec @(Job ChainSyncCommand)
