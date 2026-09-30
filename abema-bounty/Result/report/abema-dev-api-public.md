# Finding 2: Publicly Accessible Development API (`dev-api.d-c3-e.abema-tv.com`) Exposes Internal Test Infrastructure and Broadcast Data

## 1. Title
Unauthenticated Access to ABEMA Development API (`dev-api.d-c3-e.abema-tv.com`) — Internal Test Channels, Broadcast Slots, and CDN Endpoints Exposed

## 2. Vulnerability Details

**What:** The development API host `dev-api.d-c3-e.abema-tv.com` — an internal CyberAgent test environment — is **reachable from the public internet without any authentication or authorization** and serves real responses for multiple `/v1/*` endpoints, including a full channel list (56 channels), broadcast slots, and per-slot detail/stats.

**Why:** The dev environment appears to lack both (a) the auth gate that the production host enforces on the same endpoint families, and (b) any network-level restriction (it is directly DNS-resolvable and HTTP-200 from any IP). The dev API also leaks internal infrastructure identifiers: channel `gnid` values of the form `DEV_GN…`, CDN hostnames such as `dev-linear-abematv.akamaized.net` and `cyberagentdev01` (Yospace tenant), and the Fastly/Varnish edge stack.

**Reproduction context:** No credentials, no Japanese proxy, no device registration. Accessible from any IP worldwide.

## 3. Validation Steps

Prerequisites: none.

```bash
UA="AbemaTV;10.184.0;"

# 1. Dev channel list — 56 channels, no auth
curl -i -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/channels"

# 2. Dev broadcast slots — no auth (requires query param)
curl -i -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/broadcast/slots?channelId=abema-anime"

# 3. Dev single slot detail — no auth
curl -i -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/broadcast/slots/8PuvNS4rLmMyCb"

# 4. Dev slot stats — no auth
curl -i -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/broadcast/slots/8PuvNS4rLmMyCb/stats"

# 5. Contrast with prod — same host family, auth required
curl -i -H "User-Agent: $UA" "https://api.abema.io/v1/version"
# -> {"message":"authorization header must exist"}
```

**Observed output (abridged):**

`GET /v1/channels` → `HTTP/2 200`, 56 channels including internal test channels:
```
Smaqtest        "SMAqテスト1"
thorhammer      "トールハンマーテスト"
aaa             "開発局行動指針"
abema-activation "AbemaTV活性化委員チャンネル"
gemma           "げんまテスト"
qa-drm          "QA用DRMチャンネル(HDCP制限あり)"
qa-drm-personal "QA用パーソナライズドDRMチャンネル"
...
```
Each channel object embeds internal CDN URLs, e.g.:
```
"playback":{"hls":"https://dev-linear-abematv.akamaized.net/channel/abema-anime/playlist.m3u8",
            "dash":"https://dev-linear-abematv.akamaized.net/channel/abema-anime/manifest.mpd",
            "yospace":{"dash":"https://dev-linear-abematv.akamaized.net/yo/csm/extlive/cyberagentdev01,abema-news-dash-v1.mpd?..."}}
```

`GET /v1/broadcast/slots/8PuvNS4rLmMyCb` → `HTTP/2 200`, full slot metadata (title, times, channelId, timeshift windows, highlight, content, shares, thumbnails, credits).

`GET /v1/broadcast/slots/8PuvNS4rLmMyCb/stats` → `{"stats":{}}`.

## 4. Supporting Files / PoC

All files live under `Source/abema-bounty/Result/report/`.

- `poc-finding2.sh` — reproducible bash PoC (run as-is; expect 200 on all four dev endpoints).
- `evidence/f2_dev_channels.json` — captured 200 response from `/v1/channels` (56 channels, incl. internal CDN hostnames).
- `evidence/f2_dev_slots.json` — captured 200 response from `/v1/broadcast/slots?channelId=abema-anime`.
- `evidence/f2_dev_slot_detail.json` — captured 200 response from `/v1/broadcast/slots/8LVL26m4NEBXxK` (internal corporate content).
- `evidence/f2_dev_slot_stats.json` — captured 200 response from `.../stats`.
- `evidence/f2_dev_headers.txt` — captured response headers from a 401 path on the same host, showing `x-envoy-decorator-operation: abema-gateway-cdn.default.svc.cluster.local:8000/*`.

## 5. Severity Level

**Medium.** Justification: Reproducible, stable, unauthenticated access to an internal development environment that is clearly outside the intended public attack surface. Impact is disclosure of internal test infrastructure (hostnames, Yospace tenant `cyberagentdev01`, test channel/program names, QA/DRM test channels) and continued availability of a non-production environment for probing. Not Low because (a) it is a confirmed production-adjacent misconfiguration on a name that resolves publicly, (b) it materially aids further testing of ABEMA's stack by revealing internal hostnames and test fixtures, and (c) it demonstrates an inconsistent auth boundary across the `abema-tv.com` host family. Not High because the exposed data is test/non-PII and the environment is explicitly development.

## 6. Category

Information Disclosure / Misconfigured Environment (development/staging service left publicly accessible without authentication).

## 7. Language

English (with Japanese terms quoted verbatim from responses).

## Target

`https://dev-api.d-c3-e.abema-tv.com/` — related to in-scope `*.abema-tv.com` per program scope.