# Bug Bounty Report — Bucket Protocol Smart Contracts — F3

## Status: Active — not yet submitted. Reported as a robustness/timestamp defect, not as a
fund-loss primitive; the contrast pair is executable in Move.

## 1. Title

Staleness is tested with an absolute (two-sided) difference, so a reading timestamped ahead of the
clock is treated as fresh instead of being rejected

> Framing note: one defect — the *direction* of the freshness comparison at
> `price_aggregator.move:46`. The intended rule is "reject data older than `tolerance_ms`"; a
> two-sided comparison replaces that with "farther away in either direction", which admits
> future-dated data and turns publisher clock skew into an extended grace period for genuinely old
> readings. Filed as Medium/robustness, not as a fund-loss primitive. Two adjacent numeric issues in
> the parsers (the `u128 → u64` timestamp downcast and a `timestamp_sec * 1000` that could overflow)
> are **deliberately not claimed here** — they belong to the F4 cast/overflow class, and claiming
> them would double-count a single fix.

## 2. Vulnerability Details

**The comparison.** `sources/parser/price_aggregator.move:46`:

* the filter is `std::u64::diff(current_time, timestamp) <= tolerance_ms`, and `std::u64::diff`
  returns the absolute difference;
* there is no `timestamp <= current_time` bound anywhere in the module (checked by
  `../poc/static_proof.py`, check F3), so a source whose reading carries a future timestamp passes for
  any offset up to `tolerance_ms`.

**The tolerance in production.** The live SUI feed is created with `tolerance_ms = 3600_000`
(1 hour) at `sources/bucket_oracle.move:61-66`, so up to one hour of forward skew is silently
accepted.

**Where the timestamp comes from.** Every parser takes the feed's own timestamp field and converts it
to milliseconds: `switchboard_parser.move:31` and `pyth_parser.move:45`/`:70` compute
`timestamp_sec * 1000`; `supra_parser.move:21` reads `(timestamp_u128 as u64)`. These are cited only
to identify where the value that reaches the two-sided comparison originates; the arithmetic of the
conversions is not part of this report.

**Practical effect.** A feed whose publisher clock runs ahead by *x* keeps readings that are up to
*x* older than intended inside the accepted window for as long as the skew persists — the freshness
budget is silently extended by the skew instead of being enforced.

**Independence.** This report is self-contained. Its accept/reject contrast pair runs at the default
threshold, and the defect stays valid whichever way F1 and F6 are fixed, because it is the
comparison itself that is wrong — not the number of readings that reach it. It also does not lean on
F1 for impact, unlike the earlier draft of this file, which framed the risk as "no second source to
disagree with a skewed feed".

**What is not affected.** Consumers of the stored price are protected independently:
`single_oracle.move:39` and `:94` hardcode a 10_000 ms bound measured against
`latest_update_ms`, which is set from the *clock* (`:228`, `:247`) rather than from the feed. So this
finding does not, by itself, extend the window in which a poisoned price is consumable, and the
report says so rather than implying otherwise.

## 3. Validation Steps

**Target:** `https://github.com/hackenproof-public/bucket-protocol` — oracle package.

**Prerequisites:** repository checkout for step 1; `sui` CLI for step 2 (a matched accept/reject
pair is the cleanest demonstration).

1. Static:
   ```bash
   python3 poc/static_proof.py ./oracle      # check F3
   grep -n "std::u64::diff(current_time, timestamp)" sources/parser/price_aggregator.move
   grep -n "timestamp" sources/parser/*.move
   ```
   Expected: F3 `OK`, and no `timestamp <= current_time` style bound.

2. Executable contrast pair:
   ```bash
   sui move test aggregation_poc::poc4_reading_timestamped_just_ahead_of_the_clock_is_accepted
   sui move test aggregation_poc::poc5_same_offset_into_the_past_is_rejected
   ```
   With `tolerance_ms = 3_600_000` and a clock parked at `T0`, a reading stamped
   `T0 + 3_599_000` is accepted and stored, while a reading stamped `T0 - 3_601_000` — the same
   magnitude in the direction the rule is meant to police — aborts with `ENotEoughPrices`. Equal
   offsets, opposite outcomes.

## 4. Supporting Files / PoC

**This report's own PoC file:** `poc/F3-future-timestamp-accepted.move` — 4 tests, including the
contrast pair (`poc_f3_reading_59_minutes_59_seconds_ahead_is_accepted` vs
`poc_f3_reading_60_minutes_1_second_behind_is_rejected`) and
`poc_f3_ahead_skew_extends_the_life_of_a_stale_reading`, which shows the effect over two updates.
Attach with `poc/injector-snippet.move`.
Shared/auxiliary:
* `../poc/aggregation_poc.move` → `poc4_*` (accept) and `poc5_*` (reject). Both call the protocol's own
  `single_oracle::update_oracle_price` with `tolerance_ms` set through the test-only setter in
  `poc/injector-snippet.move`.
* `../poc/static_proof.py` (check F3), `../poc/verify.py` (numeric cases `poc4`, `poc5`).
* **Observed output:** none produced by me (no Move toolchain installable in the authoring
  environment); attach the transcript of step 2 after running it.

## 5. Severity Level

**Medium** — program band `$100 - $2,000`.

Justification: it is a real deviation from the stated freshness policy and it silently widens the
staleness budget by whatever skew a feed has, but the 10-second consumer bound is measured against
the clock, so the finding does not on its own create a fund-loss path. If the maintainers consider a
per-feed 1-hour acceptance of future-dated data acceptable, this can be closed as informative — I am
rating it honestly rather than inflating it to High.

## 6. Category

**`Blockchain > Timestamp Dependence`** — an exact fit from `Hackproof_category.md`; no closest-fit
substitution needed.

Rejected: `Unsecure Design` (a specific listed category fits better), `DoS with (Unexpected) revert`
(the `timestamp_sec * 1000` overflow variant does have that shape, but it is secondary and noted in
Section 2 rather than the basis of the report).
Program-side wording: "Attacks on logic (behavior of the code is different from the business
description)".

## 7. Language

Submission language: **English**.

## 8. Target

`https://github.com/hackenproof-public/bucket-protocol` — the program's sole in-scope asset.

Cited from `Bucket-Protocol/oracle` @ `df8f6a418f24a82eaf22a8309878175ae33f2cf5`:
`sources/parser/price_aggregator.move:46`, `sources/bucket_oracle.move:61-66`,
`sources/parser/switchboard_parser.move:31`, `sources/parser/pyth_parser.move:45,70`,
`sources/parser/supra_parser.move:21`, `sources/single_oracle.move:39,94,228,247`.
Placement caveat as in F1: the oracle package must be confirmed to live inside the scoped repo.
