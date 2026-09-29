# Alchemy Modular Account V2 — Program Snapshot

- Public: https://cantina.xyz/bounties/246de4d3-e138-4340-bdfc-fc4c95951491
- Platform: Cantina (Alchemy)
- Repo / branch: https://github.com/alchemyplatform/modular-account/tree/v2.0.x
- Local clone: `Source/alchemy-modular-account-v2/src`
- Reviewed commit: `7e2105743e286cf696ecb2b8a484d2e97c27e153` (`feat(account): SMA7702 v1.1.0 bare EOA ERC-1271 support and security fix #363`)
- Standards: ERC-4337 v0.7, ERC-6900 v0.8
- Rewards: Critical up to $100,000 · High $5–10k · Medium $500–2k
- Findings submitted (listing): 630

## In-scope (v2.0.x production)

| Contract | Address |
|---|---|
| AccountFactory | `0x00000000000017c61b5bEe81050EC8eFc9c6fecd` |
| ModularAccount | `0x00000000000002377B26b1EdA7b0BC371C60DD4f` |
| SemiModularAccount7702 | `0x69007702764179f14F51cdce752f4f775d74E139` |
| SemiModularAccountBytecode | `0x000000000000c5A9089039570Dd36455b5C07383` |
| SemiModularAccountStorageOnly | `0x0000000000006E2f9d80CaEc0Da6500f005EB25A` |
| ExecutionInstallDelegate | `0x0000000000008e6a39E03C7156e46b238C9E2036` |
| SingleSignerValidationModule | `0x00000000000099DE0BF6fA90dEB851E2A2df7d83` |
| WebAuthnValidationModule | `0x0000000000001D9d34E07D9834274dF9ae575217` |
| AllowlistModule | `0x0000000000002311EEE9A2B887af1F144dbb4F6e` |
| NativeTokenLimitModule | `0x00000000000001e541f0D090868FBe24b59Fbe06` |
| PaymasterGuardModule | `0x0000000000001aA7A7F7E29abe0be06c72FD42A1` |
| TimeRangeModule | `0x00000000000082B8e2012be914dFA4f62A0573eA` |

WebAuthnFactory is **not** on the bounty table.

## Rules (must obey)

- No live testing on public mainnet or public testnet — local forks only
- Only interact with accounts you own
- Non-v2.0.x branches OOS
- Audit known issues OOS (`audits/`)
- No public disclosure

## Explicit known / OOS (program + README)

- SMA7702 upgrade auth-tuple signature-format skip (bundler)
- Deferred action replacement by bundler/relayer when removal would fail validation
- User error, malicious module install, granting keys to a malicious entity
- ERC-4337 EntryPoint bugs
- Uneconomic counterfactual / hash-collision takeovers
- Design choices (two-step ownership, rounding, gas)
- Owner vs owner DoS
- Unprotected initializer if **not** used as ERC-1967 proxy
- EIP-7702 delegate must be SMA7702 only
- `signer == account` circular CONTRACT_OWNER
- SMA7702: granting limited validation `executeWithRuntimeValidation` is root-equivalent
- `isSignatureValidation` can approve deferred actions
- Native selector collision → installed fn unreachable (client check)

## Audits in repo

- 2024-01-31 Spearbit
- 2024-02-19 Quantstamp
- 2024-12-03 ChainLight (2 High, patched)
- 2024-12-11 Quantstamp
- 2026-08-05 Octane (`0a78d41`) — SMA7702 bare ERC-1271; L-01 lifecycle callbacks (Low, documented)
