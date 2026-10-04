# GMGN Web & Mobile — program sheet

Source: https://hackenproof.com/programs/gmgn-web-and-mobile (public page, read-only)
Dashboard (login): https://dashboard.hackenproof.com/user/programs/gmgn-web-and-mobile
Official docs: https://docs.gmgn.ai/index/gmgn-vulnerability-bounty-program
Captured: 2026-10-04. Status: **Live** bug bounty (not a time-boxed contest).
Program start 2025-03-17, last update 2026-07-15. Triaged by HackenProof.

## What GMGN is

A fast on-chain trading platform / DApp: "Fast Trade, Fast Copy Trade, Fast AFK Automation."
Memecoin/on-chain trading, copy-trading, and automation ("AFK"). This is a **Web + Mobile (DApp)**
target — NOT a smart-contract audit. The value at risk is **user wallets, funds, and private keys**
(the Extreme tier is explicitly about "unauthorized access to GMGN wallets, funds, or private keys").

## Assets in scope (4)

| target | type | severity ceiling |
|---|---|---|
| `https://gmgn.ai/` | Web | Critical |
| `*.gmgn.ai` | Web | Critical |
| iOS: `https://apps.apple.com/sg/app/gmgn-lite/id6740896821` (GMGN Lite) | iOS | Critical |
| Android: `https://play.google.com/store/apps/details?id=com.gmgn.app` | Android | Critical |

**Note the wildcard `*.gmgn.ai`** — every subdomain is in scope (API hosts, etc.).

**Mobile caveat:** "If the same vulnerability is identified on both iOS and Android it is a single
issue, one payout." Per `Claude.md` §0 rule 1.5, mobile apps are generally out of our current
toolset — focus is Web/API. Record mobile observations but do not expect to reach Level-3 on-device.

## Rewards

$50 – **$1,000,000**. Paid in USDT. TRUSTED-by-HackenProof triage (not confirmed as deposit-funded).

| tier | reward | meaning |
|---|---|---|
| **Extreme** | up to **$1,000,000** (≈10% of potential loss, capped at 1M) | threatens core assets; unauthorized access to **GMGN wallets, funds, or private keys** |
| Critical | $3,000 – $10,000 | undermines user-asset security; bypasses normal trading logic; remote access to essential/auth info; **key generation / encryption / decryption / signing / verification** flaws |
| High | $1,000 – $3,000 | high-risk info leakage; critical-like impact with prerequisites |
| Medium | $300 – $1,000 | partial user-info leakage via interaction or financial fraud; GMGN unable to serve web/mobile requests |
| Low | $50 – $300 | design defects without asset impact; DoS of core GMGN services |

The reward table on HackenProof shows **Critical $3k–$10k max** in the severity chips, but the
**Extreme** tier (up to $1M) sits above it in the Focus Area text. Highest realistic paydirt =
anything touching wallet/key/signing.

## Out of scope / NOT qualified for reward (verbatim list)

- Theoretical vulns without a working PoC
- Email verification defects, password-reset link expiry, password complexity policies
- Invalid/missing SPF/DKIM/DMARC
- Clickjacking/UI redressing with minimal impact
- Email or mobile enumeration (e.g. via password reset)
- Information leakage with minimal impact (stack traces, path disclosure, dir listings, logs)
- Internally known / recurring / already-published issues
- Tabnabbing
- **Self-XSS**
- Vulns only on outdated browsers/platforms
- Auto-fill web form vulns
- Known vulnerable libraries without a working PoC
- Lack of cookie security flags
- Unsafe SSL/TLS cipher suites or protocol versions
- Content spoofing
- Cache-control issues
- Internal IP / domain disclosure
- **Security headers that don't lead to direct exploitation**
- **CSRF with negligible impact** (favorites, non-vital subscriptions)
- Vulns requiring root/jailbreak
- Vulns requiring physical device access
- No-security-impact issues (e.g. page fails to load)

## Program rules that constrain how we work

- **No automated web scanners** that generate massive traffic. (Matches our safe-recon discipline.)
- Make every effort not to damage/restrict availability. No DoS/DDoS, no social engineering, no spam.
- **"Don't access or modify other user data, localize all tests to your accounts."** → we may only
  test against our own account; no touching other users' data.
- Chained vulns pay only for the highest severity.
- **Report within 24h of discovery**, exclusively through hackenproof.com.
- 100 reputation points required. PoC mandatory.
- **"AI-generated PoCs that do not include detailed architectural context and clear steps to
  demonstrate real impact may not qualify."** and "AI-generated reports without a runnable PoC are
  not accepted." → every finding must have a hand-verified, runnable PoC (matches `Claude.md` §0).
- No disclosure of any kind without mutual written agreement; platform-only disclosure.

## Program state (2026-10-04)

**169 submissions · 105 hackers · $8,050 total paid.** SLA: first response 3 business days, triage 5,
reward 14, resolution 14. The low total-paid against 169 submissions suggests a crowded duplicate
surface and/or a high bar — treat accordingly.

## ⚠ Scope & safety notes before any testing (resolve first)

1. **This is a live production trading platform handling real user funds.** `Claude.md` §0 and the
   org security policy forbid actions that could affect real users or real data. Every test must be
   (a) against our own account only, (b) non-destructive, (c) non-DoS, (d) no automated scanners.
2. **No account exists yet.** Authenticated testing requires creating our own GMGN account. Account
   creation / credential entry is governed by the harness rules — creating an account on a live
   third-party production site is NOT the "testing the user's own application on localhost" exception.
   Confirm with the user before any sign-up or credential entry.
3. **Wallet/key handling is the crown jewel** (Extreme tier). If GMGN is custodial or uses an
   in-app/embedded wallet, how private keys are generated, stored (localStorage? indexedDB? secure
   enclave?), and used for signing is the highest-value area — but also the area most likely to need
   authenticated access and real funds, which we must not risk.
4. **Safe first steps (no account, no state change):** enumerate `*.gmgn.ai` subdomains from public
   sources (passive), read the production web app's distributed JS bundles for client-side logic
   (key handling, API endpoints, auth flow, signing), review the public API surface shape, and map
   the trust boundaries — all read-only, matching the EverValue/Unitus recon discipline.

## Next step

Decide the testing posture with the user:
- **Unauthenticated / static only** (safest): read the web app's JS, map `*.gmgn.ai`, analyse
  client-side key/signing logic and API shape — no account, no state change. This is the default and
  what we can do without further authorization.
- **Authenticated** (needs user go-ahead): create our own GMGN account to test trading/wallet flows.
  Requires explicit confirmation because it is credential entry + account creation on a live
  third-party site, and may involve real funds.
