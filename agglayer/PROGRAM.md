# Agglayer by Polygon (Vault Bridge + Agglayer Contracts) — Cantina Program (Scope Record)

Source: https://cantina.xyz/code/3aaad22b-52ee-4bb2-bed2-4be53b0993cc/overview
Platform: Cantina (Spearbit/Cantina) — **Cantina-Triaged**
Program type: Public Bounty (smart contracts), "No deposit required"
Recorded: 2026-11-02 (scope investigation only — no testing performed yet)

## Program facts (from page)

- Project: **Agglayer by Polygon** (`@agglayer`). Cross-chain settlement layer; the bounty centers on the
  **Vault Bridge** (a customizable yield-generating mechanism giving L2s a native revenue stream) plus the
  core **Agglayer Contracts** (GlobalExitRoot / BridgeV2 / RollupManager). Project site: https://www.agglayer.dev/
- Status: **Live**. Start date: 14 Oct 2025. Findings submitted so far: **665** (high competition — see gate note).
- Max reward: **$250,000**. **KYC: required to join.** No deposit required.
- Payouts: by Polygon Labs directly, in USD, paid in USDC or POL (POL via 5-day TWAP from payment date).
  US persons may need tax info (1099). Invoice required per payout. OFAC/UNSC-sanctioned-country residents
  excluded.
- Account in use for this workspace: Cantina user **@VulnXLab** (confirmed logged in 2026-11-02).

## Severity → reward (In-Scope smart contracts)

| Severity | Reward |
|---|---|
| Critical | **$20,000 – $250,000** |
| High | Up to **$10,000** |
| Medium | Up to **$2,000** |

(Low/Informational: not rewarded — only Critical/High/Medium listed.)

## In-Scope Targets (Ethereum mainnet, verbatim addresses from the Cantina scope table)

| # | Address | Contract | Group |
|---|---|---|---|
| 1 | `0x580bda1e7a0cfae92fa7f6c20a3794f169ce3cfb` | PolygonGlobalExitRoot | Agglayer Contracts |
| 2 | `0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe` | PolygonBridgeV2 (PolygonZkEVMBridgeV2) | Agglayer Contracts |
| 3 | `0x5132A183E9F3CB7C848b0AAC5Ae0c4f0491B7aB2` | PolygonRollupManager | Agglayer Contracts |
| 4 | `0x2DC70fb75b88d2eB4715bc06E1595E6D97c34DFF` | vbETH | Vault Bridge |
| 5 | `0x53E82ABbb12638F09d9e624578ccB666217a765e` | vbUSDC | Vault Bridge |
| 6 | `0x6d4f9f9f8f0155509ecd6Ac6c544fF27999845CC` | vbUSDT | Vault Bridge |
| 7 | `0x2C24B57e2CCd1f273045Af6A5f632504C432374F` | vbWBTC | Vault Bridge |
| 8 | `0x3DD459dE96F9C28e3a343b831cbDC2B93c8C4855` | vbUSDS | Vault Bridge |
| 9 | `0x417d01B64Ea30C4E163873f3a1f77b727c689e02` | Migration Manager | Vault Bridge |
| 10 | `0xb2ec4d99c82417257f41b2c8ceda0962c03945f5` | VaultBridgeTokenInitializer | Vault Bridge |
| 11 | `0x1C8565F454F8239B854fe62C99B90b3FC9298E80` | VaultBridgeTokenPart2 | Vault Bridge |

All are `[Ethereum]` mainnet deployments. Each links to `etherscan.io/address/<addr>` (verified source
expected). NOTE: addresses 4–11 (vbTokens) are almost certainly proxies — resolve each implementation with
`cast implementation` / storage slot before analyzing, and confirm which contract actually holds the logic.

## Out of scope

- **Previous audit reports (do not re-report these):**
  - https://github.com/agglayer/agglayer-contracts/tree/main/audits
  - https://github.com/agglayer/vault-bridge/tree/main/audits
- "Currently only smart contracts are in scope. Any issue requiring physical access to assets/devices,
  environment manipulation, or changing config files/non-default settings." → out of scope.
- Cantina **default out-of-scope guidelines** apply (link:
  https://docs.cantina.xyz/cantina-docs/cantina-bounties/bounty-severity-classification#out-of-scope —
  redirects to docs.cantina.security; **TODO: fetch the full default OOS list via the browser** before
  deep-diving, so we don't waste effort on a class Cantina auto-rejects. Typical Cantina/Spearbit defaults
  to expect: centralization/admin-key risk where the admin is trusted, gas optimizations, best-practice-only,
  already-known/audited issues, issues requiring non-default config, theoretical/no-PoC, front-running that
  is inherent to the design, etc. — confirm from the actual doc, don't assume.)

## Prohibited actions / rules (verbatim-summarized)

- **No testing on mainnet or public testnet without prior authorization** — use local test environments /
  private forks only. (Matches Claude.md rule 3 exactly: all verification on a local Foundry/Hardhat+Anvil
  fork, never a real on-chain attack.)
- No public disclosure without written consent (even after fix). No disclosure to third parties before
  permission.
- No exploitation beyond the minimum to demonstrate; no accessing private data, social engineering, or
  service disruption.
- No conflict of interest: current/former Polygon employees or contributors to the affected code are
  ineligible.
- Report within ~24h of discovery, via Cantina only. Provide clear description + impact + reproduction/PoC +
  conditions + implications.
- Must prove **real exploitability/severity without doubt or assumptions, based on the current on-chain state
  at time of report** — this is the key bar (mirrors Claude.md §0.5 reachability ladder R1/R2/R3: non-privileged
  trigger, production real values, impact on others' funds).

## Workspace-gate implications (Claude.md)

- **Funded, high-value, real program** — no $0 gate issue. Critical floor is $20k, which is attractive, BUT:
- **665 findings already submitted** + the code is **multiply-audited** (two separate audits folders listed
  OOS) → this is a saturated, heavily-picked-over, mature target. Per Claude.md §2-(-1) red flag (d)
  ("mature/multi-audited, only format diffs left") and the general dedup realism in §2: the odds that an
  easy/surface bug remains are low. Worth pursuing ONLY with a genuine novel angle on the *new* Vault Bridge
  logic (the yield mechanism, migration manager, vbToken share/asset accounting) rather than the long-audited
  core Agglayer bridge/rollup contracts. Impact-first (§0.5-1): the hypothesis must name whose funds move and
  how much, and reach Level 3 on a local fork, before any report.
- **KYC required to join** — confirm the @VulnXLab account has completed/will complete KYC before investing
  deep effort, otherwise findings can't be rewarded.
- Priority surface (novel, less-audited): **Vault Bridge** — `VaultBridgeToken` (vbETH/vbUSDC/vbUSDT/vbWBTC/
  vbUSDS) share↔asset accounting & yield, `MigrationManager`, `VaultBridgeTokenInitializer` (re-init /
  uninitialized-proxy risk), `VaultBridgeTokenPart2` (split-logic → check for storage-layout / selector-clash
  between Part1 and Part2). The core Agglayer contracts (GER/BridgeV2/RollupManager) are the most-audited and
  least likely to yield a non-duplicate.

## Repos (for local analysis — clone, do NOT touch mainnet)

- `https://github.com/agglayer/agglayer-contracts` (GlobalExitRoot, BridgeV2, RollupManager)
- `https://github.com/agglayer/vault-bridge` (vbTokens, MigrationManager, Initializer, Part2)
- Audits to read first (dedup): `agglayer-contracts/tree/main/audits`, `vault-bridge/tree/main/audits`.

## Status

Scope confirmed and recorded. Next: (1) fetch Cantina default OOS list via browser; (2) clone both repos;
(3) read the `audits/` folders to build the known-issues inventory (Claude.md §2-0) BEFORE any deep-dive;
(4) resolve the 11 proxies to their implementations and map which deployed bytecode corresponds to which repo
commit; (5) focus the Architect→Adversary→Verifier pass on the Vault Bridge accounting, not the audited core.
No testing performed yet. Mobile/physical/config-change issues are out of scope.
