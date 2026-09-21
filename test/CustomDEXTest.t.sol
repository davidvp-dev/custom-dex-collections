// SPDX-License-Identifier: MIT
// forge test --match-test testDeployOK -vvvv --fork-url https://arb1.arbitrum.io/rpc
// ARB-USDC V2 pool https://arbiscan.io/address/0x011f31D20C8778c8Beb1093b73E3A5690Ee6271b
pragma solidity 0.8.34;

import { CustomDEX } from "../src/CustomDEX.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "../src/interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "../src/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";

contract CustomDEXTest is Test {
    CustomDEX dex;
    address constant UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address constant UNISWAP_V2_FACTORY = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9;
    address user = 0x8a53B8b59877df193C6dAE7B8D1d38251af563Cf; // Address with USDC in Arbitrum Mainnet
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC in Arbitrum Mainnet (6 decimals)
    address constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548; // ARB in Arbitrum Mainnet (18 decimals)

    address constant NFT_DAVID_COLLECTION = 0x10604f011040Fa287a7f3B73d97d7099Cb9116bA;

    function setUp() public {
        dex = new CustomDEX(UNISWAP_V2_ROUTER, UNISWAP_V2_FACTORY, NFT_DAVID_COLLECTION);
    }

    function testDeployOK() public view {
        assertEq(dex.UNISWAP_V2_ROUTER_ADDRESS(), UNISWAP_V2_ROUTER);
        assertEq(dex.UNISWAP_V2_FACTORY_ADDRESS(), UNISWAP_V2_FACTORY);
    }

    function testSwapOK() public {
        // 0. Setup variables for the test
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = ARB;
        uint256 amountIn = 1 * 1e6; // swap 1 USDC

        // simulate what the front would to: off-chain query the expected result
        uint256[] memory expectedAmounts = IUniswapV2Router02(UNISWAP_V2_ROUTER).getAmountsOut(amountIn, path);
        uint256 expectedOut = expectedAmounts[expectedAmounts.length - 1];

        // apply slippage tolerance same as front would do
        uint256 amountOutMin = (expectedOut * 995) / 1000; // 0.5% slippage

        vm.startPrank(user);

        IERC20(USDC).approve(address(dex), amountIn);

        uint256 arbBalBefore = IERC20(ARB).balanceOf(user);
        dex.swapTokens(amountIn, amountOutMin, path, block.timestamp + 300);
        uint256 arbBalAfter = IERC20(ARB).balanceOf(user);

        assert(arbBalBefore == 0);
        assert(arbBalAfter >= amountOutMin);

        vm.stopPrank();
    }

    function testAddLiquidityOK() public {
        // LP using USDC and ARB
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = ARB;
        uint256 amountADesired = 10 * 1e6; // 10 USDC paired with ? ARB

        vm.startPrank(user);
        // ---- This is what a frontend would do to calculate each parameter for addLiquidity() function ----
        // 1. first find the pair
        address pair = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(USDC, ARB);
        assert(pair != address(0));

        // 2. then read reserves and order by tokenA/tokenB (getReserves() order can be different)
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        (uint256 reserveA, uint256 reserveB) =
            token0 == USDC ? (uint256(reserve0), uint256(reserve1)) : (uint256(reserve1), uint256(reserve0));

        // 3. then calculate amountBDesired proportional to reserves of the pool
        uint256 amountBDesired = IUniswapV2Router02(UNISWAP_V2_ROUTER).quote(amountADesired, reserveA, reserveB);

        // 4. apply slippage to both min amounts to prevent revert
        uint256 slippageBps = 50; // 0.5%
        uint256 amountAMin = amountADesired * (10_000 - slippageBps) / 10_000;
        uint256 amountBMin = amountBDesired * (10_000 - slippageBps) / 10_000;
        // ---- end front simulation ----

        // Finally execute addLiquidity function
        deal(ARB, user, amountBDesired); // fund user with calculated ARB tokens
        assert(IERC20(ARB).balanceOf(user) >= amountBDesired);
        IERC20(USDC).approve(address(dex), amountADesired);
        IERC20(ARB).approve(address(dex), amountBDesired);

        uint256 balABefore = IERC20(USDC).balanceOf(user);
        uint256 balBBefore = IERC20(ARB).balanceOf(user);
        uint256 lpTokens =
            dex.addLiquidity(USDC, ARB, amountADesired, amountBDesired, amountAMin, amountBMin, block.timestamp + 300);
        uint256 balAAfter = IERC20(USDC).balanceOf(user);
        uint256 balBAfter = IERC20(ARB).balanceOf(user);

        assert(lpTokens > 0);
        assert(balABefore - balAAfter <= amountADesired);
        assert(balBBefore - balBAfter <= amountBDesired);

        vm.stopPrank();
    }

    function testRemoveLiquidityOK() public {
        // LP using USDC and ARB
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = ARB;
        uint256 amountADesired = 10 * 1e6; // 10 USDC paired with ? ARB

        vm.startPrank(user);
        /* FIRST ADD LIQUIDITY TO GET LP TOKENS IN USDC/ARB POOL */

        // ---- This is what a frontend would do to calculate each parameter for addLiquidity() function ----
        // 1. first find the pair
        address pair = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(USDC, ARB);
        assert(pair != address(0));

        // 2. then read reserves and order by tokenA/tokenB (getReserves() order can be different)
        (uint256 reserveA, uint256 reserveB) = _getReserves(pair, USDC);

        // 3. then calculate amountBDesired proportional to reserves of the pool
        uint256 amountBDesired = IUniswapV2Router02(UNISWAP_V2_ROUTER).quote(amountADesired, reserveA, reserveB);

        // 4. apply slippage to both min amounts to prevent revert
        uint256 slippageBps = 50; // 0.5%
        uint256 amountAMin = amountADesired * (10_000 - slippageBps) / 10_000;
        uint256 amountBMin = amountBDesired * (10_000 - slippageBps) / 10_000;
        // ---- end front simulation ----

        // Finally execute addLiquidity function
        deal(ARB, user, amountBDesired); // fund user with calculated ARB tokens
        assert(IERC20(ARB).balanceOf(user) >= amountBDesired);
        IERC20(USDC).approve(address(dex), amountADesired);
        IERC20(ARB).approve(address(dex), amountBDesired);

        console.log("addLiquidity - amountADesired:", amountADesired);
        console.log("addLiquidity - amountBDesired:", amountBDesired);

        uint256 balABefore = IERC20(USDC).balanceOf(user);
        uint256 balBBefore = IERC20(ARB).balanceOf(user);
        uint256 lpTokens =
            dex.addLiquidity(USDC, ARB, amountADesired, amountBDesired, amountAMin, amountBMin, block.timestamp + 300);
        uint256 balAAfter = IERC20(USDC).balanceOf(user);
        uint256 balBAfter = IERC20(ARB).balanceOf(user);

        assert(lpTokens > 0);
        assert(balABefore - balAAfter <= amountADesired);
        assert(balBBefore - balBAfter <= amountBDesired);

        /* THEN REMOVE ALL MY LP TOKENS FROM USDC/ARB POOL AND GET TOKENS BACK */
        // ---- This is what a frontend would do to calculate each parameter for addLiquidity() function ----
        // 1. first get the totalSupply of the pool
        uint256 totalSupplyPair = IERC20(pair).totalSupply();

        // 2. then read reserves and order by tokenA/tokenB (getReserves() order can be different)
        (uint256 reserveActualA_, uint256 reserveActualB_) = _getReserves(pair, USDC);

        // 3. get the proportional participation of the pool based on LP tokens
        uint256 expectedAmountA = (reserveActualA_ * lpTokens) / totalSupplyPair;
        uint256 expectedAmountB = (reserveActualB_ * lpTokens) / totalSupplyPair;

        console.log("removeLiquidity - reserveActualA:", reserveActualA_);
        console.log("removeLiquidity - reserveActualB:", reserveActualB_);
        console.log("removeLiquidity - expectedAmountA:", expectedAmountA);
        console.log("removeLiquidity - expectedAmountB:", expectedAmountB);

        // 4. apply slippage to both min amounts to prevent revert
        uint256 amountAMinRemove = (expectedAmountA * (10_000 - slippageBps)) / 10_000;
        uint256 amountBMinRemove = (expectedAmountB * (10_000 - slippageBps)) / 10_000;

        IERC20(pair).approve(address(dex), lpTokens);

        uint256 balABeforeRemoveLP = IERC20(USDC).balanceOf(user);
        uint256 balBBeforeRemoveLP = IERC20(ARB).balanceOf(user);
        (uint256 amountA_, uint256 amountB_) =
            dex.removeLiquidity(USDC, ARB, lpTokens, amountAMinRemove, amountBMinRemove, block.timestamp + 300);
        uint256 balAAfterRemoveLP = IERC20(USDC).balanceOf(user);
        uint256 balBAfterRemoveLP = IERC20(ARB).balanceOf(user);

        assert(amountA_ > 0);
        assert(amountB_ > 0);
        assertEq(balAAfterRemoveLP - balABeforeRemoveLP, amountA_, "USDC received should match the return of removeLiquidity");
        assertEq(balBAfterRemoveLP - balBBeforeRemoveLP, amountB_, "ARB received should match the return of removeLiquidity");

        vm.stopPrank();
    }

    // Helper to not repeat the ordering of reserves
    function _getReserves(address pair, address tokenA) internal view returns (uint256 reserveA, uint256 reserveB) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        (reserveA, reserveB) =
            token0 == tokenA ? (uint256(reserve0), uint256(reserve1)) : (uint256(reserve1), uint256(reserve0));
    }
}
