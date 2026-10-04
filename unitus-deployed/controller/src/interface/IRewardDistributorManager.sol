//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IRewardDistributorManager {
    function isRewardDistributorManager() external view returns (bool);

    function controller() external view returns (address);

    function afterMint(
        address iToken,
        address minter,
        uint256 mintAmount,
        uint256 mintedAmount
    ) external;

    function afterRedeem(
        address iToken,
        address redeemer,
        uint256 redeemAmount,
        uint256 redeemedAmount
    ) external;

    function afterBorrow(
        address iToken,
        address borrower,
        uint256 borrowedAmount
    ) external;

    function afterRepayBorrow(
        address iToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external;

    function afterLiquidateBorrow(
        address iTokenBorrowed,
        address iTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repaidAmount,
        uint256 seizedAmount
    ) external;

    function afterSeize(
        address iTokenBorrowed,
        address iTokenCollateral,
        address liquidator,
        address borrower,
        uint256 seizedAmount
    ) external;

    function afterTransfer(
        address iToken,
        address from,
        address to,
        uint256 amount
    ) external;

    function afterFlashloan(
        address iToken,
        address to,
        uint256 amount
    ) external;

    function updateEligibleBalances(address[] memory _accounts) external;

    function updateEligibleBalance(address _account) external;
}
