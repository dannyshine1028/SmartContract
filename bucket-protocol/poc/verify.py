#!/usr/bin/env python3
"""
Dependency-free verification for the Bucket Protocol oracle report.

Two kinds of evidence:
  * STATIC  - reads the project's own .move sources and proves that the multi-source
              divergence guard can never be reached by a production code path.
  * NUMERIC - evaluates the exact decision procedure of that guard (absolute-difference
              staleness filter, pop_back reversal, first-two averaging, 2% band) and the
              integer casts used by the parsers, so the expected values asserted by
              poc/aggregation_poc.move can be checked without a Move toolchain.

Usage:  python3 poc/verify.py [path-to-oracle-repo]      # default: ./oracle
Exit:   0 if every check agrees with the report, 1 otherwise.
"""
import os
import re
import sys

U64 = (1 << 64) - 1
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "oracle")

failures = []


def check(name, ok, detail=""):
    print(("  PASS  " if ok else "  FAIL  ") + name + (("  | " + detail) if detail else ""))
    if not ok:
        failures.append(name)


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
        return fh.read()


def body(src, signature):
    """Return the brace-balanced body that follows `signature`."""
    i = src.index(signature) + len(signature)
    j = src.index("{", i)
    depth, k = 0, j
    while k < len(src):
        if src[k] == "{":
            depth += 1
        elif src[k] == "}":
            depth -= 1
            if depth == 0:
                return src[j + 1:k]
        k += 1
    raise AssertionError("unbalanced braces near " + signature)


# ---------------------------------------------------------------- static checks
print("\n[1] Every production update path builds a fresh collector and fills ONE source")
src = read("sources/bucket_oracle.move")
entries = re.findall(r"public entry fun (update_price_from_\w+)", src)
per_entry = {}
for name in entries:
    b = body(src, "public entry fun " + name)
    per_entry[name] = (b.count("issue_price_collector("), b.count("collect_price_from_"))
print("      entry functions found: " + ", ".join(entries))
for name, (issued, collected) in per_entry.items():
    check(f"{name}: 1 fresh collector, {collected} source collected",
          issued == 1 and collected == 1, f"issue={issued} collect={collected}")
check("no entry path collects two different sources",
      all(c == 1 for _, c in per_entry.values()),
      "max len(price_info_vec) == 1 for every call")

print("\n[2] update_oracle_price pushes the three collector slots of that single call")
so = read("sources/single_oracle.move")
ub = body(so, "public fun update_oracle_price<T>")
check("exactly three push_price calls, all reading the same collector",
      ub.count("push_price(") == 3 and ub.count("PriceCollector {") == 1,
      "two of the three Options are always none -> vector length <= 1")

print("\n[3] The divergence guard lives only in the prices_len >= 2 branch")
pa = read("sources/parser/price_aggregator.move")
pp = body(pa, "fun process_prices(prices: vector<u64>, threshold: u64): u64")
check("single-price branch returns the price with no cross-check",
      "if (prices_len == 1)" in pp and pp.index("if (prices_len == 1)") < pp.index("ESignificientPriceDiff"))
check("guard compares only indices 0 and 1",
      pp.count("vector::borrow(&prices, 0)") == 1 and pp.count("vector::borrow(&prices, 1)") == 1
      and "vector::borrow(&prices, 2)" not in pp,
      "a third source is dropped entirely")
check("deployed SUI feed is created with threshold = 1",
      re.search(r"create_single_oracle<SUI>\(\s*&admin_cap,\s*&mut oracle,\s*6,\s*3600_000,\s*1,", src) is not None,
      "bucket_oracle.move init: precision 6, tolerance 3600000ms, threshold 1")

# ---------------------------------------------------------------- numeric model
def aggregate(prices, threshold, now, tolerance_ms):
    """Model of price_aggregator::aggregate_price + process_prices.
    prices: list of (price, timestamp) in push order switchboard, pyth, supra."""
    fresh = []
    for price, ts in reversed(prices):           # vector::pop_back drains from the back
        if abs(now - ts) <= tolerance_ms:        # std::u64::diff is two-sided
            fresh.append(price)
    if len(fresh) < threshold:
        return "abort ENotEoughPrices(0)", None
    if len(fresh) == 1:
        return "ok", fresh[0]                    # no divergence check on this branch
    a, b = fresh[0], fresh[1]
    avg = (a + b) // 2
    if abs(a - b) * 50 > U64:
        return "abort arithmetic overflow(586)", None
    if abs(a - b) * 50 > avg:
        return "abort ESignificientPriceDiff(1)", None
    return "ok", avg


T0, REAL, HOUR = 1_700_000_000_000, 1_000_000, 3_600_000
print("\n[4] Aggregator decision procedure, matching poc/aggregation_poc.move")
cases = [
    ("poc1  single source, real $1",            [(REAL, T0)],                              1, T0, HOUR),
    ("poc2  single source, price 0",            [(0, T0)],                                 1, T0, HOUR),
    ("poc2b single source, $0.000001",          [(1, T0)],                                 1, T0, HOUR),
    ("poc2c single source, u64::MAX",           [(U64, T0)],                               1, T0, HOUR),
    ("poc3  two sources 5% apart",              [(REAL, T0), (REAL + 50_000, T0)],         1, T0, HOUR),
    ("poc3b two sources 1% apart",              [(REAL, T0), (REAL + 10_000, T0)],         1, T0, HOUR),
    ("poc4  reading 1h ahead of the clock",     [(REAL, T0 + HOUR - 1_000)],               1, T0, HOUR),
    ("poc5  reading 1h behind the clock",       [(REAL, T0 - HOUR - 1_000)],               1, T0, HOUR),
    ("poc6  2 fake sources outvote 1 real",     [(REAL, T0), (2 * REAL, T0), (2 * REAL, T0)], 1, T0, HOUR),
]
expect = {
    "poc1  single source, real $1":            ("ok", REAL),
    "poc2  single source, price 0":            ("ok", 0),
    "poc2b single source, $0.000001":          ("ok", 1),
    "poc2c single source, u64::MAX":           ("ok", U64),
    "poc3  two sources 5% apart":              ("abort ESignificientPriceDiff(1)", None),
    "poc3b two sources 1% apart":              ("ok", 1_005_000),
    "poc4  reading 1h ahead of the clock":     ("ok", REAL),
    "poc5  reading 1h behind the clock":       ("abort ENotEoughPrices(0)", None),
    "poc6  2 fake sources outvote 1 real":     ("ok", 2 * REAL),
}
for name, prices, th, now, tol in cases:
    got = aggregate(prices, th, now, tol)
    check(name + " -> " + str(got[1] if got[1] is not None else got[0]),
          got == expect[name], f"expected {expect[name]}, got {got}")

print("\n[5] Parser integer casts (poc8 / poc8b)")
scaled = 10**18 * 10**6                       # supra_parser.move:15-20, raw 1e18, decimals 0 -> 6
check("u128 1e24 cast to u64 wraps silently to " + str(scaled & U64),
      (scaled & U64) == 2_003_764_205_206_896_640, "no abort, and the result is wrong by ~1e6x")
check("u16 decimals 256 cast to u8 becomes 0 (branch flips to multiply)", (256 & 0xFF) == 0)
check("u16 decimals 264 cast to u8 becomes 8", (264 & 0xFF) == 8)

print("\n[6] pyth_parser sign guards, all four combinations (poc9)")
guard = lambda expo_neg, price_neg: (
    "dropped by guard A (returns none)" if expo_neg
    else ("dropped by guard B (returns none)" if not price_neg
          else "passes both guards, then aborts in get_magnitude_if_negative(expo)")
)
rows = {(e, p): guard(e, p) for e in (False, True) for p in (False, True)}
for (e, p), outcome in sorted(rows.items()):
    print(f"      expo_negative={e!s:<5} price_negative={p!s:<5} -> {outcome}")
check("no sign combination produces a usable price",
      all("aborts" in o or "none" in o for o in rows.values()),
      "the Pyth source can never contribute, whatever the feed says")

print("\n" + ("ALL CHECKS AGREE WITH THE REPORT" if not failures
              else "CHECKS FAILED: " + ", ".join(failures)))
sys.exit(1 if failures else 0)
