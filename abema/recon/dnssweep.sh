#!/bin/bash
cd /home/user/Documents/Work/Guk/3.BugBounty/Source/abema/recon
: > dns_scan.tsv
while read h; do
  cn=$(timeout 6 dig +short CNAME "$h" 2>/dev/null | tr '\n' ' ')
  ip=$(timeout 6 dig +short A "$h" 2>/dev/null | tr '\n' ' ')
  tgt="${cn}${ip}"
  if [ -z "$tgt" ]; then st="NX"; else st="OK"; fi
  # check whether the CNAME target itself resolves
  dead=""
  if [ -n "$cn" ]; then
    last=$(echo "$cn" | awk '{print $NF}')
    t=$(timeout 6 dig +short A "$last" 2>/dev/null | tr '\n' ' ')
    [ -z "$t" ] && dead="DEAD-TARGET:$last"
  fi
  printf "%s\t%s\t%s\t%s\t%s\n" "$h" "$st" "$cn" "$ip" "$dead" >> dns_scan.tsv
done < hosts.txt
echo DONE $(wc -l < dns_scan.tsv)
