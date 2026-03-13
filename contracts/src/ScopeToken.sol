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
 * @title ScopeToken
 * @notice ERC-1155-style capability tokens that define what an agent can do.
 * @dev The human mints scope tokens to grant agents specific, revocable capabilities.
 *      Each token ID encodes a capability type. Token ownership = authorization.
 *      Burn = instant revocation. Fully auditable onchain.
 *
 *      This is a minimal ERC-1155 implementation (no URI, no batch) focused on
 *      the scope-as-token primitive for the hackathon demo.
 */
contract ScopeToken {
    // --- Capability Types ---
    // Token IDs map to capability types. Data is stored separately.
    uint256 public constant SCOPE_SPEND = 1;        // Permission to spend ETH
    uint256 public constant SCOPE_INTERACT = 2;     // Permission to call contracts
    uint256 public constant SCOPE_DEAL = 3;         // Permission to create escrow deals
    uint256 public constant SCOPE_ATTEST = 4;       // Permission to record attestations

    struct SpendScope {
        uint256 maxPerTx;
        uint256 maxPerDay;
        uint40 validUntil;
    }

    struct InteractScope {
        address target;             // Allowed contract to interact with
        bytes4 allowedSelector;     // Allowed function selector (0x0 = any)
        uint40 validUntil;
    }

    struct DealScope {
        uint256 maxEscrowAmount;
        uint256 maxDeals;           // Max concurrent deals
        uint40 validUntil;
    }

    // --- State ---
    address public owner;

    // ERC-1155 minimal: owner => tokenId => balance
    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    // Scope data: agent => scopeId => encoded data
    mapping(address => SpendScope) public spendScopes;
    mapping(address => InteractScope[]) public interactScopes;
    mapping(address => DealScope) public dealScopes;

    // Spending tracking
    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastResetDay;

    // Deal tracking
    mapping(address => uint256) public activeDeals;

    // --- Events ---
    event ScopeGranted(address indexed agent, uint256 indexed scopeId);
    event ScopeRevoked(address indexed agent, uint256 indexed scopeId);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "ScopeToken: not owner");
        _;
    }

    // --- Constructor ---
    constructor(address _owner) {
        require(_owner != address(0), "ScopeToken: zero owner");
        owner = _owner;
    }

    // --- Grant Scopes ---

    function grantSpendScope(
        address agent,
        uint256 maxPerTx,
        uint256 maxPerDay,
        uint40 validUntil
    ) external onlyOwner {
        spendScopes[agent] = SpendScope(maxPerTx, maxPerDay, validUntil);
        balanceOf[agent][SCOPE_SPEND] = 1;
        emit TransferSingle(owner, address(0), agent, SCOPE_SPEND, 1);
        emit ScopeGranted(agent, SCOPE_SPEND);
    }

    function grantInteractScope(
        address agent,
        address target,
        bytes4 allowedSelector,
        uint40 validUntil
    ) external onlyOwner {
        interactScopes[agent].push(InteractScope(target, allowedSelector, validUntil));
        balanceOf[agent][SCOPE_INTERACT] = 1;
        emit TransferSingle(owner, address(0), agent, SCOPE_INTERACT, 1);
        emit ScopeGranted(agent, SCOPE_INTERACT);
    }

    function grantDealScope(
        address agent,
        uint256 maxEscrowAmount,
        uint256 maxDeals,
        uint40 validUntil
    ) external onlyOwner {
        dealScopes[agent] = DealScope(maxEscrowAmount, maxDeals, validUntil);
        balanceOf[agent][SCOPE_DEAL] = 1;
        emit TransferSingle(owner, address(0), agent, SCOPE_DEAL, 1);
        emit ScopeGranted(agent, SCOPE_DEAL);
    }

    function grantAttestScope(address agent) external onlyOwner {
        balanceOf[agent][SCOPE_ATTEST] = 1;
        emit TransferSingle(owner, address(0), agent, SCOPE_ATTEST, 1);
        emit ScopeGranted(agent, SCOPE_ATTEST);
    }

    // --- Revoke (Burn) ---

    function revokeScope(address agent, uint256 scopeId) external onlyOwner {
        balanceOf[agent][scopeId] = 0;
        emit TransferSingle(owner, agent, address(0), scopeId, 1);
        emit ScopeRevoked(agent, scopeId);
    }

    function revokeAll(address agent) external onlyOwner {
        for (uint256 i = 1; i <= 4; i++) {
            if (balanceOf[agent][i] > 0) {
                balanceOf[agent][i] = 0;
                emit TransferSingle(owner, agent, address(0), i, 1);
                emit ScopeRevoked(agent, i);
            }
        }
    }

    // --- Validation (called by AgentScope core) ---

    function validateSpend(address agent, uint256 value) external returns (bool) {
        if (balanceOf[agent][SCOPE_SPEND] == 0) return false;

        SpendScope memory scope = spendScopes[agent];
        if (scope.validUntil > 0 && block.timestamp > scope.validUntil) return false;
        if (value > scope.maxPerTx) return false;

        // Daily reset
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > lastResetDay[agent]) {
            dailySpent[agent] = 0;
            lastResetDay[agent] = currentDay;
        }

        if (dailySpent[agent] + value > scope.maxPerDay) return false;

        dailySpent[agent] += value;
        return true;
    }

    function validateInteract(address agent, address target, bytes4 selector) external view returns (bool) {
        if (balanceOf[agent][SCOPE_INTERACT] == 0) return false;

        InteractScope[] memory scopes = interactScopes[agent];
        for (uint256 i = 0; i < scopes.length; i++) {
            if (scopes[i].target == target) {
                if (scopes[i].validUntil > 0 && block.timestamp > scopes[i].validUntil) continue;
                if (scopes[i].allowedSelector == bytes4(0) || scopes[i].allowedSelector == selector) {
                    return true;
                }
            }
        }
        return false;
    }

    function validateDeal(address agent, uint256 escrowAmount) external view returns (bool) {
        if (balanceOf[agent][SCOPE_DEAL] == 0) return false;

        DealScope memory scope = dealScopes[agent];
        if (scope.validUntil > 0 && block.timestamp > scope.validUntil) return false;
        if (escrowAmount > scope.maxEscrowAmount) return false;
        if (activeDeals[agent] >= scope.maxDeals) return false;

        return true;
    }

    function incrementDeals(address agent) external {
        activeDeals[agent]++;
    }

    function decrementDeals(address agent) external {
        if (activeDeals[agent] > 0) activeDeals[agent]--;
    }

    // --- View ---

    function hasScope(address agent, uint256 scopeId) external view returns (bool) {
        return balanceOf[agent][scopeId] > 0;
    }

    function getSpendScope(address agent) external view returns (SpendScope memory) {
        return spendScopes[agent];
    }

    function getDealScope(address agent) external view returns (DealScope memory) {
        return dealScopes[agent];
    }

    function getRemainingDailyBudget(address agent) external view returns (uint256) {
        SpendScope memory scope = spendScopes[agent];
        uint256 currentDay = block.timestamp / 1 days;
        uint256 spent = currentDay > lastResetDay[agent] ? 0 : dailySpent[agent];
        return scope.maxPerDay > spent ? scope.maxPerDay - spent : 0;
    }
}
