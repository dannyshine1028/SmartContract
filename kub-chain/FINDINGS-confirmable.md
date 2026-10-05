# KUB Chain — confirmable findings (2026-10-04)
All were reproduced, but each is either explicitly OUT OF SCOPE or has no demonstrable impact,
so NONE are submittable to this program without inflating severity (which we won't do).

## F1. bridge-log 500 + Mongoose model disclosure — OOS (descriptive errors)
`GET https://bridge.kubchain.com/api/v3/bridge-log?chainID=abc&txHash=0x00`
→ HTTP 500 `{"error":"Cast to Number failed for value \"NaN\" ... at path \"fromChainID\" for model
\"BridgeLog\""}`. Unhandled Mongoose cast exception; discloses stack/ODM(MongoDB)/model name.
Confirmed/reproducible. OOS: "Descriptive error messages (Stack Traces, application or server errors)".
(NoSQL operator injection is BLOCKED — backend enforces every query param be a string; array/object
params → 400 "expected a string". So no NoSQLi.)

## F2. Tokenless QuikNode RPC in public pair config — OOS (published / moderately sensitive)
`GET /api/v3/pair` returns `"public_rpc":"https://capable-little-putty.quiknode.pro/"` (no auth token
in path). It is shipped to every visitor in the public config (not "leaked"). Abuse = quota drain on a
third-party service = DoS-adjacent. OOS: "Moderately Sensitive Information Disclosure" / DoS.

## F3. BridgeERC20V3: ERC20 entry accepts NATIVE_REPRESENTATION — confirmed defect, ZERO impact
`bridge(address token_, uint256 amount_, uint64 destChainID_, DEST_TOKEN_TYPE)` (non-payable) does not
reject `token_ == NATIVE_REPRESENTATION`. In `_bridge`, the NATIVE branch then does
`_transferNative(receiver, totalAmount)` from the CONTRACT's balance and emits
`Bridge(NATIVE, msg.sender, totalAmount, …)` — i.e. it would credit the caller on the destination while
spending the contract's own native. BUT: the contract has NO receive()/fallback(), forwards 100% of
every payable bridge immediately, and holds 0 native on both ETH and KUB (verified on-chain). So it can
never hold native to steal; the call just reverts on insufficient balance. Latent code smell only.
OOS: "Theoretical vulnerabilities without any proof or demonstration."

## F4. BridgeERC20V3 `_isContract` constructor bypass — confirmed, no impact
`require(!_isContract(msg.sender))` uses extcodesize, which is 0 during a contract's constructor, so a
contract can bridge from its constructor. Impact: none for an attacker (they'd be credited at an address
they can't control on the destination). Not a vuln.

## Bottom line
Across all 3 in-scope assets (bkc protocol, bridge, staking) no in-scope, above-threshold, demonstrable
bug was found. The one unexplored high-value surface — the PoSA staking reward contracts — is
bytecode-only (unverified on Sourcify/kubscan; Solidity not in bkc repo) and the frontend's candidate
addresses have no code on mainnet, so neither source review nor a targeted fork-test is currently
possible without the contract source/address from the team.
