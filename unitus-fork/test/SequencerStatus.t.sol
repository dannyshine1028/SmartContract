// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IPriceModel {
    function sequencerStatus() external view returns (bool);
    function sequencerUptimeFeed() external view returns (address);
    function getAssetPriceStatus(address asset) external returns (uint256, bool);
}

interface IOracle {
    function getUnderlyingPriceAndStatus(address iToken) external returns (uint256, bool);
    function priceModel(address asset) external view returns (address);
}

interface IController {
    function calcAccountEquity(address account)
        external
        view
        returns (uint256, uint256, uint256, uint256);
    function getAlliTokens() external view returns (address[] memory);
}

/**
 * C-1: ChainlinkSequencerStatus._sequencerStatus() on the two deployed Unitus price models is
 *
 *     _status = _answer == 0 && block.timestamp - _startedAt > GRACE_PERIOD_TIME;   // 3600
 *
 * It never checks `_startedAt != 0`. Chainlink documents startedAt == 0 as the sentinel for an
 * invalid / not-yet-started round on an L2 Sequencer Uptime Feed. With startedAt == 0 the
 * subtraction yields ~block.timestamp, which is trivially > 3600, so the model reports
 * "sequencer up, grace period expired" — the grace window is not shortened, it is skipped.
 *
 * The same expression is also unchecked arithmetic (solc 0.6.12 in the deployed build), so a
 * startedAt in the future wraps instead of reverting, which is also reported as "up".
 */
contract SequencerStatusTest is Test {
    address constant HEARTBEAT_MODEL = 0x9913Ed5DD13E507D94d4118d96bd057F825e04f8;
    address constant POSTER_MODEL    = 0x4640DdDD85583D19460f3abAd3ce032EFcF9CCe5;
    address constant ORACLE          = 0x4B60aA7777c96D595c4a662B654D73F579fF3650;
    address constant CONTROLLER      = 0xBae8d153331129EB40E390A7Dd485363135fcE22;

    address constant iETH    = 0x76B5f31A3A6048A437AfD86be6E1a40888Dc8Bba;
    address constant iwstETH = 0xf8fBD6202FBcfC607E31A99300e6c84C2645902f;

    address feed;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("base"), vm.envUint("PIN_BLOCK"));
        feed = IPriceModel(HEARTBEAT_MODEL).sequencerUptimeFeed();
        // both deployed models must share the same feed for the rest of this to generalise
        assertEq(feed, IPriceModel(POSTER_MODEL).sequencerUptimeFeed(), "models use different feeds");
    }

    function _mockFeed(int256 answer, uint256 startedAt) internal {
        vm.mockCall(
            feed,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(uint80(1), answer, startedAt, block.timestamp, uint80(1))
        );
    }

    function test_C1_baseline_sequencerIsUp() public {
        assertTrue(IPriceModel(HEARTBEAT_MODEL).sequencerStatus(), "live feed should report up");
        emit log_named_address("uptime feed", feed);
    }

    /// The three states the integration is SUPPOSED to distinguish.
    function test_C1_correctStatesAreHandled() public {
        // sequencer reported DOWN (answer == 1) -> must be invalid
        _mockFeed(int256(1), block.timestamp - 7200);
        assertFalse(IPriceModel(HEARTBEAT_MODEL).sequencerStatus(), "down must be invalid");

        // sequencer up but INSIDE the 1h grace window -> must be invalid
        _mockFeed(int256(0), block.timestamp - 10);
        assertFalse(IPriceModel(HEARTBEAT_MODEL).sequencerStatus(), "inside grace must be invalid");

        // sequencer up and grace expired -> valid
        _mockFeed(int256(0), block.timestamp - 7200);
        assertTrue(IPriceModel(HEARTBEAT_MODEL).sequencerStatus(), "outside grace must be valid");
    }

    /// THE DEFECT: the invalid-round sentinel is read as "up, grace long expired".
    function test_C1_startedAtZero_failsOpen() public {
        _mockFeed(int256(0), 0);

        bool hb = IPriceModel(HEARTBEAT_MODEL).sequencerStatus();
        bool po = IPriceModel(POSTER_MODEL).sequencerStatus();

        emit log_named_uint("block.timestamp", block.timestamp);
        emit log_named_string("startedAt", "0  (Chainlink invalid-round sentinel)");
        emit log_named_string("heartbeat model sequencerStatus()", hb ? "true  <-- FAIL OPEN" : "false");
        emit log_named_string("poster model    sequencerStatus()", po ? "true  <-- FAIL OPEN" : "false");

        assertTrue(hb, "heartbeat model fails open on startedAt==0");
        assertTrue(po, "poster model fails open on startedAt==0");
    }

    /// Same expression, the other direction: a future startedAt wraps (unchecked in solc 0.6.12).
    function test_C1_futureStartedAt_wrapsAndFailsOpen() public {
        _mockFeed(int256(0), block.timestamp + 1 days);
        bool hb = IPriceModel(HEARTBEAT_MODEL).sequencerStatus();
        emit log_named_string("startedAt = now + 1 day -> sequencerStatus()", hb ? "true  <-- UNDERFLOW WRAP" : "false");
        assertTrue(hb, "underflow wrap also reports up");
    }

    /// Does the fail-open actually reach the lending logic? Compare in-grace vs sentinel.
    function test_C1_reachesOracleAndController() public {
        // (a) realistic post-outage state: up, inside grace -> oracle must mark the price invalid
        _mockFeed(int256(0), block.timestamp - 10);
        (uint256 p1, bool v1) = IOracle(ORACLE).getUnderlyingPriceAndStatus(iETH);
        emit log_named_uint("in-grace  price", p1);
        emit log_named_string("in-grace  valid", v1 ? "true" : "false");

        // (b) the sentinel: identical situation as far as the protocol can tell, but valid
        _mockFeed(int256(0), 0);
        (uint256 p2, bool v2) = IOracle(ORACLE).getUnderlyingPriceAndStatus(iETH);
        emit log_named_uint("sentinel  price", p2);
        emit log_named_string("sentinel  valid", v2 ? "true  <-- accepted" : "false");

        assertFalse(v1, "in-grace price should be rejected");
        assertTrue(v2, "sentinel price is accepted");
        assertEq(p1, p2, "same price, only the validity flag differs");
    }
}
