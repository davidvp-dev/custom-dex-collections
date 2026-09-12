// SPDX-License-Identifier: MIT
// forge test --match-test testDeployOK -vvvv --fork-url https://arb1.arbitrum.io/rpc
// ARB-USDC V2 pool https://arbiscan.io/address/0x011f31D20C8778c8Beb1093b73E3A5690Ee6271b
pragma solidity 0.8.34;

import "../src/interfaces/IV2Router02.sol";
import "../src/CustomDEX.sol";
import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract CustomDEXTest is Test {
    CustomDEX dex;
    address constant UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address user = 0x8a53B8b59877df193C6dAE7B8D1d38251af563Cf; // Address with USDC in Arbitrum Mainnet
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC in Arbitrum Mainnet (6 decimals)
    address constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548; // ARB in Arbitrum Mainnet (18 decimals)

    address constant NFT_DAVID_COLLECTION = 0x10604f011040Fa287a7f3B73d97d7099Cb9116bA;

    function setUp() public {
        dex = new CustomDEX(UNISWAP_V2_ROUTER, NFT_DAVID_COLLECTION);
    }

    function testDeployOK() public view {
        assertEq(dex.UNISWAP_V2_ROUTER_ADDRESS(), UNISWAP_V2_ROUTER);
    }

    function testSwapOK() public {
        // 0. Setup variables for the test
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = ARB;
        uint256 amountIn = 1 * 1e6; // swap 1 USDC

        // simulate what the front would to: off-chain query the expected result
        uint256[] memory expectedAmounts = IV2Router02(UNISWAP_V2_ROUTER).getAmountsOut(amountIn, path);
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
}
