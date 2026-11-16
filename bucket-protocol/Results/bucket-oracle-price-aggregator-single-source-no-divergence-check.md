# Bug Bounty Report — Bucket Protocol Smart Contracts — F1

## Status: Active — not yet submitted. PoC suite is written but has NOT been executed by the author
(no Move toolchain available in the authoring environment). Section 4 states exactly what must be
run before submitting.

## 1. Title

Oracle "price aggregation from multiple sources" never aggregates on the paths the protocol
actually uses: every shipped entry point delivers a single source, and the cross-source divergence
guard is never exercised

> Framing note: this is not a missing-access-control bug and it is not theoretical — it is a
> structural property of four call sites that two grep commands confirm (Section 3). One point is
> stated precisely rather than overstated: the divergence guard is not unreachable *in the language
> sense*. `collect_price_from_*`, `issue_price_collector` and `update_oracle_price` are plain
> `public`, so a caller can compose a two-source collector by hand. What is true is that **no
> shipped code path does**, and with `threshold = 1` a single source is decisive either way.
> Severity does not depend on that nuance, and it is disclosed because overclaiming would be wrong.

## 2. Vulnerability Details

**What the program promises.** The program description states the protocol consists of multiple
modules including a "Decentralized Oracle System: Price aggregation from multiple sources".

**What the code does — the single defect reported here:** on every price-update path the protocol
ships, the aggregator receives exactly one source reading, so the configured multi-source
cross-validation is never applied. All four entry points in `sources/bucket_oracle.move` have the
same shape — a *fresh* collector per call, exactly *one* source written into it, then the
call to the aggregation step:

| Entry function | header | fresh collector | one source collected | aggregate |
|---|---|---|---|---|
| `update_price_from_switchboard` | `:215` | `:222` | `:223` | `:224` |
| `update_price_from_pyth` | `:227` | `:238` | `:239` | `:240` |
| `update_price_from_pyth_read_only` | `:243` | `:251` | `:252` | `:253` |
| `update_price_from_supra` | `:256` | `:263` | `:264` | `:265` |

`single_oracle::update_oracle_price` (`sources/single_oracle.move:216-229`) then pushes the three
collector slots (`:223-225`); because only one of them is ever filled, the vector reaching
`price_aggregator::aggregate_price` has length **1** for every production call.

`price_aggregator::process_prices` (`sources/parser/price_aggregator.move:53-65`) branches on the
length: the `prices_len == 1` branch (`:57-58`) returns that lone value with no comparison, and the
`ESignificientPriceDiff` assertion (`:63`, `diff * 50 <= avg`, i.e. a ~2% band) exists only in the
`prices_len >= 2` branch. A repository-wide search finds no other caller of
`issue_price_collector` / `update_oracle_price`, so **the cross-check never runs on any path the
protocol itself ships**.

The deployment parameters make it worse rather than better: `init` creates the live SUI feed with
`threshold = 1` (`sources/bucket_oracle.move:61-66`, alongside `precision_decimal = 6` and
`tolerance_ms = 3600_000`), so `ENotEoughPrices` (`price_aggregator.move:55`) does not impose a
second source either.

**Supporting mechanism (not a second claim).** The same primitives that would have to be used to
supply more than one reading are visible to any caller: `issue_price_collector`
(`single_oracle.move:208`), the four `collect_price_from_*` (`:113`, `:139`, `:159`, `:186`) and
`update_oracle_price` (`:216`) are plain `public`, not `public(friend)`. That is reported here only
because it shows the guard is *reachable in principle* — so the defect is precisely "no shipped path
supplies two readings", not "the check is missing" and not "the check is unreachable". No separate
access-control finding is filed on the visibility itself; authorisation on the rule-side writer is a
different defect and is F5.

**Root cause.** The collector is instantiated inside each entry function instead of being
accumulated across sources before a single aggregation step, and `threshold` is deployed as 1, so
nothing in the design ever requires two feeds to agree.

**Independence.** This report stands alone. Its severity and its PoC do not depend on F2, F6 or F7
being accepted: with the other three findings fixed exactly as suggested, the shipped paths would
still deliver one reading each and the cross-check would still never be applied.

**Reproduction context.** No privileged access, no funds, no specific market state required: any
sender may call any of the four entry functions, which take the shared `BucketOracle` object and a
source object the protocol has already configured.

## 3. Validation Steps

**Target:** `https://github.com/hackenproof-public/bucket-protocol` — oracle package
(see Section 8; the equivalent public tree is `Bucket-Protocol/oracle` @ `df8f6a41`).

**Prerequisites:** the repository checked out; `python3` (stdlib only) or `git grep`. No network,
no testnet, no wallet.

1. Confirm each entry point creates exactly one fresh collector and collects exactly one source:

   ```bash
   python3 poc/static_proof.py ./oracle     # checks F1a, F1b, F1c, F1d, F1f + live line numbers
   ```
   Expected: `OK` for F1a/F1b/F1c/F1d/F1f, exit code 0.

2. Confirm the guard sits only in the length-≥2 branch:

   ```bash
   python3 poc/verify.py ./oracle           # check [3]
   ```
   Expected output includes `PASS … guard compares only indices 0 and 1` and the ordering proof
   that the `prices_len == 1` branch precedes `ESignificientPriceDiff`.

3. Manual cross-check (three commands, ~1 minute):

   ```bash
   grep -n "issue_price_collector\|collect_price_from_\|update_oracle_price(" sources/bucket_oracle.move
   grep -n "push_price" sources/single_oracle.move
   sed -n '53,65p' sources/parser/price_aggregator.move
   ```
   Each entry function must show one `issue_price_collector` and one `collect_price_from_*`.

4. Confirm the primitives are capability-free (the public-visibility half of the finding):

   ```bash
   grep -n "public(friend) fun\|public fun\|public entry fun" sources/single_oracle.move
   ```
   Expected: `collect_price_from_*` (`:113`, `:139`, `:159`, `:186`), `issue_price_collector` (`:208`)
   and `update_oracle_price` (`:216`) carry no `friend` restriction; only `new`, the `update_*_config`
   setters, `add_rule` and `remove_rule` do.

4. Confirm the deployed threshold: `sed -n '61,66p' sources/bucket_oracle.move` → `6, 3600_000, 1,`.

## 4. Supporting Files / PoC

**This report's own PoC file:** `poc/F1-single-source-no-divergence-check.move` — 6 tests
(`poc_f1_single_source_price_stored_verbatim`, `poc_f1_single_source_absurd_deviation_stored`,
`poc_f1_guard_is_functional_when_two_prices_are_supplied`, `poc_f1_two_close_prices_are_averaged`,
`poc_f1_shipped_shape_cannot_satisfy_threshold_two`, `poc_f1_empty_collector_abort`). Attach it with
`poc/injector-snippet.move`; run instructions and expected results are in its header.
Shared/auxiliary:
* `../poc/static_proof.py` — asserts the structural claims above against the real sources and prints
  live line numbers. Dependency-free, read-only.
* `../poc/verify.py` — additionally evaluates the aggregator's decision procedure so every number in
  this report is reproduced numerically.
* `../poc/aggregation_poc.move` + `poc/injector-snippet.move` — runnable Move tests:
  `poc1_single_source_sets_the_stored_price_verbatim` (one source → stored price),
  `poc3_guard_fires_when_the_collector_holds_two_diverging_prices` (**aborts**, proving the guard is
  functional but never exercised by a shipped entry point), and
  `poc3b_two_close_prices_are_averaged` (the intended behaviour exists at length 2).
* **Observed output:** none yet. The Move suite has not been compiled or executed in the environment
  that produced this report, and I will not attach output I did not observe. Run
  `sui move test` per `../poc/README.md` §2 and paste the console transcript into this section before
  submitting. Steps 1-3 above are already reproducible by the triager without any toolchain.

## 5. Severity Level

**High** — program band `$5,000 - $7,000`.

Justification, assessed on this finding alone: the price that authorises liquidation is set by a
single feed of the caller's choosing and is published without any comparison against the other two
configured feeds, even though the product advertises multi-source aggregation and pays for three
sources. The stored value is consumed by later transactions, so this is not an ordering effect. I am
not borrowing F2's zero-price or F6's majority-capture impact into this severity — those are
separate reports with separate fixes, and the program's chain rule would collapse them anyway.

Why it is High rather than Critical in this file: the direct loss-of-funds demonstration requires
either a feed that emits 0 (F2) or influence over two feeds (F5/F6). What this report proves on its
own is that the protocol's only structural defence against a single bad or chosen reading is
disabled in operation. If triage treats "one caller-chosen source sets a liquidation-critical price
with no validation" as sufficient, Critical (`$10,000 - $15,000`) is defensible and I would not
argue against it.

## 6. Category

`Hackproof_category.md` has no oracle/aggregation entry under `Blockchain`, so the **closest-fit**
category is used, explicitly noted as requested:

* Used: **`Unsecure Design`** — the aggregation step described in the product spec is structurally
  absent, which is a design defect rather than an injectable input flaw.
* Nearest `Blockchain` alternatives considered and rejected: `Timestamp Dependence` (belongs to F3),
  `Transaction-Ordering Dependence (TOD) / Front Running` (rejected — the attack does not require
  ordering; the poisoned price is persisted and consumed by later transactions), `Integer Underflow`
  (belongs to F4).
* Alternative framing, if the capability-free public primitives are treated as the primary defect
  rather than as an aggravating fact: `Broken Access Control (BAC)`. That framing is used for F5; F1
  is filed on the aggregation logic to keep the two fixes separable.
* Program-side wording this maps to: "Attacks on logic (behavior of the code is different from the
  business description)".

## 7. Language

Submission language: **English** (program requires reports in English; the submitter registered
account and email must be used as stated in the program's eligibility rules).

## 8. Target

`https://github.com/hackenproof-public/bucket-protocol` — the only asset listed in this program's
scope.

Citation basis: `https://github.com/Bucket-Protocol/oracle` at commit
`df8f6a418f24a82eaf22a8309878175ae33f2cf5` (2025-05-12), files
`sources/bucket_oracle.move`, `sources/single_oracle.move`, `sources/parser/price_aggregator.move`.
The scoped repository is private (invite-only), so this finding must be re-verified there before
submission; if the oracle package only enters the scoped repo as an imported dependency, the
program's "vulnerabilities in imported contracts" exclusion applies and this report should be
closed rather than triaged.
