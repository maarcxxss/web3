// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyToken is Script {
    uint256 internal constant INITIAL_SUPPLY = 1000;

    function run() external returns (MyToken token) {
        vm.startBroadcast();

        token = new MyToken(INITIAL_SUPPLY);

        vm.stopBroadcast();

        console2.log("MyToken deployed at:", address(token));
        console2.log("Initial supply:", token.totalSupply());
    }
}
