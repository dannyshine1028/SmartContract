# BugBase — Hunt notes (2026-10-30)

Scope tested: `https://bugbase.ai` only. No scanners. No requests to OOS hosts (`bugbase.in`, `testing.bugbase.in`, `employee.bugbase.in`, `kpi.bugbase.in`, `copilot*.bugbase.in`). The programs page itself calls `kpi.bugbase.in` for analytics; that host was not probed.

Method: same as VaultCord — read the public Next.js bundles and look for a query/profile value that reaches `location` or HTML without a scheme/origin check. Then confirm reflection in the HTML flight data.

## Result

No Level-3 bug confirmed. The VaultCord-style sink is not present in the same form.

## Checked

1. **Post-login `redirect`** (`app/login/page-9839ea69ca8c101d.js`). After a successful login the client does `new URL(decodeURIComponent(redirect), origin)` and only then `location.href = url.toString()` if `url.origin === location.origin`. External hosts and `javascript:` fail that check. Navigation uses the normalized URL, not the raw string.

2. **`copilotLogin=true`**. Navigates to the path-absolute URL `/login/copilot/${token}?copilotState=...`, which stays on `bugbase.ai`.

3. **`employeeToken` query**. A `useEffect` auto-POSTs the query value to `/api/auth/employee-login`. This is a magic-link login. No valid token was tested and tokens were not guessed.

4. **HTML breakout**. `leaderboard?search=`, `programs/bugbase?q=`, and `/profile/<payload>` put the value in the Next.js flight data as percent-encoding plus `\u003c` escapes. `</script>` does not land raw in the HTML.

5. **Profile social URL and program website**. Both use `string.includes("https://")` (or `http://`) and otherwise prefix `https://`, then set `<a href>`. A value such as `javascript:...//https://x` would pass the `includes` check. The production React bundle rewrites `javascript:` URLs on `href`. No stored payload was executed, so this is not a confirmed XSS. Social links set `rel="noopener noreferrer"`. Tabnabbing is explicitly out of scope.

6. **Markdown**. Program policy and feed/chat messages use `react-markdown` with remark plugins and a code highlighter component. No `rehype-raw` and no custom `urlTransform` on those calls, so raw HTML is skipped and `javascript:` links are filtered by the default transform.

7. **`/_next/image?url=https://example.com`**. Response: `"url" parameter is not allowed`.

## Web attack-pattern pass (same day)

Patterns from `Tools/WebAPI-AttackPatterns.md`. Still no Level-3 bug. Requests were unauthenticated GETs plus a few empty or dummy-token POSTs. No account was created, no report was filed, no API key was requested, and no other user's report body was read.

### AP-W01 / access control

Unauthenticated calls returned 401 `Unauthorized` for: user settings, KYC, dashboard, payments, company API key, SAML config, company domains, hacktivity report list, unlisted reports, private program stats, program reports, program profile, report search, competition list. Public stats and the public program directory returned 200. The directory (241 programs) had `isPrivate` count 0. External programs are listed on purpose (`isExternal: true`).

`POST /api/hacktivity/get-report` with a zero id and with `{"bid":{"$gt":""}}` both stopped at `403 Invalid CSRF token`, so the object-id lookup was not reached.

### AP-W03

`search_term[$ne]`, a quote, and a normal miss on the public asset list all returned the same `total_items: 5`. `username[$ne]` on profile hacktivity returned `400 ERROR_INVALID_DATA`. No SQL or NoSQL error text.

### AP-W05

External programs pass `programLink` into `window.open(programLink)` (`program-page.js`) and `router.push(programLink)` (`5080-bf1b678e1186cb13.js`) with no scheme allowlist. A public example (`/programs/upside`) stores an `https` URL. `javascript:` was not present. This is not a confirmed XSS. An external `https` link is the feature. Open redirects and tabnabbing are reward exclusions.

### AP-W06

`x-csrf-token` is `Secure; SameSite=Strict` and is readable by script (no `HttpOnly`), which matches the axios double-submit cookie. `Access-Control-Allow-Credentials: true` is set, and `Access-Control-Allow-Origin` was absent for `Origin: https://example.com`. Preflight did not reflect that origin.

`magic-link`, `sign-in/saml/success`, and `verify-login-otp` reached the handler without a CSRF cookie and rejected the dummy values (`ERROR_TOKEN_NOT_FOUND`, `Invalid Request`). Other POSTs returned `Invalid CSRF token`. The session cookie's flags were not read.

### Not confirmed

Cache-deception suffixes (`/api/user/settings/data.css`) returned 404 with `cf-cache-status: BYPASS`.

## Not tested (needs a decision)

- Opening `/dashboard/reports/15421980` (the logged-in hunter's own VaultCord thread) to watch how admin messages are rendered.
- IDOR on `POST /api/hacktivity/get-report` `{bid}`. Report numbers look sequential. Reading another person's report would touch their private data, so this needs a second account the hunter owns.
- State-changing GETs: `/api/user/acceptinvitation/:pid`, `acceptcompanyinvitation`, `acceptprivateinvitation`. CSRF depends on the session cookie's SameSite, which was not read.
- Unauthenticated calls to `/api/company/get-api-key`, `/api/company/get-all-csv-data`, and `/api/user/get-all-users` were not sent.
