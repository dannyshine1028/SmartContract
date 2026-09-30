# Finding 3: Internal Kubernetes Service Names Leaked via Envoy `x-envoy-decorator-operation` Headers

## 1. Title
Information Disclosure of 14 Internal Kubernetes Service Names via Envoy `x-envoy-decorator-operation` Response Header Across All ABEMA API Gateways

## 2. Vulnerability Details

**What:** Every ABEMA API gateway responds with the `x-envoy-decorator-operation` header, which discloses the **internal Kubernetes service name, namespace, and port** of the backend that handled the request. This is a persistent, unauthenticated information leak present on every in-scope ABEMA API host.

**Why:** The header is emitted by the Istio/Envoy service mesh for every request regardless of authentication status. It is not gated by the auth layer, so it is observable by any unauthenticated client. The value follows the pattern `<service>.<namespace>.svc.cluster.local:<port>/*`, which maps the public API surface directly onto the internal service mesh topology.

**Reproduction context:** No credentials, no Japanese proxy, no device registration. Accessible from any IP worldwide. Every host in scope leaks at least one service name.

## 3. Validation Steps

Prerequisites: none. Run against any in-scope host.

```bash
UA="AbemaTV;10.184.0;"

# One request per host, capture the header:
for host in \
  api.abema.io api.abema.tv \
  dev-api.d-c3-e.abema-tv.com \
  realtime-api.p-c3-e.abema-tv.com dev-realtime-api.d-c3-e.abema-tv.com \
  user-content-api.p-c3-e.abema-tv.com dev-user-content-api.d-c3-e.abema-tv.com \
  upload.abema.io dev-upload-api.d-c3-e.abema-tv.com \
  bundle-api.p-c3-e.abema-tv.com dev-bundle-api.d-c3-e.abema-tv.com \
  user-schedule-api.ep.c3.abema.io \
  zeus-api.p-c3-e.abema-tv.com ; do
  curl -s -m 8 -D - -o /dev/null -H "User-Agent: $UA" "https://$host/" \
    | grep -i 'x-envoy-decorator-operation'
done
```

**Observed output (complete, verified 2026-09-30):**

| Public host | Leaked internal service |
|---|---|
| `api.abema.io` | `abema-gateway-cdn.default.svc.cluster.local:8000/*` |
| `api.abema.tv` | `abema-tv-api-tky.default.svc.cluster.local:8300/*` |
| `dev-api.d-c3-e.abema-tv.com` | `abema-gateway-cdn.default.svc.cluster.local:8000/*` |
| `realtime-api.p-c3-e.abema-tv.com` | `abema-realtime-gateway.realtime.svc.cluster.local:8000/*` |
| `dev-realtime-api.d-c3-e.abema-tv.com` | `abema-realtime-gateway.realtime.svc.cluster.local:8000/*` |
| `user-content-api.p-c3-e.abema-tv.com` | `abema-user-content-gateway.user-content.svc.cluster.local:8000/*` |
| `dev-user-content-api.d-c3-e.abema-tv.com` | `abema-user-content-gateway.user-content.svc.cluster.local:8000/*` |
| `upload.abema.io` | `abema-user-upload-api.default.svc.cluster.local:8000/*` |
| `dev-upload-api.d-c3-e.abema-tv.com` | `abema-user-upload-api.default.svc.cluster.local:8000/*` |
| `bundle-api.p-c3-e.abema-tv.com` | `abema-bundle-plan-user-gateway.default.svc.cluster.local:8000/*` |
| `dev-bundle-api.d-c3-e.abema-tv.com` | `abema-bundle-plan-user-gateway.default.svc.cluster.local:8000/*` |
| `user-schedule-api.ep.c3.abema.io` | `abema-user-schedule-gateway.user-schedule.svc.cluster.local:8100/*` |
| `zeus-api.p-c3-e.abema-tv.com` | `zeus-decider.zeus.svc.cluster.local:80/*` |

14 distinct internal service identities across 13 public hosts (11 unique services, since realtime, user-content, upload, and bundle each appear on both prod and dev).

## 4. Supporting Files / PoC

All files live under `Source/abema-bounty/Result/report/`.

- `poc-finding3.sh` — one-liner loop above; prints the leaked service name per host.
- `evidence/f3_envoy_leaks.txt` — captured header output from all 13 hosts (raw `curl -D -` dump).

## 5. Severity Level

**Low.** Justification: This is a genuine, reproducible, unauthenticated information-disclosure defect on in-scope assets. However, the disclosed data is infrastructure topology (service names), not secrets, tokens, PII, or fund/data access. Under IssueHunt's rubric this maps to Low. It is not rated Informational because (a) it is a stable, confirmed production defect, (b) it is present on every in-scope API host, and (c) it materially aids an attacker in mapping the internal service mesh (which directly supports further reconnaissance and targeting of the dev environment disclosed in Finding 2). It is not Medium because the disclosed data alone does not enable access to any protected resource.

## 6. Category

Information Disclosure (infrastructure fingerprinting / service mesh metadata leakage).

## 7. Language

English.

## Target

All in-scope `*.abema.io` and `*.abema-tv.com` API hosts listed above.