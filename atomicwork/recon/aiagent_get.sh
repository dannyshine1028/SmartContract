#!/bin/bash
cd /home/user/Documents/Work/Guk/3.BugBounty/Source/atomicwork/recon
mkdir -p aiagent
curl -s --max-time 20 -A 'Mozilla/5.0' https://aiagent.atomicwork.com/ -o aiagent/index.html
echo "size: $(wc -c < aiagent/index.html)"
echo "== bootstrap on aiagent"; curl -s -o /tmp/ab -w '%{http_code}\n' --max-time 15 -A 'Mozilla/5.0' https://aiagent.atomicwork.com/api/public/bootstrap; head -c 300 /tmp/ab; echo
echo "== chunk refs"
grep -oE '/_next/static/[^"'"'"']+' aiagent/index.html | sort -u | head -30
