# VaultCord — BugBase Program (Scope Record)

Source: https://bugbase.ai/programs/vaultcord
Platform: BugBase
Program type: VDP (self-managed triage, BugBase-hosted)
Recorded: 2026-10-29 (scope investigation only — no testing performed)

## Program facts (from page)

- Status: Open — accepting bugs and drafts (`isAcceptingBugs: true`, `isAcceptingDrafts: true`).
- Report statistics (rendered page, verified 2026-10-29): 12 total reports received; 3 assets in scope.
- SLA (rendered page): Avg First Response 1 day, Avg Report Triage 1 day, Avg Report Resolution 1 day; latest report triaged ~6 hours before capture.
- Rewards: $0 across all severities (Informational / Low / Medium / High / Critical all $0). `programType: vdp`.
- Leaderboard: rohitchaudhary 9 bugs (earliest 2026-10-24T16:21Z), cyberian404 1 bug (earliest 2026-10-24T08:36Z).
- ANNOUNCEMENTS tab: empty. CHANGELOGS tab: empty (no policy changes recorded).
- Metadata: Website Testing + API Testing; Web; JS/TS/PHP/Node/React/MySQL.
- videoPOC: false. reporterIP: false. allowCollab: true. automatedTooling: "10".
- Required custom User-Agent: `Mozilla/5.0 ResponsibleReporter Gecko/20100101` (verbatim from page).
- No whitelist / no VPN requirement / no vault.

## Policy (verbatim)

> NextJS vulnerabilities that aren't blocked by Vercel firewall (as of 2026 we use Vercel). PHP SSRF exploits, and litecoin core RPC node exploits.

Interpretation notes:
- Policy is a positive hint list (Next.js unpatched classes not mitigated by Vercel WAF, PHP SSRF, Litecoin Core RPC), not a restriction of scope.
- Vercel WAF is an acknowledged mitigation layer; findings that Vercel already blocks are implied not to qualify.
- "litecoin core RPC node" implies a Litecoin node/RPC surface exists in infrastructure but no such asset is listed in scope (see Ambiguities).

## In-scope assets

| # | Group | Group label | Asset | Asset type | In scope | Bounty weight | Resolved | Description (verbatim, abridged) |
|---|---|---|---|---|---|---|---|---|
| 1 | `vaultcord.com` | Infrastructure | `*.vaultcord.com` | Wildcard | yes | 4 (80%) | 4 (80%) | "Nearly every *.vaultcord.com if used in production. Though docs.vaultcord.com is not covered, report it to Mintlify. There's more subdomains on VaultCord covered that are hidden in our infrastructure. They count if used in production." Labels: Production, DevOps, +1. Last update: Oct 12, 2026 |
| 2 | `api.vaultcord.com` | API Cluster | `*.vaultcord.com` | Wildcard | yes | 4 (80%) | 4 (80%) | Same wildcard asset + same description as #1. Last update: Oct 12, 2026 |
| 3 | `vaultcord.win` | Infrastructure | `https://vaultcord.win/hi` | Web | yes | 1 (20%) | 1 (20%) | "NextJS verification pages are in-scope and are critical to our business." Last update: Oct 12, 2026 |

Effective target set:
- `*.vaultcord.com` (wildcard, production subdomains only) — excluding `docs.vaultcord.com`, which is Mintlify's and must be reported to Mintlify instead.
- `https://vaultcord.win/hi` (Next.js verification page).
- Hidden subdomains not discoverable publicly still count **if in production**.

## Out-of-scope items (all isInScope: false, group label Infrastructure)

| # | Title | Asset row | Note |
|---|---|---|---|
| 1 | SPF Record or email misconfiguration | `https://github.com/orgs/VaultCord/repositories` (Web) | Asset/description mismatch. Description: "Public repositories are out of scope, private are within scope, only if used actively in the VaultCord infrasturecutre. Old microservices not used by consumers aren't in-scope, even if private." |
| 2 | User Enumeration | placeholder | "We know 'Forgot password' will indicate if email exists. This is for UX purposes." |
| 3 | All 3rd party websites being used by dependencies | placeholder | "Not in scope." |
| 4 | Self-XSS | placeholder | "Not in scope." |
| 5 | Malware on users' computers | placeholder | "Not in scope." |
| 6 | Missing security best practices not directly lead to vulnerable | placeholder | "Not in scope." (sic) |
| 7 | Missing HTTP security headers | placeholder | "Not in scope." |
| 8 | Social engineering VaultCord staff | placeholder | "Not in scope." |
| 9 | Issues that do not have any impact on the general public | placeholder | "Not in scope." |
| 10 | Public repositories on Github | placeholder | "Not in scope." |

Placeholder asset for items 2–10: `https://www.action1.com/blog/cwe-vs-cve-weaknesses-vs-vulnerabilities/` ("Not in scope."). This is a BugBase UI placeholder, NOT a target — never test it.

## Explicitly excluded by description / policy

- `docs.vaultcord.com` — owned by Mintlify; report to Mintlify, not here.
- Public GitHub repositories (`github.com/orgs/VaultCord/repositories`); private repos qualify only if actively used in VaultCord production infrastructure.
- Old microservices not used by consumers (even if private).
- Non-production subdomains ("if used in production" qualifier).
- Forgot-password user enumeration (deliberate UX).
- Third-party dependency sites, self-XSS, client-side malware, best-practice-only, missing headers, social engineering, no-public-impact findings.

## Ambiguities to resolve before testing

1. **Apex `vaultcord.com` vs `*.vaultcord.com`**: wildcard normally excludes the apex. Apex behavior is unstated.
2. **`vaultcord.win` path scope**: asset is `https://vaultcord.win/hi` only — whether other paths/subdomains of `vaultcord.win` are in scope is unstated.
3. **"used in production"**: no definition; staging/dev/QA subdomains need confirmation before testing.
4. **SPF OOS row carries a GitHub asset**: the row title (SPF/email) and its asset (GitHub org) disagree; treat both the SPF/email topic and the public-GitHub topic as OOS.
5. **Policy mentions PHP SSRF and Litecoin Core RPC node, but no PHP or Litecoin asset is listed**: these are hints, not listed assets — confirm with program owner whether a Litecoin RPC surface is in scope before touching it.
6. **"Issues that do not have any impact on the general public"**: broad; may be used to reject self-account-only or single-tenant findings.
7. **Duplicate wildcard rows**: groups #1 and #2 both resolve to the same `*.vaultcord.com` asset — `api.vaultcord.com` is not a separate asset row, just a group label.

## Workspace-gate implications (Claude.md)

- Program is a **$0 VDP** — economic gate (Claude.md selection criteria) means only findings with real, demonstrable public impact are worth pursuing; Low/Medium noise is not worth the report cost.
- Must confirm scope ambiguity #1/#2/#3 with the owner before any active testing of apex, `vaultcord.win` non-`/hi` paths, or non-production subdomains.
- Vercel WAF is acknowledged; findings the WAF blocks do not qualify per policy.
- Custom User-Agent `Mozilla/5.0 ResponsibleReporter Gecko/20100101` is required for automated tooling.
- No testing has been performed. Evidence in `evidence/`:
  - `bugbase-program.html` — raw program page (46,817 bytes)
  - `bugbase-policy-scope.png` — POLICY tab with scope list
  - `bugbase-scope-tab.png` — SCOPE tab
