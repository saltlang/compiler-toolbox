-- Copyright (c) 2013 Eric McCorkle.  All rights reserved.
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
{-# OPTIONS_GHC -Wall -Werror -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances, FlexibleContexts,
             UndecidableInstances, MultiParamTypeClasses #-}

-- | Some useful instances for 'Scope's in the bound library.  This
-- provides 'Format', 'FormatM', and 'XmlPickler' instances for any
-- 'Scope'.
module Bound.Scope.ExtraInstances where

import Bound.Scope
import Bound.Var
import Text.Format
import Text.XML.Expat.Pickle
import Text.XML.Expat.Tree(NodeG)

instance (Monad t, Format (t (Var b s))) => Format (Scope b t s) where
  format s = format (fromScope s)

instance (Monad m, Monad t, FormatM m (t (Var b s))) =>
         FormatM m (Scope b t s) where
  formatM s = formatM (fromScope s)

instance (GenericXMLString tag, Show tag, GenericXMLString text, Show text,
          Monad func, XmlPickler [NodeG [] tag text] (func (Var bound free))) =>
         XmlPickler [NodeG [] tag text] (Scope bound func free) where
  xpickle = xpWrap (toScope, fromScope) xpickle
