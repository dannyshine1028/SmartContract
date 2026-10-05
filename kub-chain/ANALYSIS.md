# KUB Chain (bkc) — Spec comprehension & attack-surface map (2026-10-04)

## 1. What the in-scope protocol is
`github.com/kub-chain/bkc` = **Bitkub Chain**, a **fork of go-ethereum** (self-version `2.4.0-bkc`,
upstream base ≈ geth 1.10.x / London-era). Consensus = **PoSA (Proof of Staked Authority)** =
extended **Clique (PoA)** + a set of on-chain **system contracts** that handle staking, validator
selection, reward distribution and slashing.

Shallow clone (depth 1); last commit `28cb560` = *"hotfix: unauthorized signer when change supernode
signer"* — a consensus-auth fix; adjacent logic is worth scrutiny.

## 2. Fork timeline (params/config.go)
standard geth forks (Homestead…Istanbul, Berlin, London) → **Erawan** (PoA→PoSA header/format change)
→ **Chaophraya** ("⭐️ POS Started" — full PoS) → **Lausanne** (StakeManager/SlashManager update) →
**Basel** (state-injection hardfork: deploys V3 contract bytecode+storage, changes block period,
supernode). Testnet variant: ChaophrayaBangkok.
Mainnet ErawanBlock = 9,100,000. (MainnetChainConfig.ChainID literal = 1 in source; real chainid set
via genesis — verify against docs: Bitkub Chain mainnet is 96.)

## 3. Custom surface (bkc diffs from upstream geth — THIS is the rewardable, non-"imported" surface)
| File | Lines | Role |
|---|---|---|
| consensus/clique/clique.go | 1619 | PoSA core: verify/seal/prepare/finalize, rewards, slashing, span, validator selection |
| consensus/clique/snapshot.go | 449 | validator-set snapshot, system-contract tracking (SuperNode/OfficialNode) |
| consensus/clique/contract/client.go | 808 | consensus↔system-contract bridge; injects system txs |
| consensus/clique/contract/abi.go | 452 | ABIs for StakeManager/SlashManager/ValidatorSet |
| consensus/clique/hardfork/basel/instruction.go | 369 | Basel state injection (V3 bytecode + hand-encoded storage slots) |
| params/config.go | — | fork schedule, CliqueConfig{Period,Epoch,Span,ValidatorContract(V2)} |
| miner/worker.go | — | sealerAddress vs beneficiary(etherbase) handling |
| core/evm.go, core/vm/instructions.go | — | carry bkc markers (check for EVM-level diffs) |

NOTE: the staking **Solidity source is NOT in this repo** — StakeManagerV3/SlashManagerV3/
BKCValidatorSetV3/NftContractV3 exist only as embedded **bytecode constants** injected at Basel.
So on-chain "smart contract" source review for the staking system is not possible from bkc alone;
reachable as bytecode on a fork, or request source from the team.

## 4. PoSA mechanics (the "business description" to test code against)
- **Validators / spans**: validator set rotates every `Span` blocks. Next set chosen in `commitSpan`
  → `selectNextValidatorSet(parent, seedBlock)`.
- **Validator selection randomness**: seed = `int64(BigEndian.Uint64(seedBlockHash[:8]))`, seedBlock =
  `parent.Number - 5`; `rand.NewSource(seed)`; weighted by voting power (createWeightedRanges +
  binarySearch + randomRangeInclusive). Eligible set from `GetEligibleValidators`.
- **Rewards**: block gas fees accumulate at `consensus.SystemAddress` → `distributeIncoming`:
  `SetBalance(SystemAddress,0)`, `AddBalance(coinbase, balance)`, then
  `DistributeToValidator(StakeManager, balance, val, …)` as a system tx.
- **System transactions**: injected by consensus via `applyTransaction`/`applyMessage`
  (GasPrice=0, nonce from state, from=validator/coinbase, to=system contract). When importing a block
  (not mining), `applyTransaction` enforces the in-block tx hash == expected system-tx hash.
  `IsSystemTransaction` = sender==header.Coinbase && to∈systemContracts && gasPrice==0.
- **System contracts** (snapshot.SystemContracts): ValidatorContract(V2), StakeManager, SlashManager,
  OfficialNode, SuperNode (+ V3 variants after Basel).
- **Slashing**: missed-turn validators slashed via SlashManager (`slash`, `isPreviousBlockSlashed`,
  `IsSlashed`, GetSlashThreshold/EpochSize/SoloSlashRate).
- **Header format (Erawan+)**: MixDigest carries the vote-signer address; Coinbase carries the
  beneficiary (reward recipient); checkpoint/epoch blocks must have zero beneficiary & zero MixDigest.

## 5. Candidate bug hypotheses — UNVERIFIED (Level 0–1). Must reach Verifier Level-3 on a LOCAL fork.
Mapped to in-scope categories (Protocol: balance/tx/price manipulation, fee bypass, tokenomics,
unauthorized tx, crypto; SC: logic/reentrancy/reordering/overflow). Front-run-only = OOS.

H1 (balance manipulation / tokenomics): reward accounting in `distributeIncoming`+`DistributeToValidator`
   — confirm fees are debited from coinbase exactly once (no double-credit/mint). Check behaviour when
   StakeManager call reverts (does coinbase keep the added balance?).
H2 (unauthorized tx / fee bypass): `IsSystemTransaction` requires sender==header.Coinbase & gasPrice==0.
   Coinbase is sealer-controlled — can a malicious validator push gasPrice-0 txs to system contracts,
   or get a crafted tx mis-classified as "system" (skipping fee/nonce checks)? Check the import-time
   hash-match guard for gaps (ordering, count mismatch, extra system tx).
H3 (validator manipulation): weak selection randomness — seed derived from a single block hash
   (parent-5). A validator that seals the seed block may grind its hash to bias selection. Assess
   whether this is exploitable beyond front-run (OOS) — e.g., repeatable bias / grinding over a turn.
H4 (consensus split / tx manipulation): `applyTransaction` nonce handling (callmsg.Nonce()=0,
   CheckNonce=false, but state nonce used for expectedTx) — mismatch between expected vs actual could
   brick import or allow divergence; compare mining vs verifying paths.
H5 (logic / the recent hotfix area): supernode/official-node signer change (snapshot.go lines ~621-634,
   getVoteAddr/getValidatorContract, intialSuperNode) — the "unauthorized signer" class the hotfix
   addressed; look for residual authorization gaps around SuperNode/OfficialNode transitions.
H6 (state correctness): Basel hand-encoded storage slots (getMappingSlot/getValidatorSlot/
   packValidatorShareAndRates) — slot math errors would corrupt validator/share state. One-time fork,
   likely already activated on mainnet (historical), lower live value.

## 6. Web targets (High) — separate from bkc repo
- bridge.kubchain.com — cross-chain bridge UI; backing contracts on-chain (not in bkc). In-scope web
  vulns: business logic, payments manipulation, IDOR/privesc, SSRF, XSS, injection, etc. Bridge
  contract logic (if reachable) → protocol/SC categories.
- staking.kubchain.com — staking/delegation UI over the PoSA StakeManager. Same web-vuln surface;
  staking contract logic ties back to §4/§5.
- Docs: https://docs.kubchain.com/ (architecture, addresses) — review next.

## 7. Duplicate-avoidance status (Claude.md §2-0)
- docs/audits = only upstream geth audits (Truesec/NCC/LeastAuthority/Cure53); not bkc-specific.
- docs/postmortems = upstream geth minority-split (2021); not bkc-specific.
- No `audit/` of bkc findings in repo. Disclosure forbidden on program → no public disclosed reports
  to check. $1,450 paid / 281 submissions / 143 hackers ⇒ busy, heavily triaged, high dup risk.

## 8. Constraints
- NEVER attack mainnet/public testnet (Claude.md §0.3). All PoC on local fork (build geth, run a
  private PoSA devnet, or unit-test the consensus package).
- PoC required + KYC required + 100 reputation required to submit.
- "front-run-only" exploits are explicitly OOS → any manipulation PoC must not rely solely on
  front-running.

## 9. Next steps (when hunting begins)
1. Review docs.kubchain.com for business description + deployed system-contract addresses.
2. Deep-read clique.go Finalize/FinalizeAndAssemble + contract/client.go applyTransaction (H1/H2/H4).
3. Build the node; stand up a local PoSA devnet or use consensus/clique unit tests as the Level-3 rig.
4. Unshallow / fetch tags to diff against upstream geth and against prior bkc releases.

---
# HUNT RESULTS — protocol core audit (2026-10-04)  [Architect→Adversary→Verifier, source-level]

## Refuted (verified sound in source; no Level-3 target)
- **H1 reward double-credit — REFUTED.** `distributeIncoming` does `AddBalance(coinbase, fees)` then
  `DistributeToValidator(StakeManager, fees)` where the system message has `from=header.Coinbase,
  value=fees` (getSystemMessage), so the EVM Call transfers the same `fees` back out of coinbase into
  StakeManager → net coinbase delta = 0, StakeManager +fees. Any failure returns err from
  Finalize → whole block rejected (no partial credit commits). No inflation.
- **H2 system-tx injection / fee bypass — REFUTED.** Three guards present:
  (1) `core/state_processor.go` only treats a tx as "system" if `IsSystemTransaction` (sender==
  header.Coinbase && to∈systemContracts && gasPrice==0) AND only on the Chaophraya path;
  (2) on import, `applyTransaction` recomputes each expected system tx and requires
  `signer.Hash(actualTx)==signer.Hash(expectedTx)` in strict order, consuming `receivedTxs[0]`;
  (3) end of `Finalize`: `if len(*systemTxs) > 0 { return errors.New("the length of systemTxs do not
  match") }` — rejects any EXTRA system tx. A producer cannot inject a fee-bypassing system call.
- **FinalizeAndAssemble vs Finalize — CONSISTENT.** Only diff is `distributeIncoming(c.val …)` (producer)
  vs `distributeIncoming(header.Coinbase …)` (verifier); harmless because `DistributeToValidator`
  packs `distributeReward()` with NO args — the `validator` param is unused. Same system tx either way.
- **H5 Recents omission — INTENTIONAL, not a bug.** verifySealPoS and snapshot.apply skip the PoA
  `errRecentlySigned` check after Chaophraya, but PoSA replaces it with deterministic round-robin:
  `inturn()` = `Validators[number % len(Validators)] == signer` (exactly one in-turn validator per
  height), regular validators are confined to in-turn blocks (Finalize returns errInvalidDifficulty /
  errUnauthorizedSigner otherwise), and only OfficialNode/SuperNode may seal no-turn backup blocks.
  Stake weighting is via duplicate entries in the span's Validators slice. Fairness/liveness come from
  rotation+slashing, so dropping Recents is by design.

## Design observations (NOT claimed as findings without the business description)
- **Base fee not burned.** `core/state_transition.go` PoS path: `AddBalance(SystemAddress,
  gasUsed * st.gasPrice)` — the FULL effective price (base+tip), later distributed to validators. No
  EIP-1559 burn (BSC-like). Accounting conserves (sender net pays gasUsed*gasPrice). Only a finding if
  the whitepaper/tokenomics claims burning or a different split — docs.kubchain.com overview does not
  specify; **UNVERIFIED → not submitting.** (Whitepaper V2.1 PDF would settle it.)

## Candidates that exist but trend OUT OF SCOPE / low-value
- **H3 validator-selection PRNG**: `selectNextValidatorSet` seeds Go `math/rand` from the first 8 bytes
  of a block hash (seedBlock = parent-5). Deterministic+public. Bias/grinding needs validator control
  of the seed block and is effectively a front-running advantage → program lists **front-run-only = OOS**.
- **Malformed posBytes panic**: `ParseAddressBytes` returning <3 contracts is `log.Error`'d but then
  `*contracts[0..2]` is indexed → panic. Reachable only by a block producer (validator) and the effect
  is a node crash → **Network-level DoS = OOS**.

## Verdict on the protocol (bkc) core
The consensus value-flow and system-tx machinery are a careful BSC/Parlia-style port with the key
guards intact. No submittable protocol bug found at source level in the core. The richest remaining
SC surface — the staking/slash/reward Solidity (StakeManagerV3/SlashManagerV3/BKCValidatorSetV3) —
is **not in the repo** (embedded bytecode only), so it cannot be source-audited here, and any dynamic
PoC needs a full PoSA devnet (high effort; many remaining ideas are OOS DoS/front-run/validator-only).

## Recommended next targets (tractable + in-scope)
1. **bridge.kubchain.com (Web/High)** — cross-chain bridge UI + its on-chain bridge contract:
   business-logic, payments manipulation, IDOR, replay/signature, SSRF. Demonstrable without a devnet.
2. **staking.kubchain.com (Web/High)** — delegation UI over the on-chain StakeManager; reward/slash
   accounting reachable as deployed bytecode on a mainnet-fork for a Level-3 PoC.
3. (Optional, high-effort) a scoped PoSA devnet to test slashing-race / selection-bias hypotheses,
   accepting the OOS risk.
