// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Script.sol";
import {ScopeToken} from "../src/ScopeToken.sol";
import {AgentScope} from "../src/AgentScope.sol";
import {DealEngine} from "../src/DealEngine.sol";
import {TrustAnchor} from "../src/TrustAnchor.sol";
import {AgentScopeFactory} from "../src/AgentScopeFactory.sol";

contract DeployV2 is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);

        // Deploy core contracts (v2 with bug fixes)
        ScopeToken scopeToken = new ScopeToken(deployer);
        AgentScope agentScope = new AgentScope(deployer, address(scopeToken));
        DealEngine dealEngine = new DealEngine(deployer, address(scopeToken));
        TrustAnchor trustAnchor = new TrustAnchor(deployer, address(scopeToken));

        // Authorize callers (bug fix: access control)
        scopeToken.authorizeCaller(address(agentScope));
        scopeToken.authorizeCaller(address(dealEngine));

        // Deploy updated factory
        AgentScopeFactory factory = new AgentScopeFactory();

        vm.stopBroadcast();

        console.log("ScopeToken:", address(scopeToken));
        console.log("AgentScope:", address(agentScope));
        console.log("DealEngine:", address(dealEngine));
        console.log("TrustAnchor:", address(trustAnchor));
        console.log("Factory:", address(factory));
    }
}
