#!/usr/bin/env bash
# ===========================================================================
# PoC — F5: four derivative-rule price writers need no capability, bind no
#          source object, and impose no deviation limit
# Report: ../bucket-oracle-rules-unbound-source-no-capability-no-deviation-limit.md
# ===========================================================================
#
# WHY THIS PoC IS NOT A MOVE TEST: reaching the rule writers requires live Volo /
# Aftermath / Haedal objects, and I will not present a mock third-party pool as if it
# were the deployed one. This script therefore does the two things that CAN be done
# rigorously:
#
#   [A] proves the structural asymmetry inside Bucket's own code (offline, decisive);
#   [B] answers the one question that decides High vs Critical — how many instances of
#       each source object exist on mainnet, and who owns them (needs network).
#
# RUN
#   bash "Result(report)/poc/F5-rules-source-object-check.sh" /path/to/oracle
#   RPC=https://fullnode.mainnet.sui.io:444 bash "$0" /path/to/oracle \
#       "0x<pkg>::native_pool::NativePool" "0x<pkg>::pool::Pool" ...
#
# Verdict rules
#   [A] must pass for the finding to stand at all.
#   [B] >1 presentable instance for any tag  -> Critical ($10,000 - $15,000): an
#       unprivileged caller chooses the price outright.
#   [B] exactly 1 shared instance each       -> High ($5,000 - $7,000): the price still
#       moves 1:1 with state the caller can influence (LP reserves, pool donation), with
#       no deviation cap and no authorisation on the write.
#   [B] not run                              -> submit as High with the open question
#       stated, exactly as the report's Section 4/5 already word it.

set -uo pipefail

REPO="${1:-./oracle}"
RPC="${RPC:-https://fullnode.mainnet.sui.io:444}"
shift 2>/dev/null || true
TAGS=("$@")

fail=0
say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; }
no()   { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fail=1; }
note() { printf '       %s\n' "$*"; }

say "[A] Structural asymmetry inside Bucket's own code ($REPO)"

# A1: the rule writer bypasses aggregation and stamps the clock itself.
sed -n '/public fun update_oracle_price_with_rule/,/^    }/p' "$REPO/sources/single_oracle.move" \
  > /tmp/f5_rule_writer 2>/dev/null || true
if [ -s /tmp/f5_rule_writer ] && grep -q "single_oracle.price = price" /tmp/f5_rule_writer; then
  ok "update_oracle_price_with_rule writes the price directly"
else no "could not locate the direct write in single_oracle.move"; fi
if grep -q "aggregate_price\|tolerance_ms\|threshold" /tmp/f5_rule_writer; then
  no "the rule writer does reference aggregation controls - re-check the claim"
else ok "the rule writer uses no aggregation, tolerance or threshold control"; fi

# A2: it is plain public, not friend-restricted.
if grep -q "public(friend) fun update_oracle_price_with_rule" "$REPO/sources/single_oracle.move"; then
  no "the writer is friend-restricted; F5 reachability claim must be revised"
else ok "the writer is plain public"; fi

# A3: per-rule capability / source binding / allowlist.
for f in "$REPO"/rules/*/sources/*.move; do
  grep -q "update_oracle_price_with_rule" "$f" || continue
  name="$(basename "$f")"
  cap=no; bind=no; allow=no
  grep -q "AdminCap" "$f" && cap=yes
  grep -q "object::id" "$f" && bind=yes
  grep -q "scoin_pairs\|exists_pair" "$f" && allow=yes
  if [ "$allow" = yes ]; then
    ok "$name: pair allowlist enforced (this is the control the others lack)"
  elif [ "$cap" = yes ] || [ "$bind" = yes ]; then
    ok "$name: some control present (cap=$cap bind=$bind)"
  else
    note "$name: AdminCap=$cap  source object-ID binding=$bind  deviation limit=none"
    case "$name" in
      vsui_rule.move|hasui_rule.move|afsui_rule.move|af_lp_rule.move)
        ok "$name: no capability, no source binding, no deviation cap -> unbound writer" ;;
      *) note "$name: not one of the four reported rules; ignored" ;;
    esac
  fi
done

# A4: the primary feeds DO bind their source objects, which is the comparison that
# makes the omission look like an oversight rather than a design choice.
bound=$(grep -c "EWrongSourceConfig" "$REPO/sources/single_oracle.move")
if [ "${bound:-0}" -ge 4 ]; then
  ok "primary feeds enforce source binding ($bound sites: :121 :152 :169 :195)"
else no "unexpected number of binding sites ($bound) - re-verify before submitting"; fi
note "caveat: :195 binds only Supra's pair_id, not the OracleHolder object"

# ---------------------------------------------------------------------------
say ""
say "[B] Mainnet instance counts (the High vs Critical question)"
if [ "${#TAGS[@]}" -eq 0 ]; then
  note "no struct tags supplied -> step [B] skipped."
  note "fill these from the deployed packages (Move.toml of each rule, or the"
  note "app's object list) and re-run; do NOT paste addresses from memory."
  note "  Volo     :: native_pool::NativePool   + volo::cert::Metadata<CERT>"
  note "  Aftermath:: pool::Pool<...LP...>      + safe::Safe<TreasuryCap<AFSUI>>"
  note "  Haedal   :: staking::Staking"
  note "  Pyth     :: price_info::PriceInfoObject (for the :195 comparison)"
else
  for tag in "${TAGS[@]}"; do
    json=$(curl -s --max-time 25 -X POST "$RPC" -H 'Content-Type: application/json' \
      -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"sui_getObjectsByStruct\",\"params\":[\"$tag\"]}")
    echo "$json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
if "error" in d:
    print("       %s -> RPC error: %s (try suix_getObjectsByStruct / an indexer)"
          % (sys.argv[1], d["error"].get("message","?")))
else:
    r=d.get("result") or []
    ids=r if isinstance(r,list) else []
    print("       %s -> %d instance(s)%s" % (sys.argv[1], len(ids),
          "  <-- MORE THAN ONE: F5 is Critical" if len(ids)>1 else ""))
    for i in ids[:5]: print("         ", i)
' "$tag" || note "$tag -> unparsable response"
  done
  note "then check ownership of each id:  sui client object <id>   (showOwner)"
  note "an object owned by the protocol multisig is not presentable by an attacker;"
  note "a transferable/creatable one is."
fi

say ""
if [ "$fail" -eq 0 ]; then
  say "[A] PASSED — the code-side claim of F5 holds. Complete [B] before choosing severity."
else
  say "[A] FAILED — do not submit F5; a premise no longer matches the tree you have."
fi
exit "$fail"
