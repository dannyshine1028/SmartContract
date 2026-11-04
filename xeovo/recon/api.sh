#!/bin/bash
# usage: ./api.sh <jar> <absURL> [datafile]
J=$1; URL=$2; shift 2
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'
P=$(python3 -c "
import re,sys,urllib.request,http.cookiejar
cj=http.cookiejar.MozillaCookieJar('$J'); cj.load(ignore_discard=True,ignore_expires=True)
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
op.addheaders=[('User-Agent','$UA')]
r=op.open('$URL'.replace(\"'\",''),timeout=30)
print(r.status); print(r.read().decode('utf8','replace')[:60000])
" 2>/tmp/apierr.txt)
if [ -z "$P" ]; then echo "ERR:"; cat /tmp/apierr.txt | tail -3; fi
