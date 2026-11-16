/// ===========================================================================
/// PoC — F4: decimal re-scaling truncates silently to u64, and the Supra
///          parser's `u16 -> u8` decimals cast wraps and flips the scaling branch
/// Report: ../bucket-oracle-parsers-u128-to-u64-truncation-decimal-wrap.md
/// ===========================================================================
///
/// NO PATCH REQUIRED — this file needs no injector and touches no other file.
/// It is self-contained because the defect is an expression, not a call graph:
/// `sources/parser/supra_parser.move:12` and `:14-20`, and the same shape in
/// `switchboard_parser.move:24-30` and `pyth_parser.move:40-43 / 65-68`.
///
/// WHY THE PARSER FUNCTIONS THEMSELVES ARE NOT CALLED HERE: `supra_parser::parse_price`
/// reads through `SupraOracle::SupraSValueFeed::get_price`, which is declared
/// `native public fun` in the vendored interface — no `OracleHolder` can be built in a
/// unit test. The report says so rather than papering over it. What is executed below is
/// Move's own cast semantics applied to the identical expressions, plus the contrast with
/// the Pyth parser's u64 rescale, which fails differently.
///
/// RUN
///   cp Result\(report\)/poc/F4-parser-cast-truncation.move <oracle-repo>/sources/tests/
///   sui move test bucket_oracle::poc_f4
///
/// EXPECTED
///   poc_f4_u128_to_u64_cast_wraps_silently ............ PASS  (1e24 -> 2003764205206896640)
///   poc_f4_the_divide_branch_is_the_safe_one ........... PASS
///   poc_f4_decimal_u16_to_u8_wraps ..................... PASS  (256 -> 0, 264 -> 8)
///   poc_f4_wrapped_decimal_flips_the_scaling_branch .... PASS
///   poc_f4_checked_scaling_would_have_been_able_to_reject ..... PASS
///
/// BUILD NOTE (pre-existing, unrelated to this PoC): the audited sources call
/// `std::u64::pow(10, <u8 value>)` at `single_oracle.move:84`,
/// `supra_parser.move:15,17`, `pyth_parser.move:41,43,67,68`, and `sui::math::pow(10,
/// <u8>)` at `af_lp_rule.move:68`. The stdlib/math `pow` exponent is a u64, so those
/// call sites may be rejected by the current compiler. If `sui move test` fails there,
/// that is a property of the published mirror, not of this file, and it is a build issue
/// rather than a security finding (the program excludes compiler-version issues anyway).
/// This file therefore casts its own exponent to u64 so it stays runnable either way.

#[test_only]
module bucket_oracle::poc_f4 {
    /// Raw feed value; the parsers move it into the oracle's own decimal scale.
    const RAW: u128 = 1_000_000_000_000_000_000; // 1e18

    /// supra_parser.move:15-20 / switchboard_parser.move:27-30, required_decimal = 6.
    /// The exponent is cast to u64 here so this file compiles on its own; see the note at the
    /// bottom of this header about the same call sites in the audited sources.
    fun rescale_multiply(price: u128, source_decimals: u8, required_decimal: u8): u64 {
        let mut scaled = price;
        if (source_decimals > required_decimal) {
            scaled = scaled / (std::u64::pow(10, (source_decimals - required_decimal) as u64) as u128);
        } else {
            scaled = scaled * (std::u64::pow(10, (required_decimal - source_decimals) as u64) as u128);
        };
        (scaled as u64) // <-- no range check: this is the defect
    }

    /// The exact case from the report table: a feed whose decimals field says 0 while the
    /// oracle needs 6. 1e24 does not fit u64, so instead of an error the value is the low
    /// 64 bits of 1e24, i.e. wrong by roughly a factor of 10^6 — and it can be either
    /// above or below the true price, so nothing downstream treats it as suspicious.
    #[test]
    fun poc_f4_u128_to_u64_cast_wraps_silently() {
        let out = rescale_multiply(RAW, 0, 6);
        assert!(out == 2_003_764_205_206_896_640, 4001);
        // and the intermediate really did exceed u64 range on the way there
        let scaled = RAW * (std::u64::pow(10, 6 - 0) as u128);
        assert!(scaled > (std::u64::max_value!() as u128), 4002);
    }

    /// The divide branch cannot overflow, which is why the wrap only appears when the
    /// decimals comparison sends execution down the multiply side.
    #[test]
    fun poc_f4_the_divide_branch_is_the_safe_one() {
        let out = rescale_multiply(RAW, 8, 6); // 1e18 / 10^2
        assert!(out == 10_000_000_000_000_000, 4003);
    }

    /// `supra_parser.move:12` narrows the feed's decimals field without validation.
    #[test]
    fun poc_f4_decimal_u16_to_u8_wraps() {
        assert!((256u16 as u8) == 0, 4004);
        assert!((264u16 as u8) == 8, 4005);
        assert!((512u16 as u8) == 0, 4006);
        assert!((520u16 as u8) == 8, 4007);
    }

    /// The wrapped decimal also selects the wrong branch: a feed that should be divided
    /// down by 10^256-6 is multiplied instead, because 256 became 0.
    #[test]
    fun poc_f4_wrapped_decimal_flips_the_scaling_branch() {
        let source_decimals = (256u16 as u8);
        let required_decimal = 6u8;
        assert!(source_decimals < required_decimal, 4008); // multiply branch taken
        let out = rescale_multiply(1_000_000u128, source_decimals, required_decimal);
        // 1e6 * 1e6 = 1e12, fits u64, so no error is raised anywhere: a price that is
        // 10^6 too large, published as if it were valid.
        assert!(out == 1_000_000_000_000, 4009);
    }

    /// Contrast that proves the inconsistency is unintentional: the Pyth parser rescales
    /// in u64 (pyth_parser.move:41,43 and :67,68), so the same magnitude of overflow
    /// aborts the transaction instead of publishing a wrong number.
    #[test, expected_failure]
    fun poc_f4_pyth_style_u64_rescale_aborts_instead() {
        let price: u64 = 1_000_000_000_000_000_000; // 1e18
        let _overflow = price * std::u64::pow(10, 6); // u64 arithmetic error, not a wrap
    }
    /// Recommendation check: the guard that would close F4 costs one line, and this test
    /// shows what a checked version returns for the same input that wrapped above.
    #[test]
    fun poc_f4_checked_scaling_would_have_been_able_to_reject() {
        let scaled = RAW * (std::u64::pow(10, 6 - 0) as u128);
        let fits = scaled <= (std::u64::max_value!() as u128);
        assert!(!fits, 4010); // i.e. a single assertion here is enough to fail safe
    }
}
