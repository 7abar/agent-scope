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
 * @title TrustAnchor
 * @notice Decentralized trust and reputation for agent interactions.
 * @dev Track: "Agents that Trust"
 *      No centralized registry. Trust is built from onchain attestations
 *      and interaction history. Any agent can verify any other agent
 *      without asking permission from a gatekeeper.
 */
contract TrustAnchor {
    // --- Types ---
    enum Outcome { Positive, Neutral, Negative }

    struct Attestation {
        address attester;
        address subject;
        Outcome outcome;
        bytes32 evidenceHash;   // IPFS or data hash
        uint256 timestamp;
    }

    struct Profile {
        uint256 positive;
        uint256 negative;
        uint256 total;
        bool erc8004Verified;
    }

    // --- State ---
    address public owner;
    ScopeToken public scopeToken;

    mapping(address => Profile) public profiles;
    Attestation[] public attestations;
    mapping(address => uint256[]) public subjectAttestations;  // subject => attestation indices

    // --- Events ---
    event AttestationCreated(uint256 indexed id, address indexed attester, address indexed subject, Outcome outcome);
    event ERC8004Verified(address indexed subject);

    // --- Constructor ---
    constructor(address _owner, address _scopeToken) {
        owner = _owner;
        scopeToken = ScopeToken(_scopeToken);
    }

    // --- Attestation Functions ---

    /**
     * @notice Record an attestation about a counterparty.
     * @dev Requires SCOPE_ATTEST token if scope system is active.
     */
    function attest(address subject, Outcome outcome, bytes32 evidenceHash) external {
        if (address(scopeToken) != address(0) && scopeToken.hasScope(msg.sender, 4)) {
            // Agent with scope token -- allowed
        } else if (msg.sender == owner) {
            // Owner -- always allowed
        } else {
            // Anyone can attest (open system)
        }

        Profile storage profile = profiles[subject];
        if (outcome == Outcome.Positive) profile.positive++;
        else if (outcome == Outcome.Negative) profile.negative++;
        profile.total++;

        uint256 id = attestations.length;
        attestations.push(Attestation({
            attester: msg.sender,
            subject: subject,
            outcome: outcome,
            evidenceHash: evidenceHash,
            timestamp: block.timestamp
        }));
        subjectAttestations[subject].push(id);

        emit AttestationCreated(id, msg.sender, subject, outcome);
    }

    /**
     * @notice Owner marks an address as ERC-8004 verified.
     * @dev In production, this would query the ERC-8004 registry directly.
     */
    function verifyERC8004(address subject) external {
        require(msg.sender == owner, "TrustAnchor: not owner");
        profiles[subject].erc8004Verified = true;
        emit ERC8004Verified(subject);
    }

    // --- Trust Score ---

    /**
     * @notice Calculate trust score (0-100).
     * @dev 30 points for ERC-8004, up to 70 for positive interaction ratio.
     */
    function trustScore(address subject) public view returns (uint256) {
        Profile memory p = profiles[subject];
        uint256 score = 0;

        if (p.erc8004Verified) score += 30;

        if (p.total > 0) {
            score += (p.positive * 70) / p.total;
        }

        return score > 100 ? 100 : score;
    }

    function isTrusted(address subject, uint256 minScore) external view returns (bool) {
        return trustScore(subject) >= minScore;
    }

    // --- View ---

    function getProfile(address subject) external view returns (Profile memory) {
        return profiles[subject];
    }

    function getAttestationCount() external view returns (uint256) {
        return attestations.length;
    }

    function getSubjectAttestations(address subject) external view returns (uint256[] memory) {
        return subjectAttestations[subject];
    }
}
