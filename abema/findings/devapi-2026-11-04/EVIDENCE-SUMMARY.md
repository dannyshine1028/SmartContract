# Evidence summary — ABEMA non-production catalog API exposed without authentication

Captured 2026-11-04 00:59–01:04 UTC (server `date:` headers quoted per file).
Egress during the window: 152.232.60.10 (also 209.58.188.249 seen from an IP echo in the same
session — this workstation's outbound address is pooled).
All requests were plain `GET`, ~15 in total, no authentication of any kind was presented, no scanner,
no write/state-changing request.

## Target (in scope)

`https://dev-api.d-c3-e.abema-tv.com` — matches the program scope row
"Web Service, REST Api: `*.abema.io, *.abem.io, *.abema-tv.com, *.abema-tv.org`".

## What the unauthenticated responses contain

| file | request | result |
|---|---|---|
| `dev_channels.json` / `.hdr` | `GET /v1/channels` | 200, 29,951 B — 57 channels, of which **48 do not exist in the production catalogue** |
| `dev_slots.json` / `.hdr` | `GET /v1/broadcast/slots` | 200, 62–74 KB — 27–32 slots, **24–29 titled `【IDS】…` / `【IGQ】…`** (internal QA test cases), **0 title overlap with the public production schedule** |
| `dev_media_slot.json` / `.hdr` | `GET /v1/media/slots/8WB9VpHQ7V83dy` | 200, 3,533 B — full media config of an internal test slot, incl. dev delivery origins and playlist URL templates |
| `prod_media_slot.json` | `GET https://api.abema.io/v1/media/slots/8WB9VpHQ7V83dy` | **404 `{"message":"Not Found"}`** — the same slot id is not public |
| `dev_neg_control.json` / `.hdr` | `GET /v1/me` | **401 `{"message":"authorization header must exist"}`** — the dev gateway *does* have the auth gate; the catalogue routes are exempt |
| `dev_version.json` | `GET /version` | 200 `{"branch":"HEAD","hash":"batch/v20261030061019.80bba2df16","timestamp":"2026-10-30T06:11:10Z"}` |
| `prod_channels.json`, `prod_slots.json`, `prod_version.json` | production comparison | 200 — used only to prove the dev/prod difference |
| `browser-dev-api-channels.png` | browser, no login | screenshot of the JSON as rendered in a normal browser address bar |

Dev-only channel ids (from `dev_channels.json` vs `prod_channels.json`):

```
Smaqtest, Smaqtest2, aaa, abema-activation, ameba-radio, anime24, club-tb, documentary,
everybody-anime, family-anime, fishing-vision, fujiwo-test, gemma, global-test, gold-temp,
hato-chan1..7, ids-cm-maine, ito-test002, live-test, mahjong-ch, midnight-anime, news-emergency,
pd-test, personalizedAd1..5, qa-drm, qa-drm-personal, qa-drm2, soccer, space-shower,
special-plus-2, spotlive-test, suga-test, test---1111, test-ch, thorhammer, variety-ch,
yospace01, yospace02
```

Internal / non-public infrastructure disclosed inside those bodies:

```
https://dev-linear-abematv.akamaized.net/channel/<id>/{playlist.m3u8,manifest.mpd}   (+ /preview/channel/…)
https://dev-vod-abematv.akamaized.net/slot/<id>/{playlist.m3u8,manifest.mpd}         (+ /preview/slot/…, /chase/slot/…)
https://dev-ds-vod-abematv.akamaized.net/{slot,chase,preview}/<id>/playlist.m3u8?%3Fvvvv=true
https://image.d-c2-x.abema-tv.com/media/slots/<id>/<hash>/timeline                   (timelineThumbComponent.urlPrefix)
https://dev.abema.tv/channels/<id>/slots/<id>                                        (share links for every slot)
chasePlayFeatureAuthorityIds: ["454e7b49-68ee-4a9b-a9d5-be557a5244e3"]               (internal feature-authority id)
skipVmap, playbackMarkers, download.retentionHours, broadcastRegionPolicies          (entitlement/test parameters)
```

Response headers on the dev gateway (`dev_channels.hdr`, `dev_slots.hdr`):

```
server: istio-envoy
x-envoy-decorator-operation: abema-catalog-api.default.svc.cluster.local:8000/*
via: 1.1 google
```

## Not claimed / not done

* **No request was made to any `*.akamaized.net` host.** That domain is not one of the program's
  target domains, so the dev delivery origins were left untouched. Consequently this report does **not**
  claim that any internal stream, manifest or media file is actually playable or downloadable.
* No credentials, tokens, PII or customer data were obtained. The `credit.casts` free-text fields in
  test slots were not reproduced in this report.
* Production `api.abema.io/v1/channels` and `/v1/broadcast/slots` being unauthenticated is **already
  reported separately as #290** and is not claimed here. The finding here is the *non-production*
  environment answering with *internal* data.
* Nothing was written, modified, or deleted; only `GET`.
