module Transity.Data.Amount
where

import Control.Bind (bind)
import Data.Argonaut.Core (toString, Json)
import Data.Argonaut.Decode.Class (class DecodeJson)
import Data.Array (take)
import Data.Boolean (otherwise)
import Data.Eq (class Eq, (/=))
import Data.Function (($))
import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Show (genericShow)
import Data.Maybe (Maybe(Nothing, Just), maybe)
import Data.Monoid (class Monoid)
import Data.Ord (class Ord)
import Data.Rational (Rational, fromInt, toNumber, (%))
import Data.Result (Result(..), toEither)
import Data.Ring ((-))
import Data.Ring (negate) as Ring
import Data.Semigroup (class Semigroup, (<>))
import Data.Semiring ((+))
import Data.Show (class Show, show)
import Data.String (Pattern(..), length, split)
import Data.Tuple (Tuple(..))
import Transity.Utils
  ( digitsToRational
  , padEnd
  , alignNumber
  , lengthOfNumParts
  , WidthRecord
  , widthRecordZero
  )


newtype Commodity = Commodity String

derive instance genericCommodity :: Generic Commodity _
derive newtype instance eqCommodity :: Eq Commodity
derive newtype instance ordCommodity :: Ord Commodity

instance showCommodity :: Show Commodity where
  show = genericShow



data Amount = Amount Rational Commodity

derive instance genericAmount :: Generic Amount _
derive instance eqAmount :: Eq Amount
derive instance ordAmount :: Ord Amount

instance semigroupAmount :: Semigroup Amount where
  append (Amount numA (Commodity comA)) (Amount numB (Commodity comB))
    | comA /= comB = Amount (fromInt 0) (Commodity "INVALID COMPUTATION")
    | otherwise = Amount (numA + numB) (Commodity comA)

instance monoidAmount :: Monoid Amount where
  mempty = Amount (fromInt 0) (Commodity "")

instance showAmount :: Show Amount where
  show = genericShow

instance decodeAmount :: DecodeJson Amount where
  decodeJson json = toEither $ decodeJsonAmount json


decodeJsonAmount :: Json -> Result String Amount
decodeJsonAmount json = do
  amount <- maybe (Error "Amount is not a string") Ok (toString json)
  let amountFrags = split (Pattern " ") amount
  case take 2 amountFrags of
    [value, currency] -> case digitsToRational value of
      Nothing -> Error "Amount does not contain a valid value"
      Just quantity -> Ok $ Amount quantity (Commodity currency)
    _ -> Error "Amount does not contain a value and a commodity"


subtract :: Amount -> Amount -> Amount
subtract (Amount numA (Commodity comA)) (Amount numB (Commodity comB))
  | comA /= comB = Amount (0 % 1) (Commodity "INVALID COMPUTATION")
  | otherwise = Amount (numA - numB) (Commodity comA)


negate :: Amount -> Amount
negate (Amount num com) = Amount (Ring.negate num) com



toWidthRecord :: Amount -> WidthRecord
toWidthRecord (Amount quantity (Commodity commodity)) =
  let
    Tuple intPart fracPart = lengthOfNumParts (toNumber quantity)
  in
    widthRecordZero
      { integer = intPart
      , fraction = fracPart
      , commodity = length commodity
      }


showPretty :: Amount -> String
showPretty (Amount value (Commodity commodity)) =
  (show (toNumber value)) <> " " <> commodity


--| Specify the width (in characters) of the integer part,
--| the width of the fractional part (including decimal point),
--| the width of commodity part
--| and receive a pretty printed amount.

showPrettyAligned :: Int -> Int -> Int -> Amount -> String
showPrettyAligned intWidth fracWidth comWidth (Amount val (Commodity com)) =
  alignNumber intWidth fracWidth (toNumber val)
  <> " "
  <> padEnd comWidth com
