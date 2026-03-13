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
import {AgentScope} from "./AgentScope.sol";
import {DealEngine} from "./DealEngine.sol";
import {TrustAnchor} from "./TrustAnchor.sol";

/**
 * @title AgentScopeFactory
 * @notice One-click deployment of the full AgentScope protocol stack.
 * @dev Anyone can call `create()` to deploy their own set of contracts:
 *      ScopeToken + AgentScope + DealEngine + TrustAnchor.
 *
 *      The caller becomes the owner of all deployed contracts.
 *      No fees. No gatekeeping. Fully permissionless.
 *
 *      This transforms AgentScope from a demo into infrastructure
 *      that any agent framework can adopt.
 */
contract AgentScopeFactory {
    // --- Types ---
    struct Deployment {
        address owner;
        address scopeToken;
        address agentScope;
        address dealEngine;
        address trustAnchor;
        uint256 createdAt;
    }

    // --- State ---
    Deployment[] public deployments;
    mapping(address => uint256[]) public ownerDeployments;

    // --- Events ---
    event AgentScopeCreated(
        uint256 indexed id,
        address indexed owner,
        address scopeToken,
        address agentScope,
        address dealEngine,
        address trustAnchor
    );

    // --- Factory ---

    /**
     * @notice Deploy a full AgentScope protocol stack.
     * @dev Deploys 4 contracts with msg.sender as owner.
     *      Total cost: ~0.002 ETH on Base (at typical gas prices).
     *      No fees. No approval needed. Fully permissionless.
     * @return id The deployment ID
     */
    function create() external returns (uint256 id) {
        // Deploy ScopeToken (permission layer)
        ScopeToken scopeToken = new ScopeToken(msg.sender);

        // Deploy AgentScope (execution layer)
        AgentScope agentScope = new AgentScope(msg.sender, address(scopeToken));

        // Deploy DealEngine (cooperation layer)
        DealEngine dealEngine = new DealEngine(msg.sender, address(scopeToken));

        // Deploy TrustAnchor (trust layer)
        TrustAnchor trustAnchor = new TrustAnchor(msg.sender, address(scopeToken));

        // Record deployment
        id = deployments.length;
        deployments.push(Deployment({
            owner: msg.sender,
            scopeToken: address(scopeToken),
            agentScope: address(agentScope),
            dealEngine: address(dealEngine),
            trustAnchor: address(trustAnchor),
            createdAt: block.timestamp
        }));

        ownerDeployments[msg.sender].push(id);

        emit AgentScopeCreated(
            id,
            msg.sender,
            address(scopeToken),
            address(agentScope),
            address(dealEngine),
            address(trustAnchor)
        );
    }

    // --- Views ---

    /**
     * @notice Get the total number of deployments.
     */
    function totalDeployments() external view returns (uint256) {
        return deployments.length;
    }

    /**
     * @notice Get all deployment IDs for an owner.
     */
    function getOwnerDeployments(address owner) external view returns (uint256[] memory) {
        return ownerDeployments[owner];
    }

    /**
     * @notice Get deployment details by ID.
     */
    function getDeployment(uint256 id) external view returns (Deployment memory) {
        return deployments[id];
    }
}
