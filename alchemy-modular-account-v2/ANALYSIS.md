# Alchemy Modular Account V2 — Investigation [01]–[25]

**Date:** 2026-09-21  
**Program:** [Cantina bounty](https://cantina.xyz/bounties/246de4d3-e138-4340-bdfc-fc4c95951491)  
**Code:** `v2.0.x` @ `7e21057`  
**Mode:** Local static review of in-scope contracts. No mainnet/public-testnet exploit. No Level-3 report.

**Verdict:** No previously-unreported account takeover / fund-theft path reached Level 3. Surfaces below are either designed, documented, already audited, or program-OOS.

---

## [01] Execution paths

Native: `execute` / `executeBatch` / `executeUserOp` / `executeWithRuntimeValidation` / `performCreate` / fallback module dispatch.

- EP-only: `validateUserOp`, `executeUserOp`.
- `wrapNativeFunction` → `_checkPermittedCallerAndAssociatedHooks` then post-hooks.
- Direct callers that are not EP/self must have **direct-call validation** for the selector.
- Self-call `execute(this, …)` is **rejected** (`SelfCallRecursionDepthExceeded`). `executeBatch` self-calls allowed one level; nested `execute`/`executeBatch` inside batch denied.

**Fund theft via unauthenticated execute:** not found.

---

## [02] Session keys

Session key = extra `installValidation` entity with selectors + hooks (Allowlist / NativeTokenLimit / TimeRange / PaymasterGuard).

- Selector-scoped: `_checkIfValidationAppliesCallData` (global vs selector).
- Global validation cannot call non-global installed exec fns (SelfCallAuthorization tests).
- Factory default: single signer, **global**, userOp + runtime + 1271 flags.

Granting a session key `installValidation` / `upgradeToAndCall` / SMA7702 `executeWithRuntimeValidation` is **root-equivalent** (README). That is user error / malicious permission — OOS.

---

## [03] Allowlist

`AllowlistModule`: validation hook on `execute`/`executeBatch` only. Other selectors are **not** checked (no revert) — by design; session keys must not be given those selectors.

Order: wildcard address → wildcard selector → specific pair.

**Not a bypass** unless the validation is also allowed to call `installValidation` / `performCreate` / etc.

---

## [04] Token spend limits

Same module, as **validation-associated execution hook**.

- Counts only inner `transfer` / `approve` amounts; other selectors on a limited token **revert** (`SelectorNotAllowed`).
- DAI-like extra spend functions are intentionally blocked.
- Tokens **without** `hasERC20SpendLimit` are not metered; docs say pair with allowlist.

No unprivileged drain of *tracked* ERC-20 beyond the limit found. Untracked token spend is config, not a Core bug.

---

## [05] Native token limits

`NativeTokenLimitModule`:

- UserOp: decrements `gas * maxFee` unless a normal paymaster is used; `specialPaymasters` still decrement.
- Execution hook: sums `value` on `execute` / `executeBatch` / `performCreate`.
- Runtime validation hook is empty (runtime gas is paid by caller). Native *transfers* still hit the exec hook.

ETH sent via a **custom installed execution** that is not those three selectors is not metered — requires installing a malicious/unscoped execution module (OOS: malicious module).

---

## [06] Time-range permissions

- UserOp: returns ERC-4337 `validAfter`/`validUntil` (EP enforces).
- Runtime: `block.timestamp` inclusive check.
- ERC-1271: **no** time check (documented; use `isSignatureValidation=false` if 1271 must be denied).
- `validUntil==0 && validAfter==0` rejected; `validUntil==0` → `uint48.max`.

Not a silent always-valid UserOp.

---

## [07] Module installation / removal

- `installValidation` / `installExecution` are `wrapNativeFunction` (need global or selector validation).
- Execution install is `delegatecall` to `ExecutionInstallDelegate` (`onlyDelegateCall`).
- Native/ERC-4337/IModule selectors blocked on install (4337 + IModule). Native collision: installed fn **unreachable**, native still wins (documented).
- Uninstall `onUninstall` is best-effort (`&&` aggregation; first failure skips later). Octane **L-01**. Not fund theft by itself.
- Per-entity uninstall does not clear other entity IDs (documented).

---

## [08] Validation bypass

Checked:

- Direct `execute` without validation: blocked unless `skipRuntimeValidation` (native wrapped fns require validation; public skip only for non-global natives like `validateUserOp` which is EP-gated).
- Session key calling FOO via `execute(account, foo)`: self-call depth revert.
- Global validation calling selector-gated FOO: `ValidationFunctionMissing`.
- Deferred action cannot use a validation that has **validation hooks**.
- SMA fallback `CONTRACT_OWNER` with `owner == address(this)` rejected on native 1271 path.

No bypass of validation for fund movement.

---

## [09] execute vs executeBatch vs executeUserOp

| Path | Validation | Hooks |
|---|---|---|
| `execute`/`executeBatch` | wrapNative / UO inner after locator | selector + (direct-call) validation hooks |
| `executeUserOp` | EP + locator from **nonce**; inner calldata after 4 bytes | **validation-associated** exec hooks; requires UO selector if those hooks exist |
| `executeWithRuntimeValidation` | locator from **authorization** blob | validation-associated exec hooks |

If validation has exec hooks, UO **must** wrap `executeUserOp` (`RequireUserOperationContext`). Prevents hook skip.

---

## [10] Runtime validation

`executeWithRuntimeValidation` → `_checkIfValidationAppliesCallData` → pre-runtime hooks → `validateRuntime` → exec hooks → self-call.

- SingleSigner: `msg.sender == signer` (no signature).
- WebAuthn: `validateRuntime` **always reverts** (passkeys cannot be `msg.sender`).
- SMA fallback: `msg.sender == fallbackSigner`.
- EOA cannot be a runtime validation module: `extcodesize==0` reverts in `invokeRuntimeCallBufferValidation`.

SMA7702 README: limited validation + `executeWithRuntimeValidation` + fallback `address(this)` = root. Configuration OOS.

---

## [11] Deferred actions

Encoded in UO signature when locator `hasDeferredAction`.

- Hash: EIP-712 `DeferredAction(nonce, deadline, keccak(call))` with account domain (`chainId`, `this`).
- Outer validation must be 1271-enabled and **hook-free**.
- Self-call then remaining sig validates the UO.

**Program OOS:** bundler replacing deferred actions.  
**Documented:** `isSignatureValidation` is powerful (can sign deferred installs).

Nonce binds deferred hash → replay of same deferred+nonce fails after EP consumes nonce.

---

## [12] Nonce / replay

- Sequential nonce lives in EntryPoint (not the account).
- Alchemy packs entity ID + flags into the 4337 nonce key (`ValidationLocatorLib`).
- SingleSigner / WebAuthn 1271: `ReplaySafeWrapper` (account-bound).
- SMA fallback 1271: `_replaySafeHash` except during `validateUserOp` (hash already EP-bound).
- SMA7702 **bare** 1271: digest is **not** replay-wrapped (Octane + docs). App must bind chain/nonce. Design; 65-byte path is for EOA-compat.

Cross-chain replay of modular 1271: domain has `chainId` + account. Bare 7702 1271: same as EOA.

---

## [13] EIP-1271

Locator prefix selects validation; `isSignatureValidation` flag required.

SMA7702 raw mode (64/65-byte): ECDSA over raw hash if fallback enabled, signer=`this`, no fallback pre-hooks. Reviewed by Octane 2026-08. Cannot universally revoke EOA sigs that verifiers check as ECDSA without 1271 — design of 7702.

---

## [14] ECDSA

- `ECDSA.tryRecover` (low-s).
- UserOp hash: `toEthSignedMessageHash`.
- Prefix byte `SignatureType` (EOA vs CONTRACT_OWNER).
- Invalid type reverts.

Malleability: OZ tryRecover canonical s. No high-s accept.

---

## [15] WebAuthn

- P-256 via `webauthn-sol`; `WebAuthn.verify(abi.encode(hash), false, …)` (UV not required — typical passkey UX / known pattern).
- Runtime disabled.
- 1271 uses replay-safe hash.
- `transferSigner` is `msg.sender` = account.

No unauthenticated WebAuthn path.

---

## [16] EIP-7702

`SemiModularAccount7702`:

- Default fallback signer = `address(this)` (the EOA).
- `upgradeToAndCall` **always reverts** (`UpgradeNotAllowed`).
- Bare 1271 only; UO/runtime still use typed SMA signatures.
- Program known issue: auth-tuple upgrade signature-format skip.

Delegating to ModularAccount (with initializer) is README-warned takeover — **user error / wrong implementation**.

---

## [17] Initializer

- Implementation constructors call `_disableInitializers()` (`initialized = uint8.max`).
- Proxy: `initializeWithValidation` / SMA storage `initialize` once.
- Factory `createAccount` deploys ERC-1967 + initializes **in the same transaction**.
- Unproxied use: initializer reentrancy during construction — **documented OOS**.

No uninitialized factory proxy takeover.

---

## [18] Upgrade

- UUPS `upgradeToAndCall` + `wrapNativeFunction`. `_authorizeUpgrade` is empty **on purpose**; auth is the wrapper.
- SMA7702: upgrades disabled.
- ERC-7201 namespaced storage.
- README: check `initialized` when upgrading onto MA.

Privileged (owner validation) upgrade to a malicious impl is user/owner action — OOS.

---

## [19] Factory deployment

- `LibClone.createDeterministicERC1967`; returns existing address if already deployed.
- Salt = `keccak(owner, salt, entityId)`.
- Default validation: SingleSigner or WebAuthn, **global**, all flags true.
- `withdraw` / stake: `onlyOwner`. Native withdraw sends `address(this).balance` (ignores `amount`) — **factory owner only**, not user accounts. Program Medium includes factory funds but this is privileged.

Front-running `initialize` on a factory-created proxy: not possible; init is atomic.

---

## [20] Selector collision

- IModule + ERC-4337 selectors **revert** on install.
- Native selectors: no revert; module fn unreachable; native remains. Client must check (README).
- Fallback routes only if `executionStorage[msg.sig].module != 0` and msg.sig is **not** a native function (Solidity dispatch). Cannot shadow `execute`.

Cannot collide into `validateUserOp` / paymaster selectors.

---

## [21] Cross-module privilege escalation

Entity IDs are isolated maps. Hooks of entity A do not automatically apply to entity B.

Escalation requires:

- installing a validation with global + installValidation, or
- SMA7702 `executeWithRuntimeValidation` on a limited key, or
- `isSignatureValidation` + deferred `installValidation`, or
- circular `signer == account`.

All documented / config / OOS.

---

## [22] Nested / reentrant execution

- `execute(this)` banned; batch self-call depth 1.
- `wrapNativeFunction` runs hooks around native calls; inner `execute` to *other* contracts can reenter the account via tokens. Reentry still needs a permitted caller or EP.
- ERC-721/1155 receivers exist; they do not skip validation for later `execute`.
- Lifecycle `onInstall` reentrancy: Octane L-01 (Low, documented).

No reentrancy that spends without the active validation’s hooks in the EP/runtime path.

---

## [23] ERC-4337 integration boundaries

- Missing funds forwarded to EP; failure ignored (EP verifies).
- EntryPoint bugs OOS.
- `executeUserOp` EP-gated.
- PaymasterGuard only on UserOp (runtime no-op) — by design.

---

## [24] ERC-6900 module boundaries

- Modules are singletons; state keyed by `(entityId, account)`.
- Account never `delegatecall`s arbitrary modules for validation (external `call`). Execution install uses a **fixed** delegate.
- `onInstall`/`onUninstall` run under intermediate authority (L-01).
- Malicious module OOS.

---

## [25] Account takeover / fund theft

| Hypothesis | Result |
|---|---|
| Unauth `execute` | Blocked |
| Session key → `installValidation` via nested execute | Self-call / selector check |
| Init front-run factory | Atomic create+init |
| 7702 + ModularAccount impl | User error (README) |
| Bare 1271 replay | App-digest / EOA-equivalent; Octane |
| GMX-style cross-lock | N/A |
| Factory drain users | No; owner withdraws factory only |

**No Level-3 novel takeover.**

---

## Candidates killed (not reporting)

| ID | Why |
|---|---|
| Allowlist ignores non-execute selectors | Design; selector association is the gate |
| PaymasterGuard empty at runtime | Design |
| Native limit ignores custom exec | Requires extra module (OOS) |
| 1271 not time-ranged | Documented |
| Factory `withdraw` ignores `amount` | Privileged owner |
| Native selector overwrite unreachable | Documented; native still executes |
| Deferred replacement | Program OOS |
| SMA7702 bare 1271 | Audited design |
| Lifecycle callback order | Octane L-01 |

---

## Private-fork note

Not run: no remaining hypothesis that is both (a) unprivileged, (b) in-scope, (c) not already known. If continuing, the only non-OOS probe with residual uncertainty is **composing in-scope hooks on a default factory account** (session key + Allowlist + NativeTokenLimit) on a local Anvil fork — expected to hold.

---

## Deep source review (follow-up)

Read in full: `ModularAccountBase`, `ExecutionLib`, `ModuleManagerInternals`, `ValidationLocatorLib`, `AllowlistModule`, `NativeTokenLimitModule`, `TimeRangeModule`, `PaymasterGuardModule`, `SingleSignerValidationModule`, `WebAuthnValidationModule`, `SemiModularAccountBase` / `7702` / `Bytecode` / `StorageOnly`, `AccountFactory`, `ExecutionInstallDelegate`, `AccountStorageInitializable`, `ModuleInstallCommonsLib`, plus deferred / self-call / allowlist tests.

### Locator / nonce

Nonce `shr(64)` then mask 5 vs 21 bytes. `lookupKey` keeps entity/address + direct-call bit (`…04`), strips global/deferred. Stored validation cannot be swapped by flipping those flags. Spoofing `isGlobal` in the nonce fails `_isValidationGlobal` (storage). Factory owner has an empty selector set and must use the global bit.

### Self-call / nested execute

`getExecuteTarget` reads `calldata[4:36]` masked to 160 bits — matches ABI `execute(address,…)`. Dirty high bits cannot hide `address(this)`. `execute(this)` always reverts. `executeBatch` self-calls: nested `execute`/`executeBatch` revert; other native selectors still need the same validation. Deferred actions reuse these checks (`test_deferredAction_privilegeEscalationPrevented_*`).

### Session key vs global

Any **global** validation may call every `_isGlobalValidationAllowedNativeFunction` (`execute`, `installValidation`, `upgradeToAndCall`, `executeWithRuntimeValidation`, …). That is the owner model. Selector-scoped session keys cannot reach those natives unless the selector was granted.

SMA7702: `executeUserOp` → self-call `executeWithRuntimeValidation` sets `msg.sender == account == fallback signer`, so runtime fallback succeeds with no signature. README: never grant `executeWithRuntimeValidation` to a limited validation. Program: user error / malicious permission.

### Permission modules (singleton)

State keyed by `[entityId][account]` where `account = msg.sender`. Direct EOA calls to `updateLimits` / `setAddressAllowlist` only write the EOA’s unused slot. If a session key’s allowlist includes `AllowlistModule` / `NativeTokenLimitModule` (or a wildcard address), it can `execute` `updateLimits` and lift its own cap. Mitigation is “don’t allowlist the hook modules”. Default factory does **not** install session keys.

### Hooks fail-open / fail-closed

Empty `onInstall` data (`data.length == 0`) skips the callback:

- NativeTokenLimit → limit 0 → spend reverts (fail closed)
- Allowlist → no addresses → `AddressNotAllowed` (fail closed)
- PaymasterGuard → paymaster 0 → UO reverts (fail closed)
- TimeRange → `(0,0)` packed as 4337 `validUntil=0` = **infinite** (fail open)

TimeRange without init data is a client mis-install, not an unauthenticated path.

### ERC-20 limit encoding

Amount loaded at `innerCalldata+0x44` (standard `transfer/approve(address,uint256)`). Other selectors revert when `hasERC20SpendLimit`. `approve` counts as spend. `increaseAllowance` / DAI `permit` blocked on limited tokens.

### Init / upgrade / factory

Impl constructors `_disableInitializers`. Factory `createAccount` = CREATE2 + `initializeWithValidation` in the same tx. SMA-Storage `initialize` has no extra ACL beyond `initializer`; intended via authorized `upgradeToAndCall`. Re-init of an already-initialized MA namespace reverts. SMA7702 `upgradeToAndCall` hard-reverts. Factory salt includes owner. Native `withdraw` sends `balance` not `amount` — factory `onlyOwner` only.

**Still no Level-3 unprivileged fund theft.**
