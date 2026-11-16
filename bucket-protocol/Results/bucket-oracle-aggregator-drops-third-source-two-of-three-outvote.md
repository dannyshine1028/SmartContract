# Bug Bounty Report — Bucket Protocol Smart Contracts — F6

## Status: Active — not yet submitted. Executable in Move (accept/reject contrast), static check
included.

## 1. Title

Three configured sources are collapsed onto the first two entries of a reversed list: the third
reading is dropped without comparison and two agreeing readings outvote one honest reading

> Framing note: this finding matters most *after* F1 is fixed. Adding `threshold = 2` or waiting for
> more feeds will not make the aggregator correct, because the aggregation itself is a
> first-two-elements average over a vector whose order is silently reversed.

## 2. Vulnerability Details

**Order is inverted before it is used.** `price_aggregator::aggregate_price`
(`sources/parser/price_aggregator.move:40-51`) drains its input with `vector::pop_back` (`:44`) while
applying the freshness filter, appending survivors with `vector::push_back`. The collector is filled
in the order switchboard, pyth, supra (`sources/single_oracle.move:223-225`), so the list handed to
`process_prices` is `(supra, pyth, switchboard)` — the reverse of the documented order.

**Only two elements are ever read.** `process_prices` (`:53-65`) takes `vector::borrow(&prices, 0)`
and `vector::borrow(&prices, 1)` (`:60-61`) and never touches index 2 or beyond, so with three fresh
readings the *switchboard* value — the first one pushed — is silently discarded rather than
compared, and the result is the average of the last two pushed.

**There is no median.** The "aggregation" is a two-element mean plus a ~2% divergence assertion
(`:62-63`). Two out of three sources that agree are therefore indistinguishable from truth against a
third that disagrees: `poc6` shows two `$2.00` readings outvoting one honest `$1.00` reading, with
`$2.00` published and no abort raised.

**Verified behaviour table** (from `../poc/verify.py`, which models the exact comparison; `poc6` asserts
the same through the protocol's own functions):

| switchboard | pyth | supra | outcome | stored price |
|---|---|---|---|---|
| `$1.00` (honest) | `$2.00` | `$2.00` | accepted | **`$2.00`** — honest reading dropped, 2-of-3 wins |
| `$1.00` | `$1.00` | `$0.9999` | accepted | **`$0.99995`** — the two sources that agree exactly are ignored; the mean is taken over the outlier plus one of them |
| `$1.00` | `$1.05` | — | aborts | guard fires (`ESignificientPriceDiff`), showing the check does work at length ≥ 2 |

**Why this is a separate report.** F1 says no shipped path ever supplies two readings; F6 says that
even when two or three readings are supplied, what happens is not an aggregation. They need different
fixes and different tests.

## 3. Validation Steps

**Target:** `https://github.com/hackenproof-public/bucket-protocol` — oracle package.

**Prerequisites:** repository checkout; `python3` for step 1; `sui` CLI for step 2.

1. ```bash
   python3 poc/static_proof.py ./oracle   # check F6: only indices 0 and 1 are ever read
   python3 poc/verify.py ./oracle          # check [4], case "poc6  2 fake sources outvote 1 real"
   sed -n '40,65p' sources/parser/price_aggregator.move
   ```
   Expected: F6 `OK` printing `indices read: ['0', '1']`; verify.py reporting the stored price
   `2000000`; and a visible `pop_back` loop above the `borrow(&prices, 0/1)` reads.

2. ```bash
   sui move test aggregation_poc::poc6_third_source_is_dropped_and_two_outvote_one
   ```
   Expected: passes, asserting the stored price read back via `single_oracle::get_price` equals
   `2 * REAL`, i.e. two bogus readings over one honest one.

3. Optional order check: run `poc3b_two_close_prices_are_averaged` and note that its inputs are the
   *switchboard* and *pyth* slots — the two that survive reversal when supra is absent.

## 4. Supporting Files / PoC

**This report's own PoC file:** `poc/F6-third-source-dropped.move` — 4 tests, three of which are the
evidence for the two claims in this report: `poc_f6_list_order_is_reversed_before_the_average`
(asserts `1_015_000`, which is only reachable if `vector::pop_back` reversed the list),
`poc_f6_two_agreeing_fakes_outvote_one_honest` (asserts `2 * REAL`), and
`poc_f6_wild_third_outlier_is_never_examined` (a 1000x wrong reading that is silently discarded).
Attach with `poc/injector-snippet.move`.
Shared/auxiliary:
* `../poc/aggregation_poc.move` → `poc6_third_source_is_dropped_and_two_outvote_one`,
  `poc3b_two_close_prices_are_averaged`, `poc3_guard_fires_...` (aborting counterpart).
* `../poc/static_proof.py` (F6), `../poc/verify.py` (numeric table above).
* These exercise `single_oracle::update_oracle_price` → `price_aggregator::aggregate_price` →
  `process_prices` — the real functions, with the test-only collector setter from
  `poc/injector-snippet.move` as the only added code.
* **Observed output:** none produced by me (no Move toolchain installable in the authoring
  environment). Attach the step-2 transcript before submitting.

## 5. Severity Level

**Medium** — program band `$100 - $2,000` on its own.

Justification, on this defect alone: with three configured sources the pipeline publishes the mean of
two of them, chosen by a reversed list order, and discards the third without examining it — so the
thing the module calls aggregation is not aggregation, and 2-of-3 agreement is attacker-sufficient
where a median would not be. Verified by `poc_f6_wild_third_outlier_is_never_examined`, which needs
no other finding to be true.

**Independence.** The four tests in this file's PoC pass against the shipped code and remain valid
after F1 is fixed (they are the reason the F1 fix is insufficient on its own). Its severity would rise
to High only if two of the three feeds could be influenced by one party, which is F5's open question,
not a premise of this report.

## 6. Category

Used (closest fit, noted explicitly): **`Unsecure Design`**.

* `Hackproof_category.md` offers no "insufficient oracle aggregation / lack of consensus" entry under
  `Blockchain`; the defect is the aggregation algorithm itself (a two-element mean over a reversed
  vector), not an input-parsing or access issue.
* Rejected: `Blockchain > Transaction-Ordering Dependence (TOD) / Front Running` (list order is a
  code artefact, not transaction order), `Blockchain > Race Conditions` (single-threaded within one
  transaction).
* Program-side wording: "Attacks on logic (behavior of the code is different from the business
  description)".

## 7. Language

Submission language: **English**.

## 8. Target

`https://github.com/hackenproof-public/bucket-protocol` — the program's sole in-scope asset.

Cited from `Bucket-Protocol/oracle` @ `df8f6a418f24a82eaf22a8309878175ae33f2cf5`:
`sources/parser/price_aggregator.move:40-51` (`pop_back` at `:44`), `:53-65` (reads at `:60-61`,
mean at `:62`, guard at `:63`), `sources/single_oracle.move:223-225` (push order).
Placement caveat as in F1.
