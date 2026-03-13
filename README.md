# AgentScope

**Your AI agent has a wallet. Who controls what it does with it?**

AgentScope is the answer. A protocol on Base that keeps humans in control of AI agents -- without limiting what agents can do.

Agents hold ERC-1155-inspired scope tokens that encode exactly what they're allowed to do. Holding the token = authorized. Burn it = instant revocation. Every action produces an onchain receipt the human can audit anytime.

No shared keys. No trusted platforms. No centralized kill switches. Just math.

---

## The Problem

AI agents are getting real wallets and real permissions. That shift is already happening.

The safety infrastructure has not caught up.

When you give an agent access to your funds today, you are trusting the agent framework, the API provider, and the agent itself -- none of which you fully control. There is no neutral layer that enforces what the agent is actually allowed to do. No per-transaction limits. No daily caps. No audit trail. No instant kill switch.

If something goes wrong, you find out after the money is gone.

**AgentScope is that neutral layer. Enforced by Ethereum, not by trust.**

---

## The Solution

AgentScope introduces **scope tokens** -- ERC-1155-inspired capability tokens that define what an agent can do.

```
Human (Owner)
    |
    | mints scope tokens
    v
+----------------------------------+
|         ScopeToken (ERC-1155-inspired)    |
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
ERC-1155-inspired capability tokens encoding spending boundaries.
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

### SelfVerifier -- Agents that Keep Secrets (Self Protocol Integration)
ZK proof-of-human verification integrated with Self Protocol.
- Queries Self Protocol's on-chain agent registry for ZK-verified human backing
- Gates high-value deals: escrow above threshold requires Self verification
- Agents prove they're backed by a real human without revealing who
- Sybil resistance: each agent represents a unique human
- Privacy-preserving identity layer on top of AgentScope's trust system

---

## Use It Yourself (One Transaction)

AgentScope is not a demo. It is infrastructure anyone can use.

Call the factory contract on Base Mainnet and get your own full protocol stack:

```bash
# Using cast (Foundry)
cast send 0x1B1D0cF6eb4816c311109DD3557152827654C7B6 "create()" \
  --rpc-url https://mainnet.base.org \
  --private-key YOUR_PRIVATE_KEY
```

One transaction. You get 4 contracts deployed with you as owner:
- **ScopeToken** -- mint permissions for your agents
- **AgentScope** -- execution engine with receipt tracking
- **DealEngine** -- escrow for agent-to-agent deals
- **TrustAnchor** -- reputation from real interactions

Gas cost: ~0.002 ETH on Base. No protocol fees. Fully permissionless.

**Factory contract:** [`0x1B1D0cF6eb4816c311109DD3557152827654C7B6`](https://basescan.org/address/0x1b1d0cf6eb4816c311109dd3557152827654c7b6#code)

### After Deploying

```bash
# 1. Read your deployment addresses from the event log
cast logs --from-block latest --address 0x1B1D0cF6eb4816c311109DD3557152827654C7B6

# 2. Register your agent
cast send YOUR_AGENTSCOPE "registerAgent(address,string)" AGENT_ADDRESS "MyAgent" \
  --rpc-url https://mainnet.base.org --private-key OWNER_KEY

# 3. Grant spending permission (e.g., 0.001 ETH/tx, 0.01 ETH/day, no expiry)
cast send YOUR_SCOPETOKEN \
  "grantSpendScope(address,uint256,uint256,uint40)" \
  AGENT_ADDRESS 1000000000000000 10000000000000000 0 \
  --rpc-url https://mainnet.base.org --private-key OWNER_KEY

# 4. Your agent can now operate within those boundaries
```

### Why a Factory?

Without the factory, adopting AgentScope means copying 4 contracts, configuring constructor arguments, and deploying them in the right order. Most developers won't do that.

With the factory, it's one function call. The barrier to adoption is as low as it can get.

---

## How ScopeToken Actually Works

ScopeToken is not "just a token." It is a token with enforcement logic.

```
Agent wants to send 0.001 ETH
    |
    v
AgentScope asks: "Does this agent hold SPEND token?"
    |
    v
ScopeToken checks:
  - Does the agent have SCOPE_SPEND? (balance > 0)
  - Is 0.001 ETH within per-tx limit? (maxPerTx)
  - Is today's total within daily cap? (maxPerDay)
  - Has the permission expired? (validUntil)
    |
    v
If ALL pass: transaction proceeds, receipt recorded
If ANY fail: transaction reverts, ETH does not move
```

A regular ERC-20 token just tracks balances. ScopeToken tracks balances AND enforces rules encoded in the token's associated data. The token is both the proof of permission and the enforcement mechanism.

**Burn the token = instant revocation.** One transaction. No database update. No API call. No waiting period. The agent's next action will be rejected by the contract.

---

## Deployed on Base Mainnet

All contracts verified on BaseScan with source code visible.

| Contract | Address | BaseScan |
|----------|---------|----------|
| AgentScopeFactory | `0x1B1D0cF6eb4816c311109DD3557152827654C7B6` | [View](https://basescan.org/address/0x1b1d0cf6eb4816c311109dd3557152827654c7b6#code) |
| ScopeToken | `0xCef94f8f4f6f875C016c246EDfACDE8c0578D580` | [View](https://basescan.org/address/0xcef94f8f4f6f875c016c246edfacde8c0578d580#code) |
| AgentScope | `0x29Ff65DBA69Af3edEBC0570a7cd7f1000B66e1BA` | [View](https://basescan.org/address/0x29ff65dba69af3edebc0570a7cd7f1000b66e1ba#code) |
| DealEngine | `0x377f2788a6A96064dF572a1A582717799d4023D6` | [View](https://basescan.org/address/0x377f2788a6a96064df572a1a582717799d4023d6#code) |
| TrustAnchor | `0x07BD306226B598834D1d5C14C11575B5D196a885` | [View](https://basescan.org/address/0x07bd306226b598834d1d5c14c11575b5d196a885#code) |
| SelfVerifier | `0xa805a3f4FF51912c867e65E2de52b8C77f830DE5` | [View](https://basescan.org/address/0xa805a3f4ff51912c867e65e2de52b8c77f830de5#code) |
| PartnerIntegrations | `0xa5aEeA7d9894bbE792eF6dEf8FAF6F150011e8E9` | [View](https://basescan.org/address/0xa5aeea7d9894bbe792ef6def8faf6f150011e8e9#code) |

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

## Security (v2 Fixes)

We audited the v1 contracts and found real vulnerabilities. All fixed in v2:

| Bug | Severity | Fix |
|-----|----------|-----|
| `validateSpend` callable by anyone (budget drain attack) | Medium | Added `onlyAuthorized` modifier -- only AgentScope and DealEngine can call |
| `incrementDeals` callable by anyone (deal slot griefing) | Medium | Added `onlyAuthorized` modifier |
| Rounding dust stuck in DealEngine | Low | Last milestone pays remainder instead of equal split |
| CEI violation in `confirmMilestone` | Low | State changes before ETH transfers in all functions |
| `expireDeal` callable by anyone (griefing) | Low | Restricted to deal parties only |
| Factory didn't authorize callers | Low | Factory auto-calls `authorizeCaller` and transfers ownership |

v1 contracts remain on-chain (immutable) but are superseded. v2 addresses are listed below.

---

## Tests

36 tests covering all flows:

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

1. **Novel primitive.** Scope tokens (ERC-1155-inspired capability tokens for agent permissions) don't exist yet. This is a new pattern for the agent-Ethereum intersection.

2. **One coherent system.** Not four separate hacks stapled together. A single protocol that addresses all four Synthesis themes through unified architecture.

3. **Working demo.** Deployed contracts, real transactions, verified source code, live SDK. Not a slide deck.

4. **Human-centric.** The human stays in control at every layer. Set boundaries, audit actions, revoke instantly. The agent operates freely within those boundaries -- no micromanagement needed.

5. **Uses real infrastructure.** ERC-1155-inspired scope tokens, ERC-8004, Base, Self Protocol, Foundry, viem. Nothing fabricated or hallucinated.

6. **Minimal trust surface.** No shared keys, no centralized registries, no platform dependency. Trust is enforced by math on Ethereum.

7. **Live partner integration.** Agents execute real Uniswap swaps through AgentScope's scoped permission system. Self Protocol provides ZK identity verification. Additional partner interfaces (Lido, ENS, Lit Protocol, OLAS) demonstrate ecosystem compatibility.

---

## Built By

**Beru** -- Autonomous AI agent, Ethereum-native  
**Jabar** -- Human builder, @7abar_eth  

For **The Synthesis Hackathon 2026**

---

*The first onchain OS for AI agents. Scoped. Auditable. Unstoppable.*
<!-- v2 Base Mainnet -->
