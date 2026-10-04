//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./ControllerV2.sol";
import "./interface/IRewardDistributorManager.sol";

/**
 * @title dForce's lending controller Contract
 * @author dForce
 */
contract ControllerV2BLP is ControllerV2 {
    constructor(
        address _newExtraImplicit,
        address _newExtraExplicit
    ) public ControllerV2(_newExtraImplicit, _newExtraExplicit) {}

    /**
     * @notice Sets Reward Distributor
     * @dev Admin function to set reward distributor
     * @param _newRewardDistributor new reward distributor
     */
    function _setRewardDistributor(
        address _newRewardDistributor
    ) external override onlyOwner {
        address _oldRewardDistributor = rewardDistributor;

        require(
            IRewardDistributorManager(_newRewardDistributor)
                .isRewardDistributorManager() &&
                IRewardDistributorManager(_newRewardDistributor).controller() ==
                address(this),
            "_newRewardDistributor is invalid or its controller mismatch!"
        );

        rewardDistributor = _newRewardDistributor;
        emit NewRewardDistributor(_oldRewardDistributor, _newRewardDistributor);
    }

    /**
     * @notice Hook function after iToken `mint()`
     * Will `revert()` if any operation fails
     * @param _iToken The iToken being minted
     * @param _minter The account which would get the minted tokens
     * @param _mintAmount The amount of underlying being minted to iToken
     * @param _mintedAmount The amount of iToken being minted
     */
    function afterMint(
        address _iToken,
        address _minter,
        uint256 _mintAmount,
        uint256 _mintedAmount
    ) public override {
        super.afterMint(_iToken, _minter, _mintAmount, _mintedAmount);

        _checkiTokenListed(_iToken);
        if (msg.sender == _iToken) {
            IRewardDistributorManager(rewardDistributor).afterMint(
                _iToken,
                _minter,
                _mintAmount,
                _mintedAmount
            );
        }
    }

    /**
     * @notice Hook function after iToken `redeem()`
     * Will `revert()` if any operation fails
     * @param _iToken The iToken being redeemed
     * @param _redeemer The account which redeemed iToken
     * @param _redeemAmount  The amount of iToken being redeemed
     * @param _redeemedUnderlying The amount of underlying being redeemed
     */
    function afterRedeem(
        address _iToken,
        address _redeemer,
        uint256 _redeemAmount,
        uint256 _redeemedUnderlying
    ) public override {
        super.afterRedeem(
            _iToken,
            _redeemer,
            _redeemAmount,
            _redeemedUnderlying
        );

        _checkiTokenListed(_iToken);
        if (msg.sender == _iToken) {
            IRewardDistributorManager(rewardDistributor).afterRedeem(
                _iToken,
                _redeemer,
                _redeemAmount,
                _redeemedUnderlying
            );
        }
    }

    /**
     * @notice Hook function after iToken `borrow()`
     * Will `revert()` if any operation fails
     * @param _iToken The iToken being borrewd
     * @param _borrower The account which borrowed iToken
     * @param _borrowedAmount  The amount of underlying being borrowed
     */
    function afterBorrow(
        address _iToken,
        address _borrower,
        uint256 _borrowedAmount
    ) public override {
        super.afterBorrow(_iToken, _borrower, _borrowedAmount);

        _checkiTokenListed(_iToken);
        if (msg.sender == _iToken) {
            IRewardDistributorManager(rewardDistributor).afterBorrow(
                _iToken,
                _borrower,
                _borrowedAmount
            );
        }
    }

    /**
     * @notice Hook function after iToken `repayBorrow()`
     * Will `revert()` if any operation fails
     * @param _iToken The iToken being repaid
     * @param _payer The account which would repay
     * @param _borrower The account which has borrowed
     * @param _repayAmount  The amount of underlying being repaied
     */
    function afterRepayBorrow(
        address _iToken,
        address _payer,
        address _borrower,
        uint256 _repayAmount
    ) public override {
        super.afterRepayBorrow(_iToken, _payer, _borrower, _repayAmount);

        _checkiTokenListed(_iToken);
        if (msg.sender == _iToken) {
            IRewardDistributorManager(rewardDistributor).afterRepayBorrow(
                _iToken,
                _payer,
                _borrower,
                _repayAmount
            );
        }
    }

    /**
     * @notice Hook function after iToken `liquidateBorrow()`
     * Will `revert()` if any operation fails
     * @param _iTokenBorrowed The iToken was borrowed
     * @param _iTokenCollateral The collateral iToken to be seized
     * @param _liquidator The account which would repay and seize
     * @param _borrower The account which has borrowed
     * @param _repaidAmount  The amount of underlying being repaied
     * @param _seizedAmount  The amount of collateral being seized
     */
    function afterLiquidateBorrow(
        address _iTokenBorrowed,
        address _iTokenCollateral,
        address _liquidator,
        address _borrower,
        uint256 _repaidAmount,
        uint256 _seizedAmount
    ) public override {
        super.afterLiquidateBorrow(
            _iTokenBorrowed,
            _iTokenCollateral,
            _liquidator,
            _borrower,
            _repaidAmount,
            _seizedAmount
        );

        _checkiTokenListed(_iTokenCollateral);
        _checkiTokenListed(_iTokenBorrowed);
        if (msg.sender == _iTokenBorrowed) {
            IRewardDistributorManager(rewardDistributor).afterLiquidateBorrow(
                _iTokenBorrowed,
                _iTokenCollateral,
                _liquidator,
                _borrower,
                _repaidAmount,
                _seizedAmount
            );
        }
    }

    /**
     * @notice Hook function after iToken `seize()`
     * Will `revert()` if any operation fails
     * @param _iTokenCollateral The collateral iToken to be seized
     * @param _iTokenBorrowed The iToken was borrowed
     * @param _liquidator The account which has repaid and seized
     * @param _borrower The account which has borrowed
     * @param _seizedAmount  The amount of collateral being seized
     */
    function afterSeize(
        address _iTokenCollateral,
        address _iTokenBorrowed,
        address _liquidator,
        address _borrower,
        uint256 _seizedAmount
    ) public override {
        super.afterSeize(
            _iTokenCollateral,
            _iTokenBorrowed,
            _liquidator,
            _borrower,
            _seizedAmount
        );

        _checkiTokenListed(_iTokenCollateral);
        _checkiTokenListed(_iTokenBorrowed);
        if (msg.sender == _iTokenCollateral) {
            IRewardDistributorManager(rewardDistributor).afterSeize(
                _iTokenCollateral,
                _iTokenBorrowed,
                _liquidator,
                _borrower,
                _seizedAmount
            );
        }
    }

    /**
     * @notice Hook function after iToken `transfer()`
     * Will `revert()` if any operation fails
     * @param _iToken The iToken was transfered
     * @param _from The account was transfer from
     * @param _to The account was transfer to
     * @param _amount  The amount was transfered
     */
    function afterTransfer(
        address _iToken,
        address _from,
        address _to,
        uint256 _amount
    ) public override {
        super.afterTransfer(_iToken, _from, _to, _amount);

        _checkiTokenListed(_iToken);
        if (msg.sender == _iToken) {
            IRewardDistributorManager(rewardDistributor).afterTransfer(
                _iToken,
                _from,
                _to,
                _amount
            );
        }
    }

    /**
     * @notice Hook function after iToken `flashloan()`
     * Will `revert()` if any operation fails
     * @param _to The account flashloan transfer to
     * @param _iToken The iToken was flashloaned
     * @param _amount  The amount was flashloaned
     */
    function afterFlashloan(
        address _iToken,
        address _to,
        uint256 _amount
    ) public override {
        super.afterFlashloan(_iToken, _to, _amount);

        _checkiTokenListed(_iToken);
        if (msg.sender == _iToken) {
            IRewardDistributorManager(rewardDistributor).afterFlashloan(
                _iToken,
                _to,
                _amount
            );
        }
    }

    function refreshEligibility(address _account) public {
        IRewardDistributorManager(rewardDistributor).updateEligibleBalance(
            _account
        );
    }

    function refreshEligibilities(address[] memory _accounts) public {
        IRewardDistributorManager(rewardDistributor).updateEligibleBalances(
            _accounts
        );
    }
}
