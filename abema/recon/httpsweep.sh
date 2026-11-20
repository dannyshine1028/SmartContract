#!/bin/bash
cd /home/user/Documents/Work/Guk/3.BugBounty/Source/abema/recon
: > http_scan.tsv
while read h; do
  grep -q "^$h\b" http_scan.tsv 2>/dev/null && continue
  r=$(curl -sS -m 10 -o /tmp/hb.out -D /tmp/hb.hdr -w "%{http_code}|%{size_download}|%{redirect_url}" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" "https://$h/" 2>/dev/null)
  srv=$(grep -i "^server:" /tmp/hb.hdr 2>/dev/null | tail -1 | tr -d '\r' | cut -d' ' -f2- | cut -c1-40)
  cty=$(grep -i "^content-type:" /tmp/hb.hdr 2>/dev/null | tail -1 | tr -d '\r' | cut -d' ' -f2- | cut -c1-30)
  ttl=$(grep -oiE "<title[^>]*>[^<]{0,60}" /tmp/hb.out 2>/dev/null | head -1 | sed 's/<title[^>]*>//I' | tr -d '\t')
  printf "%s\t%s\tsrv=%s\tct=%s\tt=%s\n" "$h" "$r" "$srv" "$cty" "$ttl" >> http_scan.tsv
done < hosts.txt
echo DONE >> http_scan.tsv
