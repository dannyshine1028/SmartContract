# Acko — Program record (scope only)

Source: https://bugbase.ai/programs/acko
Platform: BugBase
Recorded: 2026-10-30. Public program page, public stats JSON, and public assets JSON only. No requests were sent to Acko hosts.

Current policy text: `policy.md` (flight node `$1f`, the value of `programPolicy`). Older copies in the page are `policyLogs`, not the current policy.

## Program facts

- Name: Acko Responsible Disclosure Program. Username: `acko`. pid `691c4203014d50303ddd2393`.
- Type: **VDP** (`programType: vdp`). Page title is a vulnerability disclosure program. It is not a BugBase paid-bounty type.
- Status: open. `isAcceptingBugs: true`, `isAcceptingDrafts: true`. `isBlacklisted: false`.
- Triage: unmanaged (`isManaged: false`). `nonTarget: false`. Currency field: USD.
- Program website field: `https://www.acko.com/`. That exact URL is also an in-scope asset row.
- Stats (2026-10-30): 128 reports received, `totalWebsitesInScope: 10`, `minBounty: 0`, `maxBounty: null`, `showKPIs: true`.
- SLA shown: first response avg 23 hours, triage avg 39 hours, resolution avg 940 hours. Latest triaged report: 2026-10-19 05:13:51 UTC.
- Platform reward fields: one in-scope group, `bountyVals` low/medium/high/critical all `"0"`, bounty ranges 0–0, `rewards: []`. No out-of-scope asset group.
- The written policy is different from those zeros. It says rewards are **Amazon vouchers**, not BugBase cash: Critical ₹15,000, High ₹10,000, Medium no bounty, Low no bounty. Acko decides criticality. See Reward Guidelines below.
- Flags: collaboration off, reporter IP required, video PoC required. Activities: API Testing, Website Testing, Recon, WAF/RASP Bypass, Mobile Application Testing. Environments: Android, iOS, Web. Languages/frameworks: empty. Whitelist, VPN, and vault: empty. Announcements: empty.
- Leaderboard: 33 researchers, 100 credited bugs. Highest counts: captain_rip 19, sricharan_99 18, ajeethkumar_619 8, r@z!q! 6. Hall of Fame: 31 names. Asset rows sum to 4 resolved bugs, all on `*.ackodrive.com`.
- Policy changelog (10 entries, newest first): 2026-05-25 reward wording, 2026-05-25 report-detail wording, 2026-05-15 added the `acko.com` subdomain out-of-scope line, then six "Policy Update" entries from 2026-01-15 back to 2025-11-21.

## In-scope assets

One scope group: `In-Scope Assets`, `isInScope: true`, labels Microservices and Infrastructure. The group lists **10 asset ids**. The public assets endpoint returned **9** (`total_items: 9`). Stats say 10 websites in scope, which matches the id list, not the URL list.

| # | Name | Asset | Type | Labels | Last update | Resolved |
|---|---|---|---|---|---|---|
| 1 | Acko | `https://www.acko.com` | Web | Production | 2025-11-18 | 0 |
| 2 | (not in the public asset list) | id `691c4361014d50303ddd26f3` only | — | — | — | — |
| 3 | Acko Drive | `https://ackodrive.com` | Web | Production | 2025-11-18 | 0 |
| 4 | Acko Drive Wildcard | `*.ackodrive.com` | Web | Production | 2025-11-18 | 4 (100%) |
| 5 | Acko iOS Application | `https://apps.apple.com/us/app/acko-insurance/id1621244359` | iOS | Production | 2025-11-18 | 0 |
| 6 | Acko Android Application | `https://play.google.com/store/apps/details?hl=en_US&id=com.acko.android` | Android | Production | 2025-11-18 | 0 |
| 7 | Acko | `https://cx360.corp.acko.com` | Other | Production | 2026-05-18 | 0 |
| 8 | Acko | `https://lead360.corp.acko.com` | Other | Production | 2026-05-18 | 0 |
| 9 | Acko | `https://firefly.corp.acko.com` | Other | Production | 2026-05-18 | 0 |
| 10 | Acko | `https://partner-portal.corp.acko.com` | Other | Production | 2026-05-18 | 0 |

Rows 1 and 3–10 are the nine objects from `GET /api/hacktivity/get-program-assets/acko?current_page=1&limit=all`. Row 2 is the id present in `scopeGroups[0].assets` and absent from that response. Its URL, name, and type are not in the public payload. It was not guessed.

The policy does not repeat this URL list. "In scope" in the policy means this asset table.

There is no second scope group and `nonTarget` is false. Nothing in the public payload adds hosts beyond this table.

## Targets out of scope

From the current policy, "Targets Out of Scope":

- Any subdomain of `acko.com` that is not in the in-scope table.
- All sandbox and staging environments.
- All external services or software Acko does not manage or control.
- Third-party applications integrated with the Acko platform.

Applied to the table:

- In: `https://www.acko.com` exactly. Not a wildcard.
- In, as exact hosts only: `cx360.corp.acko.com`, `lead360.corp.acko.com`, `firefly.corp.acko.com`, `partner-portal.corp.acko.com`.
- Out: every other `*.acko.com` host, including other `*.corp.acko.com` hosts.
- In: `https://ackodrive.com` and `*.ackodrive.com`. The wildcard is labeled Production. Sandbox and staging stay out even if the name is under `ackodrive.com`.
- In for the program, out for this workspace: the iOS app and the Android app (`com.acko.android`). This workspace does not test mobile apps.

## Issues out of scope

Web:

- Self-XSS that cannot exploit other users.
- MITM, physical access, or social engineering.
- Missing security headers and cookie flags.
- Password-policy, lockout, and session-timeout best practice.
- Automated scanner reports (Nuclei, ZAP, Burp scan, Nessus, and similar).
- Tabnabbing, clickjacking, and UI redressing without demonstrated impact.
- Email spoofing, SPF, DMARC, DKIM.
- Content spoofing, text injection, CSV injection, and hyperlink injection without security impact.
- SSL/TLS configuration issues (weak ciphers, BEAST, BREACH, POODLE).
- Banner, version, path, or server disclosure without proven impact.
- User-id or email enumeration, and directory listing without a sensitive file.
- HTTP request smuggling without proven impact.
- API-key or hardcoded-secret disclosure without proven security impact.
- Exif data, verbose errors without sensitive data.
- Rate limiting, and brute force against forms that already have standard protections.
- Open redirects without proven token or credential theft.
- CORS misconfiguration on non-sensitive endpoints.
- Missing CSRF tokens on non-sensitive forms, including login/logout CSRF.
- Blind SSRF without proven business impact. A pingback is not enough.
- Homograph attacks and XML-RPC enabled.
- Sessions not invalidated on logout or when enabling 2FA.
- Known CVEs, known-vulnerable libraries, or leaked/breached credentials without a working exploit.
- Issues in third-party applications Acko does not control.
- DoS, DDoS, and physical security testing.

Mobile:

- Physical access, or a rooted/jailbroken device.
- Missing certificate pinning or root/jailbreak detection.
- API keys or hardcoded secrets used for non-sensitive activity, without proven impact.
- Missing obfuscation, or debugging enabled in production.
- Backup flags, and data in logs, cache, or temp files.
- Screenshots, screen recording, copy/paste, and tapjacking.
- App Transport Security bypass, and insecure IPC.
- Weak cryptography, and URL-scheme hijacking without a demonstrated exploit.
- Malicious-keyboard issues, and weak transport protection on non-sensitive data.
- Client-side injection without server-side impact.

## What they say they pay for

The policy asks for issues that expose PII, KYC, policy records, or financial data. Named classes: RCE, SSRF, SQL injection, authentication or authorization bypass into customer or admin access, IDOR of customer PII/KYC/policy documents, XSS that can steal a customer session or sensitive data, CSRF on customer-account or financial actions, and bulk customer-data exposure.

Testing limits in the same policy: do not violate privacy, destroy data, or disrupt service. Use an exploit only far enough to confirm the issue. Do not exfiltrate data, keep a shell, or pivot. Do not send the report through public channels or to third parties. Submissions count only on BugBase. Email to `bugbounty@acko.com` is for questions, not for reports. Employees, relatives, and business partners are ineligible. Ex-employees may report only after 2 years. First reporter only. Researchers must delete proof artifacts after the report is closed.

## Ambiguities

1. **Tenth asset.** Id `691c4361014d50303ddd26f3` is in the in-scope id list and is not in the public asset response. No URL is published for it. It is not an authorization to probe an unnamed host.
2. **Apex `acko.com`.** Not an asset row. `www.acko.com` is. Unlisted subdomains are out of scope. The apex itself is simply absent from the table.
3. **`*.ackodrive.com`.** In scope for production names. Staging and sandbox are out of scope by the target rule, including names that sit under that wildcard.
4. **`corp.acko.com`.** Four exact URLs are in scope. The parent host and every other subdomain are not listed, so the subdomain rule puts them out of scope.
5. **Pay.** BugBase stores `$0` for every severity because the program type is VDP. The policy still offers Amazon vouchers for Critical (₹15,000) and High (₹10,000). Medium and Low are written as no bounty. That is a non-zero reward only if Acko rates the issue High or Critical.

## Workspace gate

Paid recognition exists only as a voucher, and only at High or Critical. 128 reports are already in, and the public asset counters show 4 resolved bugs. No Acko host was requested.
