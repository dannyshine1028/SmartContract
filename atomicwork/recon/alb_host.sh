#!/bin/bash
# ALB Host-header routing probe for internal.ext.atomicwork.com
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
IPS="18.207.60.51 52.204.150.142 54.221.246.68"
SNIS="internal.ext.atomicwork.com internal-ca.ext.atomicwork.com"
HOSTS="internal.ext.atomicwork.com internal-ca.ext.atomicwork.com internal.atomicwork.com admin.internal.atomicwork.com grafana.internal.atomicwork.com teleport.internal.atomicwork.com argocd.internal.atomicwork.com jenkins.internal.atomicwork.com internal.usw2.atomicwork.com atomicwork.atomicwork.com aiagent.atomicwork.com"
PATHS="/ /healthz /api/health /robots.txt /favicon.ico /login"
run(){ # ip sni host path
  local ip="$1" sni="$2" host="$3" path="$4"
  local r
  r=$(curl -sk --max-time 10 --resolve "$sni:443:$ip" -H "Host: $host" -A "$UA" \
       -D /tmp/alb.hdr -o /tmp/alb.body \
       -w '%{http_code} %{size_download} %{content_type}' "https://$sni$path")
  local loc srv
  loc=$(grep -i '^location:' /tmp/alb.hdr | tr -d '\r' | cut -c1-120)
  srv=$(grep -i '^server:' /tmp/alb.hdr | tr -d '\r')
  printf '%-15s %-38s %-26s %-45s | %s %s %s\n' "$ip" "$host" "$path" "$r" "$srv" "$loc" "$(head -c 80 /tmp/alb.body | tr -d '\r\n')"
}
for ip in $IPS; do
  for sni in $SNIS; do
    for h in $HOSTS; do
      for pth in $PATHS; do
        run "$ip" "$sni" "$h" "$pth"
      done
    done
  done
done
