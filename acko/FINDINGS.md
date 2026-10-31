# Acko — hunt notes (2026-10-30)

Impact hypothesis before testing: a payable issue has to let an unauthenticated caller reach customer PII, KYC, policy records, or a financial action. Header findings, scanner output, self-XSS, and an open redirect that does not carry a token are out of scope in the published policy. No Level 3 break was reproduced.

No requests were sent to hosts that are not in the asset table. The unnamed scope id `691c4361014d50303ddd26f3` was not probed. Mobile apps were not tested. No scanner, no DoS, no other person's policy or KYC was read. No OTP was sent to a real address.

## What responded

| Host | Result |
|---|---|
| `https://www.acko.com` | 200. Next.js marketing site behind Cloudflare and Kong. |
| `https://partner-portal.corp.acko.com` | 200. Create React App. Unauthenticated API calls return 401. Browser shows an email-OTP / SAML login. |
| `https://ackodrive.com`, `https://www.ackodrive.com`, `https://workspace.ackodrive.com` | Cloudflare block from this network (curl 403, browser "Sorry, you have been blocked"). Not tested past that. |
| `https://cx360.corp.acko.com`, `https://lead360.corp.acko.com`, `https://firefly.corp.acko.com` | TCP timeout. Not reachable from this network. |

## Checked, and not a confirmed bug

1. **OAuth `redirect_uri` on `www.acko.com`.** `GET /platform/api/realms/acko/protocol/openid-connect/auth` returns 200 for the real callback `https://www.acko.com/platform/auth/token/acko_webapp`. The same call with `https://example.com/cb` or `https://partner-portal.corp.acko.com/` returns 400 `Invalid parameter: redirect_uri`.
2. **`/login?next=`.** The value is copied into the sign-in `state` parameter, including `https://example.com/cb`. `GET /platform/auth/token/acko_webapp?code=invalid&state=https://example.com/cb` responds 302 to `https://www.acko.com` and does not send the browser to that state. Token theft was not shown. An open redirect without a token is out of scope.
3. **Partner portal APIs.** Unauthenticated `GET /partner-portal-api/partnerships/portal/permissions`, `GET /artemis-api/v1/partnership/user/authentication/not-a-real-user/portal`, and `GET /partner-portal-api/partnerships/portal/policy/fetch?policy_ekey=not-a-real-key` return 401 `missing credential in composite sources`. `GET /artemis-api/internal/document/not-a-real-id` returns 404 `{"message":"Not found"}`, not a document. A POST to the Bajaj policy search was blocked by Cloudflare for this client. The SAML button points at `auth-saml.corp.acko.com`, which is not an in-scope asset, so that host was not requested.
4. **`www.acko.com` paths named in robots.txt.** `/policy/`, `/claim/`, and `/mastersearch/` return Cloudflare 502. `/customer/` and `/endorsement/` return S3 `AccessDenied` (no listing). `/r2d2/` is a Cloudflare 403. `/myaccount` is a 307 to login.
5. **Client analytics token** in the sign-in bundle, sent to `https://www.acko.com/external/api/v2/send`. Hardcoded secrets without a proven security impact are out of scope. It was not used.

## Still blocked

Customer and partner data sit behind login. `www.acko.com` uses phone OTP, and this pass had no number to receive it. The partner portal uses a partner email OTP or SAML. Acko Drive and three of the four `corp.acko.com` hosts did not accept a connection from this network. Those surfaces are not a negative result. They were not reached.
