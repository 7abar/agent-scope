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

/**
 * @title ISelfAgentRegistry
 * @notice Interface for Self Protocol's on-chain agent registry.
 * @dev Self Protocol uses ZK proofs to verify agent-human bindings.
 *      Agents receive soulbound ERC-721 NFTs backed by passport ZK proofs.
 */
interface ISelfAgentRegistry {
    function balanceOf(address owner) external view returns (uint256);
    function isVerifiedAgent(address agent) external view returns (bool);
}

/**
 * @title SelfVerifier
 * @notice Integrates Self Protocol's proof-of-human verification into AgentScope.
 * @dev Track: "Agents that Keep Secrets"
 *
 *      This contract bridges AgentScope's trust system with Self Protocol's
 *      ZK identity verification. Instead of trusting a centralized registry,
 *      agents prove they're backed by a real human using zero-knowledge proofs
 *      from passport/ID verification -- without revealing who that human is.
 *
 *      Use cases:
 *      - Gate high-value deals: require Self verification before escrow > threshold
 *      - Sybil resistance: ensure each agent represents a unique human
 *      - Privacy-preserving KYC: agents prove humanity without exposing identity
 */
contract SelfVerifier {
    // --- State ---
    address public owner;
    address public selfRegistry;        // Self Protocol's SelfAgentRegistry
    address public trustAnchor;         // AgentScope's TrustAnchor contract

    // Verification thresholds
    uint256 public dealThreshold;       // Escrow amount above which Self verification is required
    bool public requireSelfForDeals;    // Whether to enforce Self verification for deals

    // Cache: addresses verified through Self Protocol
    mapping(address => bool) public selfVerified;
    mapping(address => uint256) public verifiedAt;

    // --- Events ---
    event SelfVerificationChecked(address indexed agent, bool isVerified);
    event ThresholdUpdated(uint256 newThreshold);
    event RegistryUpdated(address newRegistry);
    event AgentVerifiedViaSelf(address indexed agent, uint256 timestamp);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "SelfVerifier: not owner");
        _;
    }

    // --- Constructor ---
    constructor(
        address _owner,
        address _selfRegistry,
        address _trustAnchor,
        uint256 _dealThreshold
    ) {
        owner = _owner;
        selfRegistry = _selfRegistry;
        trustAnchor = _trustAnchor;
        dealThreshold = _dealThreshold;
        requireSelfForDeals = true;
    }

    // --- Owner Functions ---

    function setSelfRegistry(address _registry) external onlyOwner {
        selfRegistry = _registry;
        emit RegistryUpdated(_registry);
    }

    function setDealThreshold(uint256 _threshold) external onlyOwner {
        dealThreshold = _threshold;
        emit ThresholdUpdated(_threshold);
    }

    function setRequireSelfForDeals(bool _require) external onlyOwner {
        requireSelfForDeals = _require;
    }

    // --- Verification Functions ---

    /**
     * @notice Check if an agent is verified through Self Protocol.
     * @dev Queries Self Protocol's on-chain registry.
     *      Self verification means the agent has a soulbound NFT backed by
     *      a ZK passport proof -- proving human backing without revealing identity.
     */
    function checkSelfVerification(address agent) public returns (bool) {
        if (selfRegistry == address(0)) {
            emit SelfVerificationChecked(agent, false);
            return false;
        }

        // Check Self Protocol registry
        bool isVerified = false;

        try ISelfAgentRegistry(selfRegistry).balanceOf(agent) returns (uint256 balance) {
            isVerified = balance > 0;
        } catch {
            // Registry call failed -- don't block, just return false
            isVerified = false;
        }

        // Cache result
        if (isVerified && !selfVerified[agent]) {
            selfVerified[agent] = true;
            verifiedAt[agent] = block.timestamp;
            emit AgentVerifiedViaSelf(agent, block.timestamp);
        }

        emit SelfVerificationChecked(agent, isVerified);
        return isVerified;
    }

    /**
     * @notice Check if a deal should require Self verification.
     * @dev Returns true if the escrow amount exceeds the threshold and
     *      Self verification is enabled.
     */
    function requiresVerification(uint256 escrowAmount) public view returns (bool) {
        return requireSelfForDeals && escrowAmount >= dealThreshold;
    }

    /**
     * @notice Verify a counterparty before a deal.
     * @dev Combines Self Protocol check with cached verification status.
     *      This is the main entry point for DealEngine integration.
     */
    function verifyForDeal(address counterparty, uint256 escrowAmount) external returns (bool) {
        // If below threshold, always allow
        if (!requiresVerification(escrowAmount)) {
            return true;
        }

        // Check cached verification first
        if (selfVerified[counterparty]) {
            return true;
        }

        // Check Self Protocol live
        return checkSelfVerification(counterparty);
    }

    /**
     * @notice Manually mark an agent as Self-verified (owner override).
     * @dev For demo purposes or when Self registry is on a different chain.
     *      In production, this would only be callable by the Self registry callback.
     */
    function manualVerify(address agent) external onlyOwner {
        selfVerified[agent] = true;
        verifiedAt[agent] = block.timestamp;
        emit AgentVerifiedViaSelf(agent, block.timestamp);
    }

    // --- View Functions ---

    function isVerified(address agent) external view returns (bool) {
        return selfVerified[agent];
    }

    function getVerificationTime(address agent) external view returns (uint256) {
        return verifiedAt[agent];
    }

    /**
     * @notice Get comprehensive verification status for an agent.
     * @dev Returns all verification data in one call for the dashboard.
     */
    function getVerificationStatus(address agent) external view returns (
        bool isSelfVerified,
        uint256 verificationTimestamp,
        bool dealVerificationRequired,
        uint256 currentThreshold
    ) {
        return (
            selfVerified[agent],
            verifiedAt[agent],
            requireSelfForDeals,
            dealThreshold
        );
    }
}
