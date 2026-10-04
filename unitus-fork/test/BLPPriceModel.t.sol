// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IOracle {
    function getUnderlyingPrice(address asset) external view returns (uint256);
    function getUnderlyingPriceAndStatus(address asset) external returns (uint256, bool);
    function priceModel(address asset) external view returns (address);
}

interface IEligibilityManager {
    function isEligible(address account) external returns (bool, bool);
    function thresholdRatio() external view returns (uint256);
    function oracle() external view returns (address);
}

interface IAeroPool {
    function getReserves() external view returns (uint256, uint256, uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/**
 * HOOK-1 gating question: is the BLP price model 0x33C2... manipulable by moving the
 * ~$27 Aerodrome vAMM-UTS/USX pool, or is it a manipulation-resistant / poster price?
 *
 * We do NOT send anything to Base. We fork, then on the fork: read the price, perform a
 * swap directly against the pool to skew reserves, and re-read the price. If the oracle
 * price barely moves, HOOK-1 is disproved (the model is not spot-reserve based).
 */
contract BLPPriceModelTest is Test {
    address constant ORACLE = 0x4B60aA7777c96D595c4a662B654D73F579fF3650;
    address constant EM     = 0xF4266178c2B1Fce48BEB9d648a806226FD945555;
    address constant BLP    = 0xB0770d4f5c430b1C3C832c62Ac1AB12B49c9D277; // vAMM-UTS/USX
    address constant UTS    = 0x3B6564b5DA73A41d3A66e6558a98FD0e9E1e77ad;
    address constant USX    = 0xc142171B138DB17a1B7Cb999C44526094a4dae05;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("base"), vm.envUint("PIN_BLOCK"));
    }

    function test_blp_priceModelIdentity() public {
        emit log_named_address("priceModel(BLP)", IOracle(ORACLE).priceModel(BLP));
        emit log_named_uint("getUnderlyingPrice(BLP)", IOracle(ORACLE).getUnderlyingPrice(BLP));
        emit log_named_uint("thresholdRatio", IEligibilityManager(EM).thresholdRatio());
        (uint256 r0, uint256 r1, ) = IAeroPool(BLP).getReserves();
        emit log_named_uint("reserve UTS", r0);
        emit log_named_uint("reserve USX", r1);
    }

    /// Directly skew the pool reserves and see whether the oracle BLP price follows.
    function test_blp_isSpotManipulable() public {
        uint256 pBefore = IOracle(ORACLE).getUnderlyingPrice(BLP);
        (uint256 r0Before, uint256 r1Before, ) = IAeroPool(BLP).getReserves();

        // Give ourselves a large pile of UTS and dump it into the pool to crush the UTS side.
        // vAMM-UTS/USX: token0 = UTS, token1 = USX. Push UTS in, pull USX out.
        uint256 utsIn = r0Before * 50; // 50x the UTS reserve — an extreme skew
        deal(UTS, address(this), utsIn);
        IERC20(UTS).transfer(BLP, utsIn);
        // pull out almost all USX (leave 1 wei so the pool invariant can still be satisfied)
        uint256 usxOut = r1Before - 1;
        // volatile-pool swap: amount0Out=0 (UTS), amount1Out=usxOut (USX)
        try IAeroPool(BLP).swap(0, usxOut, address(this), "") {
            emit log("swap succeeded");
        } catch {
            // if the AMM math rejects the exact out, just sync the donated reserves
            IAeroPool(BLP).sync();
            emit log("swap reverted; synced donated reserves instead");
        }

        (uint256 r0After, uint256 r1After, ) = IAeroPool(BLP).getReserves();
        uint256 pAfter = IOracle(ORACLE).getUnderlyingPrice(BLP);

        emit log_named_uint("reserve UTS before", r0Before);
        emit log_named_uint("reserve UTS after ", r0After);
        emit log_named_uint("reserve USX before", r1Before);
        emit log_named_uint("reserve USX after ", r1After);
        emit log_named_uint("BLP price before", pBefore);
        emit log_named_uint("BLP price after ", pAfter);

        if (pAfter == pBefore) {
            emit log(">>> PRICE UNCHANGED despite extreme reserve skew -> NOT spot-based -> HOOK-1 DISPROVED");
        } else {
            uint256 move = pAfter > pBefore
                ? (pAfter - pBefore) * 10000 / pBefore
                : (pBefore - pAfter) * 10000 / pBefore;
            emit log_named_uint("price move (bps)", move);
        }
    }
}
