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
 * @title AgentScope
 * @notice The onchain operating system for AI agents.
 * @dev Core contract that agents interact through. All actions are gated by
 *      ScopeToken ownership -- agents can only do what their scope tokens allow.
 *      Every action produces an onchain receipt for human auditability.
 */
contract AgentScope {
    // --- Types ---
    struct ActionReceipt {
        address agent;
        address target;
        uint256 value;
        bytes4 selector;
        uint256 timestamp;
        uint256 blockNumber;
        bool success;
    }

    // --- State ---
    address public owner;
    ScopeToken public scopeToken;

    mapping(address => bool) public registeredAgents;
    ActionReceipt[] public receipts;
    mapping(address => uint256[]) public agentReceipts; // agent => receipt indices

    // --- Events ---
    event AgentRegistered(address indexed agent, string name);
    event AgentRemoved(address indexed agent);
    event ActionExecuted(
        uint256 indexed receiptId,
        address indexed agent,
        address indexed target,
        uint256 value,
        bool success
    );
    event FundsDeposited(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "AgentScope: not owner");
        _;
    }

    modifier onlyAgent() {
        require(registeredAgents[msg.sender], "AgentScope: not agent");
        _;
    }

    // --- Constructor ---
    constructor(address _owner, address _scopeToken) {
        require(_owner != address(0) && _scopeToken != address(0), "AgentScope: zero address");
        owner = _owner;
        scopeToken = ScopeToken(_scopeToken);
    }

    // --- Owner Functions ---

    function registerAgent(address agent, string calldata name) external onlyOwner {
        require(agent != address(0), "AgentScope: zero agent");
        registeredAgents[agent] = true;
        emit AgentRegistered(agent, name);
    }

    function removeAgent(address agent) external onlyOwner {
        registeredAgents[agent] = false;
        emit AgentRemoved(agent);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "AgentScope: insufficient");
        (bool success,) = to.call{value: amount}("");
        require(success, "AgentScope: withdraw failed");
        emit FundsWithdrawn(to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "AgentScope: zero owner");
        owner = newOwner;
    }

    // --- Agent Actions ---

    /**
     * @notice Agent sends ETH. Requires SCOPE_SPEND token.
     */
    function spend(address to, uint256 value) external onlyAgent {
        require(scopeToken.validateSpend(msg.sender, value), "AgentScope: spend not authorized");
        require(address(this).balance >= value, "AgentScope: insufficient balance");

        (bool success,) = to.call{value: value}("");

        uint256 receiptId = _recordReceipt(msg.sender, to, value, bytes4(0), success);
        emit ActionExecuted(receiptId, msg.sender, to, value, success);

        require(success, "AgentScope: spend failed");
    }

    /**
     * @notice Agent calls a contract. Requires SCOPE_INTERACT token with matching target.
     */
    function interact(address target, uint256 value, bytes calldata data) external onlyAgent {
        bytes4 selector = data.length >= 4 ? bytes4(data[:4]) : bytes4(0);

        require(
            scopeToken.validateInteract(msg.sender, target, selector),
            "AgentScope: interact not authorized"
        );

        // Also validate spend if sending value
        if (value > 0) {
            require(scopeToken.validateSpend(msg.sender, value), "AgentScope: spend not authorized");
            require(address(this).balance >= value, "AgentScope: insufficient balance");
        }

        (bool success,) = target.call{value: value}(data);

        uint256 receiptId = _recordReceipt(msg.sender, target, value, selector, success);
        emit ActionExecuted(receiptId, msg.sender, target, value, success);

        require(success, "AgentScope: interact failed");
    }

    // --- Receipt System ---

    function _recordReceipt(
        address agent,
        address target,
        uint256 value,
        bytes4 selector,
        bool success
    ) internal returns (uint256) {
        uint256 id = receipts.length;
        receipts.push(ActionReceipt({
            agent: agent,
            target: target,
            value: value,
            selector: selector,
            timestamp: block.timestamp,
            blockNumber: block.number,
            success: success
        }));
        agentReceipts[agent].push(id);
        return id;
    }

    // --- View Functions ---

    function getReceipt(uint256 id) external view returns (ActionReceipt memory) {
        return receipts[id];
    }

    function getAgentReceiptCount(address agent) external view returns (uint256) {
        return agentReceipts[agent].length;
    }

    function getAgentReceipts(address agent, uint256 offset, uint256 limit)
        external view returns (ActionReceipt[] memory)
    {
        uint256[] memory indices = agentReceipts[agent];
        uint256 end = offset + limit > indices.length ? indices.length : offset + limit;
        ActionReceipt[] memory result = new ActionReceipt[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = receipts[indices[i]];
        }
        return result;
    }

    function totalReceipts() external view returns (uint256) {
        return receipts.length;
    }

    // --- Receive ---
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }
}
