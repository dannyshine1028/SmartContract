# staking.kubchain.com — audit (2026-10-04)  [Web/High]

## Architecture
"KUB Stake" — Next.js SPA for delegating KUB to validators (MasterChef-style reward-per-share).
- NO first-party /api backend. Data sources:
  - On-chain StakeManager (delegate/undelegate/claimRewards) via rpc.bitkubchain.io (chain 96).
  - PoS subgraph: https://gateway.bitkubgraph.io/subgraphs/name/bitkubchain/pos
    (public on-chain staking data; GraphQL introspection DISABLED).
  - Bitkub NEXT account/KYC infra: accounts.bitkubnext.com, api.bitkubnext.io/{accounts,wallets},
    consent.bitkubchain.com  --> these belong to the SEPARATE "Bitkub Blockchain Technology" program,
    OUT OF SCOPE for KUB Chain & Ecosystem.

## Staking contract interface (from embedded ABI)
- delegate(uint256 amount_, address bitkubNext_) / delegate() payable
- undelegate(uint256 claimAmount_, address bitkubNext_) / undelegate(uint256 claimAmount_)
- claimRewards(address bitkubNext_) / claimRewards()
- getRewardPerShare / rewardPerShare  (reward-per-share accumulator model)
- stakeManagerStorage() -> IStakeManagerStorage
The `bitkubNext_` variants = account-abstraction flow (NEXT account delegating); no-arg = direct EOA.

## Source availability — BLOCKER
The StakeManager / validator-share / stakeManagerStorage contracts are **NOT verified** on:
- Sourcify chain 96 (match:null), and
- kubscan.com / bkcscan.com (no ContractName, no SourceCode).
Consistent with bkc: these are the PoSA system contracts injected as **bytecode** at the Basel
hardfork (no Solidity in the in-scope bkc repo). => No source-level audit possible.

## What was checked / verdict
- Web frontend: thin, on-chain-driven; no first-party API to attack; relies on the OTHER program's
  NEXT infra (OOS here). No IDOR/secret/XSS surface of its own.
- PoS subgraph: public on-chain staking data; introspection disabled. Info disclosure on public
  on-chain data = OOS/below threshold (same calibration as the wallet program's rejected reports).
- Staking reward contracts: the only high-value in-scope surface (balance manipulation / tokenomics,
  Critical), but **bytecode-only** → not source-auditable. Reachable only via (a) bytecode reversing
  or (b) a dynamic fork-test (fork chain 96 @ rpc.bitkubchain.io, drive delegate/claim/undelegate with
  the extracted ABI, look for reward double-claim / claim-after-undelegate / rounding / inflation).
  High effort, uncertain payoff; many such issues are "front-run only" = OOS.

## Verdict — NO submittable bug found via source/web analysis
Remaining option = dynamic fork-test of the staking reward accounting (needs a go-ahead; see report).
