# VaultCord — Findings

Program: https://bugbase.ai/programs/vaultcord (VDP, $0)
Date: 2026-10-29
Researcher UA used for all automated traffic: `Mozilla/5.0 ResponsibleReporter Gecko/20100101`

---

## F1 — Reflected DOM XSS on https://vaultcord.win/hi via `to` parameter (VERIFIED, Level 3)

**Status:** Confirmed end-to-end in a real Chrome against production.
**Submitted:** 2026-10-29 to BugBase as report **#15421980** (CWE-79 Reflected Cross-Site Scripting, Moderate) — status New / Program Review Requested; evidence ZIP attached as "Attachment 1".
**Current status (2026-10-31):** BugBase shows **Resolved / Pending Close** — the sink is fixed in production (see "Third pass" below). Do not resubmit.
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

## F3 — Unauthenticated path traversal in `api.vaultcord.com/market/invites` (VERIFIED, fixed during testing; SUBMITTED #17727911)

**Submitted:** 2026-10-31 to BugBase as report **#17727911** — CWE-22 Path Traversal, Medium, status New / Program Review Requested. Draft: `Result(only BugReport)/vaultcord-01-invites-path-traversal.md`. Evidence: `evidence/vaultcord-invite-traversal-evidence.zip`.

`GET /market/invites/{code}` concatenated `{code}` into `https://discord.com/api/v10/invites/{code}` with VaultCord's Discord bot token. `..%2F` escaped the prefix, giving unauthenticated callers arbitrary Discord API v10 GET requests as the "Vault Dashboard" bot (reproduced 2026-10-30: bot account, private application object incl. redirect URIs/verify key/owner identity, gateway session limits). Read-only, host pinned to discord.com, no customer data (bot in 0 guilds).

**Fixed during testing.** Re-verified 2026-10-31: `..%2F`, `%2e%2e%2f`, `..%252F`, `..%5C`, `....%2F%2F`, nested variants → `400 {"success":false,"message":"Invalid invite code"}`; legit code `python` still 200. Residual action requested: rotate the bot token (it was usable by unauthenticated parties during the exposure window). Original raw capture files were not retained; the archive contains the 2026-10-31 raw captures plus a clearly-labelled transcription of the 2026-10-30 outputs.

---



Same required User-Agent. No scanners. No other user's data was read. `https://vaultcord.win/hi` now returns Cloudflare `cf-mitigated: challenge` to this client, so that host was not re-executed. The same Next.js app answered on `https://customers.vaultcord.com/hi` (`x-matched-path: /[[...slug]]`), which is inside `*.vaultcord.com`.

Checked, and not a second confirmed bug:

1. **`success` / `error` / `warn` query strings.** They are copied into `pageProps` and rendered on the page. A `</script>` payload is stored in the flight data as `\u003c` and in the visible HTML as `&lt;/script&gt;`. It does not break out of the tag.
2. **`customCode` blocks.** The client renders owner HTML/JS in `<iframe sandbox="allow-scripts" srcDoc=...>`. `allow-same-origin` is absent, so that script is not the parent origin. This matches a custom-code feature, not a parent-origin XSS.
3. **`redirectUrl`.** After captcha, the client sets `location.href` to the server's `redirectUrl`. On the saved public server (`id` 16303) the field is null. No `javascript:` value was stored, so this was not executed.
4. **`check_password`.** `POST /servers/16303/check_password` with `{"password":true}` returned `Password protection not enabled (16303)`. No password bypass. No password-protected public server was used, and server ids were not enumerated.
5. **Dashboard API.** Unauthenticated `GET /servers/dashboard`, `/stats/dashboard`, `/upgrade-stats`, `/accounts/settings`, `GET /servers/url/taken/...`, and `POST /accounts/searchByEmail` with a non-existent address all returned `401 Authorization header missing`.
6. **Open Graph `pic`.** Three public `pic` values (`cdn.vaultcord.com` logo, `https://example.com/`, `https://example.com/favicon.ico`) with the same name/description returned the same PNG (132248 bytes, same SHA-256 prefix). The parameter did not change the image. Internal addresses were not requested.

   **Re-confirmed, much more rigorously, 2026-11-02** (triggered by an externally-authored draft report claiming
   SSRF here — `/home/user/Documents/vaultcord/vaultcord/REPORT-SSRF-OPENGRAPH.md`, not part of this project,
   provenance unknown — that claimed a ~4s `httpbin.org/delay/4` timing oracle and differing SHA-256/size per
   `pic` value on `customers.vaultcord.com/api/opengraph`). Independently re-tested on `customers.vaultcord.com`
   with **cache-busting unique `name`/`description` on every request** and **`x-vercel-cache: MISS` confirmed
   on every single probe** (so this is not a stale-cache artifact):

   | probe | pic value | time | size | sha256 vs its own baseline |
   |---|---|---|---|---|
   | fresh-baseline | empty | 2.62s | 103893 | — |
   | fresh-delay | `httpbin.org/delay/8` | 3.35s (not ~8s) | 103893 | **identical** |
   | other1 | `avatars.githubusercontent.com/u/1` | 2.79s | 102007 | **identical** to other2 |
   | other2 | empty | 2.59s | 102007 | baseline for other1 |
   | internal(127.0.0.1) | `http://127.0.0.1/` | 2.89s | 102435 | same size as the IMDS probe |
   | internal(169.254.169.254) | IMDS | 2.55s | 102435 | same size as the 127.0.0.1 probe |

   No timing delta beyond normal network jitter (an 8-second upstream delay would be unmissable; observed
   delta was ~0.7s), and no content difference between *any* two `pic` values in any pair tested, with cache
   MISS confirmed throughout. **Conclusion: `pic` does not cause a server-side fetch at all on the current
   production deployment — there is no SSRF here, full stop.** The external draft report's specific numbers
   (claimed ~4s delay, claimed differing SHA-256/sizes per `pic`) could not be reproduced under materially
   more careful conditions (cache-busted, cache-MISS-confirmed) and should be treated as unreliable — do not
   file that report as-is. This does not rule out the parameter having *once* worked differently, but as of
   2026-11-02 it is inert.

`postMessage` preview updates accept `*.vaultcord.com` and `*.vercel.app`, and the listener is installed only when `isPreview` is true. On the public page `isPreview` is false. `?preview=1` and `?isPreview=1` were not readable on `vaultcord.win` because of the Cloudflare challenge.

---

## Third pass (2026-10-31) — fixes re-verified; new leads all below reporting bar

Same required UA `Mozilla/5.0 ResponsibleReporter Gecko/20100101`; no scanners, no state changes, no other user's data read. Current production assets: verification app is Next.js **14.2.33** / React **18.3.1** (so CVE-2025-29927 middleware bypass is not applicable); page chunk `pages/[[...slug]]-23b3af5025c6235e.js` is the live build (`buildId sLd7RGlaNHGjJ3ch0VgCb`).

### Fix re-verification (both prior findings are now fixed — do not resubmit)

1. **F1 `to` sink is fixed.** `getServerSideProps` now allowlists the destination host (`vaultcord.win`) and relative paths. Probes of `to=javascript:...`, `to=//evil.example`, `to=https://evil.example/...`, and double-encoded variants all come back as `to:null` in `pageProps`. The client no longer calls `decodeURIComponent`; the waiting room now does `window.location.replace(r)` only when `r` is present (`l>0||(window.clearInterval(e),!n.current&&(n.current=!0,r&&window.location.replace(r)))`). No script execution remains. **#15421980 should not be resubmitted; if the triager asks, this is the fix evidence.**
2. **Invite path traversal is fixed.** Alternate encodings (`..%2F`, `%2e%2e%2f`, `%5C`, overlong `%c0%ae`, `....%2F%2F`) against the invite endpoint all return `400 "Invalid invite code"`. Original `..%2F` also rejected.

### New observations — checked to Level 2/3, all NOT reportable

| # | Observation | Why it is not reported |
|---|---|---|
| P1 | `?previewToken=<anything>` (token unvalidated) sets `isPreview:true`; the page then installs a `message` listener with **no `event.source` check** and accepts `vaultcord:preview-update` from origins whose hostname is `localhost`, `dash.vaultcord.com`, `*.vaultcord.com`, `*.vercel.app`; the injected layout is zod-parsed and rendered (bio text, customCode iframe with whatever sandbox the layout supplies). | Level 3 not reached. On `vaultcord.win/hi` Cloudflare serves an interactive challenge to this client (`cf-mitigated: challenge`, 403) and bypassing it is out of bounds. On `customers.vaultcord.com/?previewToken=x` the real-browser PoC (Puppeteer, local attacker page + `window.open` + `postMessage`) rendered "Server not found" with no iframe and no injected text, because that URL has no server/vanity slug context. Content-spoofing only (no origin XSS: customCode iframe keeps `allow-scripts` without `allow-same-origin` in the server-sent layout). Needs a resolvable in-scope page that honors preview and is not CF-challenged before it could be considered. |
| P2 | `/auth?error_description=` is reflected into `/hi?error=` (`vaultcord.win/hi?error=...`), and `success`/`error`/`warn` land in `pageProps`. | Text-only: rendered through the markdown renderer with the `["http:","https:","mailto:"]` protocol allowlist and proper URL/handling encoding. `<` is emitted as `\u003c` / `&lt;`. No tag breakout, no script. Best-practice/encoding observation only. |
| P3 | `/donate` copies `access`, `userid`, `email`, `url`, `tier`, `invoiceid`, `orderId`, etc. into `pageProps` and writes `discord_access`/`discord_user`/`discord_email` to localStorage. | Deprecated page: it states "Donation payments are shut down… Fanbasis.com decided to terminate our contract". Values are `atob`-decoded/postMessaged only as a redirect string; no injection into HTML or script. No impact on current functionality. |
| P4 | Unauthenticated `POST /api/realtime/auth?cluster=us` signs arbitrary `private-cache-verify-<reference>` channels with the public Pusher/Abinator key. | Channel `reference` is a 32-hex private value that exists only while a verification is `inProgress`, and the payload is progress status only. No way to enumerate/derive references, so no cross-user data exposure. Not a bug on its own. |

Also ruled out this pass: owner-controlled `links`/`socialLinks` `javascript:` URLs (rendered `target="_blank"`, and Chrome blocks `javascript:` navigation for `_blank` — verified locally); `theme.cursor` CSS injection (value applied via CSSOM, not markup); avatar `verifyHref` (app-computed, not owner-controlled); `componentEmbed` URL buttons (rendered as escaped JSON via `dangerouslySetInnerHTML` with `<`→`\u003c`, no raw href sink); `_next/image` SSRF (400 `INVALID_IMAGE_OPTIMIZE_REQUEST`); dashboard `dangerouslySetInnerHTML` (static Radix style only); `dash.vaultcord.com` admin chunk (Cloudflare Access / Zero Trust, `nelsec.cloudflareaccess.com`).

**Net result: no new Level-3-confirmed, reportable bug this pass.** Both earlier findings are confirmed fixed in production.

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

## F2 — Client-controlled `skipDeviceCheck` on the cross-device confirmation of deletion/member-transfer (ANALYSED 2026-10-31 — verdict: NOT a reportable bug)

**Status:** Static analysis of the production bundle, plus live unauthenticated probing of the API. **No destructive action was performed and none is needed.** Conclusion: the device check is advisory by design and sits *behind* the normal session, so there is no privilege boundary to cross — see "Verdict" below. Superseded: this is not submission-ready and should not be filed.

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

### Resolved statically + live probes (2026-10-31)

The earlier draft was missing two facts that change the conclusion. Both were resolved from the same production bundle (`recon/dash-entry.js`) and confirmed with live requests:

**1. The API client is `https://api.vaultcord.com`, not the dashboard origin.**

```js
class Hr { constructor(t){
  this.baseURL = "https://api.vaultcord.com";            // Be(this,"baseURL","https://api.vaultcord.com")
  ...
  this.client = Ye.create({ baseURL: this.baseURL, ... })
}}
class Lz { constructor(){ this.urlPrefix = "/servers"; this.httpClient = new Hr({includeAuthorization:!0}) ... } }
```

So the three calls are:

| Flow | Real request |
|---|---|
| Delete server | `DELETE https://api.vaultcord.com/servers` — body `{secret, skipDeviceCheck}` |
| Confirm transfer | `PUT https://api.vaultcord.com/servers/transfer` — body `{secret, skipDeviceCheck}` |
| Request deletion (auth'd UI) | `PUT https://api.vaultcord.com/servers/{id}/delete` — sends the mail |

The client is created with `includeAuthorization: true`, and the request interceptor calls `Object.assign(i, Ba())` plus `withCredentials = true` for this origin, i.e. the destructive calls carry the normal session. Live, unauthenticated confirmation:

```
GET  https://api.vaultcord.com/servers        → 401 {"success":false,"message":"Authorization header missing"}
GET  https://api.vaultcord.com/servers/16303  → 401 {"success":false,"message":"Authorization header missing"}
```

**2. "Device" is a client-computed fingerprint sent in the `ETag` request header.**

```js
// request interceptor
const s = await this.getFingerprint(); i.ETag = s;

// fingerprint = sha256(ua|screen|colourDepth|tzOffset|language|platform|cores|maxTouchPoints|canvas|webgl)[0:32]
async function zg(){ const n=[navigator.userAgent||"unknown-ua", `${screen.width}x${screen.height}`, ...]; return await ib(n,32) }
```

So the value the server compares and echoes back as `requestedDevice` / `confirmingDevice` is entirely client-supplied, and the "Approve" path is the same request with one more client-supplied boolean. Neither half of the control is server-anchored.

### Verdict — not a reportable vulnerability

1. **No privilege boundary is crossed.** Every one of these calls goes to `api.vaultcord.com` and needs the ordinary session (401 without it, as shown above). Anyone who has a usable session on the victim's account can already delete servers from the dashboard directly — no secret, no link, no device check. The 32-char secret is a *confirmation* on top of an authenticated session, not an alternative credential for a stranger.
2. **The secret is never exposed to link scanners.** It lives in the URL **fragment** (`/delete-server#<secret>`), which is never sent to the server, never in `Referer`, and never fetched by email-security URL scanners. The "auto-forwarded email / Safe Links visits the URL" scenario therefore does not reach the endpoint at all.
3. **The device check is advisory by design.** Both the device identity (`ETag` fingerprint) and the approval (`skipDeviceCheck: true`) are client-controlled, so a caller can always satisfy or skip them. That is weak design, but it does not grant anything the caller could not already do with the session it must present.

The only way this becomes a real bug is if `DELETE /servers` (with `{secret}`) accepted the secret **without** a session, i.e. if the secret alone were a bearer credential. The 401s above are for `GET`; per-method auth on the write routes could not be tested here because the automated destructive-verb probe was blocked by the sandbox classifier. If it is ever re-opened, the determining test is non-destructive — a *random* secret must be used, so nothing can be deleted:

```bash
curl -sS -i -X DELETE 'https://api.vaultcord.com/servers' \
  -A 'Mozilla/5.0 ResponsibleReporter Gecko/20100101' \
  -H 'Content-Type: application/json' -H 'Origin: https://dash.vaultcord.com' -H 'Referer: https://dash.vaultcord.com/' \
  --data '{"secret":"11111111111111111111111111111111"}'
```

- `401 {"message":"Authorization header missing"}` → secret is not a credential; F2 stays closed.
- `200` / `{"success":false,"message":"Invalid secret"}` → the endpoint is secret-gated and unauthenticated; F2 must be re-assessed as a genuine (low-severity) bypass of the secondary control, and only then does a Level-3 run make sense.

**No server was deleted.** Ownership of `16303` was never confirmed (the dashboard redirected to `/login` and no session existed), and the user's "削除してよい" was therefore never acted on.

### Evidence

- `recon/dash-entry.js` — full entry bundle; `class Lz` (`urlPrefix="/servers"`), `class Hr` (`baseURL="https://api.vaultcord.com"`, `i.ETag = await this.getFingerprint()`), and `zg()`/`ib()` (the fingerprint hash). Grep anchors used: `class Lz{constructor(){Be(this,"httpClient")`, `Be(this,"baseURL","https://api.vaultcord.com")`, `i.ETag=s`.
- Live 2026-10-31 (unauthenticated, read-only): `GET https://api.vaultcord.com/servers` → `401 Authorization header missing`; `GET .../servers/16303` → same. `GET .../members/pub-client` → 401; `GET .../api/authorized` → 403 WAF "Verification Required"; `GET .../api/observe/browser` → 404.
- `recon/dash-bundle/dash.html`, `recon/dash-bundle/dash_importmap_keys.txt` — page + importmap listing all 365 feature chunks.
- `recon/dash-bundle/delete-account.js`, `delete-server.js`, `transfer-members.js` — the three vulnerable feature chunks (hash-secret auto-submit + intercept/retry-with-`skipDeviceCheck` logic).
- `recon/dash-bundle/device-confirm.js` — shared "Confirm it's really you" modal + `intercept()`/`approve()` hook; proves approval is just a same-tab retry with `skipDeviceCheck:true`, no second channel.
- `recon/dash-bundle/entry-api-client-excerpt.js` — excerpt of the main bundle showing the literal `ConfirmTransfer`/`DeleteServer` API client methods and their `{secret, skipDeviceCheck}` payloads.
- `recon/dash-bundle/create-api-key.js`, `crypto-payment-card.js` — reviewed, nothing actionable found (plan-gated API key creation; LTC payment polling UI, explains the program policy's "litecoin core RPC" hint).

---

## F4 — Plus-subscription gate on API-key creation is client-side only (CANDIDATE — server-side check unconfirmed)

**Status:** Client side **proven** in production (UI + bundle). Server side **not yet tested** — the single confirming request is a write (`PUT /sessions`) and was held pending the account owner's approval.

**Asset:** `https://dash.vaultcord.com/developers` + `https://api.vaultcord.com/sessions` (in scope, Production).
**Account used:** the researcher's own free test account, id `279389` (`role: "free"`).

### What is proven

The "Create API Key" dialog decides visibility from the **client-side account role** only (`recon/dash-bundle/create-api-key.js`):

```js
P = ((i?.data)?.role) === "free"                       // i = account data from the API
...
a !== "market-api" && P
  ? <Alert variant="warning">The API (including token joiner) requires Plus subscription to use. Upgrade here …</Alert>
  : <the whole form, including the Create button>
```

Observed live 2026-11-01 on the free account — the dialog renders **only** the warning and no form at all:

```
Generate API Key
Need help? Please read our documentation here
The API (including token joiner) requires Plus subscription to use. Upgrade here to unlock benefits.
Close
```

The real creation call, which the hidden form would have made, is:

```js
await new q({includeAuthorization:!0}).put("/sessions", {items: d})   // d = optional IP-whitelist array
// -> PUT https://api.vaultcord.com/sessions   body {"items":[]}   -> {success, token}
```

So the paywall is enforced by **hiding a button**, not by a server-side entitlement check — *unless* `PUT /sessions` also validates the plan.

### Supporting request mechanics (captured from the live app)

Session auth is a cookie plus a device fingerprint the server echoes as a binding:

```
X-Requested-With: VaultCord_React_SPA
ETag: <32-hex client-computed fingerprint>     # sha256(ua|screen|depth|tz|lang|platform|cores|touch|canvas|webgl)[0:32]
```

Without `X-Requested-With` → `403 Missing X-Requested-With header. Reload the dashboard and try again.`
Without a matching `ETag` → `401 Your device changed. Please log in again.`
`Authorization: Bearer <jwt>` → `200 {"success":false,"message":"This isn't an API key"}` (that header is reserved for API keys).

### Also checked and correctly scoped (no IDOR)

Free account, own session, against server `16303` which belongs to a **different** VaultCord account:

| Request | Result |
|---|---|
| `GET /servers` | `200 {"success":true,"data":[]}` (own list, empty) |
| `GET /servers/deleted` | `200 {"success":true,"data":[]}` |
| `GET /servers/16303` | `200 {"success":false,"message":"Server ID not found!"}` |
| `GET /stats/members/16303` | `200 {"success":false,"message":"A different VaultCord account owns this server."}` |
| `GET /servers/16303/pulls` | `200 {"success":false,"message":"A different VaultCord account owns this server."}` |
| `GET /servers/16303/pull-history` | `200 {"success":false,"message":"Server not found or you don't have access!"}` |
| `GET /servers/16303/roles` | `404 Not Found` |

Ownership scoping is intact; only an existence oracle remains, which is out of scope per policy.

### The one remaining test (write — needs the account owner's go-ahead)

```js
fetch('https://api.vaultcord.com/sessions', {
  method: 'PUT', credentials: 'include',
  headers: {
    'X-Requested-With': 'VaultCord_React_SPA',
    'ETag': '<the account\'s own fingerprint>',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({items: []})
})
```

- Returns `{success:true, token:"…"}` → **confirmed**: a free account can mint an API key the paywall says requires Plus. Report as Broken Function Level Authorization (OWASP A01 / CWE-863), Low–Medium. Note the key must then be revoked by changing the account password (the Developers page states this; there is no per-key revoke route and `GET /sessions` is 404).
- Returns a subscription/permission error → the gate exists server-side and this is **not** a bug; close F4.

**No key was created. No server was deleted.**

---

## F5 — Unvalidated `redirectUrl` navigation in the verification app (STRONGEST REMAINING LEAD — Level 2, needs an owned server)

**Status:** Sink proven in the production client bundle and the config field proven in a real served page. **Not Level 3** — it needs one VaultCord server that the researcher controls in order to store a `javascript:` value.

**Assets:** verification app on `vaultcord.win` / `customers.vaultcord.com` (in scope, `*.vaultcord.com`).

### The sink (`recon/cust/a6e5ca05.js`, offset ~90.9k)

```js
B ? (0,l.jsx)(G, { captchaData: w, onSuccess: () => {
      if (E(!1), r && r.redirectUrl) { window.location.href = r.redirectUrl; return }
      window.location.href = window.location.pathname + "?success=" + encodeURIComponent("Successfully verified! …")
   }})
```

`r` is the **server configuration object** the verification page loads for the server being joined. `redirectUrl` is assigned straight to `location.href` with **no scheme or host validation** — the same class of sink as F1, but reached after the captcha instead of after the 55 s countdown.

### The field is part of the per-server config block

Captured from a served flight payload (`recon/q_58dda3.html`, offset ~10.7k), alongside the other owner-editable verification settings:

```json
"passwordProtected":0, "banner":null, "cursor":null, "description":null,
"guildsJoin":1, "viewEmails":0, … ,
"verifyColor":"#5865F2", "textColor":"#FFF", "backgroundColor":"#0B0C10",
"backgroundMusic":null, "hideBranding":0, "closeVerify":0, "deleteIps":0,
"optOutMarket":0, "customDomain":null,
"redirectDomain":0, "redirectUrl":null,          <-- here
"impersonateRonix":0, "invalidApp":1, "deleteScheduled":0,
"verifyMessage":null, "verifyRayId":null, "botClientId":"1239597421613420554"
```

So `redirectUrl` is a stored, server-scoped setting, delivered to every visitor of that server's verification page. On the observed server it is `null`.

### Why this would be serious

If a server owner can store `redirectUrl: "javascript:…"`, then **every visitor who completes that server's verification** runs the owner's script in the verification app's origin. That is stored XSS from an untrusted third party (the server owner) against arbitrary users, and it is exactly the impact already proven for F1 in this same app:

- read `localStorage["password-<serverId>"]` — plaintext passwords of password-protected servers the victim has unlocked in this browser;
- read the non-HttpOnly `vc_bt` cookie;
- rewrite the verification UI and drive the Discord OAuth flow.

The browser half is already established: the F1 control run confirmed that assigning a `javascript:` URL from script in this app's context executes it in the current document (Chrome 151).

### What is NOT yet proven

1. **Writability.** No dashboard UI field for `redirectUrl` was found — it is absent from `dash-entry.js` and from the `server-settings` / `bot-settings` / `verify-oauth` chunks. It is most likely settable through `PATCH /servers/{id}` (the generic update call the dashboard uses) even if the UI does not surface it, but that is an inference, not a tested fact.
2. **Server-side validation** of the stored value.
3. **End-to-end execution** on a live page.

### Level-3 procedure (needs a server the researcher owns)

1. On the researcher's own account, create a VaultCord server for a Discord server they administer.
2. `PATCH https://api.vaultcord.com/servers/{ownServerId}` with `{"redirectUrl":"javascript:window.__pwned=1;void(0)"}` using the normal browser session (needs `X-Requested-With: VaultCord_React_SPA` and the account's own `ETag` fingerprint). Record whether the API accepts it.
3. Open that server's public verification page, complete the captcha, and observe whether the payload executes (`window.__pwned === 1`, origin of the page).
4. Reset the field to `null`.

Steps 2–4 touch only the researcher's own server and their own browser.

### Closed during this pass (do not re-open)

| Avenue | Result |
|---|---|
| IDOR on per-server routes | Correctly ownership-scoped — see the F4 table (`/servers/{id}`, `/stats/members/{id}`, `/pulls`, `/pull-history` all deny for a server owned by another account). |
| CORS on `api.vaultcord.com` | `Access-Control-Allow-Origin` is a **fixed** `https://dash.vaultcord.com`, never reflected; `Access-Control-Allow-Credentials` is not paired with attacker origins. Not a bug. |
| Session auth model | Cookie + `X-Requested-With: VaultCord_React_SPA` + `ETag` device fingerprint; `Authorization` is reserved for API keys. No weakness found in this pass. |
| `/accounts/settings` `recoveryKey` | Returned to the authenticated owner only. |
| `last-meta-pixel-trigger` | Just the storage key name for the device fingerprint, not a third-party pixel identifier. |
| F4 API-key paywall gate | Client-side-only gate proven; server-side check unconfirmed because the confirming `PUT /sessions` write was declined by the researcher. |

---

## F6 — Unauthenticated `postMessage` layout injection into the Next.js verification page (`?previewToken=` trust-boundary break) (F6 CANDIDATE — mechanism + production `isPreview` proven; rendering not yet captured)

**Status (2026-11-01):** The server-side half is proven in production (any `previewToken` value flips the page into preview mode). The client-side sink is proven in the live bundle. The final visual step — injected content actually rendering — requires a verification page that resolves a real server, and the only such host reachable for us, `vaultcord.win`, is behind a Cloudflare interactive challenge. We do **not** automate or bypass that challenge; see "Remaining step" for the manual procedure.

**Assets:** `https://customers.vaultcord.com/*` and `https://vaultcord.win/hi` (both in scope; the verification app is the same Next.js build, `buildId sLd7RGlaNHGjJ3ch0VgCb`).

### The sink (live chunk `pages/[[...slug]]`, saved as `recon/cust/a6e5ca05.js`, offset ~87.9k)

The page component installs a `message` listener **only** when `isPreview` is true, and `isPreview` comes straight from `getServerSideProps` for **any** `previewToken` value — the token is never validated:

```js
useEffect(() => {
  if (_) {                                     // _ = pageProps.isPreview
    window.addEventListener("message", e);
    window.parent.postMessage({type:"vaultcord:preview-ready"}, "*");
    return () => window.removeEventListener("message", e);
  }
  function e(e) {
    // origin check ONLY — no event.source check, no nonce, no handshake
    if (!hostnameIsAllowed(e.origin)) return;
    let l = e.data;
    if (!l || "vaultcord:preview-update" !== l.type) return;
    let s = layoutSchema.safeParse(filterBlocks(l.layout));
    if (!s.success) return;
    Z(s.data);                                 // replaces the entire rendered page layout
  }
}, [_, r]);

// hostnameIsAllowed:
let t = new URL(e).hostname;
"localhost" === t || "dash.vaultcord.com" === t || t.endsWith(".vaultcord.com") || t.endsWith(".vercel.app")
```

The layout it accepts is the same object the dashboard editor uses, and it drives every visible block: `avatar`, `banner`, `bio`, `badges`, `socialLinks`, `customCode`, `links`, plus `theme` (colours, cursor, text glow) and `backgroundEffect` (`recon/cust/a6e5ca05.js` offset ~40.4k, block renderer `g()`; render call sites at ~75.4k / 82.8k / 83.3k / 84.5k).

`customCode` is the escalation: attacker text is placed into an iframe `srcDoc` and **executed**:

```js
customCode: function(e){ let {html:t, css:r, js:a, ...s} = e;
  return t||r||a ? jsx("iframe", { sandbox:"allow-scripts",
    srcDoc:`<!doctype html><html><head><style>${r||""}</style></head><body>${t||""}<script>${a||""}</script></body></html>`, ... }) : null }
```

Checked and honestly noted: the `sandbox` attribute is a literal and cannot be overridden — the zod schema is built with plain `z.object` (unknown keys **stripped**; `Ry` → `ea.create`, `f235f9cf.js` ~210.5k), so a `sandbox:"allow-scripts allow-same-origin"` key in the injected props is dropped. So this is script execution in a sandboxed, opaque-origin frame, **not** XSS in the top `vaultcord.*` origin. Likewise `links`/`socialLinks` require `z.string().url()` and render `target="_blank"` (Chrome blocks `javascript:` navigation there — verified locally earlier), and `theme.*`/`cursor` are applied through the CSSOM (`style={{fontFamily:S, "--text-color":…}}`), not markup.

### Proven in production

`GET https://customers.vaultcord.com/hi?previewToken=harness-proof-1` (random, meaningless token; real Chrome UA) returns, in `__NEXT_DATA__`:

```json
"url": "hi", "server": null, "error": "Server not found…", "isPreview": true
```

`isPreview: true` with a garbage token on a production, in-scope host — the feature has no server-side validation. Reproduced for `/?previewToken=`, `/hi`, `/zeoai`, `/crashers`.

### Attack chain (what an attacker actually has to do)

1. Attacker hosts any page on `https://<anything>.vercel.app` (free, self-service; `*.vercel.app` is in the allowlist) — or on `http://localhost` (any port, any local app the victim runs).
2. Victim clicks a link on that page; the page calls `window.open("https://vaultcord.win/<real-vanity>?previewToken=x")` and keeps the `WindowProxy`.
3. Attacker page posts `{type:"vaultcord:preview-update", layout:<forged layout>}` to that window on a timer (every 400 ms, so any later React re-render is overwritten again).
4. The popup — address bar `vaultcord.win`, real VaultCord favicon/OG title, real "Verify" button driven by the real server config — now displays **attacker-controlled** bio text, attacker links, and an attacker HTML/JS frame rendered flush inside the page.

Because the injection is continuous and the attacker also controls `theme`, the forged content is visually indistinguishable from the genuine page. The natural abuse is credential/token harvesting against the flow this page owns (server password entry, Discord OAuth "Verify"): the attacker's frame can render a pixel-styled fake password field next to the real UI and `fetch()` the typed value out to the attacker's own server — the sandbox forbids reading the parent DOM, it does **not** forbid outbound requests. Secondary abuse: arbitrary JS execution hosted on the `vaultcord.win`/`customers.vaultcord.com` context (drive-by of third-party URLs, crypto-miner/redirect payloads inside a page users trust), and full content takeover of any VaultCord verification page a victim is lured to.

### What is NOT yet proven (be explicit in any report)

- **Rendered proof.** On `customers.vaultcord.com` no vanity slug resolves a server (`server:null`), and the page component renders the main card only when `server` exists (`r&&…`, `h.name`), so our PoC showed the listener armed but nothing visible. The PoC script is ready; it just needs a URL that resolves.
- Whether the same `isPreview` behaviour reaches `vaultcord.win/hi` for a real server — same build and same `pageProps`, so the code path is identical, but we have not captured it.
- Impact magnitude is spoofing + sandboxed script + credential harvesting, **not** origin XSS (see the zod/sandbox notes above — do not claim XSS).

### Remaining step (manual, by the researcher — no bot-check bypass)

1. In your own browser, open `https://vaultcord.win/hi` once and complete the Cloudflare "Complete Verification" captcha by hand (normal browsing; nothing is automated).
2. Keep that tab, then open `http://127.0.0.1:8123/harness.html?target=https%3A%2F%2Fvaultcord.win%2Fhi%3FpreviewToken%3Dproof&mode=popup` (served by `poc/preview-injection/run.js`'s local server: `python3 -m http.server 8123 --bind 127.0.0.1` inside `poc/preview-injection/`) and press **Open preview page** — the click is the user activation that lets the popup open.
3. The popup should replace its bio text with `PREVIEW-INJECTION-PROOF-8f2c1d` and show the `VC-SANDBOX-PROOF` frame; screenshot + the popup's `iframe[srcdoc]` outerHTML is the Level-3 evidence. `run.js` captures both automatically (`result-*.html`, `result-*.png`).
4. If the CF challenge reappears for the popup URL, take the evidence from `customers.vaultcord.com/<a vanity that resolves>` — we need one real vanity; the researcher can obtain one legitimately from a server they own, from the dashboard's own "verification link" field, or from a customer they have permission to name.

### Remediation

1. Validate `previewToken` server-side: issue it from the authenticated dashboard session, sign it, bind it to that account + server id, short TTL, single purpose. `isPreview` must be false for an unauthenticated stranger.
2. Check `event.source`, not just `event.origin` — accept the layout only from the window that opened this preview, and require a per-session nonce echoed in the message.
3. Remove `localhost` and the blanket `*.vercel.app` from the allowlist (pin the exact dashboard origin, and if a preview deploy host is needed, pin the specific project domain and rotate it).
4. Serve untrusted `customCode` from a separate, credential-free origin (a `*.vaultcordusercontent.com`-style sandbox domain), not from the origin that carries verification cookies and stored server passwords.

### Evidence

- `recon/cust/a6e5ca05.js` — listener (~87.9k), origin allowlist (~88.3k), zod layout schema (~43.9k–44.6k), `customCode` iframe renderer (~39.2k), server-conditional render sites (~75.4k, 82.8k, 90.9k).
- `recon/cust/f235f9cf.js` ~210.5k — `Ry = ea.create` (plain `z.object`) proving unknown keys (including `sandbox`) are stripped.
- `poc/preview-injection/harness.html`, `poc/preview-injection/run.js` — runnable PoC (localhost attacker origin → `window.open` + timed `postMessage`), with `result-popup-*.html`/`.png` captures of the three attempted targets.
- `poc/preview-injection/result-popup-https_customers_vaultcord_com_hi_previewToken_harness_proof_.html` — production page with `isPreview:true` and the listener armed.

---

## Fourth pass (2026-11-01) — two new candidates from the dash SPA re-analysis

Dash was **redeployed** since 2026-10-30 (old `/__vc/<hash>.js` chunk hashes now 404). Current build pulled fresh: `dash.html` → `recon/dash-bundle/chunk-entry.js` (`entry-dd3c6a64649df175f2873ab4ba82bc0d.js`, Sentry `release:"37e749d"`), plus `chunk-{refresh-discord-token,token-callback,public-bot-callback,discord-callback,verify-oauth,use-discord-data,discord-oauth}.js`.

## F7 — Unauthenticated Discord **refresh-token proxy** on `api.vaultcord.com` (NEW CANDIDATE — Level 2, one self-token test from it)

**Assets:** `https://api.vaultcord.com` (in scope, wildcard row #2 "API Cluster"). Unauthenticated GET, no session, no `X-Requested-With`, no `ETag` device fingerprint required.

### Live evidence (2026-11-01, required UA, nothing else sent)

```
$ curl -A 'Mozilla/5.0 ResponsibleReporter Gecko/20100101' \
       -H 'Referer: https://dash.vaultcord.com/' \
       'https://api.vaultcord.com/bot/public/refresh_token'
200  {"success":false,"message":"Discord API error: 400"}          # no Authorization header at all

$ curl ... 'https://api.vaultcord.com/bot/public/refresh_token' -H 'Authorization: mtplus.BOGUSBOGUSBOGUS'
200  {"success":false,"message":"Discord API error: 400"}

$ curl ... 'https://api.vaultcord.com/backups/refresh_token'      # no Authorization, no session
200  {"success":false,"message":"Discord API error: 400"}
```

Both routes return `access-control-allow-origin: https://dash.vaultcord.com` + `allow-credentials: true`, and expose `X-Request-Id, X-Phonesig`. The body proves the request was **forwarded upstream to Discord** (the error is a Discord status code, echoed verbatim) even though the caller presented no identity whatsoever.

### What these endpoints are for (production client code)

`recon/dash-bundle/chunk-discord-oauth.js` (pre-login "Continue with Discord" flow) — the SPA stores Discord tokens in `localStorage` and refreshes them by putting the **refresh token into the `Authorization` header** of this public route:

```js
const a = "pre_discord_access_token", r = "pre_discord_refresh_token", s = "pre_discord_expires_in";
async function d(){
  const e = localStorage.getItem(r), t = Number(localStorage.getItem(s));
  if (!e || t >= Math.floor(Date.now()/1e3)) return;
  const o = await new c({includeAuthorization:!0}).get("/bot/public/refresh_token", {headers:{Authorization: e}});
  o.success ? (localStorage.setItem(a, o.access_token),
               localStorage.setItem(r, o.refresh_token),        // <-- rotated refresh token returned to caller
               localStorage.setItem(s, (now+604800).toString())) : n();
}
```

`recon/dash-bundle/chunk-refresh-discord-token.js` (logged-in dashboard) does the same against `/backups/refresh_token` with `localStorage.discord_refresh_token`, and then uses `localStorage.discord_access_token` as `Authorization` for `GET /discord/self/guilds`. `chunk-use-discord-data.js` further shows the SPA carrying **Discord bot tokens** (`{token}` bodies) through `api.vaultcord.com`.

### Why this is a vulnerability, not a feature

Discord refresh tokens are **application-confidential**: redeeming one normally requires the OAuth client credentials of the app that the user authorised. VaultCord holds that secret server-side and then exposes an **unauthenticated, unbound endpoint that redeems whatever token the caller pastes**, using its own client credentials. Consequences:

1. **Stolen-token enabler.** A VaultCord-issued refresh token leaked anywhere (browser history, a shared/synced profile, an extension with `storage` access, a support screenshot, logs, the Sentry replay described in F8) is normally only redeemable by VaultCord itself. Through this route an attacker redeems it directly and receives a **live access token** plus the **rotated refresh token**.
2. **Persistence.** Because the response hands back the *new* refresh token, an attacker who sees a token once can keep refreshing ahead of the victim and hold access indefinitely, even after the victim's original grant rotates.
3. **No caller binding.** The handler performs its outbound Discord OAuth exchange even when the request carries **no credentials at all** (proved 2026-11-01: five `Authorization` shapes incl. the empty control all returned the byte-identical body `{"success":false,"message":"Discord API error: 400"}`, md5 `e445450b…`, see `evidence/refresh-token-proxy/VERIFICATION-2026-11-01.md`) — so the route's only requirement is that someone knock. NOTE: responses are byte-identical, so this is **not** a token-validity oracle and should not be claimed as one; nor do we have any evidence about throttling.
4. **Wrong trust level for the route.** `/backups/refresh_token` is the *authenticated dashboard's* route (its name refers to stored token backups) yet it needs no session cookie, no `X-Requested-With: VaultCord_React_SPA` and no `ETag` device fingerprint — all of which the rest of the API does require (compare `GET /servers` → `401 Authorization header missing`). So this is a missing access control, not a designed public surface.

CORS is correctly pinned to `https://dash.vaultcord.com`, so a random website cannot *read* the response from a browser; that does not help an attacker using `curl`/Burp, which is the realistic path.

### Remaining step to make it Level 3 (uses only the researcher's own token)

1. On `dash.vaultcord.com`, run the pre-login "Continue with Discord" flow once (the public callback stores `pre_discord_*` in `localStorage`) — DevTools → Application → Local Storage.
2. `curl -s https://api.vaultcord.com/bot/public/refresh_token -H 'Authorization: <your own pre_discord_refresh_token>'` with the required UA.
3. Evidence = the JSON containing `success:true, access_token:"…"`, showing an unauthenticated caller can mint a fresh access token from a pasted refresh token. Then revoke from Discord → Authorized Apps, and clear the three `pre_discord_*` keys.
No third-party token may be used, and none is needed — the point is the missing caller binding, not any specific token.

### Remediation

Require the VaultCord session on both routes and bind the refresh token to that session server-side (store it against the account, accept only an opaque handle from the client — never a raw Discord token in `Authorization` on an unauthenticated route); rate-limit per account/IP; stop echoing upstream Discord status text; and re-issue with `prompt=consent`-style rotation checks so a leaked token cannot be refreshed ahead of the owner.

---

## F8 — Sentry Session Replay exfiltrates the user's **JWT session token**, the device fingerprint and **unmasked DOM** to a third party (DRAFTED 2026-11-02 — Level 2, config proven in the shipped bundle)

**Status update (2026-11-02):** Config re-confirmed byte-for-byte against the current production bundle
(`entry-dd3c6a64649df175f2873ab4ba82bc0d.js`, release `37e749d`) — unchanged since the first pass. Report
draft written: `Result(only BugReport)/vaultcord-dash-sentry-replay-credential-exfiltration.md`. Evidence
saved to `evidence/sentry-replay/` (`sentry-init-full.js`, `sentry-config-excerpt.js`). **Not yet submitted**
— awaiting the account owner's review before posting to BugBase (per Claude.md rule 6, no unverified-by-a-human
submission).

**Re-verification (same day, 2026-11-02, second check):** dashboard redeployed between the two checks
(`entry-dd3c6a64649df175f2873ab4ba82bc0d.js` → `entry-19e291ac24ec14a9ae7d79ca0d6d73e3.js`, Sentry
`release` `37e749d` → `2d446e1`). Pulled the new bundle and re-extracted the Sentry init call: identical
in substance (`maskAllText:false`, `blockAllMedia:false`, `networkRequestHeaders:["Authorization","ETag",...]`,
`replaysSessionSampleRate:.1`, `replaysOnErrorSampleRate:1`, same DSN, same tunnel) — only minifier-assigned
variable names differ (`LL`→`zL`, `NL`→`WL`), which is expected and not meaningful. `vaultcord.com/istack`
re-checked live (`403`, `access-control-allow-methods: POST, OPTIONS`, `allow-origin: https://dash.vaultcord.com`)
with a GET only — no data posted either time. Second evidence snapshot saved as
`evidence/sentry-replay/sentry-init-full-2026-11-02.js`. **Conclusion: the finding is confirmed accurate
and currently live in production across two separate deploys. Submission is still blocked only by the
BugBase login requirement (see below), not by any doubt about the finding itself.**

**Asset:** `https://dash.vaultcord.com` (in scope, wildcard row #1, Production).

### The shipped configuration (`recon/dash-bundle/chunk-entry.js`, offsets ~1.1886M–1.1891M)

```js
LL({ dsn: "https://e48ec2100a8db7d0cb6ea9fb5b4e51df@o4508515390652416.ingest.de.sentry.io/4508983084384336",
     tunnel: "https://vaultcord.com/istack",
     release: "37e749d",
     beforeSend(e,t){ …only noise filters — no redaction of headers, URLs or request bodies…
                      return e },
     integrations: [ NL({ maskAllText: false,
                          blockAllMedia: false,
                          networkDetailAllowUrls: [/^https:\/\/api\.vaultcord\.com(?:\/|$)/],
                          networkRequestHeaders:  ["Authorization","ETag","Origin","Referer","Accept-Language"],
                          networkResponseHeaders: ["x-request-id","x-dash-version","cf-ray","date","server"] }),
                     DL(), OL({levels:["log","info","warn","error"]}) ],
     enableLogs: true, replaysSessionSampleRate: 0.1, replaysOnErrorSampleRate: 1, tracesSampleRate: 0.05 })
```

`NL` is Sentry's browser Replay integration (`this.instance.config.mask_all_text` is read at `chunk-entry.js` ~212k), so this is replay behaviour, not event-only capture.

### What that means in practice

* `networkRequestHeaders` **explicitly lists `Authorization` and `ETag`** for every `api.vaultcord.com` call made during a recorded session. The dashboard sends its **session JWT in `Authorization`** (the client's own error path proves it: ``this.client.post("/webhooks/errors/frontend", `[JWT] Encountered 401 on acc - …`)`` and reads back `r.config.headers.Authorization`), and per `includeAuthorization` the same header is used for Discord access/refresh tokens (`chunk-refresh-discord-token.js`, `chunk-discord-oauth.js`) and bot-token calls. **Those headers are therefore stored in Sentry replay envelopes.**
* `maskAllText:false` + `blockAllMedia:false` → the recorded DOM/visual is **unmasked**: server names, member data, the member-management screens, and any secret the owner displays (e.g. the generated API key in `create-api-key.js`, bot tokens in the bot-settings UI).
* `ETag` is VaultCord's **device-fingerprint header** (SHA-256 of client attributes, used to gate the cross-device confirmation in F2) — it is captured too, which is exactly the value an attacker would need to replay the fingerprint.
* Sampling makes it systematic, not exceptional: **10% of all sessions** (`replaysSessionSampleRate:0.1`) plus **every session that hits an error** (`replaysOnErrorSampleRate:1`) and `enableLogs`/console capture on top. The `beforeSend` hook does no scrubbing — it only drops known-noisy error classes — so nothing stands between the header and Sentry's EU ingest (`ingest.de.sentry.io`), with the SPA proxying the envelope through `https://vaultcord.com/istack` (live: `POST /istack` → `411 Length Required` from the nginx proxy, i.e. the tunnel is active; we did **not** post data into it).

### Impact

Anyone who can read the Sentry project — staff, contractors, an off-boarded member, or a Sentry account/project compromise — obtains **live user session JWTs, Discord access/refresh tokens and device fingerprints, plus full unmasked dashboard content**, i.e. bulk account takeover material held in a third-party system that is not covered by VaultCord's own access controls, retention rules or `HttpOnly` protections. It also silently breaks the security property the dashboard relies on (`__Host-auth_token` HttpOnly + non-HttpOnly `vc_bt` + fingerprint): the token is copied out-of-band into a service whose access model is unrelated to VaultCord's.

Reportable at Level 2 because the evidence is the vendor's own production configuration; the residual proof (that an event really contains a header) requires their Sentry project, which we do not have access to — do not claim to have seen it.

### Remediation

Drop `Authorization`/`ETag` from `networkRequestHeaders` (Sentry defaults to not recording them), set `maskAllText:true`/`blockAllMedia:true` or scope `unmask` to non-sensitive nodes, redact in `beforeSend`/`beforeReplay` (`event.request?.headers`, breadcrumb `data.request.headers`), move token refresh off the browser entirely (F7's fix removes the need for Discord tokens client-side), and document retention for existing replays.

---

## Closed this pass (do not re-open)

| Avenue | Result |
|---|---|
| Verification-app realtime (`private-cache-verify-<ref>`, Abinator/Pusher, app key `app_02acdac31a8a…`) | `verify-progress` payload fields (`status/completed/total/step/headline/groups[].name|id|reason`) are rendered as React **text** only; no `location`/`innerHTML`/storage sink is fed by it, and `seq` guards ordering. No XSS. Residual: progress disclosure only if a 32-hex `ref` leaks. Not reportable. |
| `/api/authorized?serverId=…` on `customers.vaultcord.com` | Static "Authorization Successful" HTML (4.7 KB, no `Set-Cookie`, no state change) — the `serverId` param is unused; **no verification-bypass** exists here. Tested with `serverId=1` and `999999999`. |
| `vc_bt` cookie | Sent only as `browserToken` to `POST /api/observe/browser` telemetry; not an authentication factor client-side. |
| SPA `redirect_uri` (localStorage → `router({to:…})` in `token-callback.js`, `discord-callback.js`, `verify-oauth.js`) | Written only from `location.pathname+location.search` (always same-origin relative) and removed after use; TanStack `to:` is a path, not an absolute navigation. No open redirect. |
| Discord OAuth `state=<serverId>` (non-random) | The exchange goes through the app's own one-time 30-char code (`POST /webhooks/oauth2/discord {code}`, client gates `code.length===30`), so the app is not relying on `state` alone. Worth noting only: `?code=`/`?ticket=` appear in the SPA URL, which ties into F8's unmasked-URL replay capture. |
| `/assets/*.js` chunk URLs on dash | SPA fallback HTML (32.6 KB) — real chunks must be fetched via the importmap `/__vc/<hash>.js` values; hashes rotate per deploy. |

### F7 — proof status and the evidence gathered 2026-11-01 (raw files in `evidence/refresh-token-proxy/`)

Differential test against the same API with **no session cookie, no `X-Requested-With`, no `ETag`** (9 requests total, all read-only, bogus values only; `.hdr`/`.body`/`.status` per probe):

| probe | route | HTTP | body |
|---|---|---|---|
| A1 | `GET /servers` | **401** | `{"success":false,"message":"Authorization header missing"}` |
| A2 | `GET /accounts/settings` | **401** | `{"success":false,"message":"Authorization header missing"}` |
| C1 | `GET /members/1/unauthed_members` | **401** | `{"success":false,"message":"Authorization header missing"}` |
| A3 | `GET /backups/refresh_token` | **200** | `{"success":false,"message":"Discord API error: 400"}` |
| A4/B1–B4 | `GET /bot/public/refresh_token` | **200** | `{"success":false,"message":"Discord API error: 400"}` |

So the API's authentication gate demonstrably covers the sibling routes and demonstrably **does not** cover the two token-refresh routes — those are executed and answered, and the answer is an **upstream Discord status code surfaced verbatim**, i.e. the handler ran its Discord OAuth exchange. That is the missing access control, proven.

Additional tests run to sharpen the claim, recorded honestly because they came back **negative**:

* *Parameter injection into the upstream request* — `Authorization: abc&grant_type=authorization_code`, `abc&client_id=…&client_secret=deadbeef`, `abc&redirect_uri=…&code=1`, `abc&scope=identify&device_id=1&properties={}` all returned the byte-identical body (single md5 across `D0`–`D4`) → the token is form-encoded correctly, **no CRLF/param injection into the Discord call**. Do not claim it.
* *Input-dependent response artefacts* — diffing `A4` (no `Authorization`) against `D0` (bogus `Authorization`) shows only volatile headers (`x-request-id`, CF `report-to`) and the `vary`/`allow-credentials` pair caused by whether `Origin` was sent → no oracle beyond success/failure.
* *Latency* — 1.08–1.16 s for the refresh routes vs 0.96–1.03 s for the 401 routes: not a usable discriminator (Cloudflare edge dominates).
* *Public repos* — `api.github.com/orgs/VaultCord/repos` returns only `vaultcord.github.io`, `Discord-Token-Joiner`, `.github`, `locale`; the API server implementation is private, so the handler source is not available.

**The one point not yet closed empirically.** It is *possible* (though inconsistent with the shipped client) that the route reads the caller's `Authorization` only when a session exists and otherwise calls Discord with an empty token — which would still explain every observation above. Two facts argue it is not the case:

1. The route exists to serve the **pre-login** flow. `chunk-public-bot-callback.js` writes `pre_discord_access_token` / `pre_discord_refresh_token` / `pre_discord_expires_in` into `localStorage` **before the visitor has any VaultCord account**, and `chunk-discord-oauth.js` then refreshes by putting that value in `Authorization`. There is no session and no other carrier for the token, so the header must be what the handler consumes — otherwise that production feature cannot work at all.
2. `chunk-refresh-discord-token.js` calls the sibling route `/backups/refresh_token` the same way (raw Discord refresh token in `Authorization`) and consumes `access_token`/`refresh_token` from the response body.

**Level-3 closer (self-token only, no secrets leave the page, ~30 s).** In DevTools on `https://dash.vaultcord.com` (logged-in with the researcher's own account, or after one run of the pre-login "Continue with Discord"), paste:

```js
(async()=>{
  const t = localStorage.getItem('discord_refresh_token') || localStorage.getItem('pre_discord_refresh_token');
  if(!t) return 'no token in this browser - run the Discord connect flow first';
  const r = await fetch('https://api.vaultcord.com/bot/public/refresh_token',
                {headers:{Authorization:t}, credentials:'omit'});   // <-- sends NO cookies at all
  const j = await r.json();
  return {tokenPrefix:t.slice(0,4), status:r.status, success:j.success,
          hasAccessToken:!!j.access_token, accessTokenLength:(j.access_token||'').length,
          rotatedRefreshReturned:!!j.refresh_token, message:j.message};
})()
```

`credentials:'omit'` is the important part: it proves the redeeming call needs **neither the session cookie nor any of the three custom auth headers**. The reportable proof is `{status:200, success:true, hasAccessToken:true, accessTokenLength:≈160, rotatedRefreshReturned:true}` — all fields non-secret. Afterwards revoke the grant at Discord → User Operations / Authorized Apps and clear the `*discord_*` localStorage keys. Never test with any token other than the researcher's own.

---

## Determination 2026-11-01 — which candidate is actually a bug

| candidate | verdict | why |
|---|---|---|
| **F6** preview `postMessage` layout injection | **not a bug** | `customCode` runs in `iframe sandbox="allow-scripts"` → opaque origin, so the script has no VaultCord cookies, no `localStorage` of the app origin, and zod `unknownKeys:"strip"` drops `sandbox`/`__proto__` style keys so it cannot be widened to `allow-same-origin`. Being able to change the *look* of a preview you were never allowed to see is not a security-boundary crossing. Worst residual: UI spoofing of a verification page — same class as a phishing page, not a VaultCord vulnerability. **Do not file.** |
| **F7** unauthenticated Discord refresh-token proxy | **the bug — file this one** | It is a *server-side* missing access control, not a client behaviour: two production routes redeem a bearer credential with VaultCord's confidential OAuth client credentials while requiring none of the three auth factors that the rest of the API demonstrably enforces. Cross-origin/`curl` is irrelevant, so the CORS pinning that kills F6-style browser chains does not protect this. Impact = a stolen/captured VaultCord Discord refresh token becomes a live access token for whoever holds it, with rotation handed back. |
| **F8** Sentry replay capture | **reportable, but as the secondary finding** | The config is the vendor's own production source (`networkRequestHeaders:["Authorization","ETag",…]`, `maskAllText:false`, `blockAllMedia:false`, 10% session + 100% error sampling, no redaction in `beforeSend`) — that is provable without touching their Sentry. But we cannot show a stored envelope, and the severity depends on who can read the Sentry project. File it after F7, or as a second report referencing F7 (F7's fix also removes Discord tokens from the browser, shrinking F8). |

### F7 evidence state today

* Proven without any secret: differential 401 vs 200 on 3 sibling routes vs both refresh routes, re-run 2026-11-01; plus the no-`Authorization` control returning the same upstream-Discord-status body ⇒ the handler does not check caller binding before acting.
* Not yet captured: `success:true` + `access_token` for the researcher's **own** refresh token. `dash.vaultcord.com` is logged out in this environment (`/login`, `authed_dashboard=true` is a client-side flag only, no `*discord_*` key in `localStorage`), and running the Discord connect flow requires the user — that is a manual step, see the "Level-3 closer" snippet above.
* Toned down honestly: no validity-oracle claim, no rate-limit claim, no upstream param-injection claim.

**Practical consequence:** F7 can be filed now at "proven missing authentication on a credential-redemption endpoint" (the vendor's own client code documents the intended token flow, and the differential documents the absent gate). The one-paste Level-3 capture converts it from *proven design flaw* to *proven token redemption*, which is the difference between High and Critical/Medium-High in most triages — worth the 30 seconds.
