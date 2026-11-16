# Bug Bounty Report — Bucket Protocol Smart Contracts (HackenProof)

Program: https://hackenproof.com/programs/bucket-protocol-smart-contracts
Target asset (the only one in scope): https://github.com/hackenproof-public/bucket-protocol
Code cited from: https://github.com/Bucket-Protocol/oracle @ `df8f6a418f24a82eaf22a8309878175ae33f2cf5` (2025-05-12)

## Status: Active investigation — F1-F7 drafted, **none submitted**. F8 **withdrawn as not-a-bug**
(see the retraction note below). Two blockers must be cleared before any submission: the oracle
package's placement inside the in-scope repo, and execution of the PoC suite (not run by me — no
Move toolchain could be installed in the authoring environment).

---

## Files (one finding per file, `Report_format.md` HackenProof 8-section format)

| File | Finding | Severity | Category |
|---|---|---|---|
| `bucket-oracle-price-aggregator-single-source-no-divergence-check.md` | F1 — aggregation never runs on any shipped path; one source sets the stored price, `threshold = 1`, and the aggregation primitives are capability-free and public | **High** (Critical if the oracle is confirmed inside the scoped repo) | `Unsecure Design` (closest fit) |
| `bucket-oracle-aggregator-accepts-zero-price-liquidation.md` | F2 — a zero reading is accepted and stored; the zero filter exists in one parser only | **High** | `Unsecure Design` (closest fit) |
| `bucket-oracle-aggregator-absolute-diff-future-timestamp-accepted.md` | F3 — staleness compared with an absolute difference, so future-dated readings count as fresh | Medium | `Blockchain > Timestamp Dependence` (exact fit) |
| `bucket-oracle-parsers-u128-to-u64-truncation-decimal-wrap.md` | F4 — decimal re-scaling truncates silently; the Supra decimals `u16 → u8` cast wraps and flips the scaling branch | Medium (High if F5's open question resolves) | `Blockchain > Integer Underflow` (closest fit) |
| `bucket-oracle-rules-unbound-source-no-capability-no-deviation-limit.md` | F5 — four derivative rules need no capability, bind no source object, impose no deviation limit, and bypass aggregation entirely | **High**, Critical pending a 2-minute mainnet check | `Broken Access Control (BAC)` (closest fit) |
| `bucket-oracle-aggregator-drops-third-source-two-of-three-outvote.md` | F6 — only the first two entries of a reversed vector are used; no median; 2-of-3 outvotes 1 | Medium | `Unsecure Design` (closest fit) |
| `bucket-oracle-pyth-parser-sign-guards-dead-source.md` | F7 — the sign guards in `pyth_parser` drop or abort for every possible input, so one of three documented sources can never contribute | Medium | `Unsecure Design` + `Blockchain > DoS with (Unexpected) revert` |

### Per-report PoC files (`Result(report)/poc/`)

Each finding now ships its own PoC, attachable to that report alone. Every file carries its own
prerequisite, run command and expected per-test result in its header.

| Report | PoC | Patch needed? |
|---|---|---|
| F1 | `Result(report)/poc/F1-single-source-no-divergence-check.move` (6 tests) | `injector-snippet.move` |
| F2 | `Result(report)/poc/F2-zero-price-accepted.move` (5 tests) | `injector-snippet.move` |
| F3 | `Result(report)/poc/F3-future-timestamp-accepted.move` (4 tests, incl. the accept/reject contrast pair) | `injector-snippet.move` |
| F4 | `Result(report)/poc/F4-parser-cast-truncation.move` (6 tests) | **no** |
| F5 | `Result(report)/poc/F5-rules-source-object-check.sh` (part [A] offline, part [B] mainnet instance counts) | **no** (not a Move test by design) |
| F6 | `Result(report)/poc/F6-third-source-dropped.move` (4 tests) | `injector-snippet.move` |
| F7 | `Result(report)/poc/F7-pyth-sign-guards-dead-source.move` (6 tests, 2 expected-abort) | **no** |

Shared artifacts: `Result(report)/poc/injector-snippet.move` (the test-only setter that F1/F2/F3/F6 require — its
header explains why a unit test needs it), `poc/static_proof.py`, `poc/verify.py`, and the combined
`poc/aggregation_poc.move` suite for a single-command run.

**Caveats on the PoC files**

* They have **not been compiled by me**. They are written against the public signatures at
  `df8f6a41`, so treat the first `sui move test` as a compile check; expect possible unused-import
  warnings (harmless).
* One real obstacle is pre-existing in the audited tree, not in these files: `std::u64::pow` is called
  with a `u8` exponent at `single_oracle.move:84`, `supra_parser.move:15,17`,
  `pyth_parser.move:41,43,67,68`, and `sui::math::pow` at `af_lp_rule.move:68`. If the current
  compiler rejects those, the package will not build for testing — a build issue in the public mirror,
  explicitly **not** submitted as a finding (compiler-version items are out of scope), and disclosed in
  `Result(report)/poc/F4-parser-cast-truncation.move` so triage is not misled. `static_proof.py` and `verify.py` need
  no build at all.
* No output has been fabricated anywhere. Where a report says "Observed output: none", keep it that
  way until the command is actually run.

---

## Corrections made during re-audit (kept visible rather than silently edited)

### F8 — withdrawn as not-a-bug

An earlier draft claimed that `update_price_from_supra` (`sources/bucket_oracle.move:256-265`)
bypasses the `assert!(bucket_oracle.version == PACKAGE_VERSION, 99)` kill-switch that the other three
update entry points carry inline (`:220`, `:236`, `:249`).

**That is wrong.** The first statement of the Supra path is `borrow_single_oracle_mut<T>(bucket_oracle)`,
and that helper performs the identical assertion at `bucket_oracle.move:211` — the same guard also sits
in `get_price` (`:201`) and `borrow_single_oracle` (`:206`). The version check is therefore enforced on
every read and write path, and the missing inline copy is a cosmetic inconsistency with no security
effect. `poc/static_proof.py` now asserts this as check `N1` so the item cannot be re-reported, and no
report file exists for F8.

### F1 — wording corrected after the same class of check

The earlier draft called the divergence guard "unreachable dead code". Strictly, `issue_price_collector`,
all four `collect_price_from_*` functions and `update_oracle_price` are plain `public`
(`single_oracle.move:113,139,159,186,208,216`), so a caller *can* compose a two-source collector in a
transaction block and reach the guard. The accurate statement, now used in F1, is that **no shipped
path ever feeds it two prices** (`threshold = 1` makes one source decisive anyway), and that the
aggregation primitives being capability-free and public is itself part of the finding. The fix and the
severity are unchanged.

---

## Shared sections (they are repeated per file because each file is submitted on its own)

**7. Language** — English for every report. The submitting account's registered email must be used
and the report must be filed exclusively through hackenproof.com within 24 hours of discovery
(program eligibility rules).

**8. Target** — all seven files cite `https://github.com/hackenproof-public/bucket-protocol`, the
program's single scope entry, with the line numbers taken from the public `Bucket-Protocol/oracle`
tree at the commit above.

**Two pre-submission blockers (they are in the individual files too):**

1. **Scope placement.** The scoped repository is private (invite-only). If `bucket_oracle` enters it
   only as an imported dependency, the program's exclusion "vulnerabilities in imported contracts"
   applies and F1-F7 should be closed rather than submitted. This is one read of the repo tree.
2. **PoC execution.** The program states that reports without a runnable PoC are not accepted. The
   Move suite has not been executed by me — the toolchain download was refused in this environment —
   so no screenshot or transcript exists yet. Run `sui move test` per `poc/README.md` §2, and at
   minimum run the two dependency-free scripts:
   ```bash
   python3 poc/static_proof.py ./oracle   # structural claims + live line numbers
   python3 poc/verify.py ./oracle         # every number asserted in the reports
   ```
   Do not attach output that was not produced.

**Scope defence, stated in every file.** Nothing reported here is a best-practice, style, redundancy,
gas-optimisation, compiler-version, or imported-contract issue, and none of it requires
front-running: the manipulated price is *persisted* into the `SingleOracle` object and consumed by
later transactions, and the update and the liquidation can be issued in the same transaction.

**One bug per report — enforced.** Each of the seven files claims exactly one defect, with one root
cause and one fix. Where a file previously leaned on another finding for its impact, that has been
removed and replaced with an "Independence" paragraph. Cross-references remain only to say that a
claim lives in the other file (so nothing is double-counted):

| Report | The one defect | Does NOT claim (filed elsewhere) | Independent of |
|---|---|---|---|
| F1 | no shipped update path supplies more than one source, and `threshold = 1`, so the configured cross-check is never applied | the missing range bound (F2), 2-of-3 aggregation (F6), Pyth being dead (F7) | all others |
| F2 | the aggregated price is stored without a range check (0 at one end, `u64::MAX` at the other) | source binding (F5) | F1 — proved by `poc_f2_zero_survives_a_second_agreeing_source` |
| F3 | the freshness comparison is two-sided, so future-dated readings count as fresh | the `u128 → u64` timestamp downcast and `× 1000` overflow (same sites, F4's class) | F1, F6 |
| F4 | values are narrowed into the oracle's 64-bit scale without validation (2 manifestations, 1 fix), incl. the rule-side sites | who may call the rule writers (F5) | F1, F2, F3, F5 |
| F5 | the rule write path validates neither the caller nor the source object | the unchecked casts on those paths (listed in F4) | F1, F2, F6 — the rule path never enters the aggregator |
| F6 | aggregation is a mean over the first two entries of a reversed vector; the third is discarded, no median | the zero bound (F2), single-source delivery (F1) | F1 — and it is why the F1 fix is not sufficient |
| F7 | `pyth_parser`'s sign guards drop or abort for every input, so one documented source can never contribute | aggregation structure (F1, F6) | all others |

**Submission order (7 separate reports, none merged).**

1. **F1** — most explanatory value; it frames the module.
2. **F2** — stands alone and has a passing-path PoC even at `threshold = 2`.
3. **F5** — submit only after Section 3 step 3 (mainnet instance counts) is filled in; without it the
   file is still submittable as High, but the report says so explicitly, so do not upgrade the label.
4. **F4**, **F7**, **F6**, **F3** — the correctness cluster; F3 and F7 may be triaged as
   informative/Low, which is what their own severity sections say.

Note that the program pays only for the highest-severity item in a chain of vulnerabilities. Keeping
these as seven separate single-defect reports (rather than one chained report) is the format the
program asks for; if triage decides two of them are one chain, they will merge them at the highest
severity rather than paying both — that is their call, not a reason to merge at submission time.
