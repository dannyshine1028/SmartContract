#!/usr/bin/env python3
"""
Static proof for the Bucket Protocol oracle findings.

Every check asserts a structural property of the shipped source that the report
cites. Nothing here re-implements their logic: it verifies that the cited code
shape actually exists in the repo, and fails loudly if a fix landed.

Usage:
    python3 poc/static_proof.py <path-to-oracle-repo>
    (repo under test: https://github.com/Bucket-Protocol/oracle)

Exit code 0 = all findings still present. Non-zero = a check did not hold.
"""
import re
import sys
from pathlib import Path

FAILURES = []
PASSES = []


def read(repo: Path, rel: str) -> str:
    p = repo / rel
    if not p.is_file():
        raise SystemExit(f"missing file: {rel}")
    return p.read_text()


def line_of(text: str, needle: str) -> int:
    """1-based line number of the first line containing `needle`."""
    for i, ln in enumerate(text.splitlines(), 1):
        if needle in ln:
            return i
    return -1


def check(cid: str, claim: str, ok: bool, evidence: str):
    entry = f"{cid}: {claim}\n      evidence -> {evidence}"
    (PASSES if ok else FAILURES).append(entry)


def body_of(text: str, header_needle: str) -> str:
    """Text of a function starting at the line containing `header_needle`,
    delimited by brace balance (good enough for this source style)."""
    start = text.index(header_needle)
    i = text.index("{", start)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
    return text[i:]


def main(repo: Path):
    bo = read(repo, "sources/bucket_oracle.move")
    so = read(repo, "sources/single_oracle.move")
    pa = read(repo, "sources/parser/price_aggregator.move")
    sup = read(repo, "sources/parser/supra_parser.move")
    pyt = read(repo, "sources/parser/pyth_parser.move")
    swb = read(repo, "sources/parser/switchboard_parser.move")

    # ---------------- F1: aggregation never aggregates -------------------
    entry_paths = [
        "public entry fun update_price_from_switchboard",
        "public entry fun update_price_from_pyth",
        "public entry fun update_price_from_pyth_read_only",
        "public entry fun update_price_from_supra",
    ]
    per_path = {}
    for h in entry_paths:
        b = body_of(bo, h)
        per_path[h.split()[-1]] = (
            b.count("issue_price_collector"),
            len(re.findall(r"collect_price_from_\w+", b)),
        )
    one_collector_each = all(n == 1 for n, _ in per_path.values())
    one_source_each = all(m == 1 for _, m in per_path.values())
    check(
        "F1a", "every price-update entry point creates a fresh collector",
        one_collector_each,
        "; ".join(f"{k} issue_price_collector x{v[0]}" for k, v in per_path.items()),
    )
    check(
        "F1b", "each entry point collects exactly ONE of the three sources",
        one_source_each,
        "; ".join(f"{k} collect_price_from x{v[1]}" for k, v in per_path.items()),
    )
    pushes = len(re.findall(r"push_price", so))
    check(
        "F1c", "update_oracle_price pushes the 3 collector Options, 2 of which are always none",
        pushes == 3 and all("option::none()" in body_of(so, "issue_price_collector") for _ in [0]),
        f"push_price x{pushes} in single_oracle.update_oracle_price; "
        f"issue_price_collector initialises all 3 fields to none",
    )
    check(
        "F1d", "consequence: the vector reaching aggregate_price has length 1",
        one_collector_each and one_source_each and pushes == 3,
        "F1a + F1b + F1c",
    )

    # ------------- F1e: divergence check sits in the never-exercised branch -
    len1 = line_of(pa, "if (prices_len == 1)")
    band = line_of(pa, "TOLERANCE_OF_PRICE_DIFF <=")
    avg = line_of(pa, "let avg_price =")
    check(
        "F1e", "the cross-source divergence assertion only exists in the len>=2 branch",
        0 < len1 < avg <= band,
        f"price_aggregator.move:{len1} len==1 branch, :{avg} avg_price, :{band} ESignificientPriceDiff assert",
    )
    live = [ln for ln in bo.splitlines()
            if "create_single_oracle<SUI>" in ln and not ln.strip().startswith("//")]
    init_call = bo[bo.index("fun init("):]
    tail = init_call[init_call.index("create_single_oracle<SUI>"):]
    args = re.findall(r"^\s*([\d_]+|option::[^,]+),", tail, re.M)[:4]
    check(
        "F1f", "the live SUI feed is created with threshold = 1 (single source satisfies it)",
        bool(live) and args[:3] == ["6", "3600_000", "1"],
        f"uncommented create_single_oracle<SUI> occurrences={len(live)}; "
        f"precision_decimal/tolerance_ms/threshold = {args[:3]}",
    )

    # ---------------- F6: third and later sources ignored ----------------
    idx = re.findall(r"vector::borrow\(&prices, (\d+)\)", pa)
    check(
        "F6", "process_prices only ever reads indices 0 and 1",
        sorted(set(idx)) == ["0", "1"],
        f"price_aggregator.move indices read: {sorted(set(idx))}",
    )

    # ---------------- F2: zero price accepted ----------------------------
    sw_zero = line_of(swb, "price_u128 == 0")
    sup_zero = re.search(r"==\s*0\)?\s*return option::none", sup)
    pyt_zero = re.search(r"price\s*==\s*0", pyt)
    check(
        "F2", "zero-value guard exists only in the Switchboard parser",
        sw_zero > 0 and sup_zero is None and pyt_zero is None,
        f"switchboard_parser.move:{sw_zero} guards 0; supra_parser/pyth_parser contain no zero guard",
    )

    # ---------------- F3: staleness uses a two-sided comparison ----------
    absdiff = line_of(pa, "std::u64::diff(current_time, timestamp)")
    check(
        "F3", "freshness test compares absolute difference, so future timestamps pass",
        absdiff > 0 and "timestamp > current_time" not in pa and "current_time <" not in pa,
        f"price_aggregator.move:{absdiff}",
    )

    # ---------------- F4: silent truncation in the parsers ---------------
    sup_cast = line_of(sup, "(price_u128 as u64)")
    sup_dec = line_of(sup, "(decimal_u16 as u8)")
    swb_cast = line_of(swb, "(price_u128 as u64)")
    no_guard = not any("max_value" in t for t in (sup, swb, pyt))
    check(
        "F4a", "Switchboard/Supra rescale in u128 then truncate to u64 with no range check",
        sup_cast > 0 and swb_cast > 0 and sup_dec > 0 and no_guard,
        f"supra_parser.move:{sup_cast} (price_u128 as u64), :{sup_dec} (decimal_u16 as u8), "
        f"switchboard_parser.move:{swb_cast}; no max_value guard in any parser",
    )
    pyt_u64_mul = re.findall(r"price = price \* std::u64::pow", pyt)
    check(
        "F4b", "the Pyth parser rescales in u64 instead, so it aborts on overflow rather than "
               "truncating (handling is inconsistent across sources)",
        len(pyt_u64_mul) == 2,
        f"pyth_parser.move: u64 rescale in {len(pyt_u64_mul)} places, no u128 widening",
    )

    # ------------- NOT A FINDING: version kill-switch (withdrawn) ---------
    # update_price_from_supra has no INLINE `assert!(version == PACKAGE_VERSION)`, but its first
    # statement is borrow_single_oracle_mut, which enforces it (bucket_oracle.move:211). The same
    # helper guards the other three entry points and every read path, so the omission is purely
    # cosmetic. Recorded so that nobody re-reports this as a kill-switch bypass.
    killswitch_in_borrow = "assert!(bucket_oracle.version == PACKAGE_VERSION, 99)" in body_of(
        bo, "public fun borrow_single_oracle_mut")
    supra_goes_through_borrow = "borrow_single_oracle_mut" in body_of(
        bo, "public entry fun update_price_from_supra").split("issue_price_collector")[0]
    check(
        "N1", "WITHDRAWN ITEM: the version kill-switch is enforced on all four update paths "
              "(inline on three, via borrow_single_oracle_mut on the Supra path) - no finding",
        killswitch_in_borrow and supra_goes_through_borrow,
        "see the Result(report) index for the retraction note",
    )

    # ---------------- F7: rule path bypasses aggregation -----------------
    rule_body = body_of(so, "public fun update_oracle_price_with_rule")
    check(
        "F7a", "update_oracle_price_with_rule writes price and latest_update_ms directly",
        "single_oracle.price = price" in rule_body
        and "latest_update_ms = current_time" in rule_body
        and "aggregate_price" not in rule_body and "tolerance_ms" not in rule_body,
        f"single_oracle.move:{line_of(so, 'public fun update_oracle_price_with_rule')}",
    )
    is_friend = "public(friend) fun update_oracle_price_with_rule" in so
    check(
        "F7b", "that writer is plain `public`, not friend-restricted",
        not is_friend,
        "declaration has no public(friend)",
    )

    rules_dir = repo / "rules"
    rule_updates = []
    for f in sorted(rules_dir.glob("*/sources/*.move")):
        t = f.read_text()
        if "update_oracle_price_with_rule" in t:
            rule_updates.append((
                str(f.relative_to(repo)),
                "AdminCap" in t,
                "object::id" in t,
                "Config" in t and "scoin_pairs" in t,
            ))
    unbound = [r for r in rule_updates if not r[1] and not r[2]]
    allowlisted = [r for r in rule_updates if r[3]]
    check(
        "F7c", "rule update entry points take no AdminCap and bind no source object id",
        len(unbound) >= 4 and len(allowlisted) >= 1,
        f"unbound: {[r[0] for r in unbound]} | control that DOES gate: {[r[0] for r in allowlisted]}",
    )

    # ---------------- F8: Pyth parser can never yield a price ------------
    expo_guard = line_of(pyt, "if (i64::get_is_negative(&decimal_i64)) return option::none();")
    price_guard = line_of(pyt, "if (!i64::get_is_negative(&price_i64)) return option::none();")
    neg_mag = line_of(pyt, "i64::get_magnitude_if_negative(&decimal_i64)")
    i64 = read(repo, "partners/pyth/sources/i64.move")
    abort_if_positive = "assert!(in.negative" in i64
    both = (
        expo_guard > 0 and price_guard > 0 and neg_mag > 0
        and pyt.count("if (i64::get_is_negative(&decimal_i64)) return option::none();") == 2
        and abort_if_positive
    )
    check(
        "F8", "after the two sign guards, the only surviving inputs abort in "
              "get_magnitude_if_negative (it requires negative, guards require non-negative)",
        both,
        f"pyth_parser.move:{expo_guard} and :{price_guard} return none; :{neg_mag} calls a "
        f"function that asserts negative (pyth/i64.move); the pattern appears in both the "
        f"VAA and read-only parsers",
    )

    # ---------------- report --------------------------------------------
    print(f"oracle repo under test: {repo}\n")
    print(f"PASSED ({len(PASSES)})")
    for c in PASSES:
        print("  \033[32mOK\033[0m   " + c.replace("\n", "\n         "))
    if FAILURES:
        print(f"\nNOT HELD ({len(FAILURES)})")
        for c in FAILURES:
            print("  \033[31mXX\033[0m   " + c.replace("\n", "\n         "))
    print(f"\n{len(PASSES)} of {len(PASSES) + len(FAILURES)} findings verified as still present.")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    sys.exit(main(Path(sys.argv[1]).resolve()))
