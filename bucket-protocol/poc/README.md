# PoC package — Bucket Protocol oracle: aggregation never aggregates

Companion to `../report.md`. Four artifacts here, two of which actually execute the protocol's own
code. Each individual finding also has its own PoC, in `../Result(report)/poc/` — see the section at
the end.

| File | What it is | Needs a Move toolchain? |
|---|---|---|
| `static_proof.py` | Read-only structural check over the project's own `.move` sources. Asserts that each cited code shape still exists and prints the **live line numbers** for it. Stdlib only — run this first. | no |
| `verify.py` | Read-only static + numeric verification. Proves that no shipped entry path ever supplies two prices to the divergence guard, and re-derives every number asserted in the Move tests. Stdlib only. | no |
| `aggregation_poc.move` | Combined `#[test_only]` Move test module (15 tests, one command — same assertions as the per-report files). Calls the protocol's `update_oracle_price` / `get_price` / `price_aggregator::new` / `pyth::i64`. | yes (`sui move test`) |
| `../Result(report)/poc/injector-snippet.move` | 3 `#[test_only]` setters to paste into `single_oracle.move`. Required only because a unit test cannot own live Switchboard/Pyth/Supra source objects. | yes |

Script finding IDs differ from the report numbering: `static_proof.py` F7 = report Finding 5 (rule
path) and F8 = report Finding 7 (Pyth parser); F1-F4 and F6 match. Check `N1` in `static_proof.py`
records the **withdrawn** item (the Supra path's missing inline version assert is *not* a bypass —
`borrow_single_oracle_mut` enforces it at `bucket_oracle.move:211`), so it cannot be re-reported.

**Reference commit:** `Bucket-Protocol/oracle` @ `df8f6a418f24a82eaf22a8309878175ae33f2cf5` (2025-05-12).
Line numbers in `report.md` are from that commit. If you run against a newer tree, re-derive them.

---

## 1. Fast path — no toolchain (about 10 seconds)

```bash
git clone https://github.com/Bucket-Protocol/oracle
python3 poc/static_proof.py ./oracle   # structural proof, prints live line numbers
python3 poc/verify.py ./oracle         # reachability proof + every asserted number
```

Expected: `OK` on every line and `N of N findings verified as still present.` from `static_proof.py`;
`PASS` on every line and `ALL CHECKS AGREE WITH THE REPORT` from `verify.py`; exit code `0` for both.
This is the evidence for findings 1, 2, 3, 4, 6, 7 and it is reproducible by anyone, with no
dependencies.

## 2. Full path — runnable Move PoC (about 3 minutes)

```bash
# 0) prerequisite
sui --version

# 1) the audited sources
git clone https://github.com/Bucket-Protocol/oracle
cd oracle

# 2) paste the injector inside `module bucket_oracle::single_oracle { ... }`,
#    right after the existing `update_price_for_testing` at the end of the file:
#        sources/single_oracle.move
#    (see the header comment of ../Result(report)/poc/injector-snippet.move for exact placement)

# 3) drop the test module in
mkdir -p sources/tests
cp /path/to/poc/aggregation_poc.move sources/tests/

# 4) run
sui move test                      # all package tests
sui move test aggregation_poc      # or filtered, if your CLI supports the positional filter
```

Paste the console output into the report's PoC field (or record a short terminal video —
HackenProof triage accepts either, and a video sidesteps any "AI-generated" objection).

## 3. What each test proves

| Test | Finding | Expected result |
|---|---|---|
| `poc1_single_source_sets_the_stored_price_verbatim` | 1 | pass — one source becomes the stored price |
| `poc2_zero_price_from_one_source_is_stored` | 2 | pass — `price == 0` is stored |
| `poc2b_..._one_hundred_thousand_percent_deviation...` | 1 | pass — $0.000001 stored where the feed says $1 |
| `poc2c_max_u64_price_from_one_source_is_stored` | 1 | pass — `u64::MAX` stored |
| `poc3_guard_fires_when_the_collector_holds_two_diverging_prices` | 1 | **aborts with code 1** — the guard works when fed two prices, which is exactly what no shipped entry path does |
| `poc3b_two_close_prices_are_averaged` | 1 | pass — `1_005_000`, i.e. the intended behaviour exists |
| `poc4_reading_timestamped_just_ahead_of_the_clock_is_accepted` | 3 | pass — a future-dated reading counts as fresh |
| `poc5_same_offset_into_the_past_is_rejected` | 3 | **aborts with code 0** — the past side is enforced, the future side is not bounded |
| `poc6_third_source_is_dropped_and_two_outvote_one` | 6 | pass — stored price `2_000_000`, the honest `$1` reading is silently discarded |
| `poc7_consumers_reject_the_stored_price_after_10_seconds` | context | **aborts with code 2** — documents the 10 s consumer window (why the attack is one transaction) |
| `poc8_u64_cast_of_a_scaled_u128_wraps_instead_of_aborting` | 4 | pass — `1e24 → 2003764205206896640` |
| `poc8b_decimal_u16_cast_to_u8_wraps_and_flips_the_scaling_branch` | 4 | pass — `256 → 0`, `264 → 8` |
| `poc9 / poc9b / poc9c` | 7 | pass / **aborts with code 0** / pass — all four sign combinations of `pyth_parser`'s guards either drop the reading or abort |

## 4. Honest caveats (please read before submitting)

* **Findings 1-7 were not produced by running the Move suite here.** No Move toolchain could be
  installed in the environment that wrote these files (the download was refused), so treat the
  first `sui move test` run as a compile check: if a line is rejected, the fix is almost always a
  `use` path or a `mut` placement — and `static_proof.py` plus `verify.py` carry the same
  assertions independently, with no toolchain required. Do not submit a screenshot you have not
  produced.
* **The injector is test-only scaffolding, not the vulnerability.** Its purpose is to reach the
  aggregation code with an N-source collector, which is precisely what production cannot do.
  The reachability claim itself is proven statically by `verify.py` step [1] and [2], and by the
  four call sites; say so in the report if triage asks.
* **`poc8`/`poc8b` test Move's cast semantics, not the parser functions.** A Supra `OracleHolder`
  is unreadable in a unit test (`native public fun get_price`), so the parser path cannot be
  invoked. The finding is the expression, and it is verifiable by reading
  `sources/parser/supra_parser.move:12-20`.
* Keep these files out of the client repository; they are PoC scaffolding.

## 5. Two open questions that change the severity

1. Is `bucket_oracle` inside the program's in-scope repo, or is it an imported package?
   If it is imported, "vulnerabilities in imported contracts" (explicitly out of scope) applies
   and the report will be rejected regardless of merit.
2. On mainnet, can an attacker present a non-canonical instance of the source objects used by
   `vsui_rule` / `hasui_rule` / `afsui_rule` / `af_lp_rule` (Volo `NativePool`, Aftermath
   `Pool<LP>` / `Safe`, Haedal `Staking`)? If yes, finding 5 is a direct Critical. If not,
   findings 1+2 still stand, but the price must be moved through legitimate protocol state.

## 6. Per-report PoC files (`../Result(report)/poc/`)

Each finding ships its own attachable PoC, with its own prerequisite / run command / expected
results in the file header:

| PoC | Tests | Needs the injector? |
|---|---|---|
| `F1-single-source-no-divergence-check.move` | 6 | yes |
| `F2-zero-price-accepted.move` | 5 | yes |
| `F3-future-timestamp-accepted.move` | 4 | yes |
| `F4-parser-cast-truncation.move` | 6 | **no** |
| `F5-rules-source-object-check.sh` | part [A] offline structural check, part [B] mainnet object-instance query | **no** (deliberately not a Move test) |
| `F6-third-source-dropped.move` | 4 | yes |
| `F7-pyth-sign-guards-dead-source.move` | 6 (2 expected-abort) | **no** |

Run **either** the combined `aggregation_poc.move` **or** the per-report files, not both at once: they
assert the same properties under different module names, and `poc6_*`/`F6` overlap is intentional, not
a duplication bug.

Build caveat that applies to all Move files (also stated in `F4-parser-cast-truncation.move`): the
audited sources call `std::u64::pow` with a `u8` exponent (`single_oracle.move:84`,
`supra_parser.move:15,17`, `pyth_parser.move:41,43,67,68`) and `sui::math::pow` with a `u8` exponent
(`af_lp_rule.move:68`). If the current compiler rejects those, the package will not build for testing.
That is a property of the published mirror, **not** one of these files, and it is not submitted as a
finding (the program excludes compiler-version issues). `static_proof.py`, `verify.py` and the
structural part of `F5-…sh` need no build at all.
