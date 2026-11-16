# Bug Bounty Report — Bucket Protocol Smart Contracts — F4

## Status: Active — not yet submitted. The arithmetic is verified numerically; the Move tests that
document Move's cast semantics are written but not executed by me.

## 1. Title

Decimal re-scaling in the Oracle parsers silently truncates to 64 bits, and the Supra parser's
`u16 → u8` decimals cast wraps — producing a price that is wrong by a factor of ~10^6 instead of
aborting

> Framing note: **one defect** — the parsers narrow a feed value to the oracle's 64-bit scale
> without validating it first. In Move an `as` downcast truncates and never aborts, so the failure is
> silent. It has two manifestations (the `u128 → u64` price cast, and the `u16 → u8` decimals cast that
> also selects the wrong scaling branch) and one fix family: validate the magnitude before narrowing.
> Filed separately from F1/F2/F3 because none of those fixes touch this code, and it maps directly onto
> the program's explicitly in-scope "Over and underflows" item.
> **Sites of this single defect** (all reported here, so that no other report claims them):
> `supra_parser.move:12,15-20`, `switchboard_parser.move:24-30`, `pyth_parser.move:35-47,56-73`, and the
> same pattern on the rule side at `vsui_rule.move:22`, `af_lp_rule.move:71-73`, `afsui_rule.move:32-34`.

## 2. Vulnerability Details

**The pattern.** Each parser converts a feed value into the oracle's own decimal scale by multiplying
or dividing by `10^(required_decimal - decimal)` and then casting the intermediate to `u64`:

* `sources/parser/supra_parser.move:14-20` — rescales in `u128`, then `(price_u128 as u64)` with no
  range check;
* `sources/parser/switchboard_parser.move:24-30` — identical shape (`(price_u128 as u64)`);
* `sources/parser/pyth_parser.move:40-43` and `:65-68` — rescales in `u64` instead, so an oversized
  value aborts with an arithmetic error rather than wrapping. The three parsers therefore do not
  fail the same way, which is itself a strong indication that the `u128`-then-cast variants are
  unintended.
* `sources/parser/supra_parser.move:12` — `(decimal_u16 as u8)` narrows the feed's decimals field
  from 16 to 8 bits before the branch comparison at `:14`.

**Verified numbers** (computed by `../poc/verify.py`, check [5]; reproduced by `poc8_*` in the Move
suite):

| expression | intended | actual | consequence |
|---|---|---|---|
| raw `1e18`, source decimals `0`, required `6` | `1e24` (or abort) | `2003764205206896640` | stored price wrong by ≈10^6, no error raised |
| decimals `256` after `u16 → u8` | reject / invalid | `0` | the parser takes the *multiply* branch instead of *divide*: scaling flips |
| decimals `264` after `u16 → u8` | reject / invalid | `8` | same branch inversion, different magnitude |

**Why this matters at length 1.** With F1 there is no second reading to disagree with the truncated
value, and `price_aggregator.move:57-58` accepts whatever it is given, so a truncated price is
published verbatim. The branch inversion in the second row is the more dangerous half: it converts a
value that should be divided by 10^n into one that is multiplied by 10^n, which is exactly the
magnitude of error needed to flip a health factor.

**Reachability, stated honestly.** The `value`/`decimals` pair is read from the source feed. In the
Switchboard case the scaling factor belongs to the aggregator and is not attacker-chosen; in the Supra
case it is read through a native accessor from an `OracleHolder` that Bucket does not authenticate, so
whether an unprivileged caller can choose those inputs is F5's open question and is **not** claimed by
this report. Two further disclosures: I could not construct a Supra `OracleHolder` in a unit test (the
accessor is a native declaration), so the parser functions themselves are not executed by the PoC —
what it executes is Move's cast semantics on the identical expressions — and the defect as a *code*
defect does not depend on that: an honest feed with an unusual decimals field is enough to trigger the
branch inversion.

**Independence.** This report stands on its own: the wrap and the branch inversion are properties of
the expressions, so fixing F1 (more sources), F3 (comparison direction) or F5 (capabilities) neither
prevents nor explains them. `poc_f4_wrapped_decimal_flips_the_scaling_branch` is a complete
demonstration of the second manifestation with no dependency on any other finding.

## 3. Validation Steps

**Target:** `https://github.com/hackenproof-public/bucket-protocol` — oracle package.

**Prerequisites:** repository checkout; `python3` (stdlib) for step 1; `sui` CLI for step 2.

1. ```bash
   python3 poc/static_proof.py ./oracle   # checks F4a, F4b
   python3 poc/verify.py ./oracle          # check [5]: the three numbers in the table above
   sed -n '10,24p' sources/parser/supra_parser.move
   ```
   Expected: F4a `OK` (no `max_value` guard in any parser), F4b `OK` (Pyth rescales in `u64`,
   i.e. inconsistent handling), and the three numeric values.

2. ```bash
   sui move test aggregation_poc::poc8_u64_cast_of_a_scaled_u128_wraps_instead_of_aborting
   sui move test aggregation_poc::poc8b_decimal_u16_cast_to_u8_wraps_and_flips_the_scaling_branch
   ```
   Expected: both pass; the first asserts `(1e18 * 1e6) as u64 == 2003764205206896640` and that the
   `u128` intermediate really does exceed `u64::MAX`, the second asserts `256 → 0`, `264 → 8` and that
   the wrapped decimal takes the multiply branch.

## 4. Supporting Files / PoC

**This report's own PoC file:** `poc/F4-parser-cast-truncation.move` — 6 tests and **no patch
required** (nothing else in this submission avoids the injector; this one does, because the defect is
an expression). Includes `poc_f4_pyth_style_u64_rescale_aborts_instead`, which demonstrates the
inconsistent handling between parsers, and a header note about the audited tree's
`std::u64::pow(10, <u8>)` call sites possibly failing to compile — a build issue in the public mirror,
not a security finding, and not caused by this file.
Shared/auxiliary:
* `../poc/aggregation_poc.move` → `poc8_*`, `poc8b_*`.
* `../poc/static_proof.py` (F4a, F4b), `../poc/verify.py` (numeric).
* **Not covered by the PoC:** a call into `supra_parser::parse_price` or `switchboard_parser::parse_price`
  with a live source object. Those need objects a unit test cannot own. The report labels these as
  semantics proofs rather than pretending to have exercised the parser, and the parser claim is
  verifiable by reading twelve lines.
* **Observed output:** none produced by me (no Move toolchain in the authoring environment). Attach
  the transcript of step 2 before submitting.

## 5. Severity Level

**Medium** — program band `$100 - $2,000`; escalates to **High** if the Supra holder or the feed's
decimals field turns out to be influenceable by an unprivileged party (the open question is F5's),
and to Critical only in combination with F1+F2 for a listed collateral.

Justification: the defect is unconditional and silent (a wrong price, not a revert), but I have not
demonstrated a path where an attacker chooses the inputs, so I am not filing it as High by default.

## 6. Category

Used (closest fit, noted explicitly): **`Blockchain > Integer Underflow`**.

* Rationale for the substitution: `Hackproof_category.md`'s `Blockchain` list has no "integer
  truncation / unsafe downcast" entry, and the observable effect here is the same class of numeric
  defect — the stored value wraps instead of failing. `Memory Corruption > Integer Overflow` exists in
  the list but belongs to native/binary memory corruption rather than Move value semantics.
* Alternative if the triage team prefers the design framing: `Unsecure Design`.
* Program-side wording: "Over and underflows" (explicitly listed as in scope).

## 7. Language

Submission language: **English**.

## 8. Target

`https://github.com/hackenproof-public/bucket-protocol` — the program's sole in-scope asset.

Cited from `Bucket-Protocol/oracle` @ `df8f6a418f24a82eaf22a8309878175ae33f2cf5`:
`sources/parser/supra_parser.move:12,14-20`, `sources/parser/switchboard_parser.move:24-30`,
`sources/parser/pyth_parser.move:40-43,65-68`, `sources/parser/price_aggregator.move:57-58`.
Related rule-side casts of the same shape: `rules/vsui-rule/sources/vsui_rule.move:22`,
`rules/aftermath-lp-rule/sources/af_lp_rule.move:71-73`, `rules/afsui-rule/sources/afsui_rule.move:32-34`.
Placement caveat as in F1.
