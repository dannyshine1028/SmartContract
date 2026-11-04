#!/bin/bash
# usage: ./login.sh <user> <pass> <jarfile>
U=$1; P=$2; J=$3
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'
rm -f $J
T=$(curl -s -m 20 -A "$UA" -c $J "https://xeovo.com/login/" | grep -o 'name="csrfmiddlewaretoken" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"//')
curl -s -m 25 -A "$UA" -b $J -c $J -o /tmp/l_$J.html -w "login:%{http_code} %{url_effective}\n" -L \
  --data-urlencode "csrfmiddlewaretoken=$T" --data-urlencode "username=$U" --data-urlencode "password=$P" --data-urlencode "next=/dashboard/" \
  -e "https://xeovo.com/login/" "https://xeovo.com/login/"
grep -o '<title>[^<]*</title>' /tmp/l_$J.html | head -1
