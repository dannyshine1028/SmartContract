# bridge.kubchain.com — audit (2026-10-04)  [Web/High]

## Architecture
Federated (trusted-operator) cross-chain bridge: KUB(96) ↔ Ethereum(1) / BSC(56) / JFIN(3501).
- Frontend: Next.js SPA. Backend API is THIN:
  - `GET /api/v3/pair` — public bridge config (pairs, fees, minimums, addresses, RPCs).
  - `GET /api/v3/bridge-log?chainID=&txHash=` — public source-tx → dest-tx lookup. Keyed by
    PUBLIC on-chain data → no IDOR / no private data.
- On-chain (verified on Sourcify, chain 1, solc 0.8.17):
  - BridgeERC20V3 `0x89943b2499d678fb2d382C66b7BaeD00b732e753` (source: lock/burn + fee + event).
  - DistributorERC20V3 `0xD920d9E80875dC86DFC0C913635766e0967718Cd` (dest: release/mint).
  - USDC/USDT burn bridge `0xcd414e024592225D43DBe05bAfbA458272Ca56A7` (KUB-side).

## BridgeERC20V3 (user-facing) — reviewed, SOUND
- `_bridge`: `require(!_isContract(msg.sender))`, `whenNotPaused`, `nonReentrant`,
  `totalAmount = amount_ - fee` (0.8.17 checked → underflow reverts if amount_<fee),
  fee FIX/PERCENTAGE from committee-set config (user can't alter), funds conserved:
  NATIVE sends totalAmount→receiver + fee→feeReceiver (==msg.value); ERC20 LOCK transferFrom both;
  ERC20 BURN burnFrom(totalAmount)+fee. Emits Bridge(token,from,totalAmount,destChainID,destType).
- dest-type check `allowedDestTokenTypes & destTokenType_ > 0 && destTokenType_ < 3` — bitmask OK.
- Config/pause/delete all `onlyCommittee`. No external theft/inflation/fee-bypass path.

## DistributorERC20V3 (release/mint) — reviewed, trust-based
- No on-chain signature verification (NO ecrecover). Release is `onlyWhitelisted` (trusted relayer),
  replay-guarded by `isSignatureUsed[signature_]` (relayer-chosen unique id). `multiCall`/`withdraw`/
  config are `onlyCommittee`. Security = trust in relayer whitelist + committee keys (OFF-CHAIN).

## Verdict — NO submittable bug
The bridge is a carefully-built federated bridge. External-attacker surface:
- Contracts: conservative, checked, access-controlled; the only "powers" are committee/whitelist
  (trusted operators) — compromising those = "org private keys", OOS.
- Web/API: thin, public data only. No IDOR (bridge-log is public), no XSS sink (the 2
  dangerouslySetInnerHTML are Next.js boilerplate), no secrets. Tokenless QuikNode RPC in the public
  pair config = low-value info disclosure = OOS ("Moderately Sensitive Information Disclosure").
- Decimals are matched per pair in config; no scaling/inflation on-chain. Any relayer-side credit
  logic is off-chain (not in scope, not testable).

## Scope note
Explicit asset = bridge.kubchain.com (Web). The contracts are its backing; analyzed as the bridge's
security. Even granting contracts in-scope, no external exploit exists.
