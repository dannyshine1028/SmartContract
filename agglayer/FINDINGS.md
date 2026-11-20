# Agglayer / Vault Bridge — Findings

Program: https://cantina.xyz/code/3aaad22b-52ee-4bb2-bed2-4be53b0993cc (Cantina, Agglayer by Polygon)
Repos analysed: `vault-bridge` @ `c2ece8a` (2026-01-16), the in-scope Vault Bridge half.
Date: 2026-11-02. No on-chain interaction (program forbids mainnet/testnet testing; Claude.md rule 3).

## Target-maturity assessment (Claude.md §2-(-1)) — read this first

This is a **saturated, formally-verified, triple-audited** target:
- `vault-bridge/audit/` contains **6 reports**: ChainSecurity (v0.4.0), Sigma Prime (v0.3.0), Certora (v0.5.0,
  v1.0.0, v1.1.0) **including a dedicated Certora Formal Verification** (v0.5.0), with a full `certora/specs/`
  tree shipped in-repo (ERC4626 conformance, allowed-changes, bridge summaries, invariants).
- Cantina shows **665 findings already submitted**.
- Core accounting uses OZ upgradeable primitives, `ReentrancyGuardTransientUpgradeable` on every state-changing
  external fn, checked arithmetic (0.8.29), ERC-7201 namespaced storage, role-gating throughout.

Per Claude.md §2-(-1) red-flag (d) ("mature / multi-audited / only format-diffs left") this is explicitly a
**low-ROI target to deep-dive**. Recorded here honestly rather than forcing a weak submission.

## What was actually reviewed (genuine pass, not a skim)

Architect→Adversary pass over the novel (non-core-Agglayer) surface — the Vault Bridge is the new code; the
GER/BridgeV2/RollupManager core is the oldest + most-audited and was deprioritised.

| Area | File | What was checked | Result |
|---|---|---|---|
| 1:1 share model | `VaultBridgeToken.sol` `convertToShares/Assets` | Are they really identity (`pure`)? → yes. So classic ERC4626 inflation / first-depositor / donation share-price attacks **do not apply** (price is hardcoded 1:1; yield goes to a role, not to shareholders). | No bug |
| Solvency invariant | `totalAssets()=stakedAssets()+reservedAssets()`, `backingDifference()`, `yield()` | `yield()` = `totalAssets − convertToAssets(totalSupply)` when positive; `collectYield` mints exactly that to the yield recipient so backingDifference returns to 0. Donations (`donateAsYield`) only add backing, never mint to the donor. | Invariant holds |
| Withdraw/redeem slippage | `_withdraw`, `_simulateWithdraw`, `_withdrawFromYieldVault` | Loss from yield-vault slippage is borne by the **withdrawer** (burns `shares=assets`, may receive less), not a protocol drain; solvency check (`ExcessiveYieldVaultSharesBurned`) bounds how many yield-vault shares can be burned per the configurable slippage %. | User-side loss only, not attacker profit |
| Part1/Part2 split (delegatecall) | `VaultBridgeToken.sol` `delegatedToPart2` + `_delegateToPart2`, `VaultBridgeTokenPart2.sol` | Part1 stubs (`rebalanceReserve`/`collectYield`/`burn`/`donate*`/`completeMigration`) have empty bodies then delegatecall Part2; **Part2 re-applies every access-control / pause / nonReentrant modifier** (`onlyRole(REBALANCER_ROLE)`, `onlyYieldRecipient`, `onlyMigrationManager`, etc.). Both contracts hardcode the **same** ERC-7201 slot `f082…4700`, so storage is shared, not clashing. Part2 `fallback()` reverts `UnknownFunction`. | No missing re-check found |
| Migration mint | `Part2.completeMigration`, `MigrationManager.onMessageReceived` | `shares`/`assets` come from the secondary-chain Native Converter message. `completeMigration` is `onlyMigrationManager`; any `shares>assets` discrepancy is covered from `migrationFeesFund` and **reverts if the fund is short** (`CannotCompleteMigration`), so there is no unbounded free-mint. Asset-before-message ordering is enforced implicitly: `_receiveUnderlyingToken` pulls `assets` from MigrationManager's balance, which only exists if the bridgeAsset claim already landed. | Bounded by fund; no infinite mint |
| Re-init / uninitialised proxy | `VaultBridgeTokenInitializer.sol`, `MigrationManager.reinitialize*`, `InitializationCounterUpgradeable` | `_disableInitializers()` in constructors; `reinitializer(n)` + a global init counter guard; init1 verifies the initializer's `VAULT_BRIDGE_PROTOCOL()` version matches. (Initializer file read only partially — see "Not fully closed".) | No obvious re-init, pending final read |

## Initializer — now fully read, clean

`VaultBridgeTokenInitializer.sol` read in full. It is called by `delegatecall` from
`__VaultBridgeToken_init1` and uses the **same** hardcoded ERC-7201 slot `f082…4700` and the **same**
`VaultBridgeTokenStorage` struct inherited from `VaultBridgeToken` — there is no independent storage
declaration in any of the three contracts that could drift, so a storage-layout mismatch is structurally
impossible (all three reference one struct via one slot). `init1` is `onlyInitializing`, validates every
param (non-zero, ≤1e18 caps), version-checks Part2 via `VAULT_BRIDGE_PROTOCOL()`, and the singleton is
`_disableInitializers()`-protected in its constructor. No missing field, no re-init path, no glue bug found.

## Not fully closed (honest gaps — would be the next session's work, not claims)
- The **deployed proxies were not resolved to implementations** (`cast implementation <addr>`), so it is not
  yet confirmed that the 11 in-scope mainnet addresses correspond to commit `c2ece8a` rather than a newer/older
  build. Any report MUST pin the on-chain bytecode to a repo commit first (program rule: "prove exploitability
  based on the current state of the blockchain").
- The secondary-chain contracts (`NativeConverter`, `CustomToken*`) were not reviewed — but note those are on
  Secondary Chains, and **only the 11 listed Ethereum-mainnet addresses are in scope**, so a secondary-chain-only
  bug is likely out of scope unless it lets a malicious message drive the in-scope mainnet `completeMigration`
  beyond the `migrationFeesFund` bound.

## Verdict (2026-11-02)

**No Level-1+ candidate found** in the reviewed surface — not even a hypothesis that survived a first careful
read. Combined with the maturity profile, the honest recommendation is that this program is a **poor ROI** and
should not get a forced/low-confidence submission (that would violate Claude.md rule 6 "no unverified
submission" and rule 7 "no exaggeration", and the §0.5 Informative-gate). If pursued further, the single
highest-value remaining task is the **initializer storage-layout diff** above; everything else reviewed is
guarded and formally verified.
