/// ===========================================================================
/// PoC — F2: the aggregator accepts and stores a price of 0
/// Report: ../bucket-oracle-aggregator-accepts-zero-price-liquidation.md
/// ===========================================================================
///
/// PREREQUISITE: paste `injector-snippet.move` (same folder) into sources/single_oracle.move
/// (test-only; stripped from published builds). Needed only to place a parsed
/// source price into a collector without live Switchboard/Pyth/Supra objects.
///
/// RUN
///   cp Result\(report\)/poc/F2-zero-price-accepted.move <oracle-repo>/sources/tests/
///   sui move test bucket_oracle::poc_f2
///
/// EXPECTED
///   poc_f2_zero_price_is_stored ......................... PASS  (stored price == 0)
///   poc_f2_zero_survives_a_second_agreeing_source ........ PASS  (stored price == 0)
///   poc_f2_max_u64_price_is_stored ...................... PASS  (stored price == u64::MAX)
///   -> No lower or upper bound is applied to the aggregated value anywhere in
///      price_aggregator::process_prices (:53-65) or single_oracle
///      ::update_oracle_price (:227). The only zero filter in the package is
///      switchboard_parser.move:22, which is a per-parser convenience, not an
///      aggregator invariant.

#[test_only]
module bucket_oracle::poc_f2 {
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;
    use sui::test_scenario::{Self as ts};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use bucket_oracle::bucket_oracle::{Self, AdminCap, BucketOracle};
    use bucket_oracle::price_aggregator;
    use bucket_oracle::single_oracle::{Self, PriceCollector};

    const T0: u64 = 1_700_000_000_000;
    const REAL: u64 = 1_000_000;

    fun setup(ctx: &mut TxContext): (BucketOracle, Clock) {
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

    /// One zero reading, delivered exactly as a shipped entry point would deliver
    /// its single source. The stored price becomes 0 => every position on this
    /// collateral reads as fully under-collateralised.
    #[test]
    fun poc_f2_zero_price_is_stored() {
        let mut scenario = ts::begin(@0xA1);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 2 /* supra slot */,
            price_aggregator::new(0, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        assert!(stored_price(&oracle, &clock) == 0, 2001);
        transfer::transfer(oracle, @0xA1);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Even at length 2 (the case the maintainers would reach for as a fix), two
    /// zero readings average to zero and the divergence guard is silent, because
    /// diff == 0. So "require two sources" alone does NOT close this finding.
    #[test]
    fun poc_f2_zero_survives_a_second_agreeing_source() {
        let mut scenario = ts::begin(@0xA2);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(so, 2);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(0, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 1, price_aggregator::new(0, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        assert!(stored_price(&oracle, &clock) == 0, 2002);
        transfer::transfer(oracle, @0xA2);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// The mirror case: no upper bound either. Relevant because a truncated parse
    /// (F4) can land near u64::MAX rather than aborting.
    #[test]
    fun poc_f2_max_u64_price_is_stored() {
        let mut scenario = ts::begin(@0xA3);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);

        let bogus = std::u64::max_value!();
        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 2, price_aggregator::new(bogus, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        assert!(stored_price(&oracle, &clock) == bogus, 2003);
        transfer::transfer(oracle, @0xA3);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Timing context for the report's "one transaction" claim: a zero price
    /// written at T0 is still consumable at T0 + 10_000 ms and is only rejected at
    /// T0 + 10_001 ms (single_oracle.move:39, :94). So a liquidator can refresh the
    /// price and liquidate in the same transaction block.
    #[test]
    fun poc_f2_zero_price_is_consumable_within_the_10s_window() {
        let mut scenario = ts::begin(@0xA4);
        let (mut oracle, mut clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 2, price_aggregator::new(0, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        clock::increment_for_testing(&mut clock, 10_000);
        assert!(stored_price(&oracle, &clock) == 0, 2004);

        transfer::transfer(oracle, @0xA4);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test, expected_failure(abort_code = 2 /* EPriceOutdated */)]
    fun poc_f2_and_one_millisecond_later_it_is_rejected() {
        let mut scenario = ts::begin(@0xA5);
        let (mut oracle, mut clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 2, price_aggregator::new(0, T0));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        clock::increment_for_testing(&mut clock, 10_001);
        assert!(stored_price(&oracle, &clock) == 0, 2005);

        transfer::transfer(oracle, @0xA5);
        clock::destroy_for_testing(clock);
        scenario.end();
    }
}
