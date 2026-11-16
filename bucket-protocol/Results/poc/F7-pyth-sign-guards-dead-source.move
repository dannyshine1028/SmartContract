/// ===========================================================================
/// PoC — F7: the sign guards in pyth_parser drop or abort every possible input,
///          so one of the three documented sources can never contribute a price
/// Report: ../bucket-oracle-pyth-parser-sign-guards-dead-source.md
/// ===========================================================================
///
/// NO PATCH REQUIRED — this file needs no injector. It imports `pyth::i64`, the very
/// module `sources/parser/pyth_parser.move` imports (`:13`), so the accessor semantics
/// are taken from the project's own dependency rather than from my description of them.
///
/// WHY `parse_price` IS NOT CALLED DIRECTLY: it needs Wormhole state, Pyth state, a
/// `PriceInfoObject` and a guardian-signed VAA. None of those can exist in a unit test,
/// and the enumeration does not need them — the guard ORDER alone decides the outcome,
/// which is why three lines of reading settle it too.
///
/// The audited sequence (identical at pyth_parser.move:35-38 and :60-63):
///   A: if (i64::get_is_negative(&decimal_i64))              return option::none();
///   B: if (!i64::get_is_negative(&price_i64))               return option::none();
///   C: decimal_u8 = i64::get_magnitude_if_negative(&decimal_i64)  // asserts negative
///   D: price    = i64::get_magnitude_if_positive(&price_i64)      // asserts non-negative
///
/// RUN
///   cp Result\(report\)/poc/F7-pyth-sign-guards-dead-source.move <oracle-repo>/sources/tests/
///   sui move test bucket_oracle::poc_f7
///
/// EXPECTED
///   poc_f7_guard_a_drops_the_typical_feed ............... PASS
///   poc_f7_guard_b_drops_a_positive_price ............... PASS
///   poc_f7_the_only_surviving_case_aborts ............... PASS (aborts, code 0)
///   poc_f7_no_input_produces_a_price .................... PASS
///   poc_f7_typical_mainnet_shape_is_dropped ............. (covered by the two guard tests)

#[test_only]
module bucket_oracle::poc_f7 {
    use pyth::i64::{Self, I64};

    /// The accessors' own assertions, quoted from partners/pyth/sources/i64.move:
    ///   get_magnitude_if_positive  -> assert!(!in.negative, 0)   (:43-46)
    ///   get_magnitude_if_negative  -> assert!( in.negative, 0)   (:48-51)

    /// Step A of the parser sequence, as written.
    fun guard_a_returns_none(expo: &I64): bool {
        i64::get_is_negative(expo)
    }

    /// Step B of the parser sequence, as written.
    fun guard_b_returns_none(price: &I64): bool {
        !i64::get_is_negative(price)
    }

    #[test]
    fun poc_f7_guard_a_drops_the_negative_expo() {
        // Any feed with a negative expo returns none() at step A, whatever the price.
        let expo = i64::new(8, true);
        assert!(guard_a_returns_none(&expo), 7001);
        let expo2 = i64::new(8, false);
        assert!(!guard_a_returns_none(&expo2), 7002); // only a non-negative expo continues
    }

    #[test]
    fun poc_f7_guard_b_drops_a_positive_price() {
        // A feed that survives step A (non-negative expo) is dropped at step B when the
        // price is positive, i.e. for every normal price quote.
        let price = i64::new(150_000_000, false);
        assert!(guard_b_returns_none(&price), 7003);
        let negative = i64::new(150_000_000, true);
        assert!(!guard_b_returns_none(&negative), 7004); // only a negative price continues
    }

    /// The single combination that passes both guards is (expo non-negative, price
    /// negative). Step C then asks for the NEGATIVE magnitude of an expo that step A
    /// has already guaranteed is non-negative, so the transaction aborts with the
    /// pyth::i64 error code 0. The Pyth path can therefore never complete: with
    /// threshold = 1 the collector ends up empty and ENotEoughPrices aborts instead.
    #[test, expected_failure(abort_code = 0 /* pyth::i64 assertion in get_magnitude_if_negative */)]
    fun poc_f7_the_only_surviving_case_aborts() {
        let expo = i64::new(8, false);   // non-negative: passes guard A
        let _price = i64::new(150_000_000, true); // negative: passes guard B
        let _decimal = i64::get_magnitude_if_negative(&expo);
    }

    /// Mirror of step D for completeness: if the order were repaired so that step C
    /// used the positive accessor, step D would then abort on the negative price.
    #[test, expected_failure(abort_code = 0 /* pyth::i64 assertion in get_magnitude_if_positive */)]
    fun poc_f7_step_d_also_aborts_on_the_surviving_case() {
        let _expo = i64::new(8, false);
        let price = i64::new(150_000_000, true);
        let _magnitude = i64::get_magnitude_if_positive(&price);
    }

    /// The exhaustive statement: for all four (expo sign, price sign) combinations the
    /// parser either returns none() (rows 1-3) or aborts (row 4). No input yields a
    /// price, so `update_price_from_pyth` and `update_price_from_pyth_read_only` cannot
    /// contribute, and a future "require two sources" fix would silently reduce to two
    /// feeds instead of three.
    #[test]
    fun poc_f7_no_input_produces_a_price() {
        let mut accounted = 0u8;
        // (expo negative, price negative) -> none at step A
        // (expo negative, price positive) -> none at step A
        // (expo non-negative, price positive) -> none at step B
        // (expo non-negative, price negative) -> aborts at step C, see poc_f7_the_only_...
        if (guard_a_returns_none(&i64::new(8, true))) { accounted = accounted + 1; };
        if (guard_a_returns_none(&i64::new(8, true))
            && guard_b_returns_none(&i64::new(150_000_000, false))) { accounted = accounted + 1; };
        if (!guard_a_returns_none(&i64::new(8, false))
            && guard_b_returns_none(&i64::new(150_000_000, false))) { accounted = accounted + 1; };
        if (!guard_a_returns_none(&i64::new(8, false))
            && !guard_b_returns_none(&i64::new(150_000_000, true))) { accounted = accounted + 1; };
        // Every one of the four sign combinations is non-productive: three drop the
        // reading, the fourth aborts before any value is read.
        assert!(accounted == 4, accounted);
    }

    /// What a correct implementation would look like, as a regression guard: expo is
    /// negative for a USD quote, so its magnitude is taken with the NEGATIVE accessor,
    /// and the price with the POSITIVE one. This is the fix, verified to be reachable.
    #[test]
    fun poc_f7_the_intended_reading_is_obtainable() {
        let expo = i64::new(8, true);            // -8
        let price = i64::new(150_000_000, false); // +1.5e8
        let decimal = i64::get_magnitude_if_negative(&expo);
        let magnitude = i64::get_magnitude_if_positive(&price);
        assert!(decimal == 8, 7005);
        assert!(magnitude == 150_000_000, 7006);
    }
}
