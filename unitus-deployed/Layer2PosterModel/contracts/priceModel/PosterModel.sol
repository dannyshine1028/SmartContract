// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../library/SafeRatioMath.sol";

import "./base/Base.sol";
import "./base/Unit.sol";

contract PosterModel is Base, Unit {
    using SafeRatioMath for uint256;

    // Approximately 1 hour: 3600 seconds.
    uint256 internal constant numSecondsPerPeriod_ = 3600;

    uint256 internal constant MINIMUM_SWING_ = 10**15;
    uint256 internal constant MAXIMUM_SWING_ = 10**17;

    uint256 internal constant mantissaOne_ = 10**18;

    uint256 internal constant expScale_ = 10**18;
    uint256 internal constant halfExpScale_ = expScale_ / 2;

    /// @dev The maximum allowed percentage difference between a new price and the anchor's price
    uint256 internal maxSwing_ = MAXIMUM_SWING_;

    /// @dev The maximum allowed percentage difference for all assets between a new price and the anchor's price
    mapping(address => uint256) internal maxSwings_;

    struct Anchor {
        // Floor(block.timestamp / numSecondsPerPeriod) + 1
        uint256 period;
        // Price in USD, scaled by decimals
        uint256 price;
    }

    /// @dev Anchors by asset.
    mapping(address => Anchor) internal anchors_;

    /// @dev Pending anchor prices by asset.
    mapping(address => uint256) internal pendingAnchors_;

    /**
     * @dev Mapping of asset addresses and their corresponding price in terms of Eth-Wei
     *      which is simply equal to AssetWeiPrice * 10e18. For instance, if OMG token was
     *      worth 5x Eth then the price for OMG would be 5*10e18 or Exp({mantissa: 5000000000000000000}).
     * map: assetAddress -> Exp
     */
    mapping(address => uint256) internal assetPrices_;

    /// @dev Emitted when `maxSwing_` is changed.
    event SetMaxSwing(uint256 maxSwing);

    /// @dev Emitted when `maxSwings_` is changed.
    event SetMaxSwings(address asset, uint256 maxSwing);

    /**
     * @dev Emitted when a pending anchor is set.
     * @param asset Asset for which to set a pending anchor.
     * @param oldScaledPrice If an unused pending anchor was present, its value; otherwise 0.
     * @param newScaledPrice The new scaled pending anchor price.
     */
    event NewPendingAnchor(
        address anchorAdmin,
        address asset,
        uint256 oldScaledPrice,
        uint256 newScaledPrice
    );

    /// @dev Emitted for all price changes.
    event PricePosted(
        address asset,
        uint256 previousPrice,
        uint256 requestedPrice,
        uint256 newPrice
    );

    /// @dev Emitted if this contract successfully posts a capped-to-max price.
    event CappedPricePosted(
        address asset,
        uint256 requestedPrice,
        uint256 anchorPrice,
        uint256 cappedPrice
    );

    /**
     * @notice Set `maxSwing` to the specified value.
     * @dev Admin function to change of max swing.
     * @param _maxSwing Value to assign to `maxSwing`.
     */
    function _setMaxSwing(uint256 _maxSwing) public onlyOwner {
        uint256 _oldMaxSwing = maxSwing_;
        require(
            _maxSwing != _oldMaxSwing,
            "_setMaxSwing: Old and new values cannot be the same."
        );

        require(
            _maxSwing >= MINIMUM_SWING_ && _maxSwing <= MAXIMUM_SWING_,
            "_setMaxSwing: 0.1% <= _maxSwing <= 10%."
        );
        maxSwing_ = _maxSwing;
        emit SetMaxSwing(_maxSwing);
    }

    /**
     * @notice Set `maxSwing` for asset to the specified value.
     * @dev Admin function to change of max swing.
     * @param _asset Asset for which to set the `maxSwing`.
     * @param _maxSwing Value to assign to `maxSwing`.
     */
    function _setMaxSwingsInternal(address _asset, uint256 _maxSwing) internal {
        uint256 _oldMaxSwing = maxSwings_[_asset];
        require(
            _maxSwing != _oldMaxSwing,
            "_setMaxSwingsInternal: Old and new values cannot be the same."
        );
        require(
            _maxSwing >= MINIMUM_SWING_ && _maxSwing <= MAXIMUM_SWING_,
            "_setMaxSwingsInternal: 0.1% <= _maxSwing <= 10%."
        );
        maxSwings_[_asset] = _maxSwing;
        emit SetMaxSwings(_asset, _maxSwing);
    }

    function _setMaxSwings(address _asset, uint256 _maxSwing)
        external
        virtual
        onlyOwner
    {
        _setMaxSwingsInternal(_asset, _maxSwing);
    }

    function _setMaxSwingsBatch(
        address[] calldata _assets,
        uint256[] calldata _maxSwings
    ) external virtual onlyOwner {
        require(
            _assets.length == _maxSwings.length,
            "_setMaxSwingForAssetBatch: assets & maxSwings must match the current length."
        );
        for (uint256 i = 0; i < _assets.length; i++)
            _setMaxSwingsInternal(_assets[i], _maxSwings[i]);
    }

    /**
     * @notice Provides ability to override the anchor price for an asset.
     * @dev Admin function to set the anchor price for an asset.
     * @param _asset Asset for which to override the anchor price.
     * @param _newScaledPrice New anchor price.
     */
    function _setPendingAnchor(address _asset, uint256 _newScaledPrice)
        external
        onlyOwner
    {
        uint256 _oldScaledPrice = pendingAnchors_[_asset];
        pendingAnchors_[_asset] = _newScaledPrice;

        emit NewPendingAnchor(
            msg.sender,
            _asset,
            _oldScaledPrice,
            _newScaledPrice
        );
    }

    /**
     * @dev Multiplies two numbers, returns an error on overflow.
     */
    function _mul(uint256 _a, uint256 _b)
        internal
        pure
        returns (bool, uint256)
    {
        if (_a == 0) {
            return (false, 0);
        }

        uint256 _c = _a * _b;

        if (_c / _a != _b) {
            return (true, 0);
        } else {
            return (false, _c);
        }
    }

    /**
     * @dev Multiplies two exponentials, returning a new exponential.
     */
    function _rmulup(uint256 _a, uint256 _b)
        internal
        pure
        returns (bool, uint256)
    {
        (bool _err, uint256 _doubleScaledProduct) = _mul(_a, _b);
        if (_err) return (true, 0);

        // We add half the scale before dividing so that we get rounding instead of truncation.
        //  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717
        // Without this change, a result like 6.6...e-19 will be truncated to 0 instead of being rounded to 1e-18.

        uint256 _doubleScaledProductWithHalfScale = halfExpScale_ +
            _doubleScaledProduct;
        if (_doubleScaledProductWithHalfScale < halfExpScale_) return (true, 0);

        // The only error `div` can return is Error.DIVISION_BY_ZERO but we control `expScale` and it is not zero.
        return (false, _doubleScaledProductWithHalfScale.div(expScale_));
    }

    // abs(price - anchorPrice) / anchorPrice
    function _calculateSwing(uint256 _anchorPrice, uint256 _price)
        internal
        pure
        returns (bool, uint256)
    {
        if (_anchorPrice == 0) return (true, 0);
        uint256 _numerator = _anchorPrice > _price
            ? _anchorPrice - _price
            : _price - _anchorPrice;
        return (false, _numerator.rdiv(_anchorPrice));
    }

    // Base on the current anchor price, get the final valid price.
    function _capToMax(
        uint256 _anchorPrice,
        uint256 _price,
        uint256 _maxSwing
    )
        internal
        pure
        returns (
            bool,
            bool,
            uint256
        )
    {
        uint256 _one = mantissaOne_;
        uint256 _onePlusMaxSwing;
        // re-used for intermediate errors

        _onePlusMaxSwing = _one + _maxSwing;
        if (_onePlusMaxSwing < _one) return (true, false, 0);

        (bool _err, uint256 _max) = _rmulup(_anchorPrice, _onePlusMaxSwing);
        if (_err) return (true, false, 0);

        if (_price > _max) return (false, true, _max);

        if (_maxSwing > _one) return (true, false, 0);
        uint256 _oneMinusMaxSwing = _one - _maxSwing;

        uint256 _min;
        (_err, _min) = _rmulup(_anchorPrice, _oneMinusMaxSwing);
        // We can't overflow here or we would have already overflowed above when calculating `max`
        assert(!_err);

        // If  _price < _anchorPrice * (1 - _maxSwing)
        // Set _price = _anchorPrice * (1 - _maxSwing)
        if (_price < _min) return (false, true, _min);

        return (false, false, _price);
    }

    struct UpdatePriceLocalVars {
        uint256 price;
        uint256 swing;
        uint256 maxSwing;
        uint256 anchorPrice;
        uint256 anchorPeriod;
        uint256 currentPeriod;
        bool priceCapped;
        bool err;
        uint256 cappingAnchorPrice;
        uint256 pendingAnchor;
    }

    /**
     * @notice Update the status of price-related data.
     * @dev Update asset price, swing and time period against requested price check.
     * @param _asset Asset address.
     * @param _requestedPrice Requested new price.
     * @return bool ture: update asset price successfully, false: update asset price failed.
     *         uint256 correct price,
     *         uint256 current period,
     *         uint256 anchor period,
     *         bool ture: price capped, false: not reached the limit,
     *         uint256 capping anchor price,
     */
    function _updatePriceRes(address _asset, uint256 _requestedPrice)
        internal
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256,
            bool,
            uint256
        )
    {
        UpdatePriceLocalVars memory _localVars;
        // We add 1 for currentPeriod so that it can never be zero and there's no ambiguity about an unset value.
        // (It can be a problem in tests with low block timestamp.)
        _localVars.currentPeriod = (block.timestamp / numSecondsPerPeriod_) + 1;
        _localVars.pendingAnchor = pendingAnchors_[_asset];
        _localVars.price = _requestedPrice;

        _localVars.maxSwing = maxSwings_[_asset] == 0
            ? maxSwing_
            : maxSwings_[_asset];

        if (_localVars.pendingAnchor != 0) {
            // let's explicitly set to 0 rather than relying on default of declaration
            _localVars.anchorPeriod = 0;
            _localVars.anchorPrice = _localVars.pendingAnchor;

            // Verify movement is within max swing of pending anchor (currently: 10%)
            (_localVars.err, _localVars.swing) = _calculateSwing(
                _localVars.anchorPrice,
                _localVars.price
            );

            if (_localVars.err || _localVars.swing > _localVars.maxSwing)
                return (false, 0, 0, 0, false, 0);
        } else {
            _localVars.anchorPeriod = anchors_[_asset].period;
            _localVars.anchorPrice = anchors_[_asset].price;

            if (_localVars.anchorPeriod != 0) {
                (
                    _localVars.err,
                    _localVars.priceCapped,
                    _localVars.price
                ) = _capToMax(
                    _localVars.anchorPrice,
                    _localVars.price,
                    _localVars.maxSwing
                );
                if (_localVars.err) return (false, 0, 0, 0, false, 0);
                if (_localVars.priceCapped) {
                    // save for use in log
                    _localVars.cappingAnchorPrice = _localVars.anchorPrice;
                }
            } else {
                // Setting first price. Accept as is (already assigned above from _requestedPrice) and use as anchor
                _localVars.anchorPrice = _requestedPrice;
            }
        }

        // Fail if anchorPrice or price is zero.
        // zero anchor represents an unexpected situation likely due to a problem in this contract
        // zero price is more likely as the result of bad input from the caller of this function
        if (_localVars.anchorPrice == 0 || _localVars.price == 0) {
            // If we get here price could also be zero, but it does not seem worthwhile to distinguish the 3rd case
            return (false, 0, 0, 0, false, 0);
        }

        return (
            true,
            _localVars.price,
            _localVars.currentPeriod,
            _localVars.anchorPeriod,
            _localVars.priceCapped,
            _localVars.cappingAnchorPrice
        );
    }

    /**
     * @notice Entry point for updating prices.
     * @dev Set price for an asset.
     * @param _asset Asset address.
     * @param _requestedPrice Requested new price, scaled by 10**18.
     * @return Boolean ture:success, false:fail.
     */
    function _setPriceInternal(address _asset, uint256 _requestedPrice)
        internal
        returns (bool)
    {
        (
            bool _success,
            uint256 _price,
            uint256 _currentPeriod,
            uint256 _anchorPeriod,
            bool _priceCapped,
            uint256 _cappingAnchorPrice
        ) = _updatePriceRes(_asset, _requestedPrice);

        if (_success) {
            // BEGIN SIDE EFFECTS

            // Set pendingAnchor = Nothing
            // Pending anchor is only used once.
            if (pendingAnchors_[_asset] != 0) {
                pendingAnchors_[_asset] = 0;
            }

            // If currentPeriod > anchorPeriod:
            //  Set anchors_[_asset] = (currentPeriod, price)
            //  The new anchor is if we're in a new period or we had a pending anchor, then we become the new anchor
            if (_currentPeriod > _anchorPeriod) {
                anchors_[_asset] = Anchor({
                    period: _currentPeriod,
                    price: _price
                });
            }

            uint256 _previousPrice = assetPrices_[_asset];

            assetPrices_[_asset] = _price;

            emit PricePosted(_asset, _previousPrice, _requestedPrice, _price);

            if (_priceCapped) {
                // We have set a capped price. Log it so we can detect the situation and investigate.
                emit CappedPricePosted(
                    _asset,
                    _requestedPrice,
                    _cappingAnchorPrice,
                    _price
                );
            }
        }

        return _success;
    }

    /**
     * @dev Set price for an asset.
     * @param _asset Asset address.
     * @param _requestedPrice Requested new price, scaled by 10**18.
     * @return Boolean ture:success, false:fail.
     */
    function _setPrice(address _asset, uint256 _requestedPrice)
        external
        virtual
        onlyOwner
        returns (bool)
    {
        return _setPriceInternal(_asset, _requestedPrice);
    }

    /**
     * @dev Get asset price.
     * @param _asset Asset address.
     * @return Asset price.
     */
    function _getAssetPrice(address _asset)
        internal
        view
        virtual
        returns (uint256)
    {
        return assetPrices_[_asset];
    }

    /**
     * @dev Get asset price.
     * @param _asset Asset address.
     * @return Asset price.
     */
    function getAssetPrice(address _asset)
        external
        virtual
        override
        returns (uint256)
    {
        return _getAssetPrice(_asset);
    }

    /**
     * @dev Get asset price status.
     * @param _asset Asset address.
     * @return Asset price status, ture: available; false: unavailable.
     */
    function getAssetStatus(address _asset)
        external
        virtual
        override
        returns (bool)
    {
        _asset;
        return true;
    }

    /**
     * @dev The price and status of the asset.
     * @param _asset Asset address.
     * @return Asset price and status.
     */
    function getAssetPriceStatus(address _asset)
        external
        virtual
        override
        returns (uint256, bool)
    {
        return (_getAssetPrice(_asset), true);
    }

    /**
     * @notice ready to update price.
     * @dev Whether the asset price needs to be updated.
     * @param _asset The asset address.
     * @param _requestedPrice New asset price.
     * @param _postSwing Min swing of the price feed.
     * @param _postBuffer Price invalidation buffer time.
     * @return _success bool true: can be updated; false: no need to update.
     */
    function readyToUpdate(
        address _asset,
        uint256 _requestedPrice,
        uint256 _postSwing,
        uint256 _postBuffer
    ) public view virtual returns (bool _success) {
        _postBuffer;
        uint256 _price;
        uint256 _currentPeriod;
        uint256 _anchorPeriod;
        (_success, _price, _currentPeriod, _anchorPeriod, , ) = _updatePriceRes(
            _asset,
            _requestedPrice
        );
        if (_success) {
            uint256 _assetPrice = assetPrices_[_asset];
            (, uint256 _swing) = _calculateSwing(_assetPrice, _requestedPrice);
            _success = _swing >= _postSwing;
            if (_success) {
                _success =
                    _price != _assetPrice ||
                    (_currentPeriod > _anchorPeriod &&
                        _price != anchors_[_asset].price);
            }
        }
    }

    /**
     * @dev The maximum allowed percentage difference between a new price and the anchor's price.
     * @return The global maximum swing.
     */
    function maxSwing() external view returns (uint256) {
        return maxSwing_;
    }

    /**
     * @dev Maximum swing by asset.
     * @param _asset Asset address.
     * @return The maximum swing value of the asset.
     */
    function maxSwings(address _asset) external view returns (uint256) {
        return maxSwings_[_asset];
    }

    /**
     * @dev Anchors by asset.
     * @param _asset Asset address.
     * @return Period = Floor(block.timestamp / numSecondsPerPeriod) + 1.
     *         Price in USD, scaled by decimals.
     */
    function anchors(address _asset) external view returns (uint256, uint256) {
        return (anchors_[_asset].period, anchors_[_asset].price);
    }

    /**
     * @dev Pending anchor prices by asset.
     * @param _asset Asset address.
     * @return Pending anchor.
     */
    function pendingAnchors(address _asset) external view returns (uint256) {
        return pendingAnchors_[_asset];
    }

    /**
     * @dev Asset price in storage.
     * @param _asset Asset address.
     * @return Asset price.
     */
    function assetPrices(address _asset) external view returns (uint256) {
        return assetPrices_[_asset];
    }
}
