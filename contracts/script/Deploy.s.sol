// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ScopeToken} from "../src/ScopeToken.sol";
import {AgentScope} from "../src/AgentScope.sol";
import {DealEngine} from "../src/DealEngine.sol";
import {TrustAnchor} from "../src/TrustAnchor.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ScopeToken (capability tokens)
        ScopeToken scopeToken = new ScopeToken(deployer);

        // 2. Deploy AgentScope (core OS)
        AgentScope agentScope = new AgentScope(deployer, address(scopeToken));

        // 3. Deploy DealEngine (agent cooperation)
        DealEngine dealEngine = new DealEngine(deployer, address(scopeToken));

        // 4. Deploy TrustAnchor (reputation)
        TrustAnchor trustAnchor = new TrustAnchor(deployer, address(scopeToken));

        vm.stopBroadcast();

        // Log addresses
        console.log("=== AgentScope Protocol Deployed ===");
        console.log("ScopeToken:  ", address(scopeToken));
        console.log("AgentScope:  ", address(agentScope));
        console.log("DealEngine:  ", address(dealEngine));
        console.log("TrustAnchor: ", address(trustAnchor));
        console.log("Owner:       ", deployer);
    }
}
