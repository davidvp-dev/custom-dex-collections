// SPDX-License-Identifier: MIT
// forge test --match-test testDeployOK -vvvv --fork-url https://arb1.arbitrum.io/rpc

pragma solidity 0.8.34;

import "../src/interfaces/IV2Router02.sol";
import "../src/CustomDEX.sol";
import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract CustomDEXTest is Test{

    CustomDEX dex;
    address uniswapRouterAddress = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address user = 0x8a53B8b59877df193C6dAE7B8D1d38251af563Cf; // Address with USDC in Arbitrum Mainnet
    address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC in Arbitrum Mainnet (6 decimals)
    address USDT0 = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT0 in Arbitrum Mainnet (6 decimals)

    function setUp() public {
        dex = new CustomDEX(uniswapRouterAddress);
    }

    function testDeployOK() public view {
        assertEq(dex.V2Router02Address(), uniswapRouterAddress);
    }

    function testSwapOK() public {
        vm.startPrank(user);
        
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = USDT0;
        uint256 amountIn = 1000 * 1e6;
        uint256 deadline = 1789139855 + 1000000000000;
        uint256[] memory amounts = IV2Router02(uniswapRouterAddress).getAmountsOut(amountIn, path);
        uint256 amountOutMin = amounts[amounts.length - 1] * 95 / 100; // 5% slippage

        // 1. aprobamos el USDC a nuestra app
        IERC20(USDC).approve(address(dex), amountIn);

        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(user);
        uint256 usdt0BalanceBefore = IERC20(USDT0).balanceOf(user);
        dex.swapTokens(amountIn, amountOutMin, path, deadline);
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(user);
        uint256 usdt0BalanceAfter = IERC20(USDT0).balanceOf(user);

        assert(usdt0BalanceBefore == 0);
        assert(usdt0BalanceAfter >= amountOutMin);
        assert(usdcBalanceBefore >= usdcBalanceAfter + amountIn);
        vm.stopPrank();
    }

}