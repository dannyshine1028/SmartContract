/// ===========================================================================
/// PoC — F1: aggregation never runs on any shipped path; one source sets the
///          stored price; threshold = 1; the aggregation primitives are public.
/// Report: ../bucket-oracle-price-aggregator-single-source-no-divergence-check.md
/// ===========================================================================
///
/// PREREQUISITE (the only edit to the audited tree, test-only, stripped from any
/// published package): paste the functions from `injector-snippet.move` (same folder) into
/// sources/single_oracle.move. They exist because a unit test cannot own live
/// Switchboard/Pyth/Supra source objects, and because `PriceCollector` fields are
/// private to `single_oracle`.
///
/// RUN
///   cp Result\(report\)/poc/F1-single-source-no-divergence-check.move \
///      <oracle-repo>/sources/tests/
///   sui move test bucket_oracle::poc_f1
///
/// EXPECTED
///   poc_f1_single_source_price_stored_verbatim ......... PASS
///   poc_f1_guard_is_functional_when_two_prices_are_supplied  PASS (aborts, as intended)
///   -> Together: the cross-check works, yet every shipped entry point delivers 1 price.
///      This deliberately does NOT claim the guard is unreachable in the language sense:
///      `issue_price_collector` (:208), the four `collect_price_from_*` (:113,:139,:159,
///      :186) and `update_oracle_price` (:216) are plain `public`, so a caller can
///      compose a two-source collector by hand. That the write needs no authorisation
///      is itself part of the finding.

#[test_only]
module bucket_oracle::poc_f1 {
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;
    use sui::test_scenario::{Self as ts};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use bucket_oracle::bucket_oracle::{Self, AdminCap, BucketOracle};
    use bucket_oracle::price_aggregator;
    use bucket_oracle::single_oracle::{Self, PriceCollector};

    const T0: u64 = 1_700_000_000_000;
    const REAL: u64 = 1_000_000; // $1.00 at precision_decimal = 6

    fun setup(ctx: &mut TxContext): (BucketOracle, Clock) {
        // new_for_testing gives threshold = 1, i.e. the deployed configuration for SUI.
        let (oracle, cap) = bucket_oracle::new_for_testing<SUI>(6, ctx);
        let mut clock = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clock, T0);
        transfer::transfer(cap, tx_context::sender(ctx));
        (oracle, clock)
    }

    fun stored_price(oracle: &BucketOracle, clock: &Clock): u64 {
        let so = bucket_oracle::borrow_single_oracle<SUI>(oracle);
        let (price, _precision) = single_oracle::get_price<SUI>(so, clock);
        price
    }

    /// Step 1 — one source in, that exact value out, with no comparison performed.
    #[test]
    fun poc_f1_single_source_price_stored_verbatim() {
        let mut scenario = ts::begin(@0xF1);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(REAL, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        assert!(stored_price(&oracle, &clock) == REAL, 1001);
        transfer::transfer(oracle, @0xF1);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Step 2 — the same call with a value ~10^6 below the reference is also stored.
    /// There is no deviation limit on the single-price path.
    #[test]
    fun poc_f1_single_source_absurd_deviation_stored() {
        let mut scenario = ts::begin(@0xF2);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(1, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        assert!(stored_price(&oracle, &clock) == 1, 1002);
        transfer::transfer(oracle, @0xF2);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Contrast — when two prices ARE supplied, the guard fires (abort code 1 =
    /// price_aggregator::ESignificientPriceDiff). This proves the guard is present
    /// and functional, so the defect is "never exercised by a shipped path", not
    /// "missing".
    #[test, expected_failure(abort_code = 1 /* ESignificientPriceDiff */)]
    fun poc_f1_guard_is_functional_when_two_prices_are_supplied() {
        let mut scenario = ts::begin(@0xF3);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(REAL, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 1, price_aggregator::new(REAL + 50_000, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        transfer::transfer(oracle, @0xF3);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// And the intended behaviour exists at length 2: two close readings average.
    #[test]
    fun poc_f1_two_close_prices_are_averaged() {
        let mut scenario = ts::begin(@0xF4);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(REAL, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 1, price_aggregator::new(REAL + 10_000, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        assert!(stored_price(&oracle, &clock) == 1_005_000, 1004);
        transfer::transfer(oracle, @0xF4);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Step 3 — with threshold raised to 2, a one-source update aborts: the shipped
    /// entry points would then fail outright, which shows they never produce two
    /// readings in the first place.
    #[test, expected_failure(abort_code = 0 /* ENotEoughPrices */)]
    fun poc_f1_shipped_shape_cannot_satisfy_threshold_two() {
        let mut scenario = ts::begin(@0xF5);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 2);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(REAL, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        transfer::transfer(oracle, @0xF5);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Empty collector — the public entry shape taken alone, sanity baseline.
    #[test, expected_failure(abort_code = 0 /* ENotEoughPrices */)]
    fun poc_f1_empty_collector_abort() {
        let mut scenario = ts::begin(@0xF6);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        let c = single_oracle::issue_price_collector<SUI>();
        single_oracle::update_oracle_price<SUI>(so, &clock, c);
        transfer::transfer(oracle, @0xF6);
        clock::destroy_for_testing(clock);
        scenario.end();
    }
}
