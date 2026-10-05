# KUB Chain & Ecosystem — HackenProof Program (snapshot 2026-10-04)

Company: BitKub Blockchain (Bitkub Blockchain Technology Co., Ltd.). Triaged by HackenProof. Live.
Public page: https://hackenproof.com/programs/kub-chain-and-ecosystem
Docs:        https://docs.kubchain.com/
**Gates: 100 REPUTATION POINTS · KYC REQUIRED · PoC REQUIRED.**

"KUB — first blockchain infrastructure in Thailand; affordable/secure/scalable L1 for dApps & digital
assets at near-zero cost." Project types: L1/L2, BRIDGE, WALLET, DAPP.

## IN SCOPE (3 assets)
| # | Target | Type | Severity |
|---|---|---|---|
| 1 | https://github.com/kub-chain/bkc | **Protocol** | **Critical** |
| 2 | https://bridge.kubchain.com | Web | High |
| 3 | https://staking.kubchain.com | Web | High |

Note: the chain node source `bkc` is the crown jewel (Critical). Bridge/Staking are web (High) but
almost certainly have on-chain contracts behind them (BRIDGE project type).

## IN SCOPE VULNS — Blockchain Protocol
Stealing/loss of funds · Unauthorized transaction · Transaction manipulation · Price manipulation ·
Fee payment bypass · Balance manipulation · Violation of tokenomics · Privacy violation ·
Cryptographic flaws.  OOS: Network-level DoS.

## IN SCOPE VULNS — Smart Contracts
Stealing/loss of funds · Unauthorized transaction · Transaction manipulation ·
Attacks on logic (code behaves differently from business description) · Reentrancy · Reordering ·
Over/underflow.
OOS: theoretical w/o PoC · old compiler · unlocked pragma · imported-contract vulns · style ·
redundant code · gas opt · best practice · **front-run-only exploits**.

## IN SCOPE VULNS — Web
Business logic · Payments manipulation · RCE · Injection (SQL, XXE) · File inclusion (LFI/RFI) ·
Access control (IDOR, PrivEsc) · Sensitive info leakage · SSRF · CSRF · XSS · Directory traversal ·
Other with clear potential loss.
OOS (web, abridged): 3rd-party/assets-not-owned · best practices · <30d 0days · outdated-browser-only ·
social/phishing/physical · login panels w/o exploit · "out of date w/o PoC" · scanner-generated ·
browser add-ons · most brute-force w/o impact · DoS/DDoS · theoretical · moderately-sensitive info ·
spam · missing security headers · TLS/SSL/cert · DNS · server config/open ports · open redirect ·
session fixation · user enumeration · clickjacking · descriptive errors/stack traces · self-XSS ·
login/logout CSRF · weak/captcha bypass · missing Secure/HTTPOnly · enum via login/forgot ·
CSRF on anon forms · OPTIONS/TRACE · host-header w/o PoC · content/text spoofing w/o vector · RFD ·
mixed content · password-reset-token manip · MitM/local · response manip w/o state change.

## REWARDS
Critical $3,000–5,000 · High $2,000–3,000 · Medium $500–2,000 · Low $100–500. Range $100–$5,000.

## STATS (2026-10-04)
Scope Review 279,984 · Submissions 281 · Total rewards $1,450 · Hackers 143.
=> Low payout ratio (stingy, heavily triaged). High duplicate/noise risk. Verify rigorously.
SLA: first response 3d, triage 3d, reward 3d, resolution 14d.

## PROGRAM RULES (key)
No scanners/massive traffic · don't damage/degrade availability · don't compromise personal data ·
**don't access/modify other users' data, localize tests to own accounts** · scope only ·
no DoS/DDoS/social/spam · chain vulns pay only the single highest severity · lawful · confidential.

## ABSOLUTE WORKSPACE RULES TO RESPECT (Claude.md §0)
- Smart-contract/chain: NEVER attack mainnet/public testnet. Local fork only (Foundry/Hardhat+Anvil).
- No unverified AI output submission (must reach Verifier Level-3: a real invariant broken on a fork).
- No exaggeration; "unknown" stays "unknown". Responsible disclosure.

## DUPLICATE-AVOIDANCE TODO (Claude.md §2-0)
- [ ] Check program "Reports" tab for disclosed reports.
- [ ] Check bkc repo for an `audit/` folder & Known Issues.
- [ ] Light public search for known CVEs in the upstream geth version bkc forks.
