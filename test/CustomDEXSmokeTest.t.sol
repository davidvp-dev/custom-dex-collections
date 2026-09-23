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

    function setUp() public {
        // do the testings against the forked network in anvil
        vm.createSelectFork("http://127.0.0.1:8545");
        dex = CustomDEX(0xa1CE0640b2aA1803E23162A4Dc2DD227F43051Cf);
    }

    function test_deployedContractIsWired() public view {
        assertEq(dex.UNISWAP_V2_ROUTER_ADDRESS(), 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        assertEq(dex.UNISWAP_V2_FACTORY_ADDRESS(), 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9);
    }
}
