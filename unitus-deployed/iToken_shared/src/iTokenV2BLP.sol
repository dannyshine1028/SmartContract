// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./iTokenV2.sol";

interface IControllerBLP {
    function refreshEligibility(address _accounts) external;

    function refreshEligibilities(address[] memory _accounts) external;
}

/**
 * @title dForce's Lending Protocol Contract.
 * @notice iTokens which wrap an EIP-20 underlying.
 * @author dForce Team.
 */
contract iTokenV2BLP is iTokenV2 {
    function mint(
        address _recipient,
        uint256 _mintAmount,
        bool refreshEligibility
    ) external {
        super.mint(_recipient, _mintAmount);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(_recipient);
        }
    }

    function redeem(
        address _from,
        uint256 _redeemiToken,
        bool refreshEligibility
    ) external {
        super.redeem(_from, _redeemiToken);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(_from);
        }
    }

    function redeemUnderlying(
        address _from,
        uint256 _redeemUnderlying,
        bool refreshEligibility
    ) external {
        super.redeemUnderlying(_from, _redeemUnderlying);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(_from);
        }
    }

    function borrow(uint256 _borrowAmount, bool refreshEligibility) external {
        super.borrow(_borrowAmount);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(msg.sender);
        }
    }

    function repayBorrow(
        uint256 _repayAmount,
        bool refreshEligibility
    ) external {
        super.repayBorrow(_repayAmount);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(msg.sender);
        }
    }

    /**
     * @dev Caller repays a borrow belonging to borrower.
     * @param _borrower the account with the debt being payed off.
     * @param _repayAmount The amount to repay.
     */
    function repayBorrowBehalf(
        address _borrower,
        uint256 _repayAmount,
        bool refreshEligibility
    ) external {
        super.repayBorrowBehalf(_borrower, _repayAmount);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(_borrower);
        }
    }

    function liquidateBorrow(
        address _borrower,
        uint256 _repayAmount,
        address _assetCollateral,
        bool refreshEligibility
    ) external {
        super.liquidateBorrow(_borrower, _repayAmount, _assetCollateral);

        if (refreshEligibility) {
            address[] memory accounts = new address[](2);
            accounts[0] = _borrower;
            accounts[1] = msg.sender;
            IControllerBLP(address(controller)).refreshEligibilities(accounts);
        }
    }

    function mintForSelfAndEnterMarket(
        uint256 _mintAmount,
        bool refreshEligibility
    ) external {
        super.mintForSelfAndEnterMarket(_mintAmount);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(msg.sender);
        }
    }

    function redeemFromSelfAndExitMarket(
        uint256 _redeemiToken,
        bool refreshEligibility
    ) external {
        super.redeemFromSelfAndExitMarket(_redeemiToken);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(msg.sender);
        }
    }
}
