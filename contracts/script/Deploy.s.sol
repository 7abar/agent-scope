// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ScopeToken} from "../src/ScopeToken.sol";
import {AgentScope} from "../src/AgentScope.sol";
import {DealEngine} from "../src/DealEngine.sol";
import {TrustAnchor} from "../src/TrustAnchor.sol";
import {SelfVerifier} from "../src/SelfVerifier.sol";

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

        // 5. Deploy SelfVerifier (Self Protocol integration)
        // Self Protocol registry on Celo Mainnet: 0xaC3DF9ABf80d0F5c020C06B04Cced27763355944
        // On Base, we use address(0) as placeholder and owner can set it later
        // Deal threshold: 0.01 ETH (require Self verification for deals above this)
        SelfVerifier selfVerifier = new SelfVerifier(
            deployer,
            address(0),  // Self registry (set later for cross-chain or when deployed on Base)
            address(trustAnchor),
            0.01 ether
        );

        vm.stopBroadcast();

        // Log addresses
        console.log("=== AgentScope Protocol Deployed ===");
        console.log("ScopeToken:    ", address(scopeToken));
        console.log("AgentScope:    ", address(agentScope));
        console.log("DealEngine:    ", address(dealEngine));
        console.log("TrustAnchor:   ", address(trustAnchor));
        console.log("SelfVerifier:  ", address(selfVerifier));
        console.log("Owner:         ", deployer);
    }
}
