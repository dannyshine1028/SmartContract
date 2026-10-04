// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../interface/IPriceModel.sol";

abstract contract Unit is IPriceModel {
    using SafeMath for uint256;

    /// @dev Double decimal point constant for padding token decimal point.
    uint256 internal constant doubleDecimals_ = 36;

    /// @dev Whether it is a priceModel contract.
    bool public constant override isPriceModel = true;

    /**
     * @notice Correct price.
     * @dev Correct price using price decimals and token decimals.
     * @param _assetDecimals Asset token decimals.
     * @param _priceDecimals Price token decimals.
     * @param _price Price.
     * @return Corrected price.
     */
    function _correctPrice(
        uint256 _assetDecimals,
        uint256 _priceDecimals,
        uint256 _price
    ) internal pure virtual returns (uint256) {
        return
            _price.mul(
                10**(doubleDecimals_.sub(_assetDecimals.add(_priceDecimals)))
            );
    }
}
