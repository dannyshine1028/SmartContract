# F7 differential re-verification — 2026-11-01

All requests: single, read-only, required UA `Mozilla/5.0 ResponsibleReporter Gecko/20100101`,
`Origin: https://dash.vaultcord.com` + `Referer: https://dash.vaultcord.com/` (WAF pass-through only),
**no** `Cookie`, **no** `X-Requested-With: VaultCord_React_SPA`, **no** `ETag` device fingerprint,
**no** VaultCord session of any kind.

## 1. Sibling routes vs the token-refresh routes (still reproducible today)

| route | HTTP | body |
|---|---|---|
| `GET /servers` | **401** | `{"success":false,"message":"Authorization header missing"}` |
| `GET /accounts/settings` | **401** | `{"success":false,"message":"Authorization header missing"}` |
| `GET /members/1/unauthed_members` | **401** | `{"success":false,"message":"Authorization header missing"}` |
| `GET /backups/refresh_token` | **200** | `{"success":false,"message":"Discord API error: 400"}` |
| `GET /bot/public/refresh_token` | **200** | `{"success":false,"message":"Discord API error: 400"}` |

Raw files: `A1_*`, `A2_*`, `A3_*`, `A4_*`, `C1_*`, `E6_control_noauth.*`.

## 2. New probe 2026-11-01 — does the handler require caller-supplied input before it acts?

`Authorization` was varied over five shapes (plausible 30-char `mj…`, 44-char `mj…`, a JWT-shaped
string, a hex-looking string, and **no `Authorization` header at all**).

All five returned HTTP 200 with a **byte-identical body** (md5 `e445450bf56db2bb9cb0a96440159f6e`):

```
e445450b  E2_plausible30.body      e445450b  E5_repeatable.body
e445450b  E3_plausible44.body      e445450b  E6_control_noauth.body   <-- no Authorization
e445450b  E4_jwt.body              e445450b  A4_nocookie_botpublic_refresh.body
```

Conclusion: the route does **not** gate on the caller having supplied or been bound to anything — it
performs its outbound Discord OAuth exchange and reports the upstream status verbatim even for a
request that carries no credentials whatsoever. That is the missing access control, and it is what a
`curl`-only attacker sees.

## 3. Claims deliberately NOT made

* **No token-format oracle.** The responses are byte-identical, so there is no observable way to test
  stolen tokens distinguishably. The route must be described as an unauthenticated token-redemption
  proxy, not a bulk validation oracle.
* **No rate-limit finding.** A repeat-request probe intended to measure throttling was not performed;
  we have no evidence for or against throttling.
* **No CRLF/parameter injection into the upstream Discord request.** See `D0`–`D4` (byte-identical).
* **No observed successful redemption.** `success:true` with a real `access_token` has not been
  captured; that is the outstanding Level-3 step in `FINDINGS.md` §"Level-3 closer".
