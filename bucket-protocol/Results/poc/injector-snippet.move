// ---------------------------------------------------------------------------
// Test-only helpers to be pasted into sources/single_oracle.move
// ---------------------------------------------------------------------------
// WHY THIS IS NEEDED
//   `PriceCollector` fields are private to the `single_oracle` module, and the only
//   functions that write them are `collect_price_from_switchboard`, `collect_price_from_pyth`,
//   `collect_price_from_pyth_read_only` and `collect_price_from_supra`. Each of those requires a
//   live third-party source object (a Switchboard `Aggregator`, a Pyth `PriceInfoObject` +
//   Wormhole state, or a Supra `OracleHolder`). A unit test cannot possess those objects, so the
//   aggregation code path cannot be driven from a test without a test-only setter.
//
//   These helpers are marked `#[test_only]`, which the Move compiler strips from any published
//   package. They change no production behaviour and no production code path.
//
// WHERE TO PASTE
//   Append the three functions below inside `module bucket_oracle::single_oracle { ... }`,
//   immediately after the existing `update_price_for_testing` at the end of the file
//   (sources/single_oracle.move). No new imports are required: `option`, `PriceInfo` and
//   `PriceCollector` are already in scope in that module.
// ---------------------------------------------------------------------------

    /// Put an already-parsed source price into a collector slot.
    /// which: 0 = switchboard_result, 1 = pyth_result, 2 = supra_result.
    #[test_only]
    public fun inject_for_testing<T>(
        collector: &mut PriceCollector<T>,
        which: u8,
        pi: PriceInfo,
    ) {
        let o = option::some(pi);
        if (which == 0) {
            collector.switchboard_result = o
        } else if (which == 1) {
            collector.pyth_result = o
        } else {
            collector.supra_result = o
        }
    }

    /// Per-feed staleness tolerance. The published value is only reachable through
    /// `single_oracle::new` (public(friend)) or `bucket_oracle::create_single_oracle`
    /// (public entry fun, needs an AdminCap and a not-yet-existing dynamic object slot).
    #[test_only]
    public fun set_tolerance_ms_for_testing<T>(oracle: &mut SingleOracle<T>, ms: u64) {
        oracle.tolerance_ms = ms
    }

    /// Minimum number of accepted sources required to produce a price.
    #[test_only]
    public fun set_threshold_for_testing<T>(oracle: &mut SingleOracle<T>, threshold: u64) {
        oracle.threshold = threshold
    }
