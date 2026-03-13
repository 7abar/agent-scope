# Agent Vault -- Architecture

## Overview

Agent Vault is a smart account framework on Base where AI agents operate with human-defined, onchain-enforced boundaries. One system, four Synthesis themes.

```
+----------------------------------------------------------+
|                      HUMAN (Owner)                        |
|  Sets policies, approves agents, defines disclosure rules |
+---------------------------+------------------------------+
                            |
                    deploys & configures
                            |
+---------------------------v------------------------------+
|                    AgentVault (Smart Account)             |
|                                                          |
|  +----------------------------------------------------+  |
|  |              SpendingPolicy Module                  |  |
|  |  - Per-agent allowances (amount/time/address)       |  |
|  |  - Session keys with expiry                         |  |
|  |  - Whitelist/blacklist targets                      |  |
|  |  - Onchain audit trail                              |  |
|  +----------------------------------------------------+  |
|                                                          |
|  +----------------------------------------------------+  |
|  |              TrustRegistry Module                   |  |
|  |  - ERC-8004 identity verification                   |  |
|  |  - Onchain attestations (EAS)                       |  |
|  |  - Reputation scores                                |  |
|  |  - Counterparty verification before transacting     |  |
|  +----------------------------------------------------+  |
|                                                          |
|  +----------------------------------------------------+  |
|  |              CooperationEscrow Module                |  |
|  |  - Agent-to-agent deal creation                     |  |
|  |  - Milestone-based release                          |  |
|  |  - Deadline enforcement                             |  |
|  |  - Dispute resolution (evidence onchain)            |  |
|  +----------------------------------------------------+  |
|                                                          |
|  +----------------------------------------------------+  |
|  |              PrivacyGuard Module                    |  |
|  |  - ZK proof of authorization (no identity leak)     |  |
|  |  - Selective disclosure policies                    |  |
|  |  - Private spending proofs                          |  |
|  +----------------------------------------------------+  |
|                                                          |
+----------------------------------------------------------+
            |                           |
     interacts with              settles on
            |                           |
   +--------v--------+        +--------v--------+
   |  Other Agents /  |        |   Base (L2)     |
   |  Services        |        |   Ethereum      |
   +------------------+        +-----------------+
```

## Contract Architecture

### 1. AgentVault.sol (Core)
The main smart account contract. Owns funds, delegates execution to modules.

- Owner (human) has full control
- Agents are registered with scoped permissions
- Modular: each capability is a separate module
- ERC-4337 compatible for gasless agent operations

### 2. SpendingPolicy.sol (Track: Agents that Pay)
Enforces spending boundaries at the contract level.

```solidity
struct AgentPolicy {
    uint256 maxPerTx;        // Max spend per transaction
    uint256 maxPerDay;       // Daily spending cap
    uint256 dailySpent;      // Tracks current day spend
    uint256 lastResetDay;    // Day number for reset logic
    uint40  validUntil;      // Session key expiry
    address[] whitelist;     // Allowed destination addresses (empty = any)
}
```

Key functions:
- `setAgentPolicy(agent, policy)` -- human sets boundaries
- `executeAsAgent(to, value, data)` -- agent executes within policy
- `getAgentSpending(agent)` -- full audit trail
- `revokeAgent(agent)` -- immediate permission removal

### 3. TrustRegistry.sol (Track: Agents that Trust)
Verifies counterparties before transacting.

- Checks ERC-8004 registration onchain
- Queries EAS (Ethereum Attestation Service) for attestations
- Maintains a local trust score based on past interactions
- No centralized registry dependency

Key functions:
- `verifyCounterparty(address)` -- check ERC-8004 + attestations
- `recordInteraction(address, outcome)` -- build reputation
- `getTrustScore(address)` -- query local reputation
- `requireTrusted(address, minScore)` -- gate transactions on trust

### 4. CooperationEscrow.sol (Track: Agents that Cooperate)
Smart contract enforcement for agent-to-agent deals.

```solidity
struct Deal {
    address initiator;       // Agent A
    address counterparty;    // Agent B
    uint256 amount;          // Escrowed value
    bytes32 termsHash;       // Hash of deal terms
    uint256 deadline;        // Auto-refund if not completed
    DealStatus status;       // Created/Active/Completed/Disputed/Expired
    uint256 milestoneCount;
    uint256 milestonesCompleted;
}
```

Key functions:
- `createDeal(counterparty, terms, milestones, deadline)` -- initiate
- `acceptDeal(dealId)` -- counterparty agrees
- `completeMilestone(dealId, evidence)` -- submit proof of work
- `confirmMilestone(dealId)` -- initiator confirms, releases funds
- `disputeDeal(dealId, evidence)` -- onchain evidence submission
- `expireDeal(dealId)` -- auto-refund after deadline

### 5. PrivacyGuard.sol (Track: Agents that Keep Secrets)
ZK-based authorization without identity exposure.

- Agent proves "I have permission to spend up to X" without revealing who authorized it
- Uses simple Groth16 or PLONK proofs for authorization
- Human sets disclosure policies: what metadata agents can reveal
- Minimal footprint: no spending patterns visible to observers

Key functions:
- `authorizeWithProof(proof, publicInputs)` -- ZK-verified execution
- `setDisclosurePolicy(agent, policy)` -- what can be revealed
- `getDisclosurePolicy(agent)` -- check what's public

## Tech Stack

- **Contracts:** Solidity 0.8.24+, Foundry
- **Chain:** Base Sepolia (testnet) -> Base Mainnet
- **Agent SDK:** TypeScript + viem
- **ZK:** Circom circuits + snarkjs (simple authorization proof)
- **Identity:** ERC-8004 integration
- **Attestations:** EAS (Ethereum Attestation Service) on Base

## Build Priority (scoped for hackathon)

### Phase 1: Core (Day 1-2)
- [ ] AgentVault.sol -- basic smart account with owner
- [ ] SpendingPolicy.sol -- full spending control
- [ ] Deploy to Base Sepolia
- [ ] Agent script that demonstrates scoped spending

### Phase 2: Trust + Cooperation (Day 3-5)
- [ ] TrustRegistry.sol -- ERC-8004 verification + attestations
- [ ] CooperationEscrow.sol -- deal creation and settlement
- [ ] Agent-to-agent deal demo

### Phase 3: Privacy (Day 6-8)
- [ ] Circom circuit for ZK authorization proof
- [ ] PrivacyGuard.sol -- ZK verification onchain
- [ ] Selective disclosure demo

### Phase 4: Polish (Day 9-14)
- [ ] Frontend dashboard (human control panel)
- [ ] Full end-to-end demo
- [ ] README + pitch
- [ ] Deploy to Base Mainnet

## Why This Wins

1. **One coherent system** -- not four separate hacks stapled together
2. **Working demo** -- deployed contracts, real transactions, verifiable onchain
3. **Human-centric** -- the human stays in control at every layer
4. **Uses real infra** -- ERC-8004, EAS, Base, ZK proofs. Nothing fabricated.
5. **Addresses all four themes** through a single, unified architecture
