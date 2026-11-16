/// ===========================================================================
/// PoC — F6: three sources are collapsed onto the first two entries of a
///          REVERSED list, so the third reading is never compared and there is
///          no median
/// Report: ../bucket-oracle-aggregator-drops-third-source-two-of-three-outvote.md
/// ===========================================================================
///
/// PREREQUISITE: paste `injector-snippet.move` (same folder) into sources/single_oracle.move
/// (test-only). This is the one finding where the injector is not a shortcut: a caller
/// CAN legitimately build a multi-source collector, because `issue_price_collector`,
/// the four `collect_price_from_*` and `update_oracle_price` are all plain `public`
/// (`single_oracle.move:113,139,159,186,208,216`). The injector reproduces exactly what
/// those public functions do to the collector's three slots.
///
/// RUN
///   cp Result\(report\)/poc/F6-third-source-dropped.move <oracle-repo>/sources/tests/
///   sui move test bucket_oracle::poc_f6
///
/// EXPECTED
///   poc_f6_list_order_is_reversed_before_the_average .... PASS (1_015_000, not 1_005_000)
///   poc_f6_two_agreeing_fakes_outvote_one_honest ....... PASS (2_000_000)
///   poc_f6_wild_third_outlier_is_never_examined ........ PASS (1_005_000; the $1000 reading
///                                                         is dropped, so a 3-way check would
///                                                         have caught what this one did not)
///   poc_f6_threshold_two_needs_two_sources ............. PASS (aborts with 1 source)

#[test_only]
module bucket_oracle::poc_f6 {
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;
    use sui::test_scenario::{Self as ts};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use bucket_oracle::bucket_oracle::{Self, AdminCap, BucketOracle};
    use bucket_oracle::price_aggregator;
    use bucket_oracle::single_oracle;

    const T0: u64 = 1_700_000_000_000;
    const REAL: u64 = 1_000_000; // $1.00
    const ONE_HOUR: u64 = 3_600_000;

    fun setup(ctx: &mut TxContext): (BucketOracle, Clock) {
        let (oracle, cap) = bucket_oracle::new_for_testing<SUI>(6, ctx);
        let mut clock = clock::create_for_testing(ctx);
        clock::set_for_testing(&mut clock, T0);
        transfer::transfer(cap, tx_context::sender(ctx));
        (oracle, clock)
    }

    /// slot indices match single_oracle.move:223-225 push order: 0 switchboard,
    /// 1 pyth, 2 supra.

    fun stored_price(oracle: &BucketOracle, clock: &Clock): u64 {
        let so = bucket_oracle::borrow_single_oracle<SUI>(oracle);
        let (price, _precision) = single_oracle::get_price<SUI>(so, clock);
        price
    }

    /// Does the list reaching process_prices keep the documented order?
    /// If it did, indices 0 and 1 would be switchboard($1.00) and pyth($1.01), giving
    /// 1_005_000 with supra never used. Because aggregate_price drains with
    /// vector::pop_back (price_aggregator.move:44), indices 0 and 1 are actually
    /// supra($1.02) and pyth($1.01), and the average is 1_015_000 instead.
    #[test]
    fun poc_f6_list_order_is_reversed_before_the_average() {
        let mut scenario = ts::begin(@0xC1);
        let (mut oracle, clock) = setup(scenario.ctx());
        let o = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(o, ONE_HOUR);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(REAL, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 1, price_aggregator::new(REAL + 10_000, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 2, price_aggregator::new(REAL + 20_000, T0));
        single_oracle::update_oracle_price<SUI>(o, &clock, c);

        // (1_020_000 + 1_010_000) / 2 : the supra+pyth pair, not switchboard+pyth.
        assert!(stored_price(&oracle, &clock) == 1_015_000, 6001);
        transfer::transfer(oracle, @0xC1);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Two readings that agree with each other are enough to outvote an honest one:
    /// switchboard reports $1.00, pyth and supra both report $2.00, and $2.00 is
    /// published. There is no median, so no majority protection.
    #[test]
    fun poc_f6_two_agreeing_fakes_outvote_one_honest() {
        let mut scenario = ts::begin(@0xC2);
        let (mut oracle, clock) = setup(scenario.ctx());
        let o = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(o, ONE_HOUR);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(REAL, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 1, price_aggregator::new(2 * REAL, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 2, price_aggregator::new(2 * REAL, T0));
        single_oracle::update_oracle_price<SUI>(o, &clock, c);

        assert!(stored_price(&oracle, &clock) == 2 * REAL, 6002);
        transfer::transfer(oracle, @0xC2);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// The complementary case: a wildly wrong third reading is never even looked at,
    /// so the pipeline reports "healthy" while one of the three configured sources is
    /// off by 1000x. Any fix that only tightens the two-element band keeps this hole.
    #[test]
    fun poc_f6_wild_third_outlier_is_never_examined() {
        let mut scenario = ts::begin(@0xC3);
        let (mut oracle, clock) = setup(scenario.ctx());
        let o = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(o, ONE_HOUR);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(1_000 * REAL, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 1, price_aggregator::new(REAL + 10_000, T0));
        single_oracle::inject_for_testing<SUI>(&mut c, 2, price_aggregator::new(REAL, T0));
        single_oracle::update_oracle_price<SUI>(o, &clock, c);

        // indices 0,1 after reversal = supra($1.00) and pyth($1.01) -> $1.005.
        // The $1000 switchboard reading is silently ignored instead of aborting.
        assert!(stored_price(&oracle, &clock) == 1_005_000, 6003);
        transfer::transfer(oracle, @0xC3);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Raising the threshold is necessary but not sufficient: with a single reading
    /// (what every shipped entry point delivers) the update aborts, which is the
    /// expected consequence of the F1 fix, and with two readings the aggregation is
    /// still the two-element mean shown above.
    #[test, expected_failure(abort_code = 0 /* ENotEoughPrices */)]
    fun poc_f6_threshold_two_needs_two_sources() {
        let mut scenario = ts::begin(@0xC4);
        let (mut oracle, clock) = setup(scenario.ctx());
        let o = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_threshold_for_testing<SUI>(o, 2);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0, price_aggregator::new(REAL, T0));
        single_oracle::update_oracle_price<SUI>(o, &clock, c);

        transfer::transfer(oracle, @0xC4);
        clock::destroy_for_testing(clock);
        scenario.end();
    }
}
