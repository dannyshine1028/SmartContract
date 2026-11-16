# Bug Bounty Report — Bucket Protocol Smart Contracts — F5

## Status: Active — **needs one mainnet check before submitting** (Section 3 step 3). The structural
half is fully verified; the exploit half depends on how many instances of the source objects exist
on-chain, and I could not query mainnet from the authoring environment.

## 1. Title

Four derivative-rule price writers enforce no validation of who may write, or of which source object
they trust — so an unauthorised caller can overwrite a liquidation-critical price directly

> Framing note: **one defect** — the absence of validation on the rule write path. "No capability",
> "no source-object binding" and "no deviation limit" are three faces of that one missing control,
> and the fix is one control (authorise the writer and pin the source, as `scallop_rule` and the
> primary feeds already do). This is the finding whose severity I cannot finish on my own: read
> Section 3 step 3 — two minutes of Sui RPC answers whether an attacker can present a
> non-canonical source object, and the answer moves this between High and Critical. The structural
> asymmetry with the controls that *do* exist in the same package is reported regardless of that
> outcome.

## 2. Vulnerability Details

**The bypass.** `sources/single_oracle.move:235-247` is a plain `public` function. It asserts only
that a `WhitelistRule<R>` dynamic field exists on the oracle, then performs
`single_oracle.price = price` (`:245`) and `latest_update_ms = clock::timestamp_ms(clock)` (`:247`).
It never consults `tolerance_ms`, never calls `price_aggregator::aggregate_price`, and is therefore
not subject to anything described in F1, F2, F3 or F6. Because it also refreshes
`latest_update_ms` from the *clock*, a rule-written price is indistinguishable to consumers from a
healthy aggregated one.

**Who can reach it.** In Move a struct can only be packed inside its declaring module, so an outside
package cannot mint `vsui_rule::Rule {}` and call `update_oracle_price_with_rule` directly — that
limitation is stated here rather than glossed over. The reachable surface is the rules' own
`update_price` functions, which are `public`, take the shared `BucketOracle`, and are callable in a
transaction block without any capability:

| Rule | function | source objects dereferenced | AdminCap | object-ID binding | deviation limit |
|---|---|---|---|---|---|
| `rules/vsui-rule/sources/vsui_rule.move:12-24` | `update_price` | Volo `NativePool`, `Metadata<CERT>` | **no** | **none** | **none** |
| `rules/hasui-rule/sources/hasui_rule.move:12-24` | `update_price` | Haedal `Staking` | **no** | **none** | **none** |
| `rules/afsui-rule/sources/afsui_rule.move:14-30` | `update_price` | Aftermath `StakedSuiVault`, `Safe<TreasuryCap<AFSUI>>` | **no** | **none** | **none** |
| `rules/aftermath-lp-rule/sources/af_lp_rule.move:17-25` | `update_price` | Aftermath `Pool<LP>` | **no** | **none** | **none** |
| `rules/scallop-rule/sources/scoin_rule.move:74-97` | `update_price` | Scallop `Version`, `Market` | no | **admin pair allowlist** (`:81-83`, `Config.scoin_pairs`, `EInvalidScoinTypeInputs`) | none |

The same package shows what the intended control looks like: the primary feeds bind the source
object identity and abort with `EWrongSourceConfig` (`single_oracle.move:121` switchboard, `:152` and
`:169` pyth; `:195` binds Supra's `pair_id` but not the holder object), and `scallop_rule` gates the
(SCOIN, COIN) pair type through an admin-managed set. Four of the five rules do neither.

**Two independent consequences.**

1. *If more than one instance of a source object can be presented* (e.g. a second
   `NativePool`, or a `Pool<LP>` for the same LP type), the caller fully determines the price of a
   registered collateral slot: any value, at any time, for free, and with no upper or lower bound —
   including 0, which is what turns this into a mass-liquidation primitive.
2. *Even if each is a singleton*, the rule derives a price from state the caller can move:
   `af_lp_rule.move:47` values an LP from that pool's reserves with no minimum-liquidity check, and
   `vsui_rule.move:19` / `hasui_rule.move:18` derive from a staking pool's share exchange rate, which
   a donation inflates. Because the write is uncapped and unthrottled, that movement propagates 1:1
   into the stored price at a moment the attacker picks, and it is consumed by liquidations within the
   10-second window (`single_oracle.move:39,94`) — which the attacker controls because the update and
   the liquidation can be issued in the same transaction. This is not a front-running-only
   construction.

**Not claimed here.** The unchecked `u128`/`u64` rescaling on these same paths
(`vsui_rule.move:22`, `af_lp_rule.move:71-73`, `afsui_rule.move:32-34`) is the cast-validation defect
reported separately, with those sites listed there; claiming it twice would double-count one fix.

**Independence.** This report does not depend on F1 or F6: the rule path never enters
`aggregate_price`, `tolerance_ms` or `threshold` at all (`single_oracle.move:245,247`), so fixing
those leaves it untouched. It does not need F2 either — the value it writes is arbitrary by
construction, which includes 0.

## 3. Validation Steps

**Target:** `https://github.com/hackenproof-public/bucket-protocol` — oracle rules packages.

**Prerequisites:** repository checkout for steps 1-2; public Sui RPC or explorer access for step 3.

1. Static (structural half, no judgement required):
   ```bash
   python3 poc/static_proof.py ./oracle   # checks F7a (direct write), F7b (plain public), F7c (4 unbound rules vs the allowlisted one)
   ```
   Expected: three `OK` lines; F7c prints the unbound rule files and the one rule that does gate.

2. Manual:
   ```bash
   grep -n "AdminCap\|object::id\|update_oracle_price_with_rule" rules/*/sources/*.move
   sed -n '235,247p' sources/single_oracle.move
   ```
   Expected: `update_oracle_price_with_rule` is not declared `public(friend)`; no rule except
   `scoin_rule` mentions a control on which pair/slot may be written; no rule mentions
   `object::id`.

3. **The open question — please resolve before scoring severity.** Enumerate instances of the source
   types on mainnet:
   ```bash
   # for each type, how many objects exist, and who owns them?
   sui client call --object <RPC> ... # or, more directly:
   curl -s -X POST https://fullnode.mainnet.sui.io:443 -H 'Content-Type: application/json' -d \
     '{"jsonrpc":"2.0","id":1,"method":"sui_getObjectsByStruct","params":["<struct tag>"]}'
   ```
   Struct tags to check: `volo::native_pool::NativePool`, `amm::pool::Pool<…LP…>` for every LP token
   Bucket lists as collateral, `haedal::staking::Staking`,
   `staked_sui_vault::StakedSuiVault` and `safe::Safe<…TreasuryCap<AFSUI>>`.
   * More than one instance, or an instance a normal user can obtain → this is a direct arbitrary
     price write, i.e. **Critical**.
   * Exactly one shared instance each → the singleton route (consequence 2) still applies; severity
     stays **High**, and I would additionally recommend binding object IDs as defence-in-depth.
   Note also that `afsui_rule` requires `&Safe<TreasuryCap<AFSUI>>`, which only the holder of that
   treasury can present, so that rule is the least reachable of the four — disclosed rather than
   smoothed over.

## 4. Supporting Files / PoC

**This report's own PoC file:** `poc/F5-rules-source-object-check.sh` — a two-part script, because
this finding is the one that cannot be closed with a Move test: part [A] proves the structural
asymmetry offline (the writer's direct `price` assignment, its plain `public` visibility, per-rule
capability/binding/allowlist status across all five rule packages, and the four `EWrongSourceConfig`
binding sites that make the omission look like an oversight), and part [B] asks mainnet how many
instances of each source object exist and who owns them — which is what moves this report between
High and Critical. Run `bash "Result(report)/poc/F5-rules-source-object-check.sh" /path/to/oracle`
with no tags to see part [A] and the list of struct tags that still have to be filled from the
deployed packages (do not paste addresses from memory).
Shared/auxiliary:
* `../poc/static_proof.py` (checks F7a, F7b, F7c) — verifies the capability/binding asymmetry
  mechanically over all five rule packages.
* `../poc/aggregation_poc.move` does **not** cover this finding: constructing Volo/Aftermath/Haedal
  objects is out of reach in a unit test, and I am not going to present a mock of a third-party pool
  as if it were the deployed one. If step 3 shows a user-obtainable instance, the PoC is a two-call
  transaction block (rule `update_price` with that object, then a liquidation) and I will extend the
  suite for it on request.
* **Observed output:** step 1 only (static). No exploit output exists yet.

## 5. Severity Level

**High** as filed; **Critical** (`$10,000 - $15,000`) if Section 3 step 3 shows a source object that
an unprivileged account can present.

Justification: this is a capability and source-validation gap on the write path that determines who
may set a liquidation-critical price, and unlike F1 it is not bounded by any aggregation logic at
all — there is no divergence check, no tolerance filter, no threshold and no deviation cap in the
code path being written.

## 6. Category

Used (closest fit, noted explicitly): **`Broken Access Control (BAC)`**.

* Rationale: the defect is that the function enforces no capability on *who* may write, and no
  binding on *which* source object may be trusted. `Hackproof_category.md` lists only Brute Force /
  IDOR / Privilege Escalation / SSRF as BAC children, none of which is a precise match, so the
  parent category is used.
* Secondary, if the triage team prefers the design framing: `Unsecure Design`.
* Program-side wording: "Unauthorized transaction", "Attacks on logic", "Stealing or loss of funds".

## 7. Language

Submission language: **English**.

## 8. Target

`https://github.com/hackenproof-public/bucket-protocol` — the program's sole in-scope asset.

Cited from `Bucket-Protocol/oracle` @ `df8f6a418f24a82eaf22a8309878175ae33f2cf5`:
`sources/single_oracle.move:235-247`, `sources/single_oracle.move:121,152,169,195`,
`rules/vsui-rule/sources/vsui_rule.move:12-24`, `rules/hasui-rule/sources/hasui_rule.move:12-24`,
`rules/afsui-rule/sources/afsui_rule.move:14-30`,
`rules/aftermath-lp-rule/sources/af_lp_rule.move:17-25,47`,
`rules/scallop-rule/sources/scoin_rule.move:54-70,74-97,81-83`.
The third-party packages themselves are **not** the reported defect (they are excluded as imported
contracts); the defect is Bucket's own omission of the controls those packages' objects pass through.
Placement caveat as in F1.
