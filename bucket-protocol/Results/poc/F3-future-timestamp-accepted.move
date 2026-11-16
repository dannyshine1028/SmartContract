/// ===========================================================================
/// PoC — F3: staleness uses a two-sided (absolute) comparison, so a reading
///          timestamped ahead of the clock counts as fresh
/// Report: ../bucket-oracle-aggregator-absolute-diff-future-timestamp-accepted.md
/// ===========================================================================
///
/// PREREQUISITE: paste `injector-snippet.move` (same folder) into sources/single_oracle.move
/// (test-only). It is used here only to set `tolerance_ms` to the deployed value
/// (3 600 000 ms, bucket_oracle.move:61-66) and to place one parsed reading.
///
/// RUN
///   cp Result\(report\)/poc/F3-future-timestamp-accepted.move <oracle-repo>/sources/tests/
///   sui move test bucket_oracle::poc_f3
///
/// EXPECTED — the two halves are the whole point: the SAME magnitude of offset on
/// the two sides of the clock produces OPPOSITE outcomes.
///   poc_f3_reading_59_minutes_59_seconds_ahead_is_accepted ....... PASS
///   poc_f3_reading_60_minutes_1_second_behind_is_rejected ........ PASS (aborts, code 0)
///   poc_f3_reading_one_second_ahead_is_accepted .................. PASS
///   poc_f3_ahead_skew_extends_the_life_of_a_stale_reading ........ PASS

#[test_only]
module bucket_oracle::poc_f3 {
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
    const ONE_HOUR: u64 = 3_600_000; // deployed tolerance_ms for the SUI feed

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

    /// A reading stamped just inside the tolerance in the FUTURE direction.
    /// price_aggregator.move:46 uses std::u64::diff(current_time, timestamp), so
    /// this is indistinguishable from a fresh reading and is published.
    #[test]
    fun poc_f3_reading_59_minutes_59_seconds_ahead_is_accepted() {
        let mut scenario = ts::begin(@0xB1);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(so, ONE_HOUR);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0,
            price_aggregator::new(REAL, T0 + ONE_HOUR - 1_000));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        assert!(stored_price(&oracle, &clock) == REAL, 3001);
        transfer::transfer(oracle, @0xB1);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// The mirror: the identical magnitude in the PAST direction — the direction
    /// the rule exists to police — is rejected (abort code 0 = ENotEoughPrices).
    #[test, expected_failure(abort_code = 0 /* ENotEoughPrices */)]
    fun poc_f3_reading_60_minutes_1_second_behind_is_rejected() {
        let mut scenario = ts::begin(@0xB2);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(so, ONE_HOUR);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0,
            price_aggregator::new(REAL, T0 - ONE_HOUR - 1_000));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        transfer::transfer(oracle, @0xB2);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Trivially in-window case, kept to show the tests are not boundary artefacts.
    #[test]
    fun poc_f3_reading_one_second_ahead_is_accepted() {
        let mut scenario = ts::begin(@0xB3);
        let (mut oracle, clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(so, ONE_HOUR);

        let mut c = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c, 0,
            price_aggregator::new(REAL, T0 + 1_000));
        single_oracle::update_oracle_price<SUI>(so, &clock, c);

        assert!(stored_price(&oracle, &clock) == REAL, 3003);
        transfer::transfer(oracle, @0xB3);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    /// Consequence over repeated updates: a publisher whose clock runs ahead by
    /// ~1 hour keeps a reading that is 1 hour old in real terms inside the accepted
    /// window on every subsequent update, because the filter never asks whether the
    /// timestamp is in the past relative to the data it describes.
    #[test]
    fun poc_f3_ahead_skew_extends_the_life_of_a_stale_reading() {
        let mut scenario = ts::begin(@0xB4);
        let (mut oracle, mut clock) = setup(scenario.ctx());
        let so = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        single_oracle::set_tolerance_ms_for_testing<SUI>(so, ONE_HOUR);

        // The feed's own timestamp is pinned 1 hour ahead of reality and never moves.
        let skewed_ts = T0 + ONE_HOUR - 1_000;

        // Update 1, at real time T0. `so_a` stops being used here, so its borrow ends.
        let so_a = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        let mut c_a = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c_a, 0, price_aggregator::new(REAL, skewed_ts));
        single_oracle::update_oracle_price<SUI>(so_a, &clock, c_a);

        // 50 minutes of real time passes; the reading is now 50 minutes old in real terms.
        clock::increment_for_testing(&mut clock, 3_000_000);
        let so_b = bucket_oracle::borrow_single_oracle_mut<SUI>(&mut oracle);
        let mut c_b = single_oracle::issue_price_collector<SUI>();
        single_oracle::inject_for_testing<SUI>(&mut c_b, 0, price_aggregator::new(REAL + 1, skewed_ts));
        single_oracle::update_oracle_price<SUI>(so_b, &clock, c_b);

        assert!(stored_price(&oracle, &clock) == REAL + 1, 3004);
        transfer::transfer(oracle, @0xB4);
        clock::destroy_for_testing(clock);
        scenario.end();
    }
}
