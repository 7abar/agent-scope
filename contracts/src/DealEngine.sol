// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 *  .............................................................................
 *  .  ___  ________  ________  ________  ________                             .
 *  . |\  \|\   __  \|\   __  \|\   __  \|\   __  \                            .
 *  . \ \  \ \  \|\  \ \  \|\ /\ \  \|\  \ \  \|\  \                           .
 *  .  \ \  \ \   __  \ \   __  \ \   __  \ \   _  _\                           .
 *  .   \ \  \ \  \ \  \ \  \|\  \ \  \ \  \ \  \\  \|                          .
 *  .    \ \__\ \__\ \__\ \_______\ \__\ \__\ \__\\ _\                          .
 *  .     \|__|\|__|\|__|\|_______|\|__|\|__|\|__|\|__|                          .
 *  .                                                                            .
 *  .    AgentScope Protocol -- Onchain OS for AI Agents                         .
 *  .    Built by Beru x Jabar for The Synthesis Hackathon 2026                  .
 *  .............................................................................
 */

import {ScopeToken} from "./ScopeToken.sol";

/**
 * @title DealEngine
 * @notice Agent-to-agent deal enforcement with milestone-based escrow.
 * @dev Track: "Agents that Cooperate"
 *      Deals are created, accepted, and settled entirely onchain.
 *      No platform can rewrite the terms after both parties agree.
 */
contract DealEngine {
    // --- Types ---
    enum Status { Created, Active, Completed, Disputed, Expired, Cancelled }

    struct Deal {
        address initiator;
        address counterparty;
        uint256 amount;
        bytes32 termsHash;
        uint256 deadline;
        Status status;
        uint256 milestoneCount;
        uint256 milestonesCompleted;
        uint256 createdAt;
    }

    struct Milestone {
        bytes32 evidenceHash;
        bool submitted;
        bool confirmed;
    }

    // --- State ---
    address public owner;
    ScopeToken public scopeToken;
    uint256 public dealCount;

    mapping(uint256 => Deal) public deals;
    mapping(uint256 => mapping(uint256 => Milestone)) public milestones;

    // --- Events ---
    event DealCreated(uint256 indexed id, address indexed initiator, address indexed counterparty, uint256 amount);
    event DealAccepted(uint256 indexed id);
    event MilestoneSubmitted(uint256 indexed id, uint256 milestone);
    event MilestoneConfirmed(uint256 indexed id, uint256 milestone, uint256 payout);
    event DealCompleted(uint256 indexed id);
    event DealExpired(uint256 indexed id, uint256 refund);
    event DealCancelled(uint256 indexed id);
    event DealDisputed(uint256 indexed id, address indexed by);

    // --- Constructor ---
    constructor(address _owner, address _scopeToken) {
        owner = _owner;
        scopeToken = ScopeToken(_scopeToken);
    }

    // --- Deal Lifecycle ---

    function createDeal(
        address counterparty,
        bytes32 termsHash,
        uint256 milestoneCount,
        uint256 deadline
    ) external payable returns (uint256) {
        require(msg.value > 0, "DealEngine: no value");
        require(milestoneCount > 0 && milestoneCount <= 10, "DealEngine: bad milestones");
        require(deadline > block.timestamp, "DealEngine: past deadline");

        // Check scope if sender has scope tokens
        if (address(scopeToken) != address(0)) {
            require(
                scopeToken.validateDeal(msg.sender, msg.value),
                "DealEngine: deal scope exceeded"
            );
            scopeToken.incrementDeals(msg.sender);
        }

        uint256 id = dealCount++;
        deals[id] = Deal({
            initiator: msg.sender,
            counterparty: counterparty,
            amount: msg.value,
            termsHash: termsHash,
            deadline: deadline,
            status: Status.Created,
            milestoneCount: milestoneCount,
            milestonesCompleted: 0,
            createdAt: block.timestamp
        });

        emit DealCreated(id, msg.sender, counterparty, msg.value);
        return id;
    }

    function acceptDeal(uint256 id) external {
        Deal storage d = deals[id];
        require(msg.sender == d.counterparty, "DealEngine: not counterparty");
        require(d.status == Status.Created, "DealEngine: wrong status");
        d.status = Status.Active;
        emit DealAccepted(id);
    }

    function submitMilestone(uint256 id, uint256 idx, bytes32 evidence) external {
        Deal storage d = deals[id];
        require(msg.sender == d.counterparty, "DealEngine: not counterparty");
        require(d.status == Status.Active, "DealEngine: not active");
        require(idx < d.milestoneCount, "DealEngine: bad index");

        Milestone storage m = milestones[id][idx];
        require(!m.submitted, "DealEngine: already submitted");

        m.evidenceHash = evidence;
        m.submitted = true;
        emit MilestoneSubmitted(id, idx);
    }

    function confirmMilestone(uint256 id, uint256 idx) external {
        Deal storage d = deals[id];
        require(msg.sender == d.initiator, "DealEngine: not initiator");
        require(d.status == Status.Active, "DealEngine: not active");

        Milestone storage m = milestones[id][idx];
        require(m.submitted && !m.confirmed, "DealEngine: invalid state");

        m.confirmed = true;
        d.milestonesCompleted++;

        // Fix rounding: last milestone gets the remainder to prevent dust
        uint256 payout;
        if (d.milestonesCompleted == d.milestoneCount) {
            // Last milestone: pay remaining balance (prevents dust)
            uint256 alreadyPaid = (d.amount / d.milestoneCount) * (d.milestoneCount - 1);
            payout = d.amount - alreadyPaid;

            // CEI: update state before external call
            d.status = Status.Completed;
            if (address(scopeToken) != address(0)) {
                scopeToken.decrementDeals(d.initiator);
            }

            (bool ok,) = d.counterparty.call{value: payout}("");
            require(ok, "DealEngine: payout failed");

            emit MilestoneConfirmed(id, idx, payout);
            emit DealCompleted(id);
        } else {
            payout = d.amount / d.milestoneCount;

            (bool ok,) = d.counterparty.call{value: payout}("");
            require(ok, "DealEngine: payout failed");

            emit MilestoneConfirmed(id, idx, payout);
        }
    }

    function expireDeal(uint256 id) external {
        Deal storage d = deals[id];
        require(msg.sender == d.initiator || msg.sender == d.counterparty, "DealEngine: not party");
        require(block.timestamp > d.deadline, "DealEngine: not expired");
        require(d.status == Status.Created || d.status == Status.Active, "DealEngine: wrong status");

        uint256 paid = (d.amount / d.milestoneCount) * d.milestonesCompleted;
        uint256 refund = d.amount - paid;

        // CEI: update state before external call
        d.status = Status.Expired;
        if (address(scopeToken) != address(0)) {
            scopeToken.decrementDeals(d.initiator);
        }

        if (refund > 0) {
            (bool ok,) = d.initiator.call{value: refund}("");
            require(ok, "DealEngine: refund failed");
        }

        emit DealExpired(id, refund);
    }

    function cancelDeal(uint256 id) external {
        Deal storage d = deals[id];
        require(msg.sender == d.initiator, "DealEngine: not initiator");
        require(d.status == Status.Created, "DealEngine: cannot cancel");

        uint256 refundAmount = d.amount;

        // CEI: update state before external call
        d.status = Status.Cancelled;
        if (address(scopeToken) != address(0)) {
            scopeToken.decrementDeals(d.initiator);
        }

        (bool ok,) = d.initiator.call{value: refundAmount}("");
        require(ok, "DealEngine: refund failed");

        emit DealCancelled(id);
    }

    function disputeDeal(uint256 id) external {
        Deal storage d = deals[id];
        require(msg.sender == d.initiator || msg.sender == d.counterparty, "DealEngine: not party");
        require(d.status == Status.Active, "DealEngine: not active");
        d.status = Status.Disputed;
        emit DealDisputed(id, msg.sender);
    }

    // --- View ---

    function getDeal(uint256 id) external view returns (Deal memory) {
        return deals[id];
    }

    function getMilestone(uint256 id, uint256 idx) external view returns (Milestone memory) {
        return milestones[id][idx];
    }
}
