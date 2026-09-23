// SPDX-License-Identifier: MIT
// forge script script/DeployCustomDEX.s.sol --rpc-url http://127.0.0.1:8545 --broadcast (LOCAL ANVIL FORK)
// forge script script/DeployCustomDEX.s.sol --rpc-url https://arb1.arbitrum.io/rpc --broadcast --verify (ARB MAINNET)
pragma solidity 0.8.34;

import { Script } from "forge-std/Script.sol";
import { CustomDEX } from "../src/CustomDEX.sol";

contract DeployCustomDEX is Script {
    function run() external returns (CustomDEX) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        address UNISWAP_V2_FACTORY = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9;

        vm.startBroadcast(deployerPrivateKey);
        CustomDEX customDex = new CustomDEX(UNISWAP_V2_ROUTER, UNISWAP_V2_FACTORY);
        vm.stopBroadcast();
        return customDex;
    }
}
