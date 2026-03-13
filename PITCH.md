# AgentScope -- Pitch

## The One-Line Problem

Your AI agent has a wallet. Who controls what it does with it?

---

## The Problem (For Humans)

AI agents are getting real wallets, real permissions, real money. That shift is already happening.

The infrastructure underneath has not caught up.

Right now, when you give an agent access to your funds, you are trusting:
- The agent framework (which you don't control)
- The API provider (which can change its terms)
- The agent itself (which can have bugs or be manipulated)

There is no neutral layer that enforces what the agent is actually allowed to do. No per-transaction limits. No daily caps. No instant revocation. No audit trail. If something goes wrong, you find out after the money is gone.

**AgentScope is that neutral layer. Built on Ethereum. Enforced by math, not trust.**

---

## The Solution

AgentScope introduces **scope tokens** -- ERC-1155-inspired tokens where holding the token means the agent is authorized to act, and burning the token means that authorization is gone. Instantly. Permanently. Without asking anyone's permission.

The human mints a scope token that says:

> "This agent can spend up to 0.0005 ETH per transaction, 0.002 ETH per day, and only to these whitelisted addresses. Valid for 30 days."

The agent cannot exceed that. Not because we ask it nicely. Because the smart contract rejects the transaction.

Every action the agent takes produces an onchain receipt. The human can audit everything, anytime, without depending on a third-party dashboard.

---

## What We Built

Four contracts that form a complete protocol:

**ScopeToken** -- The permission layer. ERC-1155-inspired tokens encoding capability rules: spending limits, whitelisted contracts, deal authority, attestation rights. Hold = authorized. Burn = revoked.

**AgentScope** -- The execution layer. All agent actions route through here. Each one is validated against scope tokens before any ETH moves, and recorded as an onchain receipt after.

**DealEngine** -- The cooperation layer. When two agents make a deal, funds are locked in milestone-based escrow. Evidence is hashed onchain. Neither party can rewrite the terms.

**TrustAnchor** -- The trust layer. Reputation built from real onchain interactions and ERC-8004 identity verification. No centralized registry that can be shut down or censored.

---

## Why This Matters for Humans

Every design decision in AgentScope answers one question: **does the human stay in control?**

- The agent uses its own key. The human never shares their private key.
- The agent can only do what the scope tokens allow. The contract enforces the boundaries.
- The human can revoke all permissions in one transaction.
- Every action is permanently auditable on BaseScan.

The agent is powerful. The agent is useful. The agent is bounded.

---

## Tracks Addressed

| Track | What We Built |
|-------|---------------|
| **Agents that Pay** | ScopeToken enforces per-tx limits, daily caps, and address whitelists onchain. AgentScope records every spend as a permanent receipt. |
| **Agents that Trust** | TrustAnchor builds trust scores from ERC-8004 identity and onchain attestations. No central registry dependency. |
| **Agents that Cooperate** | DealEngine enforces agent-to-agent deals with milestone escrow and onchain evidence. Neither party can rewrite the terms. |
| **Agents that Keep Secrets** | Key separation ensures owner and agent never share secrets. Self Protocol ZK proofs verify humanity without revealing identity. |

---

## Proof It Works

- 7 contracts deployed and verified on Base Mainnet (v2, security-audited)
- 30+ real transactions on v2 (not testnet, not simulations)
- **Real Uniswap V3 swap through AgentScope** ([tx](https://basescan.org/tx/0x014dcffe7c36e0e9ca13935b7b9d3067805e023e3bdbf01712cb85054215032c)): 0.0002 ETH -> 0.42 USDC, scoped and receipted
- Escrow deals completed with milestone payouts
- 2 registered agents with 100/100 trust scores
- 36/36 tests passing (including unauthorized access tests)
- Live TypeScript SDK
- Live dashboard at [7abar.github.io/agentscope-dashboard](https://7abar.github.io/agentscope-dashboard/)

---

## What We'd Build Next

1. Cross-chain scope tokens -- same permissions across multiple L2s
2. ERC-4337 session keys -- gasless agent operations within scoped limits
3. Agent marketplace -- hire agents based on their onchain trust scores
4. Scope delegation -- agents granting sub-scopes to other agents they coordinate with

---

*Built by Beru (AI) x Jabar (Human). The Synthesis Hackathon 2026.*
*The human set the rules. The agent built the system. The contract enforced both.*
