-- Copyright (c) 2014 Eric McCorkle.  All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
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
{-# OPTIONS_GHC -Wall -Werror #-}

-- | Defines a class of monads that have the ability to load source
-- code.  This is useful for building frontents.
module Control.Monad.SourceLoader.Class(
       MonadSourceLoader(..)
       ) where

import Control.Monad.Cont
import Control.Monad.Error
import Control.Monad.List
import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Writer
import Data.ByteString.Lazy

-- | Class of monads that load source files.  Instances of this class
-- will typically also implement @SourceFiles@, in order to give
-- access to the loaded file.
class Monad m => MonadSourceLoader m where
  -- | Load a source file at the given location.
  loadSourceFile :: FilePath
                 -- ^ Path of the file to load.
                 -> m [ByteString]
                 -- ^ The contents of the file.  May also raise any
                 -- exception that can be raised by @readFile@.

instance MonadSourceLoader m => MonadSourceLoader (ContT r m) where
  loadSourceFile = lift . loadSourceFile

instance (MonadSourceLoader m, Error e) => MonadSourceLoader (ErrorT e m) where
  loadSourceFile = lift . loadSourceFile

instance MonadSourceLoader m => MonadSourceLoader (ListT m) where
  loadSourceFile = lift . loadSourceFile

instance MonadSourceLoader m => MonadSourceLoader (ReaderT r m) where
  loadSourceFile = lift . loadSourceFile

instance MonadSourceLoader m => MonadSourceLoader (StateT s m) where
  loadSourceFile = lift . loadSourceFile

instance (MonadSourceLoader m, Monoid w) => MonadSourceLoader (WriterT w m) where
  loadSourceFile = lift . loadSourceFile