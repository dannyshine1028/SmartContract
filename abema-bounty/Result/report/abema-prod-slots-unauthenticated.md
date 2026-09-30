# Finding 1: Unauthenticated Access to Production Broadcast Slots API (api.abema.io)

## 1. Title
Unauthenticated Public Exposure of Production Broadcast Schedule Data via `api.abema.io/v1/broadcast/slots`

## 2. Vulnerability Details

**What:** The production ABEMA API endpoint `api.abema.io/v1/broadcast/slots` (and its sub-paths `/v1/broadcast/slots/{slotId}` and `/v1/broadcast/slots/{slotId}/stats`) returns **live production broadcast schedule data, program metadata, audience statistics, cast/crew credits, and copyright information without requiring any authentication**.

**Why:** The endpoint family is intended to be consumed by the ABEMA web/mobile client after a user authenticates (the same host, `api.abema.io`, returns `{"message":"authorization header must exist"}` for every other `/v1/*` path tested — e.g. `/v1/video/program`, `/v1/media/token`, `/v1/account/plan`, `/v1/subscription/status`). The broadcast slots family is the **sole exception**: it has no auth gate. This is an inconsistent authorization boundary on the catalog API (`abema-catalog-api.default.svc.cluster.local`), not a deliberate public endpoint.

**Reproduction context:** No credentials, no device registration, no Japanese proxy required. Accessible from any IP worldwide.

## 3. Validation Steps

Prerequisites: none. Any HTTP client.

```bash
UA="AbemaTV;10.184.0;"

# 1. List all production broadcast slots (no auth) — returns 52 live slots
curl -i -H "User-Agent: $UA" "https://api.abema.io/v1/broadcast/slots"

# 2. Fetch a single slot's full metadata (no auth)
curl -i -H "User-Agent: $UA" "https://api.abema.io/v1/broadcast/slots/C6hPcxgiXXS3eF"

# 3. Fetch audience stats for a slot (no auth)
curl -i -H "User-Agent: $UA" "https://api.abema.io/v1/broadcast/slots/C6hPcxgiXXS3eF/stats"

# 4. Contrast — every other path on the same host demands auth
curl -i -H "User-Agent: $UA" "https://api.abema.io/v1/media/token"
# -> {"message":"authorization header must exist"}
```

**Observed output (abridged):**

`GET /v1/broadcast/slots` → `HTTP/2 200`, 52 slots. Example:
```json
{"slots":[
  {"id":"C6hPcxgiXXS3eF","title":"【再放送】フリースタイルティーチャー：#118~#126",
   "startAt":1790740800,"endAt":1790755200,"channelId":"hiphop",
   "highlight":"RECTRUCK：毎週火曜にHIPHOPchで放送中",
   "content":"芸人界最強ラッパー決定トーナントーナメントでを振り返る伝説のベストバウト集!!",
   "shares":{"twitter":{"link":"https://abema.go.link/QsdwM"},...},
   "thumbnails":{"default":{"version":"1695701260","id":"88-96_s15_p1","name":"thumb001"}},
   "credit":{"casts":["【MC】","Zeebra","青山テルマ"],
             "crews":["企画協力:Ameba","プロデューサー:北田暢子(テレビ朝日)","制作:テレビ朝日 MMJ"],
             "copyrights":["(C)テレビ朝日"]},
   "stats":{"view":2885,"comment":2}, ...}
]}
```

`GET /v1/broadcast/slots/C6hPcxgiXXS3eF/stats` → `{"stats":{"view":2885,"comment":2}}`

## 4. Supporting Files / PoC

All files live under `Source/abema-bounty/Result/report/`.

- `poc-finding1.sh` — reproducible bash PoC (run as-is; expect 200 on all three slot endpoints). Includes a retry loop because `api.abema.io` intermittently resets connections (HTTP 000).
- `evidence/f1_prod_slots.json` — captured 200 response from `/v1/broadcast/slots` (~179 KB, 53 slots).
- `evidence/f1_slot_detail.json` — captured 200 response from `/v1/broadcast/slots/C6hPcxgiXXS3eF` (full slot metadata incl. credits, thumbnails, stats).
- `evidence/f1_slot_stats.json` — captured 200 response from `.../C6hPcxgiXXS3eF/stats` → `{"stats":{"view":2885,"comment":2}}`.
- `evidence/f1_auth_required.json` — captured 401 from `/v1/media/token` → `{"message":"authorization header must exist"}` (differential proof).
- `evidence/f1_headers.txt` — captured response headers from `/v1/broadcast/slots`, showing `x-envoy-decorator-operation: abema-catalog-api.default.svc.cluster.local:8000/*`.

## 5. Severity Level

**Medium.** Justification: This is a genuine, reproducible authorization-boundary failure on a production in-scope asset (`*.abema.io`), confirmed by differential testing against sibling endpoints that correctly require auth. Impact is information disclosure of non-PII broadcast operations data (schedules, credits, aggregate view counts) rather than account takeover or PII, which caps it at Medium under IssueHunt's rubric. It is not rated Low because (a) it is a stable, reproducible production defect on an in-scope asset, (b) it exposes real operational metadata continuously, and (c) it demonstrates that the catalog API's auth model is inconsistently applied — the same class of misconfiguration could protect a more sensitive endpoint.

## 6. Category

Access Control / Authorization (Insecure Direct Object Reference family — here the "object" is the entire broadcast-schedule resource, reachable without any principal).

## 7. Language

English (with Japanese terms quoted verbatim from responses).

## Target

`https://api.abema.io/v1/broadcast/slots` (and sub-paths) — in-scope per program `*.abema.io`.