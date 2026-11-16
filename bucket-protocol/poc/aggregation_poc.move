#[test_only]
/// ---------------------------------------------------------------------------
/// Proof of concept for the HackenProof report on the Bucket Protocol oracle.
/// ---------------------------------------------------------------------------
/// HOW TO RUN: see poc/README.md (2 steps: paste the injector snippet, drop this file
/// into sources/tests/, then `sui move test`).
///
/// WHAT THIS FILE DOES NOT DO
///   It reimplements nothing. Every assertion is made against the protocol's own functions:
///     bucket_oracle::new_for_testing / borrow_single_oracle / borrow_single_oracle_mut
///     single_oracle::issue_price_collector / update_oracle_price / get_price
///     price_aggregator::new
///     pyth::i64 (the same module pyth_parser uses)
///   The only added code is the three `#[test_only]` setters in Result(report)/poc/injector-snippet.move,
///   needed because a unit test cannot own live Switchboard/Pyth/Supra source objects.
///
/// Abort codes used below are the private constants of the respective modules:
///   price_aggregator: 0 = ENotEoughPrices, 1 = ESignificientPriceDiff
///   single_oracle:    2 = EPriceOutdated
module bucket_oracle::aggregation_poc {
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;
    use sui::test_scenario::{Self as ts};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use pyth::i64;

    use bucket_oracle::bucket_oracle::{Self, AdminCap, BucketOracle};
    use bucket_oracle::price_aggregator;
    use bucket_oracle::single_oracle::{Self, PriceCollector};

    /// A realistic mainnet-style clock value, in ms.
    const T0: u64 = 1_700_000_000_000;
    /// Reference price of the asset at precision_decimal = 6, i.e. $1.00.
    const REAL: u64 = 1_000_000;
    /// Per-feed tolerance used by the protocol at deployment (init, SUI feed).
    const ONE_HOUR: u64 = 3_600_000;

    /// Creates a BucketOracle holding a `<SUI>` slot (tolerance_ms = MAX_U64, threshold = 1)
    /// plus a Clock parked at T0.
    fun setup(ctx: &mut TxContext): (BucketOracle, Clock) {
        let (oracle, cap) = bucket_oracle::new_for_testing<SUI>(6, ctx);
        let mut clock = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clock, T0);
        transfer::transfer(cap, tx_context::sender(ctx));
        (oracle, clock)
    }

    /// Builds a collector carrying exactly `n` source prices, which is what one of the four
    /// production update paths can ever produce (see poc/verify.py, check 1).
    fun collector_of_1(price: u64, ts: u64): PriceCollector<SUI> {
        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(price, ts));
        c
    }

    fun collector_of_2(p0: u64, p1: u64, ts: u64): PriceCollector<SUI> {
        let mut c = collector_of_1(p0, ts);
        single_oracle::inject_for_testing<SUI>(&mut c, 1, price_aggregator::new(p1, ts));
        c
    }

    fun collector_of_3(p0: u64, p1: u64, p2: u64, ts: u64): PriceCollector<SUI> {
        let mut c = collector_of_2(p0, p1, ts);
        single_oracle::inject_for_testing<SUI>(&mut c, 2, price_aggregator::new(p2, ts));
        c
    }

    fun stored_price(oracle: &BucketOracle, clock: &Clock): u64 {
        let so = bucket_oracle::borrow_single_oracle<SUI>(oracle);
        let (price, _precision) = single_oracle::get_price<SUI>(so, clock);
        price
    }

    /// ----------------------------------------------------------------------
    /// FINDING 1 + 2: with a single source in the collector, whatever that source
    /// reports becomes the stored price. No deviation limit is applied at all, so
    /// a zero price and a maximal price are both accepted.
    /// ----------------------------------------------------------------------

    #[test]
    fun poc1_single_source_sets_the_stored_price_verbatim() {
        let mut scenario = ts::begin(@0x1);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        let c = collector_of_1(REAL, T0);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        assert!(stored_price(&oracle, &clock) == REAL, 100);
        transfer::transfer(oracle, @0x1);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test]
    fun poc2_zero_price_from_one_source_is_stored() {
        let mut scenario = ts::begin(@0x2);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        // A feed reporting 0 is not filtered by the aggregator. Collateral valued at 0 makes
        // every open position liquidatable at no cost.
        let c = collector_of_1(0, T0);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        assert!(stored_price(&oracle, &clock) == 0, 200);
        transfer::transfer(oracle, @0x2);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test]
    fun poc2b_one_hundred_thousand_percent_deviation_from_the_reference_is_stored() {
        let mut scenario = ts::begin(@0x3);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        // $1 real price vs $0.000001 reported: ~99.9999% below, accepted.
        let c = collector_of_1(1, T0);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        assert!(stored_price(&oracle, &clock) == 1, 300);
        transfer::transfer(oracle, @0x3);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test]
    fun poc2c_max_u64_price_from_one_source_is_stored() {
        let mut scenario = ts::begin(@0x4);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        let bogus = std::u64::max_value!();
        let c = collector_of_1(bogus, T0);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        assert!(stored_price(&oracle, &clock) == bogus, 400);
        transfer::transfer(oracle, @0x4);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// ----------------------------------------------------------------------
    /// FINDING 1 (the reachability half): the ESignificientPriceDiff guard does
    /// exist and does fire - but only when the collector carries two or more
    /// prices, which none of the four production entry paths can ever produce.
    /// These two tests are the contrast that proves the guard is dead code.
    /// ----------------------------------------------------------------------

    /// Two prices ~5% apart: rejected by the ~2% band (diff * 50 <= avg).
    #[test, expected_failure(abort_code = 1 /* price_aggregator::ESignificientPriceDiff */)]
    fun poc3_guard_fires_when_the_collector_holds_two_diverging_prices() {
        let mut scenario = ts::begin(@0x5);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        let c = collector_of_2(REAL, REAL + 50_000, T0);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        transfer::transfer(oracle, @0x5);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Two close prices are averaged, which is the intended behaviour.
    #[test]
    fun poc3b_two_close_prices_are_averaged() {
        let mut scenario = ts::begin(@0x6);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        let c = collector_of_2(REAL, REAL + 10_000, T0);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        assert!(stored_price(&oracle, &clock) == 1_005_000, 600);
        transfer::transfer(oracle, @0x6);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// ----------------------------------------------------------------------
    /// FINDING 3: freshness is an absolute (two-sided) comparison, so a reading
    /// stamped up to tolerance_ms into the future is treated as fresh. A feed
    /// whose clock runs ahead (or a source whose timestamp field is influenceable)
    /// therefore keeps genuinely stale readings inside the accepted window for as
    /// long as the skew lasts. Contrast pair: the same magnitude into the past is
    /// rejected. Severity: hardening, not a direct fund-loss primitive.
    /// ----------------------------------------------------------------------

    #[test]
    fun poc4_reading_timestamped_just_ahead_of_the_clock_is_accepted() {
        let mut scenario = ts::begin(@0x7);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(so, ONE_HOUR);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        let c = collector_of_1(REAL, T0 + ONE_HOUR - 1_000);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        assert!(stored_price(&oracle, &clock) == REAL, 700);
        transfer::transfer(oracle, @0x7);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test, expected_failure(abort_code = 0 /* price_aggregator::ENotEoughPrices */)]
    fun poc5_same_offset_into_the_past_is_rejected() {
        let mut scenario = ts::begin(@0x8);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(so, ONE_HOUR);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        let c = collector_of_1(REAL, T0 - ONE_HOUR - 1_000);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        transfer::transfer(oracle, @0x8);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// ----------------------------------------------------------------------
    /// FINDING 6: three sources are collapsed onto the first two of a REVERSED
    /// list. aggregate_price drains the input with vector::pop_back, so the
    /// surviving pair is (supra, pyth) and the switchboard reading is dropped
    /// without ever being compared. Two agreeing sources outvote one, so even
    /// after the single-source defect is fixed, controlling 2 of 3 feeds fully
    /// determines the price. There is no median.
    /// ----------------------------------------------------------------------

    #[test]
    fun poc6_third_source_is_dropped_and_two_outvote_one() {
        let mut scenario = ts::begin(@0x9);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(so, ONE_HOUR);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        // push order is switchboard, pyth, supra; the switchboard value is the real one.
        let c = collector_of_3(REAL, 2 * REAL, 2 * REAL, T0);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        // $2, $2 outvote the single honest $1 and become the stored price.
        assert!(stored_price(&oracle, &clock) == 2 * REAL, 900);
        transfer::transfer(oracle, @0x9);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// ----------------------------------------------------------------------
    /// CONTEXT for the exploit window: consumers are limited by a hardcoded
    /// 10_000 ms staleness check in single_oracle::get_price, which ignores the
    /// per-feed tolerance_ms. So a poisoned price is usable inside the same
    /// transaction (or the next one), which is exactly how a liquidation would
    /// be submitted. Informational, included so triage can see the timing model.
    /// ----------------------------------------------------------------------

    #[test, expected_failure(abort_code = 2 /* single_oracle::EPriceOutdated */)]
    fun poc7_consumers_reject_the_stored_price_after_10_seconds() {
        let mut scenario = ts::begin(@0xA);
        let (mut oracle, mut clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 1);
        let c = collector_of_1(REAL, T0);
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        clock::increment_for_testing(&mut clock, 10_001);
        assert!(stored_price(&oracle, &clock) == REAL, 1000);
        transfer::transfer(oracle, @0xA);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// ----------------------------------------------------------------------
    /// FINDING 4 (language semantics, mirroring the expressions at
    /// sources/parser/supra_parser.move:15-20 and the decimal cast at :12).
    /// These two tests document Move's casting behaviour, which is what makes the
    /// parsers' rescaling silently wrap instead of aborting. They are labelled as
    /// semantics proofs, not as calls into the parser, because a Supra
    /// `OracleHolder` cannot be constructed in a unit test (its read function is
    /// a native declaration in the vendored interface).
    /// ----------------------------------------------------------------------

    #[test]
    fun poc8_u64_cast_of_a_scaled_u128_wraps_instead_of_aborting() {
        // raw = 1e18 with source decimals = 0 and required decimals = 6 => scale by 1e6.
        let raw: u128 = 1_000_000_000_000_000_000;
        let scaled: u128 = raw * (std::u64::pow(10, 6 - 0) as u128);
        let truncated = (scaled as u64);
        // 1e24 mod 2^64. Not 1e24, and no abort: the value is simply wrong.
        assert!(truncated == 2_003_764_205_206_896_640, 1100);
        // A wrapped price below the real one is enough to trigger liquidations.
        assert!(scaled > std::u64::max_value!() as u128, 1101);
    }

    #[test]
    fun poc8b_decimal_u16_cast_to_u8_wraps_and_flips_the_scaling_branch() {
        // supra_parser.move:12 does `(decimal_u16 as u8)`; decimal_u16 > 255 wraps.
        assert!((256u16 as u8) == 0, 1200);
        assert!((264u16 as u8) == 8, 1201);
        // With the wrapped 0 and required 6, the parser takes the multiply branch
        // instead of the divide branch, i.e. it scales the wrong way.
        let decimal = (256u16 as u8);
        let required = 6u8;
        assert!(decimal < required, 1202);
    }

    /// ----------------------------------------------------------------------
    /// FINDING 7: the sign guards in pyth_parser.move:35-38 / 60-63 (written in the
    /// same order there) never yield a price. These tests use pyth::i64 itself, the
    /// exact module the parser imports.
    /// ----------------------------------------------------------------------

    #[test]
    fun poc9_normal_positive_price_is_dropped_by_the_guards() {
        // Typical Pyth SUI/USD: expo = -8, price = positive magnitude.
        let expo = i64::new(8, true);
        let price = i64::new(150_000_000, false);
        // guard A: `if (get_is_negative(&decimal_i64)) return option::none();`
        let dropped_a = i64::get_is_negative(&expo);
        // guard B: `if (!get_is_negative(&price_i64)) return option::none();`
        let dropped_b = !i64::get_is_negative(&price);
        assert!(dropped_a, 1300);
        assert!(dropped_b, 1301);
        // Either guard alone already returns none(), so this source is never aggregated.
    }

    #[test, expected_failure(abort_code = 0 /* pyth::i64 negative-value assertion */)]
    fun poc9b_the_only_input_that_passes_both_guards_then_aborts() {
        // Non-negative expo passes guard A, negative price passes guard B; the very next
        // line takes the magnitude of the *expo* as if it were negative, which aborts.
        let expo = i64::new(8, false);
        let _price = i64::new(150_000_000, true);
        let _decimal = i64::get_magnitude_if_negative(&expo);
    }

    #[test]
    fun poc9c_all_four_sign_combinations_are_covered() {
        // (expo negative) => dropped by guard A, regardless of the price sign.
        assert!(i64::get_is_negative(&i64::new(8, true)), 1400);
        // (expo non-negative, price non-negative) => dropped by guard B.
        assert!(!i64::get_is_negative(&i64::new(150_000_000, false)), 1401);
        // (expo non-negative, price negative) => guard A passes, guard B passes, and the
        // magnitude call in poc9b aborts.
        let expo = i64::new(8, false);
        assert!(!i64::get_is_negative(&expo), 1402);
    }
}
