# Bug Bounty Report — Bucket Protocol Smart Contracts — F7

## Status: Active — not yet submitted. Fully determined by case enumeration over the project's own
`i64` accessors; the executable part is a 4-row proof, the rest is 4 lines of reading.

## 1. Title

One of the three documented price sources can never contribute a reading: the sign guards in
`pyth_parser` are tested in an order that returns `none()` or aborts for every possible input

> Framing note: this is filed as a correctness/availability defect, not as a fund-loss bug. Its
> security value is that it makes the "aggregation from multiple sources" claim false even after F1
> and F6 are fixed, and that the Pyth update entry points abort unconditionally.

## 2. Vulnerability Details

**The guard sequence.** `sources/parser/pyth_parser.move` — identical in both functions
(`parse_price` at `:35-38`, `parse_price_read_only` at `:60-63`):

1. `if (i64::get_is_negative(&decimal_i64)) return option::none();` — so the function continues only
   when the expo is **non-negative**.
2. `if (!i64::get_is_negative(&price_i64)) return option::none();` — so it continues only when the
   price is **negative**.
3. `let decimal_u8 = (i64::get_magnitude_if_negative(&decimal_i64) as u8);` — this accessor asserts
   that its argument **is** negative.
4. `let price = (i64::get_magnitude_if_positive(&price_i64));` — this accessor asserts that its
   argument **is not** negative.

**The accessors** (`partners/pyth/sources/i64.move:39-51`, the same module the parser imports):
`get_is_negative` returns the sign flag; `get_magnitude_if_positive` aborts on a negative value;
`get_magnitude_if_negative` aborts on a non-negative value.

**Complete enumeration** (`../poc/verify.py` check [6]; three of the four cases are asserted in
`poc9`/`poc9b`/`poc9c`):

| expo negative | price negative | path taken | result |
|---|---|---|---|
| yes | yes | step 1 | `option::none()` — no reading |
| yes | no | step 1 | `option::none()` — no reading |
| no | no | step 2 | `option::none()` — no reading |
| no | yes | steps 1, 2 pass → step 3 | **abort** (step 3 requires the expo to be negative, but step 1 guaranteed it is not) |

There is no input for which a price is produced.

**Why that is the deployed situation, not a corner case.** Pyth price feeds carry a negative expo
(e.g. `-8` for a USD pair) and a positive price magnitude — the first row of the table's third
column pattern: step 1 drops the expo-negative case outright, and the normal (expo negative, price
positive) combination returns `none()`. So `update_price_from_pyth` and
`update_price_from_pyth_read_only` either abort with `ENotEoughPrices` (when `threshold = 1`, the
deployment value, because the collector ends up empty) or contribute a permanently `none` slot.

**Impact boundaries — stated so this report is not over-read.**

* Affected: the redundancy promised by "price aggregation from multiple sources" (the program's own
  description), and the availability of the Pyth update entry points, which cannot succeed.
* Not affected: no funds move because of this finding alone. It does not create a price by itself;
  it removes one of the three checks that would otherwise have made F1/F6 harder to exploit.
* Interaction: with the Pyth slot always empty, an aggregator fixed to require `threshold = 2` would
  reduce to switchboard + supra only, and the ordering subtlety in F6 becomes the deciding factor.

## 3. Validation Steps

**Target:** `https://github.com/hackenproof-public/bucket-protocol` — oracle package.

**Prerequisites:** repository checkout; `python3` for step 1; `sui` CLI for step 2.

1. ```bash
   python3 poc/static_proof.py ./oracle   # check F8: both guards appear twice (VAA + read-only), the accessor asserts negative
   sed -n '35,38p;60,63p' sources/parser/pyth_parser.move
   sed -n '39,51p' partners/pyth/sources/i64.move
   ```
   Expected: the guard order and the two accessor assertions are directly visible; no range or
   zero check between them.

2. ```bash
   sui move test aggregation_poc::poc9_normal_positive_price_is_dropped_by_the_guards
   sui move test aggregation_poc::poc9b_the_only_input_that_passes_both_guards_then_aborts
   sui move test aggregation_poc::poc9c_all_four_sign_combinations_are_covered
   ```
   Expected: `poc9` and `poc9c` pass; `poc9b` **aborts with code 0**, i.e. it demonstrates the
   remaining case rather than asserting around it.

3. Optional mainnet corroboration: `sui_getEvents` for `ParsePriceEvent` with `source_id: 1`
   (`sources/single_oracle.move:16-20`, `:147`, `:172`) — the emitted `price_info` should be `none`
   for every Pyth collection ever observed.

## 4. Supporting Files / PoC

**This report's own PoC file:** `poc/F7-pyth-sign-guards-dead-source.move` — 6 tests and **no patch
required**: it imports `pyth::i64` itself, the module `pyth_parser.move:13` imports, so the accessor
assertions are taken from the project's own dependency. Includes
`poc_f7_the_only_surviving_case_aborts` and `poc_f7_step_d_also_aborts_on_the_surviving_case`
(both expected-abort), `poc_f7_no_input_produces_a_price` (all four sign combinations accounted for as
non-productive), and `poc_f7_the_intended_reading_is_obtainable`, which shows the corrected accessor
pair does read a normal quote — i.e. the fix is one-line and reachable.
Shared/auxiliary:
* `../poc/aggregation_poc.move` → `poc9`, `poc9b` (expected abort), `poc9c`. These call
  `pyth::i64::new`, `get_is_negative`, `get_magnitude_if_negative` — the project's own dependency
  module, not a reimplementation.
* `../poc/static_proof.py` (check F8), `../poc/verify.py` (check [6], the 4-row table).
* **Not covered:** a call into `pyth_parser::parse_price` itself, which needs Wormhole and Pyth state
  plus a signed VAA. The enumeration does not need them: the guard order alone determines the
  outcome, which is why step 1 is sufficient for triage.
* **Observed output:** none produced by me (no Move toolchain in the authoring environment). Attach
  the step-2 transcript before submitting.

## 5. Severity Level

**Medium** — program band `$100 - $2,000`.

Justification: the defect is unconditional and the affected source cannot be salvaged by
configuration, but no value is lost by it directly; its weight is that it silently reduces a
documented 3-source design to 2 sources and permanently breaks two public entry points.

**Independence.** This is a defect inside `pyth_parser` alone: it is unaffected by, and does not
contribute to, the fixes proposed in F1, F2, F3 or F6. Its PoC (`poc_f7_*`) needs no injector and no
other finding, and the enumeration in Section 2 covers every possible input, so nothing here is
conditional on deployment configuration. If the maintainers prefer to close it as a functional bug
rather than a security one, the availability half — two public entry functions that can never
complete — stands on its own.

## 6. Category

Used (closest fit, noted explicitly): **`Unsecure Design`**.

* A second category also genuinely applies and should be recorded if the triage system accepts two:
  **`Blockchain > DoS with (Unexpected) revert`** — `update_price_from_pyth` and
  `update_price_from_pyth_read_only` cannot complete, which is exactly an unexpected revert on a
  public entry point.
* Primary is `Unsecure Design` because the loss of one documented aggregation source is the
  substantive finding; the revert is its symptom.
* Program-side wording: "Attacks on logic (behavior of the code is different from the business
  description)".

## 7. Language

Submission language: **English**.

## 8. Target

`https://github.com/hackenproof-public/bucket-protocol` — the program's sole in-scope asset.

Cited from `Bucket-Protocol/oracle` @ `df8f6a418f24a82eaf22a8309878175ae33f2cf5`:
`sources/parser/pyth_parser.move:35-38`, `:60-63` (guards and magnitude calls),
`partners/pyth/sources/i64.move:39-51` (accessor semantics; **third-party code — cited only to fix
the meaning of Bucket's own guard order, not reported as a vulnerability in an imported contract**),
`sources/bucket_oracle.move:227-241`, `:243-254` (the two dead entry points),
`sources/single_oracle.move:16-20` (`ParsePriceEvent`). Placement caveat as in F1.
