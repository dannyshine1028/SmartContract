# Metric (Immunefi) — FINDINGS

Program: https://immunefi.com/bug-bounty/metric/information/ ・ scope: `Source/metric/PROGRAM.md`
Rules that constrain everything here: **local fork only**, no mainnet/testnet tx; trusted roles are OOS;
oracle data is assumed correct; known issues (audits + `Metricxyz/Known_issues`) are ineligible **including
reports sharing a root cause**.

## 0. Environment (reproducible)

- `pool-contracts` @ `ddf8ae0c`, `oracle-contracts` @ `7525bbd6`, `periphery-contracts` @ `53cbe784`
  (all 2026-10-30), submodules initialised, `forge` 1.8.3, solc **0.8.35**, `via_ir` on.
- `forge build` OK (compiles with lint warnings only). Baseline: shipped suite passes —
  `MetricOmmPoolSwap`: 35/35 PASS.
- Probes added by me live in `pool-contracts/test/PoolSolvencyProbe.t.sol` and
  `periphery-contracts/test/AdderBoundsProbe.t.sol`.

## 1. Areas ruled out before hunting (dedup discipline)

- **Core swap math (`SwapMath`)** and **`MetricOmmPoolLiquidityAdder`** are listed as *reported,
  fix pending*. A finding whose root cause is in either is ineligible. (New, unrelated root causes inside
  the same files are still fair game, but must not be the known issue.)
- **`ScheduledMultiplier`**, multiplier pricing on BNB Chain, frontend bundle config — reported.
- **Oracle-shock + two-leg cycle drain** (`other/contest-known-issues.pdf`) — known; "findings that only
  restate this" are ineligible. Rules out the whole "oracle moves → arbitrage stale bins" family.
- Previously disclosed: stop-loss `afterSwap` gas growth; >80 bins/side pool creation; quoter single-hop
  partial fill; permissionless `MultiplierOracle` feeds (by design); custom price providers (by design).

## 2. Probes written and results

### P-A. `addLiquidityWeighted` cap guarantee (periphery) — HOLDS

Declared invariant: never spend more than `maxAmountToken0/1` (docs on both overloads, plus the
`_scaleWeightsToShares` "one wei of headroom per bin" logic). The final backstop is the callback's
`amount0Delta > max0 || amount1Delta > max1` revert.

Tests (inherit the shipped fixture verbatim, so pool/oracle/bins are byte-identical to the project's own):

| test | result |
|---|---|
| `testFuzz_P1_weightedNeverExceedsCap(uint96 cap0, uint96 cap1)` — 300 runs over tight caps | **PASS** (never exceeded) |
| `testFuzz_P2_zeroCapOneLeg(uint96 cap)` — a 0 cap on one leg must not unbound the other | **PASS** |
| `test_P3_reportedAmountsMatchSpend` — returned amounts == tokens actually pulled | **PASS** |

⇒ The zero-cap branch (`scaleWad = type(uint256).max` when `need == 0`) is safe because the paying
callback still enforces the absolute cap. No finding.

### P-B. Pool solvency under add / swap / full-exit interleavings (pool) — HOLDS

| test | result |
|---|---|
| `testFuzz_S1_binsDoNotClaimMoreThanBalance` — Σ bin balances ≤ token balance of the pool, over 200 runs of add+add+swap | **PASS** |
| `testFuzz_S2_allLPsExitAfterSwaps` — two LPs exit fully after an arbitrary swap; total paid out never exceeds what the pool held, and residual bin claims are exactly 0 | **PASS** |

⇒ No over-payment, no residual claims, no insolvency path from this angle.
(Note: the fixture's `MINIMAL_OPERATIONAL_LIQUIDITY` is 1e6; smaller deltas revert by design with
`SharesDeltaSmallerThanMinimalOperationalLiquidity`, which is intended behaviour, not a bug.)

### P-C. Extension call ordering (static review) — no defect

`ExtensionCalling` runs `before*` and `after*` for add/remove/swap, walking a 3-bit-packed order word
until a zero group; any revert, empty slot, or wrong selector reverts the whole action. Because an
`afterSwap`/`afterRemove` revert unwinds the action, a stop-loss or allowlist extension cannot be
"skipped" by ordering. No bypass found statically.

## 3. Status

**No Level-3 finding yet. Nothing submitted.** Every probe so far *confirmed* a control rather than
breaking one. The two most valuable untested surfaces, and why they are not in this pass:

1. **Extension allowlist / stop-loss bypass (in-scope Medium 13 & 16)** — the extension contracts are in
   `periphery-contracts`, but their state is set by a **curator/pool admin**. Attacking them requires a
   pool configured with those extensions, and the program downgrades by one level attacks that need a
   user to interact with an attacker-created pool. Needs a careful read of
   `OracleValueStopLossExtension.sol` (367 lines) against `afterSwap` inputs — next step.
2. **`AnchoredPriceProvider` band/staleness (in-scope High 5)** — "swap on a Metric anchored price
   provider pool executes outside the band or beyond its configured staleness limit" is an *explicit*
   in-scope High, i.e. the program expects this to be breakable. `AnchoredPriceProvider.sol` +
   `PoolStateLibrary` band logic is the highest-value target not yet examined.

## 4. Do-not-report list (accumulated)

- Anything from §1.
- Rounding dust below 0.01% **and** $10 unless repeatable to Medium+.
- Feed-stale halts (`FeedStalled`), sequencer/deviation checks — intended.
- Trusted-role misuse (factory owner, oracle ADMIN_ROLE, factory admins, pool admin within bounds).
- Off-chain infra, API, SDK, app, docs.

---

## 5. Second pass — anchored provider, stop-loss (2026-11-11 later)

### P-D. `AnchoredPriceProvider` widening (High 5 candidate) — BY DESIGN

Reading `oracle-contracts/contracts/AnchoredPriceProvider.sol` in full: the header states the clamp is
**one-directional by design** —

> "The reference bounds how TIGHT it may quote … Widening is NOT bounded: the pool will quote
> arbitrarily far outside the band if the source says so."

with an explicit rationale (the reported `referencePrice` is the anchor mid, never the source's, so
widening only worsens the widener's own execution and cannot move the fee base), and it names the
outward side as **operator due diligence**. A finding that "the quote can be driven outside the band
in the widening direction" therefore restates documented behaviour, not a bug.
The in-scope High 5 wording ("executes outside the band or beyond its configured staleness limit")
has to be read against this: the *tight* side and the staleness halts are the enforced properties.
Both are implemented and guarded (`_readLeg` → ok=false on stale/saturated/zero/guard-violating;
`_computeBidAsk` → `(0, uint128.max, 0)` on a collapsed band). **No finding.**

### P-E. Stop-loss direction semantics (Medium 16 candidate) — ALREADY TESTED, NOT A BUG

`OracleValueStopLossExtension._checkAndUpdateWatermarks` blocks only the direction whose metric
breached. That per-direction behaviour is **explicitly covered by the project's own suite**:

- `test_metricT0BreachBlocksZeroForOneOnly`
- `test_metricT1BreachBlocksOneForZeroOnly`
- `test_bothBreachedBlocksBothDirections`
- `test_autoReopenOnMidMeanReversion`, `test_vShapeMove_blocksEachSideThenDecays`

I wrote an independent probe (`test/StopLossDirectionProbe.t.sol`) inheriting the same fixture:
- **Q2 (ratchet) holds**: a non-breaching direction never lowers either watermark
  (`hwm0`/`hwm1` unchanged after an opposite-direction swap with both metrics collapsed).
- The 1e18-scale fixture saturates the metric at `uint104` max, so a breach cannot be staged at that
  size — worth noting only as a fixture limitation, not a contract defect (the shipped tests use
  500–1000-scale balances precisely to stay under saturation).
- Also confirms the documented gaps are intentional and written down: watermarks are not seeded on
  add (first touch unprotected) and not cleared on remove (a remint can freeze swaps until an empty
  crossing resets HWM). Both are in the contract NatSpec, so reporting them restates known behaviour.

**No finding.**

## 6. Where this stands

Four independent probe families (periphery caps, pool solvency, anchored band, stop-loss direction)
all *upheld* the documented invariants. Nothing has reached Level 3, so nothing is submitted.

Honest assessment of remaining upside on this program:
1. **Multi-extension composition** — several extensions installed on one pool with interleaved
   `before`/`after` orders; not covered above and the order word is the only thing sequencing them.
2. **`LiquidityLadder`** (546 lines, periphery) — the depth/routing math feeding the quoter; the
   known-issue list mentions quoter *partial fill* but not the ladder itself.
3. **`Sequence` / `ExternalSwap`** — audited 2026-10-10 with 18 Low/Info findings (HyperCore,
   approvals, forged `QuoteResult`). Those are known; only a *new* root cause is eligible.
4. **`CompressedOracle` registrationless push path** — Critical impact 1 is about accepting a push
   from an unauthorized pusher; the contract is explicitly "registrationless", so the signature/role
   check there is the single most valuable thing left to read closely.
