{-|
Lift the first-order language for continuous maps `CMap`
into a higher-order language in Haskell by simply
using generalized points `CMap g a` at "stage of definition" `g`.

For instance, `add : CMap (R, R) R` becomes
`(+) : forall g. CMap g R -> CMap g R -> CMap g R`
which is "equivalent".
-}

{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE Arrows #-}
{-# LANGUAGE RankNTypes #-}

module Expr (
  module Expr,
  Interval,
  MPFR,
  ($),
  Num ((+), (*), (-), abs, negate),
  Fractional (..),
  (!!),
  CMap (..),
  Bool,
) where

import Prelude hiding (max, min, pow, (&&), (||), (^), (<), (>))

import Data.List (intercalate)
import GHC.Float (Floating (..))
import Control.Arrow (Arrow, arr, (<<<), (&&&))
import Control.Category (Category)
import qualified Control.Category as C
import RealExpr (CMap, B, CNum (..), CFractional (..), CFloating (..), CPoint)
import qualified RealExpr as E
import Interval (Interval (..), unitInterval)
import Rounded (Rounded)
import qualified Rounded as R
import Data.Number.MPFR (MPFR)

instance Show a => Show (CMap () a) where
  show = intercalate "\n" . map show . E.runPoint

ap2 :: CMap (a, b) c -> CMap g a -> CMap g b -> CMap g c
ap2 f x y = f <<< x &&& y

ap1 :: CMap a b -> CMap g a -> CMap g b
ap1 f = (f <<<)

max :: Rounded a => CMap g (Interval a) -> CMap g (Interval a) -> CMap g (Interval a)
max = ap2 E.max

min :: Rounded a => CMap g (Interval a) -> CMap g (Interval a) -> CMap g (Interval a)
min = ap2 E.min

infixr 3 &&
(&&) :: CMap g B -> CMap g B -> CMap g B
(&&) = ap2 E.and

infixr 2 ||
(||) :: CMap g B -> CMap g B -> CMap g B
(||) = ap2 E.or

infix 4 <
(<) :: Rounded a => CMap g (Interval a) -> CMap g (Interval a) -> CMap g B
(<) = ap2 E.lt

infix 4 >
(>) :: Rounded a => CMap g (Interval a) -> CMap g (Interval a) -> CMap g B
x > y = y < x

infixr 8 ^
(^) :: Rounded a => CMap g (Interval a) -> Int -> CMap g (Interval a)
x ^ k = ap1 (E.pow k) x

isTrue :: CMap g B -> CMap g Bool
isTrue = ap1 (arr fst)

isFalse :: CMap g B -> CMap g Bool
isFalse = ap1 (arr snd)

mkInterval :: Rounded a => CMap g (Interval a) -> CMap g (Interval a) -> CMap g (Interval a)
mkInterval = ap2 E.mkInterval

dedekind_cut1 :: Rounded a => (CMap (g, Interval a) B) -> CMap g (Interval a)
dedekind_cut1 f = E.secondOrderPrim E.dedekind_cut' f

dedekind_cut :: Rounded a => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) B)
             -> CMap g (Interval a)
dedekind_cut f = E.secondOrderPrim E.dedekind_cut' (f (arr snd))

firstRoot1 :: Rounded a => (CMap (g, Interval a) B) -> CMap g (Interval a)
firstRoot1 f = E.secondOrderPrim' unitInterval E.firstRoot f

newton_cut' :: Rounded a => (CMap (g, Interval a) (Interval a, Interval a))
             -> CMap g (Interval a)
newton_cut' = E.newton_cut'

newton_cut :: Rounded a => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) (Interval a, Interval a))
             -> CMap g (Interval a)
newton_cut f = E.newton_cut' (f (arr snd))

integral_unit_interval :: Rounded a => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) (Interval a))
             -> CMap g (Interval a)
integral_unit_interval f = E.integral' 16 unitInterval (f (arr snd))

forall_unit_interval :: (Show a, Rounded a) => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) Bool)
             -> CMap g Bool
forall_unit_interval f = E.forall_interval' unitInterval (f (arr snd))

exists_unit_interval :: (Show a, Rounded a) => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) Bool)
             -> CMap g Bool
exists_unit_interval f = E.exists_interval' 16 unitInterval (f (arr snd))

max_unit_interval' :: Rounded a => CMap (g, Interval a) (Interval a) -> CMap g (Interval a)
max_unit_interval' = E.max_interval' unitInterval

max_unit_interval :: Rounded a => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) (Interval a))
             -> CMap g (Interval a)
max_unit_interval f = max_unit_interval' (f (arr snd))

min_unit_interval' :: Rounded a => CMap (g, Interval a) (Interval a) -> CMap g (Interval a)
min_unit_interval' = E.min_interval' unitInterval

min_unit_interval :: Rounded a => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) (Interval a))
             -> CMap g (Interval a)
min_unit_interval f = min_unit_interval' (f (arr snd))

argmax_unit_interval' :: Rounded a => CMap (g, Interval a) (Interval a) -> CMap g (Interval a)
argmax_unit_interval' = E.argmax_interval' unitInterval

argmax_unit_interval :: Rounded a => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) (Interval a))
             -> CMap g (Interval a)
argmax_unit_interval f = argmax_unit_interval' (f (arr snd))

argmin_unit_interval' :: Rounded a => CMap (g, Interval a) (Interval a) -> CMap g (Interval a)
argmin_unit_interval' = E.argmin_interval' unitInterval

argmin_unit_interval :: Rounded a => (CMap (g, Interval a) (Interval a) -> CMap (g, Interval a) (Interval a))
             -> CMap g (Interval a)
argmin_unit_interval f = argmin_unit_interval' (f (arr snd))

restrictReal :: Rounded a => CMap g Bool -> CMap g (Interval a) -> CMap g (Interval a)
restrictReal = ap2 E.restrictReal

-- Let statement with sharing
lett :: CMap g a -> (CMap (g, a) a -> CMap (g, a) b) -> CMap g b
lett x f = proc g -> do
  a <- x -< g
  f (arr snd) -< (g, a)

-- Weakening
wkn :: CMap g a -> CMap (g, x) a
wkn f = f <<< arr fst

instance CNum a => Num (CMap g a) where
  (+) = ap2 cadd
  (-) = ap2 csub
  (*) = ap2 cmul
  negate = ap1 cnegate
  abs = ap1 cabs
  signum = ap1 csignum
  fromInteger = cfromInteger

instance CFractional a => Fractional (CMap g a) where
  (/) = ap2 cdiv
  recip = ap1 crecip
  fromRational = cfromRational


instance CFloating a => Floating (CMap g a) where
  pi = cpi
  exp = ap1 cexp
  log = ap1 clog
  sqrt = ap1 csqrt
  sin = ap1 csin
  cos = ap1 ccos
  tan = ap1 ctan
  asin = ap1 casin
  acos = ap1 cacos
  atan = ap1 catan
  sinh = ap1 csinh
  cosh = ap1 ccosh
  tanh = ap1 ctanh
  asinh = ap1 casinh
  acosh = ap1 cacosh
  atanh = ap1 catanh
  log1p = ap1 clog1p
  expm1 = ap1 cexpm1
  log1pexp = ap1 clog1pexp
  log1mexp = ap1 clog1mexp

-- use as a type hint
asMPFR :: CMap g (Interval MPFR) -> CMap g (Interval MPFR)
asMPFR = id

inEmptyCtx :: CPoint a -> CPoint a
inEmptyCtx = id

showReal' :: Show a => Int -> CPoint a -> String
showReal' n = intercalate "\n" . map show . take n . E.runPoint