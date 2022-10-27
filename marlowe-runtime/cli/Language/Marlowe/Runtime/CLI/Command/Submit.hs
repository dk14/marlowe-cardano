module Language.Marlowe.Runtime.CLI.Command.Submit
  where

import qualified Cardano.Api as C
import Control.Concurrent.STM (atomically)
import Control.Concurrent.STM.Delay (newDelay, waitDelay)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans (lift)
import Control.Monad.Trans.Except (ExceptT(ExceptT))
import Data.Aeson (toJSON)
import qualified Data.Aeson as A
import Data.Bifunctor (Bifunctor(first))
import Data.ByteString.Base16 (encodeBase16)
import qualified Data.Text as T
import Language.Marlowe.Runtime.CLI.Env (Env(..))
import Language.Marlowe.Runtime.CLI.Monad (CLI, asksEnv, logDebug, runCLIExceptT, runTxJobClient)
import Language.Marlowe.Runtime.ChainSync.Api
  (BlockHeader(BlockHeader), BlockHeaderHash(unBlockHeaderHash), BlockNo(unBlockNo), SlotNo(unSlotNo))
import Language.Marlowe.Runtime.Transaction.Api (MarloweTxCommand(Submit), SubmitError, marloweTxCommandSchema)
import Network.Protocol.Job.Client
  ( ClientStAwait(SendMsgDetach, SendMsgPoll)
  , ClientStCmd(..)
  , ClientStHandshake(..)
  , ClientStIdle(SendMsgExec)
  , jobClient
  )
import Options.Applicative

newtype SubmitCommand = SubmitCommand
  { txFile :: FilePath
  }

submitCommandParser :: ParserInfo SubmitCommand
submitCommandParser = info parser $ progDesc "Submit a signed transaction to the Cardano node. Expects the CBOR bytes of the signed Tx from stdin."
  where
    parser = SubmitCommand
      <$> txFileParser
    txFileParser = strArgument $ mconcat
      [ metavar "FILE_PATH"
      , help "A file containing the CBOR bytes of the signed transaction to submit."
      ]

data CilentSubmitError
  = SchemaMistmatch
  | SubmitFailed SubmitError
  | SubmitInterrupted
  | TransactionDecodingFailed
  deriving (Show)

runSubmitCommand :: SubmitCommand -> CLI ()
runSubmitCommand SubmitCommand{txFile} = runCLIExceptT do
  lift $ logDebug $ "Trying to decode tx file:" <> T.pack txFile
  tx <- ExceptT $ liftIO $ first (const TransactionDecodingFailed) <$> C.readFileTextEnvelope (C.AsTx C.AsBabbageEra) txFile
  let
    cmd = Submit tx
    next = ClientStCmd
      { recvMsgAwait = \_ _ -> do
          delay <- liftIO $ newDelay 500_000 -- poll every 500 ms
          sigIntVar <- asksEnv sigInt
          keepGoing <- liftIO $ atomically $
            False <$ sigIntVar <|> True <$ waitDelay delay
          pure if keepGoing
            then SendMsgPoll next
            else SendMsgDetach (Left SubmitInterrupted)
      , recvMsgFail = \err -> do
          liftIO $ putStrLn "recvMsgFailed"
          liftIO $ print err
          pure . Left . SubmitFailed $ err
      , recvMsgSucceed = pure . Right
      }
    jobClient' = jobClient marloweTxCommandSchema . pure $ ClientStHandshake
      { recvMsgHandshakeRejected = const $ pure $ Left SchemaMistmatch
      , recvMsgHandshakeConfirmed = pure $ SendMsgExec cmd next
      }
  BlockHeader slotNo hash blockNo <- ExceptT $ runTxJobClient jobClient'
  let
    res = A.object
      [ ("slotNo", toJSON $ unSlotNo slotNo)
      , ("blockHeaderHash", toJSON . encodeBase16 $ unBlockHeaderHash hash)
      , ("blockNo", toJSON $ unBlockNo blockNo)
      ]
  liftIO . print $ A.encode res

