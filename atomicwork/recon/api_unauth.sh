#!/bin/bash
B=https://atomicwork.atomicwork.com
t() { m=$1; p=$2; shift 2; out=$(curl -s -o /tmp/e -w '%{http_code} %{content_type}' --max-time 10 -A 'Mozilla/5.0' -X "$m" "$@" "$B$p"); printf '%-6s %-40s %s | %s\n' "$m" "$p" "$out" "$(head -c 110 /tmp/e | tr '\n' ' ')"; }
t GET /api/intercom/hash
t POST /api/intercom/hash -H 'content-type: application/json' -d '{"email":"a@b.com"}'
t GET '/api/v1/realtime/auth/token'
t POST '/api/v1/realtime/auth/token' -H 'content-type: application/json' -d '{}'
t GET '/api/attachments/as-link?key=x'
t POST /api/attachments/as-link -H 'content-type: application/json' -d '{}'
t GET '/api/attachments?key=x'
t POST /api/attachments -H 'content-type: application/json' -d '{}'
t GET '/api/v2/attachments/upload-for-field'
t POST /api/v2/attachments/upload-for-field -H 'content-type: application/json' -d '{}'
t GET '/api/requests'
t POST /api/code-execute -H 'content-type: application/json' -d '{}'
t GET '/api/atom/starter-prompts'
t GET '/api/public/bootstrap'
