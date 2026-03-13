// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Script.sol";
import {AgentScopeFactory} from "../src/AgentScopeFactory.sol";
contract DeployFactory is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        AgentScopeFactory factory = new AgentScopeFactory();
        console.log("Factory:", address(factory));
        vm.stopBroadcast();
    }
}
