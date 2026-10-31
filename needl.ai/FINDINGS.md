# Needl.Ai — Hunt notes (2026-10-31)

No Level 3 issue. No report was submitted.

Requests used `User-Agent: dannyshine1028/bugbase`, `X-Bugbase-Username: dannyshine1028`, and `X-Bugbase-dannyshine1028: dannyshine1028`. No scanner. No account was created, and no verification email was sent. Mobile apps, the three asset ids that have no public URL, and `*.idatagenie.com` were not requested. No other user's data was read.

## What the app is

`https://app.needl.ai/` is the production SPA. Its API client uses `https://app.needl.ai/api`. The session header is `token` (a Cognito id token), plus `app-type` and `x-request-origin`. Cognito is configured in the page bundle: pool `us-east-1_EsumPinsw`, client `6mq6oqaav0tsrg6k0fvqdqcbso`, hosted UI domain `auth.needl.ai`. Redirects registered in that config are `https://app.needl.ai/auth/signin` and, in the admin bundle, `https://app.needl.ai/admin/login`. Those identifiers are in the public JavaScript. They are not a vulnerability by themselves.

Document reads go to `GET /api/doc/{source}` with `deeplink` and either `access_key` or `public_access_key`. The asset page at `asset_hash` calls `GET /api/asset/private/{hash}` and, only after an authenticated response, navigates to the final URL.

## Unauthenticated API

These routes returned `403` `{"error":"Forbidden"}` with no token, and the same `403` when the `token` header was an `alg: none` JWT:

- `GET /api/user`, `GET /api//user`
- `GET /api/organizations/self`
- `GET /api/connect/public`
- `GET /api/boards`, `GET /api/boards/v2`
- `GET /api/onboarding/flags`
- `GET /api/categories`
- `GET /api/source/public`, `GET /api/source/needlbox`
- `GET /api/redirect/document`, `GET /api/oauth/redirect`
- `GET /api/asset/private/test`
- `GET /api/doc/rss?deeplink=test&public_access_key=test`
- `POST /api/connect/rss` with `{"url":"https://example.com/"}`
- `POST /api/search/exchanges` with the client's public filter body (`num_docs` 0)

`Origin: https://example.com` on `GET /api/user` did not produce `Access-Control-Allow-Origin`.

`https://api.needl.ai/` is `Cannot GET /`. `GET /user` is `Cannot GET /user`. `GET /api/user` is the same `403` JSON as the app API.

## Auth host

`https://auth.needl.ai/` is an empty `200` from the load balancer. `/.well-known/openid-configuration` is `404`. `/login` without OAuth parameters is `400`.

`/oauth2/authorize` with `redirect_uri=https://example.com`, `https://app.needl.ai/auth/signin.example.com`, and `https://app.needl.ai.example.com/auth/signin` is `400`. The registered `redirect_uri=https://app.needl.ai/auth/signin` returns the login page (`200`). No authorization code was issued to an external host.

The hosted UI HTML includes a sign-up form. `SignUp` on the pool, with a username that is not an email, returns `Username should be an email.` With an email username and the password `short`, it returns `Password did not conform with policy: Password not long enough.` That means the pool evaluates the password policy. A policy-compliant password was not sent, so no user was created and no mail was sent. The sign-in bundle also handles the Cognito message `signups are not allowed` and tells the visitor to contact support. That later rejection was not reached.

Google and Apple buttons are on the hosted UI. Neither provider flow was completed.

## Admin, Grafana, Flagr, k8s, Mixpanel, imgproxy, pricing

- `https://app.needl.ai/admin/` is the admin SPA. `GET /admin/api/organizations` and `GET /admin/api/permissions` return `403` `{"error":"Authentication failed"}`. The first `/admin/api` response set `Access-Control-Allow-Origin` to `https://app.needl.ai/admin`, not to a foreign origin.
- `GET /grafana/` redirects to `/grafana/login`. `GET /grafana/api/org` and `/grafana/api/datasources` are `401`. `GET /grafana/api/health` is `200` and includes Grafana `12.2.10`. Version disclosure is out of scope in the policy.
- `GET /flagr` and `GET /flagr/api/v1/flags` are `401`.
- `GET /k8s` returned the main SPA. `GET /k8s/`, `/k8s/api`, `/k8s/version`, `/k8s/health`, and `/k8s/docs` are a Flask `404`. No cluster API was exposed on those paths.
- `GET /mixpanel/` is Mixpanel's own `404` welcome JSON. `GET /mixpanel/api/2.0/engage` is an S3 `NoSuchKey`. No object list was requested.
- `https://imgproxy.needl.ai/` is the default imgproxy page. `GET /unsafe/plain/https://example.com/` is `403` `Forbidden`. `Access-Control-Allow-Origin: *` is set on that response. No internal address was requested.
- `https://pricing.needl.ai/`, `/health`, `/api`, and `/v1` are `404 page not found`. The app bundle does not reference this host.
- `https://needl.ai/` is a Framer marketing page. `https://needl.ai/help` is that same site's `404`.

## debug-logs

`POST /api/debug-logs` is not behind the same auth check. With `x-request-origin: FRONTEND_REACT` and `{"logData":"Got 403, trying to get new JWT token"}` (the string the client itself sends), the response is `200` `{"message":"Logs logged successfully"}` and `x-response-origin: backend_express`. No session token was sent. `GET /api/debug-logs` is `403`. The written line cannot be read back. A later quote and object probe did not complete because name resolution failed. There is no shown change to another user's data, to HTML, or to an authorization decision. The policy lists text injection without an attack that modifies HTML or CSS as out of scope.

A second pass on `feature/config`, `upload`, `user/preferences`, `user/workspaces`, `notebook/list`, `onboarding/flags`, and `needl-analytics/report` was `403` from `backend_express`. `index-D_z-OH9o.js.map` is the SPA HTML, not a source map. `grafana/api/dashboards/home` is `401`. `imgproxy/health` returns `imgproxy is running`.

## Not reached

IDOR, cross-account document access, and the asset-download redirect need a confirmed session. Self-signup reaches the password policy, and the client expects a later "signups are not allowed" rejection. Neither a confirmed account nor a second account exists, so that surface was not tested.
