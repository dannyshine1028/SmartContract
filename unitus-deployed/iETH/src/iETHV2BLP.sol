// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./iETHV2.sol";

interface IControllerBLP {
    function refreshEligibility(address _accounts) external;

    function refreshEligibilities(address[] memory _accounts) external;
}

/**
 * @title dForce's Lending Protocol Contract.
 * @notice iTokens which wrap Ether.
 * @author dForce Team.
 */
contract iETHV2BLP is iETHV2 {
    function mint(
        address _recipient,
        bool refreshEligibility
    ) external payable {
        super.mint(_recipient);

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

    function repayBorrow(bool refreshEligibility) external payable {
        super.repayBorrow();

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(msg.sender);
        }
    }

    function repayBorrowBehalf(
        address _borrower,
        bool refreshEligibility
    ) external payable {
        super.repayBorrowBehalf(_borrower);

        if (refreshEligibility) {
            IControllerBLP(address(controller)).refreshEligibility(_borrower);
        }
    }

    function liquidateBorrow(
        address _borrower,
        address _assetCollateral,
        bool refreshEligibility
    ) external payable {
        super.liquidateBorrow(_borrower, _assetCollateral);

        if (refreshEligibility) {
            address[] memory accounts = new address[](2);
            accounts[0] = _borrower;
            accounts[1] = msg.sender;
            IControllerBLP(address(controller)).refreshEligibilities(accounts);
        }
    }

    function mintForSelfAndEnterMarket(
        bool refreshEligibility
    ) external payable {
        super.mintForSelfAndEnterMarket();

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
