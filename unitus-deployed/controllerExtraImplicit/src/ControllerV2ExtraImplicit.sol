//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IController.sol";
import "./interface/IPriceOracle.sol";
import "./interface/IiToken.sol";
import "./interface/IRewardDistributor.sol";
import "./interface/ITimeLockStrategy.sol";
import "./interface/IDefaultTimeLock.sol";
import "./interface/IERC20Metadata.sol";

import "./library/Initializable.sol";
import "./library/Ownable.sol";
import "./library/SafeRatioMath.sol";

import "./ControllerV2ExtraBase.sol";

/**
 * @title dForce's lending controller Contract
 * @author dForce
 */
contract ControllerV2ExtraImplicit is
    ControllerV2ExtraBase,
    IControllerV2ExtraImplicit
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeRatioMath for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /*********************************/
    /******** Security Check *********/
    /*********************************/

    /**
     * @notice Ensure this is a Controller contract.
     */
    function isControllerExtraImplicit() external view override returns (bool) {
        return true;
    }

    /*********************************/
    /******** Admin Operations *******/
    /*********************************/

    /******** Protocol Operations *******/

    /**
     * @dev Admin function to update time lock contract
     * @param _newTimeLock new time lock contract
     */
    function _setTimeLock(address _newTimeLock) external override onlyOwner {
        address _oldTimeLock = timeLock;

        // timeLock can be zero
        require(_newTimeLock != _oldTimeLock, "_newTimeLock address invalid!");
        if (_newTimeLock != address(0)) {
            require(
                IDefaultTimeLock(_newTimeLock).controller() == address(this),
                "_newTimeLock's controller mismatch!"
            );
        }

        timeLock = _newTimeLock;

        emit NewTimeLock(_oldTimeLock, _newTimeLock);
    }

    /**
     * @dev Admin function to update time lock strategy contract
     * @param _newTimeLockStrategy new time lock strategy contract
     */
    function _setTimeLockStrategy(
        address _newTimeLockStrategy
    ) external override onlyOwner {
        address _oldTimeLockStrategy = timeLockStrategy;

        // timeLockStrategy can be zero
        require(
            _newTimeLockStrategy != _oldTimeLockStrategy,
            "_newTimeLockStrategy address invalid!"
        );
        if (_newTimeLockStrategy != address(0)) {
            require(
                IDefaultTimeLock(_newTimeLockStrategy).controller() ==
                    address(this),
                "_newTimeLockStrategy's controller mismatch!"
            );
        }

        timeLockStrategy = _newTimeLockStrategy;

        emit NewTimeLockStrategy(_oldTimeLockStrategy, _newTimeLockStrategy);
    }

    /******** SMode Operations *******/

    /**
     * @dev Add new sMode config
     * @param _liquidationIncentive the liquidation incentive of iToken in sMode
     * @param _closeFactor the close factor of iToken in sMode
     * @param _label the label of iToken in sMode
     */
    function _addSMode(
        uint256 _liquidationIncentive,
        uint256 _closeFactor,
        string memory _label
    ) external override onlyOwner {
        _addSModeInternal(_liquidationIncentive, _closeFactor, _label);
    }

    // Update `_liquidationIncentive` in the sMode
    function _setSModeLiquidationIncentive(
        uint8 _sModeID,
        uint256 _liquidationIncentive
    ) external override onlyOwner {
        // Should use `_setLiquidationIncentive` to set the sMode 0
        _validateSModeID(_sModeID, 1);
        _validateSModeLiquidationIncentive(_liquidationIncentive);

        uint256 _oldSModeLiquidationIncentive = sModes[_sModeID]
            .liquidationIncentive;
        sModes[_sModeID].liquidationIncentive = _liquidationIncentive;

        emit NewSModeLiquidationIncentive(
            _sModeID,
            _oldSModeLiquidationIncentive,
            _liquidationIncentive
        );
    }

    // Update `_closeFactor` in the sMode
    function _setSModeCloseFactor(
        uint8 _sModeID,
        uint256 _closeFactor
    ) external override onlyOwner {
        // Should use `_setCloseFactor` to set the sMode 0
        _validateSModeID(_sModeID, 1);
        _validateSModeCloseFactor(_closeFactor);

        uint256 _oldSModeCloseFactor = sModes[_sModeID].closeFactor;
        sModes[_sModeID].closeFactor = _closeFactor;

        emit NewSModeCloseFactor(_sModeID, _oldSModeCloseFactor, _closeFactor);
    }

    /******** Market Operations *******/

    /**
     * @notice Should use `DEBT_CEILING_DECIMALS` at the same time.
     * @dev Sets the debt ceiling in segregation mode for the _iToken
     * @param _iToken The _iToken to set debt ceiling
     * @param _newDebtCeiling The new debt ceiling for the _iToken
     */
    function _setDebtCeiling(
        address _iToken,
        uint256 _newDebtCeiling
    ) external override onlyOwner {
        _checkiTokenListed(_iToken);

        MarketV2 storage _market = markets[_iToken];
        uint256 _oldDebtCeiling = _market.debtCeiling;
        // non-segregated market can not be changed to segregated
        require(
            _oldDebtCeiling != 0,
            "_setDebtCeiling: can not change to segregated!"
        );

        _setDebtCeilingInternal(_iToken, _newDebtCeiling);
    }

    /**
     * @notice Only assets of the same family (eg USD stablecoins) should be borrowable in segregation mode to keep
     * consistency in the debt ceiling calculations
     * @dev When the flag _borrowable is true, it means that the _iToken can be borrowed against segregated collaterals,
     * and the amount borrowed will be added to the total debt exposure of the segregated collateral
     * @param _iToken The _iToken to set in segregation mode
     * @param _borrowable True if the _iToken is borrowable in segregation mode
     */
    function _setBorrowableInSegregation(
        address _iToken,
        bool _borrowable
    ) external override onlyOwner {
        _checkiTokenListed(_iToken);

        _setBorrowableInSegregationInternal(_iToken, _borrowable);
    }

    /**
     * @notice In V1, collateral factor of the iToken has been set.
     * @dev Only for setting the sMode config for iTokens in V1.
     * @param _iToken The _iToken will be added to sMode
     * @param _sModeID The _sModeID to which _iToken belongs
     * @param _sModeLtv The collateral factor of _iToken in the sMode
     * @param _sModeLiqThreshold The liquidation threshold of _iToken in the sMode
     */
    function _setSMode(
        address _iToken,
        uint8 _sModeID,
        uint256 _sModeLtv,
        uint256 _sModeLiqThreshold
    ) external override onlyOwner {
        _checkiTokenListed(_iToken);

        _setSModeInternal(_iToken, _sModeID, _sModeLtv, _sModeLiqThreshold);
    }

    /**
     * @notice Sets the LiquidationThreshold for a iToken
     * @dev Admin function to set LiquidationThreshold for a iToken
     * @param _iToken The token to set the liquidation threshold on
     * @param _newLiquidationThresholdMantissa The new liquidation threshold, scaled by 1e18
     */
    function _setLiquidationThreshold(
        address _iToken,
        uint256 _newLiquidationThresholdMantissa
    ) external override onlyOwner {
        _checkiTokenListed(_iToken);

        // Its value will be taken into account when calculate account equity
        // Check if the price is available for the calculation
        require(
            IPriceOracle(priceOracle).getUnderlyingPrice(_iToken) != 0,
            "_setLiquidationThreshold: Underlying price is unavailable!"
        );

        _setLiquidationThresholdInternal(
            _iToken,
            _newLiquidationThresholdMantissa
        );
    }

    // Update `_ltv` in the sMode
    function _setSModeLTV(
        address _iToken,
        uint256 _ltv
    ) external override onlyOwner {
        _checkiTokenListed(_iToken);

        require(
            markets[_iToken].sModeID > 0,
            "_setSModeLTV: has not set sMode!"
        );

        _validateSModeLTV(
            marketCollateralFactor[_iToken][0], // collateral factor
            marketCollateralFactor[_iToken][3], // sMode liquidation threshold
            _ltv
        );

        uint256 _oldSModeLTV = marketCollateralFactor[_iToken][2];
        marketCollateralFactor[_iToken][2] = _ltv;

        emit NewSModeLTV(_iToken, _oldSModeLTV, _ltv);
    }

    // Update `_liquidationThreshold` in the sMode
    function _setSModeLiquidationThreshold(
        address _iToken,
        uint256 _liquidationThreshold
    ) external override onlyOwner {
        _checkiTokenListed(_iToken);
        require(
            markets[_iToken].sModeID > 0,
            "_setSModeLiquidationThreshold: has not set sMode!"
        );
        _validateLiquidationThreshold(
            marketCollateralFactor[_iToken][2], // sModeLtv
            _liquidationThreshold
        );

        uint256 _oldSModeLiquidationThreshold = marketCollateralFactor[_iToken][
            3
        ];
        marketCollateralFactor[_iToken][3] = _liquidationThreshold;

        emit NewSModeLiquidationThreshold(
            _iToken,
            _oldSModeLiquidationThreshold,
            _liquidationThreshold
        );
    }

    /*********************************/
    /********* Policy Hooks **********/
    /*********************************/

    function beforeTransferUnderlying(
        address _iToken,
        address _underlying,
        uint256 _amount,
        address _recipient
    ) external override returns (address _dst) {
        // Will update timelock states, should only be called by iToken
        require(
            msg.sender == _iToken && iTokens.contains(_iToken),
            "sender must be iToken"
        );

        _dst = _recipient;

        // Direct transfer to _recipient
        if (timeLock == address(0) || timeLockStrategy == address(0)) {
            return _dst;
        }

        uint256 _delayTime = ITimeLockStrategy(timeLockStrategy)
            .calculateTimeLockParams(_iToken, _amount, _recipient);

        if (_delayTime != 0) {
            IDefaultTimeLock(timeLock).createAgreement(
                _underlying,
                _amount,
                _recipient,
                block.timestamp.add(_delayTime) // release time
            );

            _dst = timeLock;
        }
    }

    /*********************************/
    /** Account equity calculation ***/
    /*********************************/

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `iTokenBalance` is the number of iTokens the account owns in the collateral,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountEquityLocalVars {
        uint256 sumCollateral;
        uint256 sumBorrowed;
        uint256 iTokenBalance;
        uint256 borrowBalance;
        uint256 exchangeRateMantissa;
        uint256 underlyingPrice;
        uint256 collateralValue;
        uint256 borrowValue;
        bool isPriceValid;
        uint256 collateralFactor;
        uint8 accountSModeID;
        uint8 iTokenSModeID;
    }

    /**
     * @notice Calculates current account equity plus some token and amount to effect
     */
    function calcAccountEquityWithEffectV2(
        address _account,
        address _tokenToEffect,
        uint256 _redeemAmount,
        uint256 _borrowAmount,
        bool _isLiquidation
    )
        public
        view
        virtual
        override
        returns (uint256, uint256, uint256, uint256)
    {
        AccountEquityLocalVars memory _local;
        AccountData storage _accountData = accountsData[_account];

        _local.accountSModeID = accountsSMode[_account];

        // Calculate value of all collaterals
        // collateralValuePerToken = underlyingPrice * exchangeRate * collateralFactor
        // collateralValue = balance * collateralValuePerToken
        // sumCollateral += collateralValue
        uint256 _len = _accountData.collaterals.length();
        for (uint256 i = 0; i < _len; i++) {
            IiToken _token = IiToken(_accountData.collaterals.at(i));

            _local.iTokenSModeID = _getiTokenSModeID(address(_token));
            _local.collateralFactor = getCollateralFactor(
                address(_token),
                _local.accountSModeID,
                _local.iTokenSModeID,
                _isLiquidation
            );

            _local.iTokenBalance = IERC20Upgradeable(address(_token)).balanceOf(
                _account
            );
            _local.exchangeRateMantissa = _token.exchangeRateStored();

            if (_tokenToEffect == address(_token) && _redeemAmount > 0) {
                _local.iTokenBalance = _local.iTokenBalance.sub(_redeemAmount);
            }

            (_local.underlyingPrice, _local.isPriceValid) = IPriceOracle(
                priceOracle
            ).getUnderlyingPriceAndStatus(address(_token));

            require(
                _local.underlyingPrice != 0 && _local.isPriceValid,
                "Invalid price to calculate account equity"
            );

            _local.collateralValue = _local
                .iTokenBalance
                .mul(_local.underlyingPrice)
                .rmul(_local.exchangeRateMantissa)
                .rmul(_local.collateralFactor);

            _local.sumCollateral = _local.sumCollateral.add(
                _local.collateralValue
            );
        }

        // Calculate all borrowed value
        // borrowValue = underlyingPrice * underlyingBorrowed / borrowFactor
        // sumBorrowed += borrowValue
        _len = _accountData.borrowed.length();
        for (uint256 i = 0; i < _len; i++) {
            IiToken _token = IiToken(_accountData.borrowed.at(i));

            _local.borrowBalance = _token.borrowBalanceStored(_account);

            if (_tokenToEffect == address(_token) && _borrowAmount > 0) {
                _local.borrowBalance = _local.borrowBalance.add(_borrowAmount);
            }

            (_local.underlyingPrice, _local.isPriceValid) = IPriceOracle(
                priceOracle
            ).getUnderlyingPriceAndStatus(address(_token));

            require(
                _local.underlyingPrice != 0 && _local.isPriceValid,
                "Invalid price to calculate account equity"
            );

            // borrowFactorMantissa can not be set to 0
            _local.borrowValue = _local
                .borrowBalance
                .mul(_local.underlyingPrice)
                .rdiv(markets[address(_token)].borrowFactorMantissa);

            _local.sumBorrowed = _local.sumBorrowed.add(_local.borrowValue);
        }

        // Should never underflow
        return
            _local.sumCollateral > _local.sumBorrowed
                ? (
                    _local.sumCollateral - _local.sumBorrowed,
                    uint256(0),
                    _local.sumCollateral,
                    _local.sumBorrowed
                )
                : (
                    uint256(0),
                    _local.sumBorrowed - _local.sumCollateral,
                    _local.sumCollateral,
                    _local.sumBorrowed
                );
    }

    /**
     * @notice Calculate amount of collateral iToken to seize after repaying an underlying amount
     * @dev Used in liquidation
     * @param _iTokenBorrowed The iToken was borrowed
     * @param _iTokenCollateral The collateral iToken to be seized
     * @param _actualRepayAmount The amount of underlying token liquidator has repaid
     * @param _borrower The account whose borrow should be liquidated.
     * @return _seizedTokenCollateral amount of iTokenCollateral tokens to be seized
     */
    function liquidateCalculateSeizeTokensV2(
        address _iTokenBorrowed,
        address _iTokenCollateral,
        uint256 _actualRepayAmount,
        address _borrower
    ) external view virtual override returns (uint256 _seizedTokenCollateral) {
        /* Read oracle prices for borrowed and collateral assets */
        (uint256 _priceBorrowed, bool isPriceBorValid) = IPriceOracle(
            priceOracle
        ).getUnderlyingPriceAndStatus(_iTokenBorrowed);
        (uint256 _priceCollateral, bool isPriceColValid) = IPriceOracle(
            priceOracle
        ).getUnderlyingPriceAndStatus(_iTokenCollateral);

        require(
            _priceBorrowed != 0 &&
                isPriceBorValid &&
                _priceCollateral != 0 &&
                isPriceColValid,
            "Borrowed or Collateral asset price is invalid"
        );

        uint256 _liquidationIncentiveMantissa = getLiquidationIncentive(
            _iTokenCollateral,
            _borrower
        );
        uint256 _valueRepayPlusIncentive = _actualRepayAmount
            .mul(_priceBorrowed)
            .rmul(_liquidationIncentiveMantissa);

        // Use stored value here as it is view function
        uint256 _exchangeRateMantissa = IiToken(_iTokenCollateral)
            .exchangeRateStored();

        // seizedTokenCollateral = valueRepayPlusIncentive / valuePerTokenCollateral
        // valuePerTokenCollateral = exchangeRateMantissa * priceCollateral
        _seizedTokenCollateral = _valueRepayPlusIncentive
            .rdiv(_exchangeRateMantissa)
            .div(_priceCollateral);
    }

    /*********************************/
    /*** Account Markets Operation ***/
    /*********************************/

    /**
     * @dev Updates sMode ID for the caller.
     * @param _newSModeId new sMode ID user wants to enter.
     */
    function enterSMode(uint8 _newSModeId) external override {
        // Check sMode id.
        _validateSModeID(_newSModeId, 0);

        AccountData storage _accountData = accountsData[msg.sender];
        // Length of all the borrowed assets.
        uint256 _len = _accountData.borrowed.length();

        // If users do not borrow any assets, can set sMode ID directly.
        if (_len == 0) {
            _enterSMode(_newSModeId, msg.sender);
            return;
        }

        if (_newSModeId != 0) {
            // If users have borrowed some assets, all borrowed assets should belong to the new sMode ID.
            for (uint256 i = 0; i < _len; i++) {
                address _borrowedAsset = _accountData.borrowed.at(i);
                uint8 _borrowedAssetSModeID = _getiTokenSModeID(_borrowedAsset);
                require(
                    _borrowedAssetSModeID == _newSModeId,
                    "enterSMode: has borrowed asset of other sMode!"
                );
            }
        }

        _enterSMode(_newSModeId, msg.sender);

        // Calculate new equity with the new sMode config.
        // TODO: Maybe should update interest at first.
        (, uint256 _shortfall, , ) = calcAccountEquityWithEffectV2(
            msg.sender, // _account
            address(0), // _tokenToEffect,
            0, // _redeemAmount,
            0, // _borrowAmount,
            false // _isLiquidation
        );

        require(_shortfall == 0, "enterSMode: Do not have enough equity!");
    }

    /*********************************/
    /****** General Information ******/
    /*********************************/

    /**
     * @dev Get actual iToken collateral factor of the caller.
     */
    function getCollateralFactor(
        address _iToken,
        uint8 _accountSModeID,
        uint8 _iTokenSModeID,
        bool _isLiquidation
    ) public view override returns (uint256 _collateralFactor) {
        // if ((_accountSModeID == _iTokenSModeID) && _iTokenSModeID > 0) {
        //     _collateralFactor = _isLiquidation
        //         ? marketCollateralFactor[_iToken][3]
        //         : marketCollateralFactor[_iToken][2];
        // } else {
        //     _collateralFactor = _isLiquidation
        //         ? marketCollateralFactor[_iToken][1]
        //         : marketCollateralFactor[_iToken][0];
        // }

        uint256 _index;
        assembly {
            // isSMode = (_accountSModeID == _iTokenSModeID) && _iTokenSModeID > 0
            // isSMode << 1 | _isLiquidation
            _index := or(
                shl(
                    1,
                    and(
                        eq(_accountSModeID, _iTokenSModeID),
                        gt(_iTokenSModeID, 0)
                    )
                ),
                _isLiquidation
            )
        }
        _collateralFactor = marketCollateralFactor[_iToken][_index];
    }

    /**
     * @dev Get the length of all the sMode configs.
     */
    function getSModeLength() external view override returns (uint256) {
        return sModes.length;
    }

    function marketsV2(
        address _iToken
    ) external view returns (MarketV2 memory _market) {
        MarketV2 storage market = markets[_iToken];
        _market = MarketV2({
            collateralFactorMantissa: market.collateralFactorMantissa,
            borrowFactorMantissa: market.borrowFactorMantissa,
            borrowCapacity: market.borrowCapacity,
            supplyCapacity: market.supplyCapacity,
            mintPaused: market.mintPaused,
            redeemPaused: market.redeemPaused,
            borrowPaused: market.borrowPaused,
            sModeID: market.sModeID,
            borrowableInSegregation: market.borrowableInSegregation,
            debtCeiling: market.debtCeiling,
            currentDebt: market.currentDebt
        });
    }

    function getLTV(address _iToken) external view override returns (uint256) {
        return marketCollateralFactor[_iToken][0];
    }

    function getLiquidationThreshold(
        address _iToken
    ) external view override returns (uint256) {
        return marketCollateralFactor[_iToken][1];
    }

    function getSModeLTV(
        address _iToken
    ) external view override returns (uint256) {
        return marketCollateralFactor[_iToken][2];
    }

    function getSModeLiquidationThreshold(
        address _iToken
    ) external view override returns (uint256) {
        return marketCollateralFactor[_iToken][3];
    }
}
