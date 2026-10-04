//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "./interface/IController.sol";
import "./interface/IPriceOracle.sol";
import "./interface/IiToken.sol";
import "./interface/IRewardDistributorV3.sol";
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
contract ControllerV2ExtraExplicit is
    ControllerV2ExtraBase,
    IControllerV2ExtraExplicit
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
    function isControllerExtraExplicit() external view override returns (bool) {
        return true;
    }

    /**
     * @notice upgrade the controller to V2.
     */
    function initialize() external override {
        uint256 _liquidationIncentive = 0;
        uint256 _closeFactor = 0;
        string memory _label = "Default";

        // Initialize the default sMode.
        sModes.push(
            SModeConfig({
                liquidationIncentive: _liquidationIncentive,
                closeFactor: _closeFactor,
                label: _label
            })
        );

        // Use the length of sModes as the new sMode id.
        emit SModeAdded(0, _liquidationIncentive, _closeFactor, _label);
    }

    /**
     * @notice upgrade the controller to V2.
     */
    function _upgrade() external override {
        // Setup the liquidation threshold related configurations
        uint256 _len = iTokens.length();

        for (uint256 i = 0; i < _len; i++) {
            address _iToken = iTokens.at(i);
            MarketV2 storage market = markets[_iToken];
            uint256 _collateralFactor = market.collateralFactorMantissa;

            marketCollateralFactor[_iToken][0] = _collateralFactor;
            // TODO: How should we define new ltv and liquidation threshold
            _setLiquidationThresholdInternal(
                _iToken,
                _collateralFactor.mul(103).div(100)
            );

            IRewardDistributorSecondV3(rewardDistributor)._upgrade(_iToken);
        }

        // Initialize the default sMode.
        _addSModeInternal(
            liquidationIncentiveMantissa,
            closeFactorMantissa,
            "Default"
        );
    }

    /*********************************/
    /******** Admin Operations *******/
    /*********************************/

    /******** Protocol Operations *******/

    /**
     * @notice Admin function to add iToken into supported markets
     * Checks if the iToken already exists
     * Will `revert()` if any check fails
     */
    function _addMarketV2(
        IControllerV2.AddMarketV2LocalVars memory _vars
    ) external override {
        // Collateral Factor was duplicated in marketCollateralFactor
        marketCollateralFactor[_vars._iToken][0] = _vars._collateralFactor;

        _setLiquidationThresholdInternal(
            _vars._iToken,
            _vars._liquidationThreshold
        );

        if (_vars._sModeID != 0) {
            // Set config for sMode
            _setSModeInternal(
                _vars._iToken,
                _vars._sModeID,
                _vars._sModeLtv,
                _vars._sModeLiqThreshold
            );
        }

        if (_vars._borrowableInSegregation) {
            _setBorrowableInSegregationInternal(
                _vars._iToken,
                _vars._borrowableInSegregation
            );
        }

        if (_vars._debtCeiling != 0) {
            _setDebtCeilingInternal(_vars._iToken, _vars._debtCeiling);
        }
    }

    /**
     * @notice duplicates the global closeFactor into the sMode 0
     */
    function _setCloseFactor(
        uint256 _newCloseFactorMantissa
    ) external override {
        sModes[0].closeFactor = _newCloseFactorMantissa;
    }

    /**
     * @notice duplicates the global liquidation incentive into the sMode 0
     */
    function _setLiquidationIncentive(
        uint256 _newLiquidationIncentiveMantissa
    ) external override {
        sModes[0].liquidationIncentive = _newLiquidationIncentiveMantissa;
    }

    /******** Market Operations *******/

    /**
     * @notice duplicates the iToken collateral factor into the marketCollateralFactor 0
     */
    function _setCollateralFactor(
        address _iToken,
        uint256 _newCollateralFactorMantissa
    ) external override {
        _validateCollateralFactor(
            _newCollateralFactorMantissa,
            marketCollateralFactor[_iToken][1] // liquidation threshold
        );
        marketCollateralFactor[_iToken][0] = _newCollateralFactorMantissa;
    }

    /*********************************/
    /********* Policy Hooks **********/
    /*********************************/
    /**
     * @notice Hook function before iToken `borrow()`
     * Checks if the account should be allowed to borrow the given iToken
     * Will `revert()` if any check fails
     * @param _iToken The iToken to check the borrow against
     * @param _borrower The account which would borrow iToken
     * @param _borrowAmount The amount of underlying to borrow
     */
    function beforeBorrow(
        address _iToken,
        address _borrower,
        uint256 _borrowAmount
    ) external override {
        MarketV2 storage market = markets[_iToken];

        (
            bool _isInSegregationMode,
            address _segregationModeCollateral
        ) = getSegregationModeState(_borrower);

        if (_isInSegregationMode) {
            MarketV2 storage collateralMarket = markets[
                _segregationModeCollateral
            ];

            require(
                market.borrowableInSegregation,
                "beforeBorrow: Invalid to borrow in segregation mode!"
            );

            uint256 _newDebt = collateralMarket.currentDebt.add(
                _borrowAmount.div(
                    10 ** (_getDecimals(_iToken).sub(DEBT_CEILING_DECIMALS))
                )
            );

            require(
                _newDebt <= collateralMarket.debtCeiling,
                "beforeBorrow: Segregation debt ceiling exceeded!"
            );

            // only update state when called by corresponding iToken
            if (msg.sender == _iToken) {
                collateralMarket.currentDebt = _newDebt;
            }
        }

        // Check sMode ID of the `_borrower` and `_iToken`
        uint8 _borrowerSModeID = accountsSMode[_borrower];
        uint8 _iTokenSModeID = _getiTokenSModeID(_iToken);
        if (_borrowerSModeID != 0) {
            require(
                _iTokenSModeID == _borrowerSModeID,
                "beforeBorrow: Inconsistent sMode ID"
            );
        }
    }

    /**
     * @notice Hook function after iToken `repayBorrow()`
     * Will `revert()` if any operation fails
     * @param _iToken The iToken being repaid
     * @param _payer The account which would repay
     * @param _borrower The account which has borrowed
     * @param _repayAmount  The amount of underlying being repaid
     */
    function afterRepayBorrow(
        address _iToken,
        address _payer,
        address _borrower,
        uint256 _repayAmount
    ) external override {
        // Only update state when called by corresponding iToken
        if (msg.sender != _iToken) return;

        (
            bool _isInSegregationMode,
            address _segregationModeCollateral
        ) = getSegregationModeState(_borrower);

        if (_isInSegregationMode) {
            MarketV2 storage collateralMarket = markets[
                _segregationModeCollateral
            ];

            uint256 _currentDebt = collateralMarket.currentDebt;
            uint256 _repayDebt = _repayAmount.div(
                10 ** (_getDecimals(_iToken).sub(DEBT_CEILING_DECIMALS))
            );

            collateralMarket.currentDebt = _currentDebt < _repayDebt
                ? 0
                : _currentDebt.sub(_repayDebt);
        }

        _payer;
    }

    /*********************************/
    /*** Account Markets Operation ***/
    /*********************************/

    /**
     * @notice 1.1 If user does not have any collateral, enters market directly;
     *         1.2 If user has collaterals:
     *             1.2.1 If user is in segregation mode, revert
     *             1.2.2 If user is not in segregation mode:
     *                  1.2.2.1 If _iToken does not have debt ceiling, enters market
     *                  1.2.2.1 If _iToken has debt ceiling, revert
     * @dev check should add _iToken to the account's markets list for equity calculations
     * @param _iToken The MarketV2 to enter
     * @param _account The address of the account to modify
     */
    function beforeEnterMarket(
        address _iToken,
        address _account
    ) external view override {
        uint256 _enteredMarketsLength = getEnteredMarketsLength(_account);

        if (_enteredMarketsLength > 0) {
            (bool _isInSegregationMode, ) = getSegregationModeState(_account);
            MarketV2 storage market = markets[_iToken];

            if (_isInSegregationMode || market.debtCeiling != 0) {
                revert("_enterMarket: can only have one segregated collateral!");
            }
        }
    }

    function getCloseFactor(
        address _iToken,
        address _account
    ) external view override returns (uint256 _closeFactor) {
        uint8 _effectedSMode = _getEffectedSMode(_iToken, _account);

        _closeFactor = sModes[_effectedSMode].closeFactor;
    }
}
