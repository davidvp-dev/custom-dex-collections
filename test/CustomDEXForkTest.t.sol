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

contract CustomDEXSmokeTest is Test {

    CustomDEX dex;
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC in Arbitrum Mainnet (6 decimals)
    address constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548; // ARB in Arbitrum Mainnet (18 decimals)
    address user = vm.envAddress("TARGET_WALLET");

    function setUp() public {
        // do the testings against the forked network in anvil
        vm.createSelectFork("http://127.0.0.1:8545");
        dex = CustomDEX(0xa1CE0640b2aA1803E23162A4Dc2DD227F43051Cf);
    }

    function test_deployedContractIsWired() public view {
        assertEq(dex.UNISWAP_V2_ROUTER_ADDRESS(), 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        assertEq(dex.UNISWAP_V2_FACTORY_ADDRESS(), 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9);
    }

    function testSwapOK() public {
        // 0. Setup variables for the test
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = ARB;
        uint256 amountIn = 10 * 1e6; // swap 10 USDC

        // simulate what the front would to: off-chain query the expected result
        uint256[] memory expectedAmounts = IUniswapV2Router02(dex.UNISWAP_V2_ROUTER_ADDRESS()).getAmountsOut(amountIn, path);
        uint256 expectedOut = expectedAmounts[expectedAmounts.length - 1];

        // apply slippage tolerance same as front would do
        uint256 amountOutMin = (expectedOut * 995) / 1000; // 0.5% slippage

        vm.startPrank(user);
        console.log("USDC balance de user:", IERC20(USDC).balanceOf(user));
        console.log("Expected ARB out:", expectedOut);
        IERC20(USDC).approve(address(dex), amountIn);

        uint256 arbBalBefore = IERC20(ARB).balanceOf(user);
        dex.swapTokens(amountIn, amountOutMin, path, block.timestamp + 300);
        uint256 arbBalAfter = IERC20(ARB).balanceOf(user);

        assert(arbBalAfter >= arbBalBefore + amountOutMin);

        vm.stopPrank();
    }
}
