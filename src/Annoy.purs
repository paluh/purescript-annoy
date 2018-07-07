module Annoy
  ( get
  , unsafeGet
  , length
  , save
  , unsafeLoad
  -- , nnsByItem
  -- , nnsByItem_
  , nnsByVec
  -- , nnsByVec_
  , distance
  , unsafeDistance
  , fromVectors
  , fromVectors_
  ) where

import Prelude

import Annoy.ST (build_, new, push, unsafeFreeze)
import Annoy.Types (Annoy, Metric)
import Annoy.Unsafe as U
import Control.Monad.Eff (Eff, runPure)
import Control.Monad.ST (runST)
import Data.Foldable (class Foldable, traverse_)
import Data.Foreign.NullOrUndefined (undefined)
import Data.Maybe (Maybe(..), fromJust)
import Data.Typelevel.Num (class Nat, class Pos, toInt)
import Data.Vec (Vec, fromArray, toArray)
import Node.FS (FS)
import Partial.Unsafe (unsafePartial)
import Unsafe.Coerce (unsafeCoerce)

fromVectors
  :: forall s t f
   . Nat s
  => Foldable f
  => Pos t
  => t
  -> Metric
  -> f (Vec s Number)
  -> Annoy s
fromVectors trees metric vectors = unsafePartial $ fromJust $ fromVectors_ (toInt trees) metric vectors

fromVectors_
  :: forall s f
   . Nat s
  => Foldable f
  => Int
  -> Metric
  -> f (Vec s Number)
  -> Maybe (Annoy s)
fromVectors_ trees metric vectors = build_ trees (do
  a <- new (unsafeCoerce unit :: s) metric
  traverse_ (\v -> push v a) vectors
  pure a)

-- | `get i annoy` returns `i`-th vector. Performs bounds check.
get :: forall s. Nat s => Int -> Annoy s -> Maybe (Vec s Number)
get i a = 
  if 0 <= i && i < length a
  then Just $ unsafeGet i a
  else Nothing

-- | Similar to `get` but no bounds checks are performed.
unsafeGet :: forall s. Nat s => Int -> Annoy s -> Vec s Number
unsafeGet i a = unsafeFromArray $ runPure (runST (U.unsafeGetItem i $ unsafeCoerce a))

-- | `length annoy` returns number of stored vectors
length :: forall s. Annoy s -> Int
length a = runPure (runST (U.getNItems $ unsafeCoerce a))

-- | `save path annoy` dumps annoy to the file. Boolean indicates succes or failure.
save :: forall s r. String -> Annoy s -> Eff ( fs :: FS | r ) Boolean
save path a = runST (U.save path $ unsafeCoerce a)

-- | `unsafeLoad path s metric` creates `STAnnoy` using `s` and `metric`, then loads annoy using `path`
-- | Unsafe aspect is that it does not check loaded vector sizes against `s`
unsafeLoad
  :: forall r s
   . Nat s
  => String
  -> s
  -> Metric
  -> Eff ( fs :: FS | r ) (Maybe (Annoy s))
unsafeLoad path s metric = runST (do
  stAnnoy <- new s metric
  isOk <- U.unsafeLoad path $ unsafeCoerce stAnnoy
  if isOk then Just <$> unsafeFreeze stAnnoy else pure Nothing)

-- nnsByItem

-- nnsByItem_

nnsByVec :: forall s r. Nat s => Vec s Number -> Int -> ({ searchK :: Int } -> { searchK :: Int }) -> Annoy s -> Array Int
nnsByVec v n update a = 
  runPure (runST (U.unsafeGetNNsByVector (toArray v) n ops.searchK (unsafeCoerce a)))
  where
  ops :: { searchK :: Int }
  ops = update { searchK: unsafeCoerce undefined }

-- nnsByVec_

distance :: forall s. Nat s => Int -> Int -> Annoy s -> Maybe Number
distance i j a = if i < 0 || j < 0 || i >= n || j >= n then Nothing
  else Just $ unsafeDistance i j a
  where n = length a

unsafeDistance :: forall s. Nat s => Int -> Int -> Annoy s -> Number
unsafeDistance i j a = runPure (runST (U.unsafeGetDistance i j $ unsafeCoerce a))

unsafeFromArray :: forall a s. Nat s => Array a -> Vec s a
unsafeFromArray arr = unsafePartial $ fromJust $ fromArray arr
