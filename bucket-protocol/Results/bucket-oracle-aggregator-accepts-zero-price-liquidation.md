# Bug Bounty Report — Bucket Protocol Smart Contracts — F2

## Status: Active — not yet submitted. Move PoC written but not executed by the author
(no toolchain in the authoring environment); the static part is reproducible with one command.

## 1. Title

The aggregator stores a price of 0: no range check is applied to the aggregated value

> Framing note: one defect, reported on its own terms. The missing assertion is a bound on the
> value that `process_prices` returns; the zero case is the dangerous end of that range and the
> `u64::MAX` case is the other end. The fix is a single `price > 0 && price <= limit` check.
> **This finding does not depend on F1.** `poc_f2_zero_survives_a_second_agreeing_source` shows that
> two zero readings also produce a stored price of 0, so tightening `threshold` does not close it.

## 2. Vulnerability Details

**Where the check exists.** `sources/parser/switchboard_parser.move:22` returns `option::none()`
when the unpacked value is 0, so a zero reading from Switchboard never enters the collector.

**Where it does not.**

* `sources/parser/supra_parser.move:6-24` — no comparison of the parsed value against 0 anywhere in
  the function; `price_u128` is rescaled and cast to `u64` and the result is wrapped in
  `option::some(...)` unconditionally (`:23`).
* `sources/parser/pyth_parser.move` — both `parse_price` (`:18-48`) and `parse_price_read_only`
  (`:50-73`) likewise have no zero check; they filter only on the sign of `expo`/`price`.

**Where it should be.** `price_aggregator::process_prices` (`sources/parser/price_aggregator.move:53-65`)
returns the accepted value with no lower bound, and `single_oracle.move:227` stores it directly:
`single_oracle.price = agg_price`. There is no post-aggregation sanity check either.

**Evidence that the authors considered a zero valuation dangerous.** `rules/scallop-rule/sources/utils.move:25`
explicitly aborts when a derived unit is 0 (`assert!(scoin_amount > 0, 1)` — the comment there reads
"if the coin is too less, just throw error"). The same protection is absent from the generic
aggregation path that all feeds go through, which makes the omission inconsistent rather than
intentional.

**Why two sources do not save it either.** With `threshold = 2` and two zero readings, the mean is 0
and the divergence guard is silent because `diff == 0`. That is the exact configuration a maintainer
would reach for as the F1 fix, which is why this is filed as its own defect with its own assertion.

**Reachability, stated honestly.** The trigger is a feed that emits 0: a delisted, stopped, or
empty-position reading on the Supra or Pyth side. I could not confirm from mainnet data that any
listed collateral currently has such a feed, and the Pyth path is separately broken (F7) so it
cannot deliver 0 today either. If the only reachable zero is the Supra holder addressed in F5, then
this report's severity follows that open question rather than assuming it.

## 3. Validation Steps

**Target:** `https://github.com/hackenproof-public/bucket-protocol` — oracle package.

**Prerequisites:** repository checkout; `python3` (stdlib) for step 1; `sui` CLI for step 2.

1. Static — confirm the asymmetric filtering and that the aggregator has no lower bound:

   ```bash
   python3 poc/static_proof.py ./oracle    # check F2 prints which parsers contain a zero guard
   ```
   Expected: `OK F2 … zero-value guard exists only in the Switchboard parser`, exit code 0.

   Manual equivalent:
   ```bash
   grep -n "== 0" sources/parser/*.move          # only switchboard_parser.move:22
   sed -n '53,65p' sources/parser/price_aggregator.move
   ```

2. Executable — drive the protocol's own aggregation function with a zero-valued source price:

   ```bash
   sui move test aggregation_poc::poc2_zero_price_from_one_source_is_stored
   ```
   Expected: test passes with the stored price asserted as `0`, read back through
   `single_oracle::get_price` (not a mock). See `../poc/README.md` §2 for the two setup steps.

3. Optional consumer-side check: `poc7_consumers_reject_the_stored_price_after_10_seconds` documents
   the 10-second window (`single_oracle.move:39`, `:94`), which is why a zero price is consumed within
   the same transaction rather than waiting for the next update.

## 4. Supporting Files / PoC

**This report's own PoC file:** `poc/F2-zero-price-accepted.move` — 5 tests
(`poc_f2_zero_price_is_stored`, `poc_f2_zero_survives_a_second_agreeing_source`,
`poc_f2_max_u64_price_is_stored`, `poc_f2_zero_price_is_consumable_within_the_10s_window`,
`poc_f2_and_one_millisecond_later_it_is_rejected`). Note that the second test shows `threshold = 2`
alone does not close this finding. Attach with `poc/injector-snippet.move`.
Shared/auxiliary:
* `../poc/aggregation_poc.move` → `poc2_zero_price_from_one_source_is_stored` — injects a
  `PriceInfo(0, T0)` and asserts `get_price` returns 0. Uses the real
  `single_oracle::update_oracle_price` and `single_oracle::get_price`; the only added code is the
  `#[test_only]` setter described in `poc/injector-snippet.move`.
* `poc2b_one_hundred_thousand_percent_deviation_from_the_reference_is_stored` and
  `poc2c_max_u64_price_from_one_source_is_stored` show the same absence of bounds in both directions.
* `../poc/static_proof.py` (check F2), `../poc/verify.py` (numeric cases `poc2`, `poc2b`, `poc2c`).
* **Observed output:** not produced by me — no Move toolchain was installable in the authoring
  environment. The submitter must run step 2 and attach the console output. The static claim in
  step 1 requires nothing and is verifiable by reading four short functions.

## 5. Severity Level

**High** — program band `$5,000 - $7,000`.

Justification, on this defect alone: a stored collateral price of 0 makes every open position on that
collateral appear fully under-collateralised, so a liquidator seizes collateral for essentially
nothing — "Stealing or loss of funds" in the program's own wording — and the pipeline has no bound
that rejects it. Critical (`$10,000 - $15,000`) would be appropriate if a reachable zero-emitting
feed for a listed collateral is confirmed; I am not asserting that from mainnet data, so the rating
stops at High.

**Independence.** The defect is the missing bound on the value `process_prices` returns, which is a
property of that function only. `poc_f2_zero_survives_a_second_agreeing_source` runs with
`threshold = 2` — i.e. with the F1 fix already applied — and still stores 0, so this report cannot be
answered by fixing F1, F6 or F7, and it does not borrow their impact.

## 6. Category

Closest-fit category, noted explicitly: **`Unsecure Design`**.

* `Hackproof_category.md` has no "missing input validation" entry under `Blockchain`, and the defect
  is the absence of a lower-bound invariant in the aggregation design rather than a corruptible
  input path.
* Rejected: `Integer Underflow` (no arithmetic underflow is required to reach this — a plain 0 from a
  feed suffices; F4 covers the arithmetic cases); `Transaction-Ordering Dependence (TOD) / Front
  Running` (ordering is not required).
* Program-side wording: "Stealing or loss of funds", "Attacks on logic".

## 7. Language

Submission language: **English**.

## 8. Target

`https://github.com/hackenproof-public/bucket-protocol` — the program's sole in-scope asset.

Cited from `Bucket-Protocol/oracle` @ `df8f6a418f24a82eaf22a8309878175ae33f2cf5`:
`sources/parser/switchboard_parser.move:22`, `sources/parser/supra_parser.move:6-24`,
`sources/parser/pyth_parser.move:18-73`, `sources/parser/price_aggregator.move:53-65`,
`sources/single_oracle.move:227`, `rules/scallop-rule/sources/utils.move:25`.
Same placement caveat as F1: if the oracle is an imported dependency of the scoped repo, the
"vulnerabilities in imported contracts" exclusion applies.
