// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../base/Base.sol";

abstract contract Heartbeat is Base {
    /// @dev asset default valid interval.
    uint256 internal defaultHeartbeat_ = 1 days;

    /// @dev Mapping of asset addresses to validInterval.
    mapping(address => uint256) internal heartbeat_;

    /// @dev Emitted when `defaultHeartbeat_` is changed.
    event SetDefaultValidInterval(uint256 defaultValidInterval);

    /// @dev Emitted when `heartbeat_` is changed.
    event SetAssetValidInterval(address asset, uint256 validInterval);

    /**
     * @notice Set `defaultHeartbeat_`.
     * @dev Function to change of `defaultHeartbeat_`.
     * @param _defaultValidInterval Default valid interval.
     */
    function _setDefaultValidInterval(uint256 _defaultValidInterval)
        external
        virtual
        onlyOwner
    {
        require(
            _defaultValidInterval != defaultHeartbeat_,
            "_setDefaultValidInterval: defaultValidInterval is invalid!"
        );
        defaultHeartbeat_ = _defaultValidInterval;
        emit SetDefaultValidInterval(_defaultValidInterval);
    }

    /**
     * @notice Set `validInterval` for asset to the specified address.
     * @dev Function to change of validInterval.
     * @param _asset Asset for which to set the `validInterval`.
     * @param _validInterval Address to assign to `validInterval`.
     */
    function _setAssetValidIntervalInternal(
        address _asset,
        uint256 _validInterval
    ) internal {
        uint256 _oldValidInterval = heartbeat_[_asset];
        require(
            _validInterval != _oldValidInterval,
            "_setAssetValidIntervalInternal: validInterval is invalid!"
        );

        heartbeat_[_asset] = _validInterval;
        emit SetAssetValidInterval(_asset, _validInterval);
    }

    function _setAssetValidInterval(address _asset, uint256 _validInterval)
        external
        virtual
        onlyOwner
    {
        _setAssetValidIntervalInternal(_asset, _validInterval);
    }

    function _setAssetValidIntervalBatch(
        address[] calldata _assets,
        uint256[] calldata _validIntervals
    ) external virtual onlyOwner {
        require(
            _assets.length == _validIntervals.length,
            "_setAssetValidIntervalBatch: assets & validIntervals must match the current length."
        );
        for (uint256 i = 0; i < _assets.length; i++)
            _setAssetValidIntervalInternal(_assets[i], _validIntervals[i]);
    }

    /**
     * @dev Get default valid interval.
     * @return Default valid interval.
     */
    function defaultValidInterval() external view returns (uint256) {
        return defaultHeartbeat_;
    }

    /**
     * @notice Asset valid time interval.
     * @dev Get valid time interval.
     * @param _asset Asset address.
     * @return Valid time interval.
     */
    function validInterval(address _asset) external view returns (uint256) {
        return heartbeat_[_asset];
    }
}
