-- Copyright (c) 2016 Eric McCorkle.  All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
--
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- 3. Neither the name of the author nor the names of any contributors
--    may be used to endorse or promote products derived from this software
--    without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS''
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS
-- OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-- SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
-- LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
-- USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
-- OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
{-# OPTIONS_GHC -funbox-strict-fields -Wall -Werror #-}
{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances, UndecidableInstances #-}

module Control.Monad.Messages(
       MonadMessages(..),
       MessagesT,
       Messages,
       runMessagesT,
       runMessages,
       mapMessagesT,
       putMessagesT,
       putMessagesTNoContext,
       putMessagesTXML,
       putMessagesTXMLNoContext
       ) where

import Control.Applicative
import Control.Monad.Artifacts.Class
import Control.Monad.CommentBuffer.Class
import Control.Monad.Comments.Class
import Control.Monad.Cont
import Control.Monad.Except
import Control.Monad.Genpos.Class
import Control.Monad.Gensym.Class
import Control.Monad.GraphBuilder.Class
import Control.Monad.Journal
import Control.Monad.Keywords.Class
import Control.Monad.Loader.Class
import Control.Monad.Messages.Class
import Control.Monad.Positions.Class
import Control.Monad.Reader
import Control.Monad.ScopeBuilder.Class
import Control.Monad.SourceFiles.Class
import Control.Monad.SourceBuffer.Class
import Control.Monad.State
import Control.Monad.Symbols.Class
import Control.Monad.Writer
import System.IO

import qualified Data.Message as Message
import qualified Data.Position as Position

data MessageState msgs =
  MessageState {
    -- | All reported messages.
    msMessages :: !msgs,
    -- | The highest severity seen so far.
    msSeverity :: !Message.Severity
  }

newtype MessagesT msgs msg m a =
  MessagesT { unpackMessagesT :: (WriterT (MessageState msgs) m) a }

type Messages msgs msg a = MessagesT msgs msg IO a

-- | Execute the computation wrapped in a MessagesT monad transformer.
runMessagesT :: Monad m =>
                MessagesT msgs msg m a
             -> m (a, MessageState msgs)
runMessagesT m = runWriterT (unpackMessagesT m)

-- | Execute the computation wrapped in a MessagesT monad transformer.
runMessages :: Messages msgs msg a
            -> IO (a, MessageState msgs)
runMessages = runMessagesT

-- | Execute the computation wrapped in a MessagesT monad transformer,
-- output all messages generated to the given handle, return the
-- result only if the maximum severity is below a certain level.
putMessagesT :: (Message.Messages msg msgs, Message.MessagePosition pos msg,
                 Position.Position info pos, Position.PositionInfo info,
                 MonadSourceFiles m, MonadPositions m, MonadIO m) =>
                Handle
             -> Message.Severity
             -> MessagesT msgs msg m a
             -> m (Maybe a)
putMessagesT handle maxsev m =
  do
    (res, MessageState { msSeverity = sev, msMessages = msgs }) <-
      runMessagesT m
    Message.putMessages handle msgs
    if sev < maxsev
      then return (Just res)
      else return Nothing

-- | Execute the computation wrapped in a MessagesT monad transformer,
-- output all messages generated to the given handle without context
-- strings, return the result only if the maximum severity is below a
-- certain level.
putMessagesTNoContext :: (Message.Messages msg msgs,
                          Message.MessagePosition pos msg,
                          Position.Position info pos,
                          Position.PositionInfo info,
                          MonadPositions m, MonadIO m) =>
                         Handle
                      -> Message.Severity
                      -> MessagesT msgs msg m a
                      -> m (Maybe a)
putMessagesTNoContext handle maxsev m =
  do
    (res, MessageState { msSeverity = sev, msMessages = msgs }) <-
      runMessagesT m
    Message.putMessagesNoContext handle msgs
    if sev < maxsev
      then return (Just res)
      else return Nothing

-- | Execute the computation wrapped in a MessagesT monad transformer,
-- output all messages generated to the given handle, return the
-- result only if the maximum severity is below a certain level.
putMessagesTXML :: (Message.Messages msg msgs, MonadSourceFiles m,
                    Message.MessagePosition pos msg, Position.Position info pos,
                    Position.PositionInfo info, MonadPositions m, MonadIO m) =>
                   Handle
                -> Message.Severity
                -> MessagesT msgs msg m a
                -> m (Maybe a)
putMessagesTXML handle maxsev m =
  do
    (res, MessageState { msSeverity = sev, msMessages = msgs }) <-
      runMessagesT m
    Message.putMessagesXML handle msgs
    if sev < maxsev
      then return (Just res)
      else return Nothing

-- | Execute the computation wrapped in a MessagesT monad transformer,
-- output all messages generated to the given handle, return the
-- result only if the maximum severity is below a certain level.
putMessagesTXMLNoContext :: (Message.Messages msg msgs,
                             Message.MessagePosition pos msg,
                             Position.Position info pos,
                             Position.PositionInfo info,
                             MonadPositions m, MonadIO m) =>
                            Handle
                         -> Message.Severity
                         -> MessagesT msgs msg m a
                         -> m (Maybe a)
putMessagesTXMLNoContext handle maxsev m =
  do
    (res, MessageState { msSeverity = sev, msMessages = msgs }) <-
      runMessagesT m
    Message.putMessagesXMLNoContext handle msgs
    if sev < maxsev
      then return (Just res)
      else return Nothing

mapMessagesT :: (Monad m, Monad n) =>
                (m (a, MessageState msgsa) -> n (b, MessageState msgsb)) ->
                MessagesT msgsa msg m a -> MessagesT msgsb msg n b
mapMessagesT f = MessagesT . mapWriterT f . unpackMessagesT

message' :: (Message.Messages msg msgs, Monad m) => msg ->
            (WriterT (MessageState msgs) m) ()
message' msg = tell MessageState { msMessages = Message.singleton msg,
                                   msSeverity = Message.severity msg }

instance Monoid msgs => Monoid (MessageState msgs) where
  mempty = MessageState { msMessages = mempty, msSeverity = mempty }
  mappend MessageState { msMessages = msgs1, msSeverity = s1 }
          MessageState { msMessages = msgs2, msSeverity = s2 } =
    MessageState { msMessages = msgs1 <> msgs2, msSeverity = s1 <> s2 }

instance (Monoid msgs, Monad m) => Monad (MessagesT msgs msg m) where
  return = MessagesT . return
  s >>= f = MessagesT $ unpackMessagesT s >>= unpackMessagesT . f

instance (Monoid msgs, Monad m) => Applicative (MessagesT msgs msg m) where
  pure = return
  (<*>) = ap

instance (Monoid msgs, Monad m, Alternative m) =>
         Alternative (MessagesT msgs msg m) where
  empty = lift empty
  s1 <|> s2 = MessagesT (unpackMessagesT s1 <|> unpackMessagesT s2)

instance Functor (MessagesT msgs msg m) where
  fmap = fmap

instance (Monoid msgs, MonadIO m) => MonadIO (MessagesT msgs msg m) where
  liftIO = MessagesT . liftIO

instance Monoid msgs => MonadTrans (MessagesT msgs msg) where
  lift = MessagesT . lift

instance (Message.Messages msg msgs, Message.Message msg,
          Monoid msgs, Monad m) =>
         MonadMessages msg (MessagesT msgs msg m) where
  message = MessagesT . message'

instance (Monoid msgs, MonadArtifacts path m) =>
         MonadArtifacts path (MessagesT msgs msg m) where
  artifact path = lift . artifact path
  artifactBytestring path = lift . artifactBytestring path
  artifactLazyBytestring path = lift . artifactLazyBytestring path

instance (Monoid msgs, MonadCommentBuffer m) =>
         MonadCommentBuffer (MessagesT msgs msg m) where
  startComment = lift startComment
  appendComment = lift . appendComment
  finishComment = lift finishComment
  addComment = lift . addComment
  saveCommentsAsPreceeding = lift . saveCommentsAsPreceeding
  clearComments = lift clearComments

instance (Monoid msgs, MonadComments m) =>
         MonadComments (MessagesT msgs msg m) where
  preceedingComments = lift . preceedingComments

instance (Monoid msgs, MonadCont m) => MonadCont (MessagesT msgs msg m) where
  callCC f = MessagesT (callCC (\c -> unpackMessagesT (f (MessagesT . c))))

instance (Monoid msgs, MonadError e m) =>
         MonadError e (MessagesT msgs msg m) where
  throwError = lift . throwError
  m `catchError` h =
    MessagesT (unpackMessagesT m `catchError` (unpackMessagesT . h))

instance (Monoid msgs, MonadEdgeBuilder nodety m) =>
         MonadEdgeBuilder nodety (MessagesT msgs msg m) where
  addEdge src dst = lift . addEdge src dst

instance (Monoid msgs, MonadGenpos m) =>
         MonadGenpos (MessagesT msgs msg m) where
  point = lift . point
  filename = lift . filename

instance (Monoid msgs, MonadGensym m) =>
         MonadGensym (MessagesT msgs msg m) where
  symbol = lift . symbol
  unique = lift . unique

instance (Monoid msgs, Monoid w, MonadJournal w m) =>
         MonadJournal w (MessagesT msgs msg m) where
  journal = lift . journal
  history = lift history
  clear = lift clear

instance (Monoid msgs, MonadKeywords p t m) =>
         MonadKeywords p t (MessagesT msgs msg m) where
  mkKeyword p = lift . mkKeyword p

instance (Monoid msgs, MonadLoader path info m) =>
         MonadLoader path info (MessagesT msgs msg m) where
  load = lift . load

instance (Monoid msgs, MonadNodeBuilder nodety m) =>
         MonadNodeBuilder nodety (MessagesT msgs msg m) where
  addNode = lift . addNode

instance (Monoid msgs, MonadPositions m) =>
         MonadPositions (MessagesT msgs msg m) where
  pointInfo = lift . pointInfo
  fileInfo = lift . fileInfo

instance (Monoid msgs, MonadScopeStack m) =>
         MonadScopeStack (MessagesT msgs msg m) where
  enterScope = lift . enterScope
  finishScope = lift finishScope

instance (Monoid msgs, MonadScopeBuilder tmpscope m) =>
         MonadScopeBuilder tmpscope (MessagesT msgs msg m) where
  getScope = lift getScope
  setScope = lift . setScope

instance (Monoid msgs, MonadSourceFiles m) =>
         MonadSourceFiles (MessagesT msgs msg m) where
  sourceFile = lift . sourceFile

instance (Monoid msgs, MonadSourceBuffer m) =>
         MonadSourceBuffer (MessagesT msgs msg m) where
  linebreak = lift . linebreak
  startFile fname = lift . startFile fname
  finishFile = lift finishFile

instance (Monoid msgs, MonadState s m) =>
         MonadState s (MessagesT msgs msg m) where
  get = lift get
  put = lift . put

instance (Monoid msgs, MonadSymbols m) =>
         MonadSymbols (MessagesT msgs msg m) where
  nullSym = lift nullSym
  allNames = lift allNames
  allSyms = lift allSyms
  name = lift . name

instance (Monoid msgs, MonadReader r m) =>
         MonadReader r (MessagesT msgs msg m) where
  ask = lift ask
  local f = mapMessagesT (local f)
{-
instance (Monoid msgs, MonadWriter w m) =>
         MonadWriter w (MessagesT msgs msg m) where
  tell = lift . tell
  listen = mapMessagesT listen
  pass = mapMessagesT pass
-}
instance (Monoid msgs, MonadPlus m) => MonadPlus (MessagesT msgs msg m) where
  mzero = lift mzero
  mplus s1 s2 = MessagesT (mplus (unpackMessagesT s1) (unpackMessagesT s2))

instance (Monoid msgs, MonadFix m) => MonadFix (MessagesT msgs msg m) where
  mfix f = MessagesT (mfix (unpackMessagesT . f))
