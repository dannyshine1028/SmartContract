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

import "./ControllerStock.sol";

/**
 * @title dForce's lending controller Contract
 * @author dForce
 */
abstract contract ControllerV2ExtraBase is
    Initializable,
    Ownable,
    ControllerStorageV2Extra,
    IControllerV2ExtraBase
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeRatioMath for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    constructor() public {
        __initialize();
    }

    function __initialize() internal initializer {
        __Ownable_init();
    }

    /*********************************/
    /***** Internal  Functions *******/
    /*********************************/

    /******** validations *******/

    /**
     * @dev Check if _iToken is listed
     */
    function _checkiTokenListed(address _iToken) internal view {
        require(iTokens.contains(_iToken), "Token has not been listed");
    }

    /**
     * @dev Check if the _sModeID is valid
     */
    function _validateSModeID(uint8 _sModeID, uint8 validFrom) internal view {
        uint8 _totalSModes = uint8(sModes.length);
        require(
            _sModeID >= validFrom && _sModeID < _totalSModes,
            "_validateSModeID: Invalid sMode ID!"
        );
    }

    // Check if parameter `_liquidationIncentive` is valid in the sMode
    function _validateSModeLiquidationIncentive(
        uint256 _liquidationIncentive
    ) internal pure {
        require(
            _liquidationIncentive >= liquidationIncentiveMinMantissa &&
                _liquidationIncentive <= liquidationIncentiveMaxMantissa,
            "_validateSModeLiquidationIncentive: Invalid liquidation incentive!"
        );
    }

    // Check if parameter `_closeFactor` is valid in the sMode
    function _validateSModeCloseFactor(uint256 _closeFactor) internal pure {
        require(
            _closeFactor >= closeFactorMinMantissa &&
                _closeFactor <= closeFactorMaxMantissa,
            "_validateSModeCloseFactor: Invalid close factor!"
        );
    }

    // Check if parameter `_sModeLtv` is valid in the sMode
    function _validateSModeLTV(
        uint256 _collateralFactor,
        uint256 _sModeLiquidationThreshold,
        uint256 _sModeLtv
    ) internal pure {
        require(
            _sModeLtv >= _collateralFactor &&
                _sModeLtv <= _sModeLiquidationThreshold,
            "_validateSModeLTV: Invalid LTV!"
        );
    }

    // Check if parameter `_liquidationThreshold` is valid
    function _validateLiquidationThreshold(
        uint256 _ltv,
        uint256 _liquidationThreshold
    ) internal pure {
        require(
            _liquidationThreshold >= _ltv &&
                _liquidationThreshold <= collateralFactorMaxMantissa,
            "_validateLiquidationThreshold: Invalid liquidation threshold!"
        );
    }

    // Check if parameter `_collateralFactor` is valid
    function _validateCollateralFactor(
        uint256 _collateralFactor,
        uint256 _liquidationThreshold
    ) internal pure {
        // v1 has check some validation, only check against the liquidation threshold
        require(
            _collateralFactor <= _liquidationThreshold,
            "_validateCollateralFactor: Invalid collateral factor!"
        );
    }

    /******** Getters *******/

    function _getDecimals(address _iToken) internal view returns (uint256) {
        return uint256(IERC20Metadata(_iToken).decimals());
    }

    /**
     * @dev Get sMode id by iToken address.
     */
    function _getiTokenSModeID(
        address _iToken
    ) internal view returns (uint8 _iTokenSModeID) {
        MarketV2 storage _market = markets[_iToken];
        _iTokenSModeID = _market.sModeID;
    }

    function _getEffectedSMode(
        address _iToken,
        address _account
    ) internal view returns (uint8 _sModeID) {
        uint8 _accountSMode = accountsSMode[_account];
        _sModeID = _accountSMode == markets[_iToken].sModeID
            ? _accountSMode
            : 0;
    }

    /******** Setters *******/

    function _setBorrowableInSegregationInternal(
        address _iToken,
        bool _borrowable
    ) internal {
        MarketV2 storage _market = markets[_iToken];
        _market.borrowableInSegregation = _borrowable;

        emit BorrowableInSegregationChanged(_iToken, _borrowable);
    }

    function _setDebtCeilingInternal(
        address _iToken,
        uint256 _newDebtCeiling
    ) internal {
        MarketV2 storage _market = markets[_iToken];
        uint256 _oldDebtCeiling = _market.debtCeiling;

        _market.debtCeiling = _newDebtCeiling;

        emit DebtCeilingChanged(_iToken, _oldDebtCeiling, _newDebtCeiling);
    }

    function _setLiquidationThresholdInternal(
        address _iToken,
        uint256 _newLiquidationThresholdMantissa
    ) internal {
        _validateLiquidationThreshold(
            marketCollateralFactor[_iToken][0],
            _newLiquidationThresholdMantissa
        );

        uint256 _oldLiquidationThresholdMantissa = marketCollateralFactor[
            _iToken
        ][1];
        marketCollateralFactor[_iToken][1] = _newLiquidationThresholdMantissa;

        emit NewLiquidationThreshold(
            _iToken,
            _oldLiquidationThresholdMantissa,
            _newLiquidationThresholdMantissa
        );
    }

    /**
     * @dev Sets the sMode config for iToken
     */
    function _setSModeInternal(
        address _iToken,
        uint8 _newSModeID,
        uint256 _sModeLtv,
        uint256 _sModeLiqThreshold
    ) internal {
        _validateSModeID(_newSModeID, 1);

        MarketV2 storage _market = markets[_iToken];
        uint8 _oldSModeID = _market.sModeID;

        require(_oldSModeID == 0, "_setSMode: Has set sMode id!");
        _validateSModeLTV(
            _market.collateralFactorMantissa,
            _sModeLiqThreshold,
            _sModeLtv
        );
        _validateLiquidationThreshold(_sModeLtv, _sModeLiqThreshold);

        _market.sModeID = _newSModeID;

        uint256 _oldSModeLtv = marketCollateralFactor[_iToken][2];
        marketCollateralFactor[_iToken][2] = _sModeLtv;
        uint256 _oldSModeLiqThreshold = marketCollateralFactor[_iToken][3];
        marketCollateralFactor[_iToken][3] = _sModeLiqThreshold;

        emit SModeChanged(_iToken, _oldSModeID, _newSModeID);
        emit NewSModeLTV(_iToken, _oldSModeLtv, _sModeLtv);
        emit NewSModeLiquidationThreshold(
            _iToken,
            _oldSModeLiqThreshold,
            _sModeLiqThreshold
        );
    }

    function _addSModeInternal(
        uint256 _liquidationIncentive,
        uint256 _closeFactor,
        string memory _label
    ) internal {
        uint8 _sModesLen = uint8(sModes.length);
        require(_sModesLen < MAX_SMODE_ID, "_addSMode: Max SMode reached!");

        // Check parameters in the sMode.
        _validateSModeLiquidationIncentive(_liquidationIncentive);
        _validateSModeCloseFactor(_closeFactor);

        sModes.push(
            SModeConfig({
                liquidationIncentive: _liquidationIncentive,
                closeFactor: _closeFactor,
                label: _label
            })
        );

        // Use the length of sModes as the new sMode id.
        emit SModeAdded(
            _sModesLen,
            _liquidationIncentive,
            _closeFactor,
            _label
        );
    }

    /**
     * @notice Has already checked the parameter `_newSModeId`.
     * @dev Update caller's sMode ID.
     */
    function _enterSMode(uint8 _newSModeId, address _account) internal {
        uint8 _oldSModeID = accountsSMode[_account];
        accountsSMode[_account] = _newSModeId;

        emit SModeEntered(_oldSModeID, _newSModeId, _account);
    }

    /*********************************/
    /****** General Information ******/
    /*********************************/

    /**
     * @param _account The address of the account to query
     * @return _len The length of the markets that account has entered
     */
    function getEnteredMarketsLength(
        address _account
    ) internal view returns (uint256 _len) {
        AccountData storage _accountData = accountsData[_account];

        _len = _accountData.collaterals.length();
    }

    function getSegregationModeState(
        address _account
    ) public view override returns (bool, address) {
        AccountData storage _accountData = accountsData[_account];

        if (_accountData.collaterals.length() > 0) {
            // Has collateral
            address firstCollateral = _accountData.collaterals.at(0);
            MarketV2 storage _market = markets[firstCollateral];

            if (_market.debtCeiling > 0) {
                return (true, firstCollateral);
            }
        }

        return (false, address(0));
    }

    function getLiquidationIncentive(
        address _iToken,
        address _account
    ) public view override returns (uint256 _liquidationIncentive) {
        uint8 effectedSMode = _getEffectedSMode(_iToken, _account);

        _liquidationIncentive = sModes[effectedSMode].liquidationIncentive;
    }
}
