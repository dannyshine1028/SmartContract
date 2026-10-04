// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../../interface/IChainlinkAggregator.sol";

abstract contract ChainlinkSequencerStatus {
    /// @dev Chainlink Sequencer Uptime Proxy address.
    IChainlinkAggregator private sequencerUptimeFeed_;

    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /// @dev Emitted when `sequencerUptimeFeed_` is changed.
    event SetChainlinkSequencer(address sequencerUptimeFeed);

    /**
     * @dev Set the address of the Chainlink sequencer.
     * @param _sequencerUptimeFeed The address of the Chainlink sequencer.
     */
    function _setChainlinkSequencer(IChainlinkAggregator _sequencerUptimeFeed)
        internal
    {
        require(
            _sequencerUptimeFeed != sequencerUptimeFeed_,
            "_setChainlinkSequencer: defaultValidInterval is invalid!"
        );
        sequencerUptimeFeed_ = _sequencerUptimeFeed;
        emit SetChainlinkSequencer(address(_sequencerUptimeFeed));
    }

    /**
     * @dev Get sequencer status.
     * @return _status true: Sequencer is up; false: Sequencer is down.
     */
    function _sequencerStatus() internal view returns (bool _status) {
        (, int256 _answer, uint256 _startedAt, , ) = sequencerUptimeFeed_
        .latestRoundData();
        _status =
            _answer == 0 &&
            block.timestamp - _startedAt > GRACE_PERIOD_TIME;
    }

    /**
     * @dev Get Chainlink Sequencer Uptime Proxy address.
     * @return Chainlink Sequencer Uptime Proxy address.
     */
    function sequencerUptimeFeed()
        external
        view
        returns (IChainlinkAggregator)
    {
        return sequencerUptimeFeed_;
    }

    /**
     * @dev Get sequencer status.
     * @return true: Sequencer is up; false: Sequencer is down.
     */
    function sequencerStatus() external view returns (bool) {
        return _sequencerStatus();
    }
}
