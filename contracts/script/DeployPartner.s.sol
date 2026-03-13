// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Script.sol";
import {PartnerIntegrations} from "../src/PartnerIntegrations.sol";
contract DeployPartner is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);
        PartnerIntegrations pi = new PartnerIntegrations(deployer, 0x2885D6a0EAc7E03476Ef458faea4a5bA609fFB1b);
        // Set agent names
        pi.setAgentName(deployer, "beru.agentscope.eth");
        pi.setAgentName(0xeba5076a9f5C62Cab0b8C11ac3075B725a6eE842, "echo.agentscope.eth");
        // Record a swap event (Uniswap integration demo)
        pi.recordSwap(deployer, 0x4200000000000000000000000000000000000006, 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, 0.0001 ether, 250000);
        // Record a stake event (Lido integration demo)
        pi.recordStake(deployer, 0.001 ether);
        // Set encrypted deal terms (Lit Protocol demo)
        pi.setEncryptedDealTerms(0, keccak256("Build AgentScope frontend"), "QmLitEncryptedCID_AgentScope_Deal_0_v1");
        pi.setEncryptedDealTerms(1, keccak256("Audit smart contracts"), "QmLitEncryptedCID_AgentScope_Deal_1_v1");
        // Set partner addresses (SelfVerifier)
        pi.setPartnerAddresses(address(0), address(0), address(0), 0xa805a3f4FF51912c867e65E2de52b8C77f830DE5);
        vm.stopBroadcast();
        console.log("PartnerIntegrations:", address(pi));
    }
}
