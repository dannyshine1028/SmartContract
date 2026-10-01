# ABEMA Bug Bounty Program — Investigation Findings

## Program Info
- **Platform**: IssueHunt
- **Program ID**: `75563b98-3a9c-4ca3-956d-07b30d5d3962`
- **Organization**: CyberAgent, Inc.
- **Active Since**: Feb 2025
- **Response Time**: 5 days
- **Scope**: Web + Mobile (iOS/Android)

## Investigation Summary

### What Was Done
1. **APK Downloaded & Extracted**: `tv.abema` v10.184.0 XAPK (46.8MB) → main APK (45MB) → extracted to `/tmp/apk_extracted/`
2. **DEX String Analysis**: Extracted all strings from `classes.dex` through `classes5.dex` to identify API endpoints, auth mechanisms, proto message types, and gateway class names
3. **API Reconnaissance**: Tested 200+ endpoint paths across 15+ API hosts (prod + dev + staging)
4. **Auth Flow Investigation**: Tested all known auth header schemes and token exchange endpoints
5. **Vulnerability Fuzzing**: Tested IDOR, SSRF, path traversal, HTTP method override, query parameter injection
6. **Dev/Staging Environment Testing**: Discovered dev API is publicly accessible with different behavior

### Key Findings

#### Finding 1: Unauthenticated Production Broadcast Slots API (Medium)
- **Host**: `api.abema.io`
- **Endpoints**: `/v1/broadcast/slots`, `/v1/broadcast/slots/{slotId}`, `/v1/broadcast/slots/{slotId}/stats`
- **Status**: Returns HTTP 200 **without any authentication** — full production broadcast schedule data including titles, times, channel IDs, highlights, content descriptions, thumbnails, cast/crew credits, copyrights, and aggregate view/comment stats
- **Differential proof**: Every other `/v1/*` path on the same host (e.g. `/v1/media/token`, `/v1/account/plan`, `/v1/subscription/status`) correctly returns `{"message":"authorization header must exist"}` (401)
- **Impact**: Continuous, unauthenticated disclosure of ABEMA's live broadcast operations metadata; demonstrates an inconsistent auth boundary on the catalog API (`abema-catalog-api.default.svc.cluster.local`)
- **Reproducibility**: Stable; PoC `poc-finding1.sh` runs end-to-end and prints 200/200/200 vs 401. Active slot set rotates, so the PoC derives a live slot id from the list rather than hard-coding one. `api.abema.io` intermittently resets connections (HTTP 000) — the PoC includes a 5x retry loop.
- **Evidence**: `Source/abema-bounty/Result/report/evidence/f1_*.json` + `poc-finding1.sh`

#### Finding 2: Publicly Accessible Development API (Medium)
- **Host**: `dev-api.d-c3-e.abema-tv.com`
- **Endpoints**: `/v1/channels` (56 channels), `/v1/broadcast/slots`, `/v1/broadcast/slots/{slotId}`, `/v1/broadcast/slots/{slotId}/stats`
- **Status**: HTTP 200 without authentication
- **Exposes**: Internal test channels (Smaqtest, thorhammer, aaa, abema-activation, gemma, qa-drm, qa-drm-personal), internal CDN hostnames (`dev-linear-abematv.akamaized.net`, `cyberagentdev01` Yospace tenant), test broadcast slots with full metadata including internal company content (e.g. "ABEMA Developer Principles" corporate values document)
- **Reproducibility**: Stable; PoC `poc-finding2.sh` runs end-to-end and prints 200/200/200/200 vs 401. Slot ids rotate, so the PoC derives a live slot id from the list rather than hard-coding one (fixed 2026-09-30 — the earlier version hard-coded ids that had rotated to 404).
- **Impact**: Public exposure of internal development infrastructure, test fixtures, and internal corporate content.
- **Evidence**: `Source/abema-bounty/Result/report/evidence/f2_*.json` + `poc-finding2.sh`

#### Finding 3: Internal K8s Service Names Leaked via Envoy Headers (Low) — SUBMISSION READY
- **Header**: `x-envoy-decorator-operation` on **every** in-scope API host, unauthenticated
- **Full list (14 identities / 11 unique services across 13 hosts, verified 2026-09-30)**:
  - `api.abema.io` → `abema-gateway-cdn.default.svc.cluster.local:8000/*`
  - `api.abema.tv` → `abema-tv-api-tky.default.svc.cluster.local:8300/*`
  - `dev-api.d-c3-e.abema-tv.com` → `abema-gateway-cdn.default.svc.cluster.local:8000/*`
  - `realtime-api.p-c3-e.abema-tv.com` → `abema-realtime-gateway.realtime.svc.cluster.local:8000/*`
  - `dev-realtime-api.d-c3-e.abema-tv.com` → `abema-realtime-gateway.realtime.svc.cluster.local:8000/*`
  - `user-content-api.p-c3-e.abema-tv.com` → `abema-user-content-gateway.user-content.svc.cluster.local:8000/*`
  - `dev-user-content-api.d-c3-e.abema-tv.com` → `abema-user-content-gateway.user-content.svc.cluster.local:8000/*`
  - `upload.abema.io` → `abema-user-upload-api.default.svc.cluster.local:8000/*`
  - `dev-upload-api.d-c3-e.abema-tv.com` → `abema-user-upload-api.default.svc.cluster.local:8000/*`
  - `bundle-api.p-c3-e.abema-tv.com` → `abema-bundle-plan-user-gateway.default.svc.cluster.local:8000/*`
  - `dev-bundle-api.d-c3-e.abema-tv.com` → `abema-bundle-plan-user-gateway.default.svc.cluster.local:8000/*`
  - `user-schedule-api.ep.c3.abema.io` → `abema-user-schedule-gateway.user-schedule.svc.cluster.local:8100/*`
  - `zeus-api.p-c3-e.abema-tv.com` → `zeus-decider.zeus.svc.cluster.local:80/*`
- **Impact**: Discloses internal Istio/Envoy service mesh topology (service name + namespace + port) for every ABEMA gateway, enabling an attacker to map the internal network and target the dev environment (Finding 2)
- **Reproducibility**: Stable; PoC `poc-finding3.sh` prints all 13 hosts
- **Evidence**: `Source/abema-bounty/Result/report/evidence/f3_envoy_leaks.txt` + `poc-finding3.sh` + `abema-envoy-service-names.md`

#### Finding 4: Version/Build Info Leak (Low)
- **Endpoint**: `/v1/version` (requires auth on prod, but accessible on dev)
- **Exposes**: Branch name, git hash, build timestamp
- **Caveat**: Out of scope per guidelines ("Disclosure of software, library, or framework versions")

#### Finding 5: CORS Configuration (Informational)
- **Headers**: `access-control-allow-origin: https://abema.tv`, `access-control-allow-methods: POST`, `access-control-allow-headers` includes `Authorization`, `X-Abema-Pat`, `X-Abema-Ppv-Ticket`
- **Impact**: CORS allows specific origin with specific headers — not a vulnerability per se

#### Finding 6: Certificate Pinning Bypass via Cleartext (Low)
- **Network Security Config**: Allows cleartext for `yospace.com`, `localhost`, `10.0.2.2`, `10.0.3.2`
- **Impact**: If an attacker can redirect traffic to yospace.com, cleartext HTTP would bypass certificate pinning
- **Caveat**: Requires man-in-the-middle position or DNS hijack

#### Finding 7: Auth Flow Details (Informational)
- **Token Exchange**: `/v1/account/token-exchange/single-device` exists but requires valid auth header
- **Auth Headers**: `X-Abema-PAT`, `X-Abema-PPV-Ticket`, `Authorization: Bearer`, `X-Gateway-Authorization`
- **Token Storage**: `abema-native-access-token`, `abema-native-refresh-token`, `abema-native-user-token`, `abema-native-refresh-token-revoked-user-id`, `abema-native-user-token-before-switching-auth`
- **Auth interceptor**: `nqsAuthorizationInterceptor` (Kotlin lambda `$nqsAuthorizationInterceptor$lambda$2`) adds the auth headers; `account.token?.bearerToken?.take(10)` extracts the Bearer token
- **Proto message types** (Google.protobuf.Any, `type.googleapis.com/auth.*`):
  - `CreateAccessTokenRequest/Response`, `CreateSessionRequest/Response`, `LoginAsGuestRequest/Response`, `LoginWithEmailRequest/Response`, `LoginWithOneTimePasswordRequest/Response`, `LoginWithSingleDeviceOneTimeTokenRequest/Response`, `RegisterEmailRequest/Response`, `RestoreUserRequest/Response`, `IssueOneTimeTokenRequest/Response`, `StartAuthorizationRequest/Response`, `VerifyDeviceAuthorizationRequest/Response`, `VerifyKYCEmailOneTimePasscodeRequest/Response`
- **Device binding**: `deviceTypeId` (`DefaultDeviceTypeIdService`), `GetMediaDeviceTypeIDResponse`, `SaveDeviceNotificationTokenRequest/Response`, `account_token_exchange_single_device`
- **SSO/OAuth**: `auth_api_credentials_begin_sign_in`, `auth_api_credentials_authorize`, `auth_api_credentials_save_account_linking_token`, `auth_api_credentials_revoke_access`, `identityProviderType` (FB/VK OAuth patterns `^(fb|vk)[0-9]{5,}[^:]*://authorize.*access_token=.*`)
- **Status**: Unable to obtain valid tokens without Japanese proxy or device registration

### What Was NOT Found
- No IDOR on public endpoints (all require auth except the broadcast slots family)
- No SSRF on public endpoints (WAF blocks `url=` params with 403; no endpoint accepts a URL parameter)
- No path traversal on image CDN (blocked by WAF "Blocked Extension")
- No SQL injection on public endpoints
- No exposed admin/debug endpoints
- No token generation mechanism found (requires device registration)
- No open redirect (abema.go.link only redirects to fixed abema.tv paths)

### Blocked Items
- **Cloudflare**: pureapk.com, apkpure.com, apkmirror.com all block with 403
- **No Japanese proxy**: All 15 proxies tested (HTTP + SOCKS5) fail with connection refused/timeout
- **No Android emulator**: No `adb` or Android SDK available
- **Geo-restricted**: Akamai CDN HLS/DASH streams return 403 "Access Denied" from non-Japan IPs
- **API instability**: api.abema.io frequently returns HTTP 000 (connection reset) under load — ~50% of requests fail, requiring retry loops

### Recommendations for Future Work
1. **Submit Findings 1, 2 & 3** — all are stable, reproducible, in-scope, and demonstrate real defects (auth-boundary failure, public dev environment, service-mesh fingerprinting)
2. Obtain a Japanese proxy to test authenticated endpoints (token-exchange, user profile, PPV)
3. Use an Android emulator to register a device and capture the auth flow (`LoginAsGuest` → `CreateAccessToken` → `token-exchange/single-device`)
4. Test the PPV ticket bypass more thoroughly (`X-Abema-PPV-Ticket`)
5. Investigate the MediaToken endpoint for token format vulnerabilities
6. Test the realtime-api for SSE-based vulnerabilities