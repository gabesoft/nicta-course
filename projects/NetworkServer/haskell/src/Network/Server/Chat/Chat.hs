module Network.Server.Chat.Chat where

import Control.Applicative ((<$), (<$>))
import Control.Monad.Trans (MonadIO(..))
import Data.Foldable (msum)
import Data.IORef (atomicModifyIORef)
import Data.Maybe (fromMaybe)
import Network.Server.Chat.Loop
import Network.Server.Common.Line

type Chat a = IORefLoop Integer a

data ChatCommand
    = Chat String
    | Incr
    | Add String
    | Unknown String
    deriving (Eq,Show)

incr :: Chat Integer
incr = do
    e <- readEnvval
    liftIO $ atomicModifyIORef e (\n -> (n + 1, n + 1))

chat :: IO a
chat = iorefLoop 0 printCounter (process . chatCommand)

-- |
--
-- >>> chatCommand "CHAT hi"
-- Chat "hi"
--
-- >>> chatCommand "CHAT bye"
-- Chat "bye"
--
-- >>> chatCommand "INCR"
-- Incr
--
-- >>> chatCommand "ADD 5"
-- Add 5
--
-- >>> chatCommand "Nothing"
-- UNKNOWN "Nothing"
chatCommand
    :: String -> ChatCommand
chatCommand z =
    Unknown z `fromMaybe`
    msum
        [ Chat <$> trimPrefixThen "CHAT" z
        , Incr <$ trimPrefixThen "INCR" z
        , Add <$> trimPrefixThen "ADD" z]

printCounter :: IORefLoop Integer ()
printCounter = readIOEnvval >>= pPutStrLn . showCounter
  where showCounter = ("counter is at " ++) . show

process :: ChatCommand -> Chat ()
process (Chat s) = allClientsButThis ! s
process (Incr) = incr >> printCounter
process (Add s) = addToIOEnvval (read s) >> printCounter
process (Unknown s) = allClientsButThis ! s