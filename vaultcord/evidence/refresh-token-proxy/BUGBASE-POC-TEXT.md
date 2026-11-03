## Description:

`api.vaultcord.com` gates its API with three factors the dashboard client always sends together: the `__Host-auth_token` cookie, `Authorization` (session JWT / API key) and `ETag` (SHA-256 device fingerprint). Two endpoints that implement the **Discord OAuth2 `refresh_token` grant** sit outside that gate: `GET /bot/public/refresh_token` and `GET /backups/refresh_token` answer **200 with no credentials at all**, returning `{"success":false,"message":"Discord API error: 400"}` — the upstream Discord status surfaced verbatim, i.e. the handler ran its Discord exchange for an anonymous caller. Your shipped client documents the contract: the caller's **raw Discord refresh token goes into the `Authorization` header**, and the response's `access_token`/`refresh_token` are stored in `localStorage`.

## Steps To Reproduce:

Preconditions: none — no account, no cookies, no tokens. UA `Mozilla/5.0 ResponsibleReporter Gecko/20100101` (as required). `Origin`/`Referer: https://dash.vaultcord.com` only satisfy the app WAF (which else answers 403); no Cloudflare/WAF challenge was bypassed.

1. Differential — same host, transport and headers, only the path changes:

```
for p in servers accounts/settings members/1/unauthed_members backups/refresh_token bot/public/refresh_token; do
  curl -sS -o /dev/null -w "%{http_code} $p\n" -A "$UA" -H 'Origin: https://dash.vaultcord.com' \
    -H 'Referer: https://dash.vaultcord.com/' "https://api.vaultcord.com/$p"; done
```

`/servers`, `/accounts/settings`, `/members/1/unauthed_members` → **401** `Authorization header missing`; `/backups/refresh_token`, `/bot/public/refresh_token` → **200** `Discord API error: 400`.

2. The route acts before it checks who is calling: `Authorization` varied over four shapes plus the **empty control** (header not sent) — all five HTTP 200, **byte-identical** body, md5 `e445450bf56db2bb9cb0a96440159f6e`.

3. The contract, from your own production bundle (verbatim chunks attached). Pre-login `discord-oauth`:

```js
const e=localStorage.getItem("pre_discord_refresh_token");
const o=await new c({includeAuthorization:!0}).get("/bot/public/refresh_token",{headers:{Authorization:e}});
o.success&&(localStorage.setItem("pre_discord_access_token",o.access_token),
            localStorage.setItem("pre_discord_refresh_token",o.refresh_token));
```

The logged-in twin `refresh-discord-token` calls `/backups/refresh_token` identically. `pre_discord_*` is written by the **public** callback *before any account exists*, so there is no session and no other carrier for the token — and `/backups/refresh_token`, the dashboard's own route, demands no session either.

## Not claimed

* **No successful redemption captured**: it needs a valid refresh token, and I only test with my own credential (logged out at the time). Confirm with your own account: `curl -H "Authorization: <localStorage.discord_refresh_token>" .../bot/public/refresh_token`.
* **Not a validation oracle**; **no rate-limit claim** (no load test); **no upstream injection** — `Authorization` values carrying `&grant_type=`, `&client_id=…&client_secret=`, `&redirect_uri=`, `&scope=` all returned identical bodies, so the value is correctly form-encoded. CORS is pinned, so only curl/Burp works. GET with bogus values only: no state change, no other user's data, no scanner.

## Security Impact

Discord refresh tokens are application-confidential; you hold the client secret and these routes hand the redemption to anyone. 1) A leaked VaultCord refresh token becomes usable by whoever finds it (history, synced profile, screenshot, log, session-capture tooling) — the difference between a leaked string and a compromised Discord account. 2) The rotated refresh token comes back to the caller, so a one-time glimpse outlives the rotation meant to revoke it. 3) Anonymous callers make your server spend authenticated Discord token-endpoint quota and standing, with no accounting. 4) Upstream status is disclosed. **Moderate (CVSS 5.3) as captured**; if the caller-supplied token is confirmed as the redeemed one — which your client shows is the design — it is High (C:H, 7.5).

## Recommendations

1. Stop accepting a raw Discord refresh token from the client: store it server-side against the account and let the client pass an opaque handle (session + `backupId`); for the pre-login flow bind it to the `state`/32-hex one-time code you already use.
2. Require the session on `/backups/refresh_token` (no public callers).
3. If tokens stay client-side, bind the route to the granting session (`ETag` fingerprint + one-time code) and reject foreign tokens.
4. Rate-limit per account/IP, log redemptions, and return a generic error instead of `"Discord API error: <status>"`.

## Specifics

* Discovered 2026-10-31 (IP 77.247.126.189), re-verified 2026-11-01 (IP 50.7.158.74).
* Attachment: raw captures (A1–A4, B1–B4, C1, D0–D4, E2–E6) with every `Set-Cookie`/`Authorization` line stripped, README, md5 table, the 3 chunks above.
