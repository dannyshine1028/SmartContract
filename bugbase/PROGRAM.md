# BugBase — Bug Bounty Program (Scope Record)

Source: https://bugbase.ai/programs/bugbase
Platform: BugBase (自社プログラム)
Recorded: 2026-10-30 (scope investigation only — no testing performed)

## Program facts (from page + public JSON)

- Status: Open — `isAcceptingBugs: true`, `isAcceptingDrafts: true`.
- Type: paid bug bounty (`programType: bugbounty`), managed triage (`isManaged: true`). Currency: USD.
- Program website (metadata): `https://bugbase.in`. This host is **not** an in-scope asset.
- Stats (rendered page, 2026-10-30): 670 total reports received; 1 asset in scope; bounty range $100–$500. `showKPIs: false` — SLA averages are not shown.
- Rewards (in-scope group, fixed amounts, eligible for bounty): Critical $500 / High $250 / Medium $100 / Low $0.
- Out-of-scope group: all severities $0, ineligible for bounty and swag.
- ANNOUNCEMENTS: "No announcements have been made yet."
- HALL OF FAME: leaderboard of 88 researchers, 215 credited bugs. Top: abhisek_r 27 bugs (earliest 2025-01-04). Dated entries span 2024-09-08 through 2026-07-01. `hallOfFameUsers` itself is empty; the tab renders `leaderboard`.
- CHANGELOGS (2):
  - 2023-03-16 — test reports on the platform are marked as spam.
  - 2023-01-21 — "Added a gif to the policy."
- Policy "Last updated" on page: March 16, 2023.
- Flags: `allowCollab: false`, `reporterIP: false`, `videoPOC: false`. No required User-Agent. `requireWhitelist` / `vpnEnabled` / `vaultEnabled` are empty. No active campaigns.
- In-scope asset has `whitelistRequirements: []` and a leftover `customWhitelistDescription: "TestFlight ID"`. No whitelist is actually required.

## In-scope assets

| # | Name | Asset | Type | Labels | Last update | Resolved | In scope |
|---|---|---|---|---|---|---|---|
| 1 | BugBase Web App | `https://bugbase.ai` | Web | Production | 2025-06-27 | 5 (7.24%) | yes |

Asset rows have no description text. The URL is the exact host `https://bugbase.ai`, not a wildcard.

## Out-of-scope assets (group "Out Of Scope Targets", `isInScope: false`)

| # | Name | Asset | Type | Labels | Last update | Resolved |
|---|---|---|---|---|---|---|
| 1 | BugBase Testing | `https://testing.bugbase.in/` | Web | Testing, Staging | 2022-09-19 | 0 |
| 2 | BugBase Employee | `https://employee.bugbase.in/` | Web | Production, Internal, Employee Portal | 2022-09-19 | 0 |
| 3 | BugBase KPI Server | `https://kpi.bugbase.in` | API | KPI Server | 2023-04-26 | 0 |
| 4 | Bugbase Pentest Copilot | `https://copilot*.bugbase.in/` | Web | Copilot | 2023-06-29 | 0 |

## Policy rules that constrain testing

- No scanners or automated tools (policy names nuclei and nessus explicitly). Manual testing only.
- Do not discuss a vulnerability until it is fixed. PoC videos must be private.
- PoC note (current policy): all PoCs should be tried on sandbox `testing.bugbase.in`. Reports whose PoCs are sent to the main website `bugbase.in` are marked **spam**. The 2023-03-16 changelog is this change (previous wording marked them **invalid**).
- Functional bugs are not this program. Contact: https://bugbase.in/contact-us.
- Give reasonable time before public disclosure. Avoid harm, damage, and privacy violations while investigating.
- First reporter only. One vulnerability per report unless chaining is required for impact. Screenshots or PoC code required, plus a concrete attack scenario.
- No reward if already known, disclosed to a third party first, or reported by a current/former employee within the past three months.
- Reward amount is still "case-by-case" even with the published table.
- Safe harbour: good-faith, accidental policy violations will not be pursued; they will say the activity was authorized if a third party sues and the rules were followed.

## Out-of-scope categories (reward exclusions)

Policy section "Out-of-Scope":

- Any subdomain of `bugbase.in` unless listed in scope.
- All testing and staging environments.
- External services / software BugBase does not manage. Exception, case-by-case: issues that could leak customer PII.

Reward exclusions (also treated as out of scope, not rewarded):

- Enumerating already-claimed user or program handles (public or private).
- Spamming users via BugBase email/notifications (example: forgot-password form).
- Public 0-days: considered only case-by-case, and only if an official patch has been available for less than one month.
- Known-vulnerable libraries without a working PoC.
- Subdomain takeover that does not actually take control of the subdomain.
- Information disclosure without significant, executable impact.
- Information leakage / data cached in search engines or web archives.
- Self-XSS and XSS without impact.
- Password and account-recovery policies.
- Session management (timeout, session hijacking, etc.).
- Clickjacking on pages with no sensitive actions.
- CSRF on forms with no sensitive actions, or without a realistic scenario.
- Attacks that need MITM or physical access.
- CSV injection without a demonstrated vulnerability.
- Missing SSL/TLS best practices.
- DoS, and self-DoS (only the actor is denied service).
- Content spoofing / text injection that cannot modify HTML/CSS.
- Rate limiting or brute force on non-authentication endpoints.
- Missing CSP best practices.
- Missing HttpOnly or Secure cookie flags.
- Missing email best practices (SPF/DKIM/DMARC).
- Issues that only affect browsers more than 2 stable versions behind current.
- Version disclosure, banner grabbing, descriptive errors or headers (stack traces, application/server errors).
- Tab nabbing.
- Open redirects without a clear impact such as sending secret tokens to an arbitrary domain.
- Issues that require unlikely user interaction.

## Ambiguities to resolve before testing

1. **Sandbox vs scope.** Policy says develop PoCs on `testing.bugbase.in`, but that host is an explicit out-of-scope Testing/Staging asset, and the policy also says all testing and staging environments are out of scope. Findings that exist only there are not payable. Do not test it until this is confirmed.
2. **`bugbase.in` vs `bugbase.ai`.** The only in-scope asset is `https://bugbase.ai`. `https://bugbase.in` is the program website and the "main website" the spam rule names, but it is not in the scope table. Do not send PoCs to `bugbase.in`.
3. **Host boundary of `bugbase.ai`.** The asset is the exact URL, not `*.bugbase.ai`. Subdomains and other paths/hosts are unstated.
4. **`bugbase.in` apex.** The subdomain ban does not literally cover the apex. The apex is still absent from the in-scope list.
5. **`customWhitelistDescription: "TestFlight ID"`** with an empty whitelist. Treat as unused metadata, not a testing instruction.
6. **Historical volume.** 670 reports and 215 hall-of-fame bugs vs 5 resolved on the current in-scope asset. Duplicate risk is high; Low pays $0.

## Workspace-gate implications

- Paid from Medium up ($100 / $250 / $500). Low is $0, so header-only and best-practice findings are not worth reporting.
- Scanners are explicitly forbidden.
- No testing has been performed. Evidence: `bugbase-program.html`, `program-data.json`, `assets.json`, `stats.json`.
