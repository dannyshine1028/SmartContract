#!/bin/bash
B=https://aiagent.atomicwork.com
for p in \
 /api/public/bootstrap /api/public/config /api/version /api/status /api/v1 /api/v1/ \
 /api/v1/chat /api/chat /api/agent /api/agents /api/agent/runs /api/runs \
 /api/threads /api/v1/threads /api/tools /api/mcp /api/v1/mcp /api/sse \
 /api/auth/login /api/auth/callback /api/auth/session /api/oauth/login \
 /api/users/me /api/me /api/config /api/openapi.json /api/swagger.json \
 /api/graphql /api/webhooks/slack /api/webhooks/teams /api/healthz /api/readyz \
 /api/internal/health /api/metrics; do
  out=$(curl -s -o /tmp/ap -w '%{http_code} %{content_type} %{size_download}' --max-time 12 -A 'Mozilla/5.0' "$B$p")
  printf '%-34s %s | %s\n' "$p" "$out" "$(head -c 110 /tmp/ap | tr '\n' ' ')"
done
