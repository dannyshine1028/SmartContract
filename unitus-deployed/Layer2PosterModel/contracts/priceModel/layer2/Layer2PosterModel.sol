// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../PosterModel.sol";
import "../status/ChainlinkSequencerStatus.sol";

contract Layer2PosterModel is PosterModel, ChainlinkSequencerStatus {
    /**
     * @notice Only for the implementation contract, as for the proxy pattern,
     *            should call `initialize()` separately.
     * @param _sequencerUptimeFeed The address of the Chainlink sequencer.
     */
    constructor(IChainlinkAggregator _sequencerUptimeFeed) public Base() {
        _setChainlinkSequencer(_sequencerUptimeFeed);
    }

    function getAssetStatus(address _asset)
        external
        virtual
        override
        returns (bool)
    {
        _asset;
        return _sequencerStatus();
    }

    function getAssetPriceStatus(address _asset)
        external
        virtual
        override
        returns (uint256, bool)
    {
        return (_getAssetPrice(_asset), _sequencerStatus());
    }
}
