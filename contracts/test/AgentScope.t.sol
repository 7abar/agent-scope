// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ScopeToken} from "../src/ScopeToken.sol";
import {AgentScope} from "../src/AgentScope.sol";
import {DealEngine} from "../src/DealEngine.sol";
import {TrustAnchor} from "../src/TrustAnchor.sol";

contract AgentScopeTest is Test {
    ScopeToken scopeToken;
    AgentScope agentScope;
    DealEngine dealEngine;
    TrustAnchor trustAnchor;

    address owner = address(0x1);
    address agent1 = address(0x2);
    address agent2 = address(0x3);
    address recipient = address(0x4);

    function setUp() public {
        vm.startPrank(owner);

        scopeToken = new ScopeToken(owner);
        agentScope = new AgentScope(owner, address(scopeToken));
        dealEngine = new DealEngine(owner, address(scopeToken));
        trustAnchor = new TrustAnchor(owner, address(scopeToken));

        // Authorize AgentScope and DealEngine to call validation functions
        scopeToken.authorizeCaller(address(agentScope));
        scopeToken.authorizeCaller(address(dealEngine));

        // Fund the AgentScope contract
        vm.deal(address(agentScope), 10 ether);
        vm.deal(address(dealEngine), 0);

        vm.stopPrank();
    }

    // ============================================================
    //                    SCOPE TOKEN TESTS
    // ============================================================

    function test_GrantSpendScope() public {
        vm.prank(owner);
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);

        assertTrue(scopeToken.hasScope(agent1, 1)); // SCOPE_SPEND = 1
        assertEq(scopeToken.balanceOf(agent1, 1), 1);

        ScopeToken.SpendScope memory s = scopeToken.getSpendScope(agent1);
        assertEq(s.maxPerTx, 0.1 ether);
        assertEq(s.maxPerDay, 1 ether);
    }

    function test_GrantInteractScope() public {
        vm.prank(owner);
        scopeToken.grantInteractScope(agent1, recipient, bytes4(0), 0);

        assertTrue(scopeToken.hasScope(agent1, 2)); // SCOPE_INTERACT = 2
    }

    function test_GrantDealScope() public {
        vm.prank(owner);
        scopeToken.grantDealScope(agent1, 1 ether, 5, 0);

        assertTrue(scopeToken.hasScope(agent1, 3)); // SCOPE_DEAL = 3
    }

    function test_GrantAttestScope() public {
        vm.prank(owner);
        scopeToken.grantAttestScope(agent1);

        assertTrue(scopeToken.hasScope(agent1, 4)); // SCOPE_ATTEST = 4
    }

    function test_RevokeScope() public {
        vm.startPrank(owner);
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);
        assertTrue(scopeToken.hasScope(agent1, 1));

        scopeToken.revokeScope(agent1, 1);
        assertFalse(scopeToken.hasScope(agent1, 1));
        vm.stopPrank();
    }

    function test_RevokeAll() public {
        vm.startPrank(owner);
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);
        scopeToken.grantAttestScope(agent1);

        scopeToken.revokeAll(agent1);
        assertFalse(scopeToken.hasScope(agent1, 1));
        assertFalse(scopeToken.hasScope(agent1, 4));
        vm.stopPrank();
    }

    function test_ValidateSpend_Success() public {
        vm.startPrank(owner);
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);

        bool valid = scopeToken.validateSpend(agent1, 0.05 ether);
        assertTrue(valid);
        vm.stopPrank();
    }

    function test_ValidateSpend_ExceedsPerTx() public {
        vm.startPrank(owner);
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);

        bool valid = scopeToken.validateSpend(agent1, 0.2 ether);
        assertFalse(valid);
        vm.stopPrank();
    }

    function test_ValidateSpend_ExceedsDaily() public {
        vm.startPrank(owner);
        scopeToken.grantSpendScope(agent1, 1 ether, 0.5 ether, 0);

        // First spend ok
        bool valid1 = scopeToken.validateSpend(agent1, 0.3 ether);
        assertTrue(valid1);

        // Second spend exceeds daily
        bool valid2 = scopeToken.validateSpend(agent1, 0.3 ether);
        assertFalse(valid2);
        vm.stopPrank();
    }

    function test_ValidateSpend_Expired() public {
        vm.startPrank(owner);
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, uint40(block.timestamp + 100));

        // Warp past expiry
        vm.warp(block.timestamp + 200);

        bool valid = scopeToken.validateSpend(agent1, 0.05 ether);
        assertFalse(valid);
        vm.stopPrank();
    }

    function test_ValidateSpend_DailyReset() public {
        vm.startPrank(owner);
        scopeToken.grantSpendScope(agent1, 1 ether, 0.5 ether, 0);

        // Spend to daily limit
        scopeToken.validateSpend(agent1, 0.5 ether);

        // Warp to next day
        vm.warp(block.timestamp + 1 days + 1);

        // Should work again
        bool valid = scopeToken.validateSpend(agent1, 0.3 ether);
        assertTrue(valid);
        vm.stopPrank();
    }

    function test_RemainingDailyBudget() public {
        vm.startPrank(owner);
        scopeToken.grantSpendScope(agent1, 1 ether, 1 ether, 0);

        scopeToken.validateSpend(agent1, 0.3 ether);
        vm.stopPrank();
        assertEq(scopeToken.getRemainingDailyBudget(agent1), 0.7 ether);
    }

    function test_ValidateSpend_RevertUnauthorized() public {
        vm.prank(owner);
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);

        // Random address tries to call validateSpend -- should revert
        vm.prank(agent2);
        vm.expectRevert("ScopeToken: not authorized");
        scopeToken.validateSpend(agent1, 0.05 ether);
    }

    function test_RevertWhen_NonOwnerGrantsScope() public {
        vm.prank(agent1);
        vm.expectRevert("ScopeToken: not owner");
        scopeToken.grantSpendScope(agent2, 0.1 ether, 1 ether, 0);
    }

    // ============================================================
    //                    AGENT SCOPE TESTS
    // ============================================================

    function test_RegisterAgent() public {
        vm.prank(owner);
        agentScope.registerAgent(agent1, "Beru");

        assertTrue(agentScope.registeredAgents(agent1));
    }

    function test_RemoveAgent() public {
        vm.startPrank(owner);
        agentScope.registerAgent(agent1, "Beru");
        agentScope.removeAgent(agent1);
        vm.stopPrank();

        assertFalse(agentScope.registeredAgents(agent1));
    }

    function test_AgentSpend() public {
        vm.startPrank(owner);
        agentScope.registerAgent(agent1, "Beru");
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);
        vm.stopPrank();

        uint256 recipientBefore = recipient.balance;

        vm.prank(agent1);
        agentScope.spend(recipient, 0.05 ether);

        assertEq(recipient.balance, recipientBefore + 0.05 ether);
        assertEq(agentScope.totalReceipts(), 1);
    }

    function test_AgentSpend_RecordsReceipt() public {
        vm.startPrank(owner);
        agentScope.registerAgent(agent1, "Beru");
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);
        vm.stopPrank();

        vm.prank(agent1);
        agentScope.spend(recipient, 0.05 ether);

        AgentScope.ActionReceipt memory receipt = agentScope.getReceipt(0);
        assertEq(receipt.agent, agent1);
        assertEq(receipt.target, recipient);
        assertEq(receipt.value, 0.05 ether);
        assertTrue(receipt.success);
    }

    function test_RevertWhen_UnregisteredAgentSpends() public {
        vm.prank(owner);
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);

        vm.prank(agent1);
        vm.expectRevert("AgentScope: not agent");
        agentScope.spend(recipient, 0.05 ether);
    }

    function test_RevertWhen_AgentExceedsScope() public {
        vm.startPrank(owner);
        agentScope.registerAgent(agent1, "Beru");
        scopeToken.grantSpendScope(agent1, 0.1 ether, 1 ether, 0);
        vm.stopPrank();

        vm.prank(agent1);
        vm.expectRevert("AgentScope: spend not authorized");
        agentScope.spend(recipient, 0.2 ether); // exceeds maxPerTx
    }

    function test_OwnerWithdraw() public {
        uint256 ownerBefore = owner.balance;

        vm.prank(owner);
        agentScope.withdraw(owner, 1 ether);

        assertEq(owner.balance, ownerBefore + 1 ether);
    }

    function test_DepositEmitsEvent() public {
        vm.deal(agent1, 1 ether);
        vm.prank(agent1);
        (bool ok,) = address(agentScope).call{value: 0.5 ether}("");
        assertTrue(ok);
    }

    function test_MultipleAgentReceipts() public {
        vm.startPrank(owner);
        agentScope.registerAgent(agent1, "Beru");
        agentScope.registerAgent(agent2, "Agent2");
        scopeToken.grantSpendScope(agent1, 1 ether, 5 ether, 0);
        scopeToken.grantSpendScope(agent2, 1 ether, 5 ether, 0);
        vm.stopPrank();

        vm.prank(agent1);
        agentScope.spend(recipient, 0.01 ether);

        vm.prank(agent2);
        agentScope.spend(recipient, 0.02 ether);

        vm.prank(agent1);
        agentScope.spend(recipient, 0.03 ether);

        assertEq(agentScope.totalReceipts(), 3);
        assertEq(agentScope.getAgentReceiptCount(agent1), 2);
        assertEq(agentScope.getAgentReceiptCount(agent2), 1);
    }

    // ============================================================
    //                    DEAL ENGINE TESTS
    // ============================================================

    function test_CreateAndAcceptDeal() public {
        vm.prank(owner);
        scopeToken.grantDealScope(agent1, 1 ether, 5, 0);

        vm.deal(agent1, 1 ether);
        vm.prank(agent1);
        uint256 dealId = dealEngine.createDeal{value: 0.5 ether}(
            agent2,
            keccak256("test terms"),
            2,
            block.timestamp + 7 days
        );

        DealEngine.Deal memory d = dealEngine.getDeal(dealId);
        assertEq(d.initiator, agent1);
        assertEq(d.counterparty, agent2);
        assertEq(d.amount, 0.5 ether);
        assertEq(uint256(d.status), 0); // Created

        vm.prank(agent2);
        dealEngine.acceptDeal(dealId);

        d = dealEngine.getDeal(dealId);
        assertEq(uint256(d.status), 1); // Active
    }

    function test_MilestoneFlow() public {
        vm.prank(owner);
        scopeToken.grantDealScope(agent1, 1 ether, 5, 0);

        vm.deal(agent1, 1 ether);
        vm.prank(agent1);
        uint256 dealId = dealEngine.createDeal{value: 1 ether}(
            agent2,
            keccak256("build something"),
            2, // 2 milestones
            block.timestamp + 7 days
        );

        vm.prank(agent2);
        dealEngine.acceptDeal(dealId);

        // Submit milestone 0
        vm.prank(agent2);
        dealEngine.submitMilestone(dealId, 0, keccak256("proof1"));

        // Confirm milestone 0 -- releases 0.5 ETH to agent2
        uint256 agent2Before = agent2.balance;
        vm.prank(agent1);
        dealEngine.confirmMilestone(dealId, 0);
        assertEq(agent2.balance, agent2Before + 0.5 ether);

        // Submit and confirm milestone 1
        vm.prank(agent2);
        dealEngine.submitMilestone(dealId, 1, keccak256("proof2"));

        vm.prank(agent1);
        dealEngine.confirmMilestone(dealId, 1);

        DealEngine.Deal memory d = dealEngine.getDeal(dealId);
        assertEq(uint256(d.status), 2); // Completed
    }

    function test_DealExpiry() public {
        vm.prank(owner);
        scopeToken.grantDealScope(agent1, 1 ether, 5, 0);

        vm.deal(agent1, 1 ether);
        vm.prank(agent1);
        uint256 dealId = dealEngine.createDeal{value: 1 ether}(
            agent2,
            keccak256("terms"),
            2,
            block.timestamp + 1 days
        );

        uint256 agent1Before = agent1.balance;

        // Warp past deadline
        vm.warp(block.timestamp + 2 days);

        vm.prank(agent1);
        dealEngine.expireDeal(dealId);

        DealEngine.Deal memory d = dealEngine.getDeal(dealId);
        assertEq(uint256(d.status), 4); // Expired
        assertEq(agent1.balance, agent1Before + 1 ether); // Refunded
    }

    function test_CancelDeal() public {
        vm.prank(owner);
        scopeToken.grantDealScope(agent1, 1 ether, 5, 0);

        vm.deal(agent1, 1 ether);
        vm.prank(agent1);
        uint256 dealId = dealEngine.createDeal{value: 0.5 ether}(
            agent2,
            keccak256("terms"),
            1,
            block.timestamp + 7 days
        );

        uint256 agent1Before = agent1.balance;

        vm.prank(agent1);
        dealEngine.cancelDeal(dealId);

        assertEq(agent1.balance, agent1Before + 0.5 ether);
        DealEngine.Deal memory d = dealEngine.getDeal(dealId);
        assertEq(uint256(d.status), 5); // Cancelled
    }

    function test_DisputeDeal() public {
        vm.prank(owner);
        scopeToken.grantDealScope(agent1, 1 ether, 5, 0);

        vm.deal(agent1, 1 ether);
        vm.prank(agent1);
        uint256 dealId = dealEngine.createDeal{value: 0.5 ether}(
            agent2,
            keccak256("terms"),
            1,
            block.timestamp + 7 days
        );

        vm.prank(agent2);
        dealEngine.acceptDeal(dealId);

        vm.prank(agent2);
        dealEngine.disputeDeal(dealId);

        DealEngine.Deal memory d = dealEngine.getDeal(dealId);
        assertEq(uint256(d.status), 3); // Disputed
    }

    // ============================================================
    //                    TRUST ANCHOR TESTS
    // ============================================================

    function test_Attest() public {
        vm.prank(owner);
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Positive, keccak256("good deal"));

        TrustAnchor.Profile memory p = trustAnchor.getProfile(agent1);
        assertEq(p.positive, 1);
        assertEq(p.total, 1);
    }

    function test_TrustScore_WithERC8004() public {
        vm.startPrank(owner);
        trustAnchor.verifyERC8004(agent1);
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Positive, keccak256("good"));
        vm.stopPrank();

        // 30 (ERC-8004) + 70 (100% positive) = 100
        assertEq(trustAnchor.trustScore(agent1), 100);
    }

    function test_TrustScore_Mixed() public {
        vm.startPrank(owner);
        trustAnchor.verifyERC8004(agent1);
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Positive, keccak256("good1"));
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Positive, keccak256("good2"));
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Negative, keccak256("bad1"));
        vm.stopPrank();

        // 30 (ERC-8004) + (2/3 * 70) = 30 + 46 = 76
        assertEq(trustAnchor.trustScore(agent1), 76);
    }

    function test_TrustScore_NoERC8004() public {
        vm.prank(owner);
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Positive, keccak256("good"));

        // 0 (no ERC-8004) + 70 (100% positive) = 70
        assertEq(trustAnchor.trustScore(agent1), 70);
    }

    function test_IsTrusted() public {
        vm.startPrank(owner);
        trustAnchor.verifyERC8004(agent1);
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Positive, keccak256("good"));
        vm.stopPrank();

        assertTrue(trustAnchor.isTrusted(agent1, 50));
        assertTrue(trustAnchor.isTrusted(agent1, 100));
        assertFalse(trustAnchor.isTrusted(agent2, 1)); // agent2 has no profile
    }

    function test_SubjectAttestations() public {
        vm.startPrank(owner);
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Positive, keccak256("a"));
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Neutral, keccak256("b"));
        trustAnchor.attest(agent1, TrustAnchor.Outcome.Negative, keccak256("c"));
        vm.stopPrank();

        uint256[] memory indices = trustAnchor.getSubjectAttestations(agent1);
        assertEq(indices.length, 3);
    }

    // ============================================================
    //                    INTEGRATION TESTS
    // ============================================================

    function test_FullFlow_AgentSpendsWithinScope() public {
        // Owner sets up agent with scoped permissions
        vm.startPrank(owner);
        agentScope.registerAgent(agent1, "Beru");
        scopeToken.grantSpendScope(agent1, 0.1 ether, 0.5 ether, uint40(block.timestamp + 1 days));
        vm.stopPrank();

        // Agent spends within limits
        vm.prank(agent1);
        agentScope.spend(recipient, 0.05 ether);

        vm.prank(agent1);
        agentScope.spend(recipient, 0.1 ether);

        // Verify receipts
        assertEq(agentScope.totalReceipts(), 2);
        assertEq(scopeToken.getRemainingDailyBudget(agent1), 0.35 ether);
    }

    function test_FullFlow_DealWithTrustCheck() public {
        // Setup: verify agent2 as trusted
        vm.startPrank(owner);
        trustAnchor.verifyERC8004(agent2);
        trustAnchor.attest(agent2, TrustAnchor.Outcome.Positive, keccak256("reliable"));
        scopeToken.grantDealScope(agent1, 1 ether, 3, 0);
        vm.stopPrank();

        // Check trust before deal
        assertTrue(trustAnchor.isTrusted(agent2, 50));

        // Create deal
        vm.deal(agent1, 1 ether);
        vm.prank(agent1);
        uint256 dealId = dealEngine.createDeal{value: 0.5 ether}(
            agent2,
            keccak256("build frontend"),
            1,
            block.timestamp + 7 days
        );

        // Accept and complete
        vm.prank(agent2);
        dealEngine.acceptDeal(dealId);

        vm.prank(agent2);
        dealEngine.submitMilestone(dealId, 0, keccak256("deployed"));

        uint256 agent2Before = agent2.balance;
        vm.prank(agent1);
        dealEngine.confirmMilestone(dealId, 0);

        assertEq(agent2.balance, agent2Before + 0.5 ether);

        // Record positive interaction
        vm.prank(owner);
        trustAnchor.attest(agent2, TrustAnchor.Outcome.Positive, keccak256("deal completed"));

        assertEq(trustAnchor.trustScore(agent2), 100);
    }
}
