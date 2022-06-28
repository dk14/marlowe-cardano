{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE DerivingStrategies #-}

module Actus.Domain.BusinessEvents where

import Data.Aeson.Types (FromJSON, ToJSON)
import GHC.Generics (Generic)

{-| ACTUS event types
    https://github.com/actusfrf/actus-dictionary/blob/master/actus-dictionary-event.json
-}
data EventType =
      IED  -- ^ Initial Exchange
    | FP   -- ^ Fee Payment
    | PR   -- ^ Principal Redemption
    | PD   -- ^ Principal Drawing
    | PY   -- ^ Penalty Payment
    | PP   -- ^ Principal Prepayment (unscheduled event)
    | IP   -- ^ Interest Payment
    | IPFX -- ^ Interest Payment Fixed Leg
    | IPFL -- ^ Interest Payment Floating Leg
    | IPCI -- ^ Interest Capitalization
    | CE   -- ^ Credit Event
    | RRF  -- ^ Rate Reset Fixing with Known Rate
    | RR   -- ^ Rate Reset Fixing with Unknown Rate
    | PRF  -- ^ Principal Payment Amount Fixing
    | DV   -- ^ Dividend Payment
    | PRD  -- ^ Purchase
    | MR   -- ^ Margin Call
    | TD   -- ^ Termination
    | SC   -- ^ Scaling Index Fixing
    | IPCB -- ^ Interest Calculation Base Fixing
    | MD   -- ^ Maturity
    | XD   -- ^ Exercise
    | STD  -- ^ Settlement
    | PI   -- ^ Principal Increase
    | AD   -- ^ Monitoring
    deriving stock (Eq, Show, Read, Ord, Enum, Generic)
    deriving anyclass (FromJSON, ToJSON)

{-| Risk factor observer
-}
data RiskFactors a = RiskFactors
    { o_rf_CURS :: a
    , o_rf_RRMO :: a
    , o_rf_SCMO :: a
    , pp_payoff :: a
    , xd_payoff :: a
    , dv_payoff :: a
    }
    deriving stock (Show, Generic)
    deriving anyclass (FromJSON, ToJSON)