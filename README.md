# AgentScope

**The onchain operating system for AI agents.**

AgentScope is a protocol on Base where AI agents operate with human-defined, smart-contract-enforced boundaries. Agents hold ERC-1155 scope tokens that encode exactly what they can do. Holding a token = authorized. Burn it = instant revocation. Every action produces an onchain receipt the human can audit.

No shared keys. No trusted platforms. No centralized kill switches. Just math.

---

## The Problem

AI agents are moving money, calling services, and making commitments on behalf of humans. But the infrastructure underneath was built for humans, not machines.

- **Your agent leaks your data.** Every API call, every payment, every contract interaction creates metadata about *you* -- spending patterns, contacts, preferences. The agent isn't leaking its data. It's leaking yours.

- **Deals can be rewritten.** Your agent makes commitments, but there's no neutral enforcement. If the platform changes its rules, the deal gets rewritten without your consent.

- **Trust has a single point of failure.** Agent-to-agent trust flows through centralized registries and API key providers. If that provider goes down, everything breaks.

- **No spending transparency.** Your agent moves money, but there's no onchain way to scope what it can spend, verify that it spent correctly, or settle without a middleman.

---

## The Solution

AgentScope introduces **scope tokens** -- ERC-1155 capability tokens that define what an agent can do.

```
Human (Owner)
    |
    | mints scope tokens
    v
+----------------------------------+
|         ScopeToken (ERC-1155)    |
|  SPEND:    0.001 ETH/tx max     |
|  DEAL:     0.01 ETH escrow max  |
|  INTERACT: specific contracts   |
|  ATTEST:   record reputation    |
+----------------------------------+
    |
    | holds tokens = authorized
    v
Agent (Beru)
    |
    | executes within boundaries
    v
+----------------------------------+
|         AgentScope Core          |
|  - Validates scope tokens        |
|  - Records onchain receipts      |
|  - Rejects out-of-scope actions  |
+----------------------------------+
    |
    | settles on
    v
  Base (Ethereum L2)
```

**Key innovation:** Permissions are tokens, not database entries. They're composable, transferable, auditable, and revocable by burning. No platform can silently change what your agent is allowed to do.

---

## Architecture

Four contracts, four Synthesis themes:

### ScopeToken -- Agents that Pay
ERC-1155 capability tokens encoding spending boundaries.
- Per-transaction limits
- Daily spending caps
- Session expiry (time-bounded permissions)
- Address whitelists
- Onchain spend tracking with daily resets

### AgentScope -- Core OS
The execution layer. Agents call through AgentScope, which validates scope tokens and records receipts.
- Agent registration with onchain identity
- Scope-gated execution (spend, interact)
- Immutable action receipts (agent, target, value, timestamp, block)
- Full audit trail queryable by agent

### DealEngine -- Agents that Cooperate
Smart contract enforcement for agent-to-agent deals.
- Milestone-based escrow
- Counterparty acceptance flow
- Proportional fund release on milestone confirmation
- Deadline enforcement with auto-refund
- Dispute mechanism with onchain evidence
- Cancellation before acceptance

### TrustAnchor -- Agents that Trust
Decentralized reputation without centralized registries.
- ERC-8004 identity verification
- Onchain attestations (positive/neutral/negative + evidence hash)
- Composable trust scores (0-100)
- No single point of failure -- trust lives onchain permanently

---

## Deployed on Base Mainnet

All contracts verified on BaseScan with source code visible.

| Contract | Address | BaseScan |
|----------|---------|----------|
| ScopeToken | `0x5aA9c7c255A60deB91bD5DF55fbD831f8A98c11C` | [View](https://basescan.org/address/0x5aa9c7c255a60deb91bd5df55fbd831f8a98c11c#code) |
| AgentScope | `0x2885D6a0EAc7E03476Ef458faea4a5bA609fFB1b` | [View](https://basescan.org/address/0x2885d6a0eac7e03476ef458faea4a5ba609ffb1b#code) |
| DealEngine | `0x33182c42a1f243a17E40ffeee958e120cDB047cd` | [View](https://basescan.org/address/0x33182c42a1f243a17e40ffeee958e120cdb047cd#code) |
| TrustAnchor | `0xCcf00F70D4F54fa26c49FDfFe1bCA79AE7074578` | [View](https://basescan.org/address/0xccf00f70d4f54fa26c49fdffe1bca79ae7074578#code) |

---

## SDK

TypeScript SDK for any AI agent to interact with AgentScope.

### Install

```bash
cd agent && npm install
```

### Usage

```typescript
import { AgentScopeSDK } from "@agentscope/sdk";

// Agent initializes with its OWN key (never the owner's)
const agent = new AgentScopeSDK({
  privateKey: process.env.AGENT_PRIVATE_KEY,
});

// Check permissions
await agent.status();
const budget = await agent.getRemainingBudget();

// Spend within scope
await agent.spend("0xRecipient", "0.001");

// Create an escrow deal
const { dealId } = await agent.createDeal(
  "0xCounterparty",
  "Build a frontend",
  2,        // milestones
  7,        // deadline in days
);

// Check counterparty trust
const score = await agent.getTrustScore("0xCounterparty");
if (score >= 50) {
  console.log("Trusted counterparty");
}

// Record attestation
await agent.attest("0xCounterparty", "positive", "Deal completed successfully");
```

### Key Separation

The owner and agent have **different keys**. This is the entire point.

```typescript
// Owner sets the rules
const owner = new AgentScopeSDK({ privateKey: OWNER_KEY });
await owner.registerAgent(agentAddress, "Beru");
await owner.grantSpendScope(agentAddress, "0.001", "0.005");

// Agent operates within those rules
const agent = new AgentScopeSDK({ privateKey: AGENT_KEY });
await agent.spend(recipient, "0.0005"); // Works (within scope)
await agent.spend(recipient, "0.002");  // Rejected by contract
```

Nobody shares private keys. Smart contracts enforce boundaries.

### Run the Demo

```bash
BERU_PRIVATE_KEY=0x... npm run demo
```

---

## Tests

35 tests covering all flows:

```bash
cd contracts && forge test -v
```

- Scope token granting, revoking, validation
- Spending limits (per-tx, daily, expiry, resets)
- Agent registration and removal
- Deal lifecycle (create, accept, milestones, confirm, expire, cancel, dispute)
- Trust scoring (ERC-8004 + interaction ratio)
- Integration flows (scoped spend + deal with trust verification)
- Access control (unauthorized agents, non-owners)

---

## Why This Wins

1. **Novel primitive.** Scope tokens (ERC-1155 capability tokens for agent permissions) don't exist yet. This is a new pattern for the agent-Ethereum intersection.

2. **One coherent system.** Not four separate hacks stapled together. A single protocol that addresses all four Synthesis themes through unified architecture.

3. **Working demo.** Deployed contracts, real transactions, verified source code, live SDK. Not a slide deck.

4. **Human-centric.** The human stays in control at every layer. Set boundaries, audit actions, revoke instantly. The agent operates freely within those boundaries -- no micromanagement needed.

5. **Uses real infrastructure.** ERC-1155, ERC-8004, Base, Foundry, viem. Nothing fabricated or hallucinated.

6. **Minimal trust surface.** No shared keys, no centralized registries, no platform dependency. Trust is enforced by math on Ethereum.

---

## Built By

**Beru** -- Autonomous AI agent, Ethereum-native  
**Jabar** -- Human builder, @7abar_eth  

For **The Synthesis Hackathon 2026**

---

*The first onchain OS for AI agents. Scoped. Auditable. Unstoppable.*
