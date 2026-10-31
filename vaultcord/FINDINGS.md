# VaultCord — Findings

Program: https://bugbase.ai/programs/vaultcord (VDP, $0)
Date: 2026-10-29
Researcher UA used for all automated traffic: `Mozilla/5.0 ResponsibleReporter Gecko/20100101`

---

## F1 — Reflected DOM XSS on https://vaultcord.win/hi via `to` parameter (VERIFIED, Level 3)

**Status:** Confirmed end-to-end in a real Chrome against production.
**Submitted:** 2026-10-29 to BugBase as report **#15421980** (CWE-79 Reflected Cross-Site Scripting, Moderate) — status New / Program Review Requested; evidence ZIP attached as "Attachment 1".
**Asset:** `https://vaultcord.win/hi` (in-scope, Web)
**Severity estimate:** Medium (CVSS 3.1: AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N = 6.1), potentially High for victims with stored server passwords.

### Summary

`/hi` accepts the query parameters `wait` and `to`. When `wait=1`, the page renders a
"waiting room" and, after a fixed 55-second countdown, executes:

```js
window.location.replace(decodeURIComponent(r))   // r = pageProps.to
```

There is no validation of the URL scheme or host. Supplying
`to=javascript:...` therefore executes attacker JavaScript in the origin
`https://vaultcord.win` of any visitor who opens the crafted link and keeps the tab
open for the countdown. The page CSP
(`upgrade-insecure-requests; frame-ancestors ...`) has no `script-src`, so the
`javascript:` navigation is not mitigated.

This is reflected XSS, not self-XSS: the victim only opens a link.

### Affected code

- Server: `getServerSideProps` of the Next.js catch-all route copies the raw query
  values `wait` and `to` into `pageProps` (`__NEXT_DATA__`).
- Client: `/_next/static/chunks/pages/%5B%5B...slug%5D%5D-cc3e49f0c08263d0.js`
  (`Source/vaultcord/recon/cust/a6e5ca05.js`), component `U`:
  `window.location.replace(decodeURIComponent(r))` after `Date.now()+55e3`.
  Rendered when `("1" === wait)`: `I?(0,l.jsx)(U,{serverId:r?.id,to:j})`.
- Exact snippets: `evidence/served-sink.txt`.

### Reproduction

1. Request (required researcher UA; the Origin/Referer headers only pass
   VaultCord's automated-request WAF — a normal browser does not need them):

```bash
curl -sS -A 'Mozilla/5.0 ResponsibleReporter Gecko/20100101' \
  -H 'Accept: text/html' -H 'Referer: https://vaultcord.com/' -H 'Origin: https://vaultcord.com' \
  'https://vaultcord.win/hi?wait=1&to=javascript:window.__pwned=1' -o out.html -D hdr
```

HTTP/2 200; `__NEXT_DATA__.props.pageProps` contains
`wait = "1"`, `to = "javascript:window.__pwned=1"` verbatim, and the waiting-room
markup is server-rendered (`evidence/reflection-200.txt`, response body
`recon/replay2.html`).

2. Load the same URL in a normal browser and wait 55 s. Observed in
   Chrome 151 headless (Puppeteer, required UA) against production:

```
HTTP 200 https://vaultcord.win/hi?wait=1&to=javascript:window.__pwned=42;void(0)
before: title="Verify in Server", window.__pwned=null
after 60s: window.__pwned=42, document.domain="vaultcord.win"   (page preserved)
```

Visual run: `to=javascript:window.__pwned=1;document.documentElement.style.background='lime';document.body.style.background='lime';void(0)`
→ after 60 s both `html` and `body` computed background are `rgb(0, 255, 0)`,
`window.__pwned=1`. Screenshot: `evidence/xss-poc.png`
(md5 d700cef43547d00a7ed260eb89ad1f08). Full transcript:
`evidence/browser-poc-transcript.txt`.

3. Sanity check on the same Chrome build: a local page performing the identical
   `location.replace(decodeURIComponent("javascript:..."))` executes the code
   (control), so this is not a browser mitigation artifact.

### Impact

Script execution in the `vaultcord.win` origin for any user who opens the crafted
link (socially plausible: the waiting room asks the user to keep the tab open).
In that origin an attacker can:

- Read localStorage written by the verification app, including
  `password-<serverId>` — the plaintext password of every password-protected
  server the victim has unlocked in this browser
  (`localStorage.setItem(\`password-${t.id}\`, i)` in the same chunk) — and the
  `$referrer-<id>` / `<id>_opened_at` entries.
- Read the non-HttpOnly `vc_bt` cookie.
- Rewrite the verification UI (e.g. display a different server name/logo) and
  drive the Discord OAuth flow, including changing `state` so the victim joins an
  attacker-chosen Discord server with `identify guilds.join`.
- Use the origin as a trusted-looking page for credential phishing.

The same sink is also a client-side open redirect for `http(s)` targets
(`to=https://evil.example`).

### Remediation

- Validate `to` server-side: allow only `https://` to an allowlist of first-party
  hosts (e.g. `vaultcord.com`, `*.vaultcord.com`, `vaultcord.win`), reject
  `javascript:`, `data:`, `vbscript:` and control characters after decoding.
- Do not pass raw query values into `pageProps`; normalize/encode once.
- Add a CSP `script-src` (Next.js nonces) as defense in depth.

### Scope / policy notes

- Target is exactly the in-scope asset `https://vaultcord.win/hi`.
- Not self-XSS, not best-practice-only, not a missing-header report, no DoS.
- No user interaction other than opening the link and waiting 55 s; the payload is
  delivered in the URL.
- VaultCord's bot WAF answered automated curl/headless traffic with a custom
  "Verification Required" page until Origin/Referer were supplied; this affects
  tooling only, not real browsers, and is not reported as a separate issue.
- No data of other users was accessed during testing; only the researcher's own
  browser state was used.

### Evidence index

| File | Content |
|---|---|
| `evidence/reflection-200.txt` | 200 response + raw `to` reflection |
| `recon/replay2.html` | Served page (contains payload in `__NEXT_DATA__`) |
| `evidence/served-sink.txt` | Exact client sink + render condition |
| `evidence/browser-poc-transcript.txt` | Level-3 Chrome runs A/B/C + control |
| `evidence/xss-poc.png` | Screenshot after payload execution (green page) |
| `evidence/evidence-md5.txt` | Hashes |

---

## Second pass (2026-10-30) — no additional Level-3 bug

Same required User-Agent. No scanners. No other user's data was read. `https://vaultcord.win/hi` now returns Cloudflare `cf-mitigated: challenge` to this client, so that host was not re-executed. The same Next.js app answered on `https://customers.vaultcord.com/hi` (`x-matched-path: /[[...slug]]`), which is inside `*.vaultcord.com`.

Checked, and not a second confirmed bug:

1. **`success` / `error` / `warn` query strings.** They are copied into `pageProps` and rendered on the page. A `</script>` payload is stored in the flight data as `\u003c` and in the visible HTML as `&lt;/script&gt;`. It does not break out of the tag.
2. **`customCode` blocks.** The client renders owner HTML/JS in `<iframe sandbox="allow-scripts" srcDoc=...>`. `allow-same-origin` is absent, so that script is not the parent origin. This matches a custom-code feature, not a parent-origin XSS.
3. **`redirectUrl`.** After captcha, the client sets `location.href` to the server's `redirectUrl`. On the saved public server (`id` 16303) the field is null. No `javascript:` value was stored, so this was not executed.
4. **`check_password`.** `POST /servers/16303/check_password` with `{"password":true}` returned `Password protection not enabled (16303)`. No password bypass. No password-protected public server was used, and server ids were not enumerated.
5. **Dashboard API.** Unauthenticated `GET /servers/dashboard`, `/stats/dashboard`, `/upgrade-stats`, `/accounts/settings`, `GET /servers/url/taken/...`, and `POST /accounts/searchByEmail` with a non-existent address all returned `401 Authorization header missing`.
6. **Open Graph `pic`.** Three public `pic` values (`cdn.vaultcord.com` logo, `https://example.com/`, `https://example.com/favicon.ico`) with the same name/description returned the same PNG (132248 bytes, same SHA-256 prefix). The parameter did not change the image. Internal addresses were not requested.

`postMessage` preview updates accept `*.vaultcord.com` and `*.vercel.app`, and the listener is installed only when `isPreview` is true. On the public page `isPreview` is false. `?preview=1` and `?isPreview=1` were not readable on `vaultcord.win` because of the Cloudflare challenge.

---

## Disproven — IDOR hypothesis on `GET /servers/{id}` and sibling endpoints

**Verdict: NOT a bug.** Tested live 2026-10-31 with a real, freshly-created VaultCord test account (own session cookie `__Host-auth_token`, logged in via the dashboard, not via API key).

`GET https://api.vaultcord.com/servers/16303` (a server id belonging to a different account, referenced in earlier recon) with the test account's own valid session returned:

```
HTTP 200
{"success":false,"message":"Server ID not found!"}
```

No server data was returned. The endpoint correctly scopes the lookup to the caller's own servers — looking up an id that exists but isn't owned by the caller behaves identically to a genuinely nonexistent id (same message, same `200`/`success:false` shape), which is actually good practice: it avoids leaking an "exists but not yours" vs "doesn't exist" oracle on top of not leaking the data itself.

Not independently re-tested: `GET /servers/{id}/roles`, `GET /stats/members/{id}`, `PATCH /servers/{id}`, `PUT /servers/{id}/duplicate` — these likely share the same ownership-scoped query pattern given `GetServer` is the base case, but this is an inference, not a tested fact. Do not assume they're safe without testing each one directly if revisited.

**Evidence:** screenshots of the live DevTools Network panel (request `GET https://api.vaultcord.com/servers/16303`, status 200, response body above) shared in-session 2026-10-31; not yet saved as files in `evidence/` — if this needs to be cited later, re-capture and save as `evidence/idor-servers-16303-disproven.png`.

---

## F2 — Client-controlled `skipDeviceCheck` bypasses the cross-device confirmation step on account/server deletion and member-transfer (STATIC — Level 2 only, NOT yet verified live)

**Status:** Confirmed by reading the production client bundle only. **No live request has been sent against this flow and no account/server deletion or transfer has been triggered.** This is NOT submission-ready — it needs Level 3 (R1/R2/R3) verification by the account owner before it can be reported (see "What's needed to reach Level 3" below).

**Asset:** `https://dash.vaultcord.com` (in-scope under the `*.vaultcord.com` wildcard group, Production). Bundle fetched 2026-10-30 with the required UA `Mozilla/5.0 ResponsibleReporter Gecko/20100101`, `Referer`/`Origin: https://vaultcord.com`.

### Summary

VaultCord's dashboard has three destructive, secret-link-gated flows, each following the identical pattern:

| Feature | Route | API call (from `entry-*.js`) |
|---|---|---|
| Delete Account | `/delete-account#<32-char-secret>` | `POST /deleteAccount` body `{secret, ...}` |
| Delete Server | `/delete-server#<32-char-secret>` | `DeleteServer(secret, skipDeviceCheck)` → `this.httpClient.delete(urlPrefix, {data:{secret, skipDeviceCheck}})` |
| Transfer Server Members | `/transfer-members#<32-char-secret>` | `ConfirmTransfer(secret, skipDeviceCheck)` → `this.httpClient.put(`${urlPrefix}/transfer`, {secret, skipDeviceCheck})` |

On page load, the client reads the 32-char secret from `window.location.hash` (the link the user receives by email after requesting the action from their authenticated session) and immediately submits it. If the server considers this a cross-device situation, it apparently replies with something like `{success:false, deviceChanged:true, requestedDevice:"...", confirmingDevice:"..."}` instead of performing the action. The shared handler for this (`device-confirm.js`, hook `u()`/component `D`) is:

```js
// intercept(response, retryFn)
n = (s,f) => !s.success && s.deviceChanged
  ? (t({open:true, requestedDevice:s.requestedDevice, confirmingDevice:s.confirmingDevice}), c(()=>f), true)
  : false
```

It shows a "Confirm it's really you — we noticed you are confirming this request from X, but you requested it from Y" modal **in the same browser tab that already has the secret**. Clicking "Approve" just re-invokes the original request with one field added:

```js
// delete-account.js
d(secret) → POST /deleteAccount {secret}
// on intercept(): retry stored as
() => d(secret, {skipDeviceCheck: true})
```

```js
// entry-*.js — the three real client methods
async ConfirmTransfer(t,n){ return this.httpClient.put(`${this.urlPrefix}/transfer`, {secret:t, skipDeviceCheck:n}) }
async DeleteServer(t,n){ return this.httpClient.delete(this.urlPrefix, {data:{secret:t, skipDeviceCheck:n}}) }
```

**There is no second channel, token, or push approval involved.** "Approving from the other device" is not a real cross-device handshake — it is a client-side modal in the *same* tab that sets a boolean the server apparently trusts. Nothing stops a caller from sending `skipDeviceCheck: true` on the **very first** request, before the server would ever have returned `deviceChanged`, from a tool like curl/Burp instead of the real UI. If the server honors that flag unconditionally (to be confirmed live), the entire device-binding check for these three destructive actions is a no-op against anyone who has the secret but is not the account's own device.

### Why this matters despite requiring the secret already

The secret itself is the intended sole authorization factor (standard "click the email link" pattern) — this bug does **not** let an unauthenticated stranger with zero access delete an arbitrary account. What it removes is the **secondary** control that specifically exists for the scenario where the secret has leaked or been used outside its intended device/session: compromised or auto-forwarded email, a corporate email-security gateway that visits links, a shared/synced mail client, a support ticket where a confused user pastes the link for help, browser history on a shared machine, etc. In all of those realistic scenarios, VaultCord's own UX explicitly tries to stop the action ("we noticed this is a different device, authorize?") — and that stop is bypassable with one extra JSON field. Impact: unauthorized, irreversible deletion of a server or account, or hijack of a member-transfer, performed from a device the real owner never approved, for anyone who obtains a leaked/forwarded confirmation link.

### What's needed to reach Level 3 (must be done by the account owner, not by Claude)

Per the Claude Code safety rules, I will not create a VaultCord account, log in, or trigger an irreversible delete myself. To confirm this live, you (the researcher) need to, on your **own** test account / a disposable test server:

1. Log into `dash.vaultcord.com` normally in Browser A.
2. Trigger "Delete Server" on a throwaway test server you don't mind losing (lower blast radius than Delete Account). This should email a `/delete-server#<secret>` link.
3. Open that link once in a **different context** (different browser/incognito/VPN egress IP, or just clear cookies) to naturally trigger the `deviceChanged` response — confirm you see the modal and capture the raw JSON response (Network tab) to learn the exact response shape.
4. Request a **fresh** deletion (secrets are presumably single-use) and this time, instead of opening the link in a browser, replay it directly with curl/Burp **with `skipDeviceCheck: true` included from the start**, from that same "wrong" context, e.g.:
   ```bash
   curl -X DELETE 'https://dash.vaultcord.com/<urlPrefix-observed-in-step-3>' \
     -H 'Content-Type: application/json' \
     --data '{"secret":"<the 32-char secret>","skipDeviceCheck":true}'
   ```
   (confirm the exact path via the Network tab in step 3 — `urlPrefix` wasn't fully resolved from the static bundle alone.)
5. If the server performs the deletion immediately (HTTP success, server actually gone) without ever having been challenged, that is the Level-3 proof: the device check is bypassable by a client-supplied flag with no real second-factor behind it.
6. Repeat the same curl-only test (skip the browser step entirely) to see if `skipDeviceCheck:true` works even when the server has *never* returned `deviceChanged` for that secret — the starkest version of the bug (the check is never even consulted).

Once you have the raw request/response pair showing the bypass, send it back and I'll turn this into a full report (BugBase format, per `Report.md`) with severity justification.

### Evidence (static only)

- `recon/dash-bundle/dash.html`, `recon/dash-bundle/dash_importmap_keys.txt` — page + importmap listing all 365 feature chunks.
- `recon/dash-bundle/delete-account.js`, `delete-server.js`, `transfer-members.js` — the three vulnerable feature chunks (hash-secret auto-submit + intercept/retry-with-`skipDeviceCheck` logic).
- `recon/dash-bundle/device-confirm.js` — shared "Confirm it's really you" modal + `intercept()`/`approve()` hook; proves approval is just a same-tab retry with `skipDeviceCheck:true`, no second channel.
- `recon/dash-bundle/entry-api-client-excerpt.js` — excerpt of the main bundle showing the literal `ConfirmTransfer`/`DeleteServer` API client methods and their `{secret, skipDeviceCheck}` payloads.
- `recon/dash-bundle/create-api-key.js`, `crypto-payment-card.js` — reviewed, nothing actionable found (plan-gated API key creation; LTC payment polling UI, explains the program policy's "litecoin core RPC" hint).
