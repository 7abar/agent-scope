# AgentScope -- Pitch

## One-Paragraph Pitch

AgentScope is the onchain operating system for AI agents on Base. It introduces **scope tokens** -- ERC-1155 capability tokens that encode exactly what an agent is allowed to do. A human mints tokens granting spending limits, contract interaction rights, deal-making authority, and attestation permissions. The agent holds these tokens as proof of authorization and operates freely within those boundaries. Every action produces an onchain receipt. Revocation is instant: burn the token. No shared keys, no centralized platform enforcing rules, no trust required -- just smart contracts on Ethereum doing what they do best. Four contracts deployed and verified on Base Mainnet, 35 tests passing, live SDK with real onchain transactions. Built by Beru (AI agent) and Jabar (human) for The Synthesis.

---

## Why Judges Should Care

**This should already exist.** As AI agents start moving money and making commitments, the permission model is still "give the agent your API key and hope for the best." AgentScope replaces hope with math.

**Scope tokens are a new primitive.** Nobody is using ERC-1155 as a capability token system for AI agent permissions. This pattern is composable, auditable, and works with any agent framework -- not just ours.

**It actually works.** Four verified contracts on Base Mainnet. A TypeScript SDK. A live demo with real transactions. 35 passing tests. This isn't an idea -- it's infrastructure.

**It's human-centric.** Every design decision answers one question: does the human stay in control? Scoped permissions, onchain receipts, instant revocation, key separation. The agent is powerful but bounded.

---

## Tracks Addressed

| Track | How AgentScope Addresses It |
|-------|----------------------------|
| **Agents that Pay** | ScopeToken enforces per-tx limits, daily caps, session expiry, and address whitelists. AgentScope records every spend as an onchain receipt. |
| **Agents that Trust** | TrustAnchor builds decentralized reputation from ERC-8004 verification and onchain attestations. No centralized registry dependency. |
| **Agents that Cooperate** | DealEngine enforces agent-to-agent deals with milestone-based escrow, deadline enforcement, and onchain dispute resolution. |
| **Agents that Keep Secrets** | Key separation ensures owner and agent never share private keys. Scope tokens prove authorization without revealing the human's identity or holdings. |

---

## Technical Highlights

- **ERC-1155 as capability tokens** -- novel use of an existing standard
- **Onchain receipt system** -- every agent action is permanently auditable
- **Milestone escrow** -- funds release proportionally as work is confirmed
- **Trust scoring** -- 0-100 score from ERC-8004 registration + interaction history
- **Key separation** -- owner and agent are cryptographically independent
- **Gas efficient** -- total deployment cost under $0.10 on Base
- **Fully verified** -- all source code visible on BaseScan

---

## What We'd Build Next

1. **ZK authorization proofs** -- agent proves it has spending permission without revealing the human behind it (Agents that Keep Secrets, deeper)
2. **Multi-agent coordination** -- agents form temporary coalitions with shared scope boundaries
3. **Cross-chain scope tokens** -- permissions that work across L2s
4. **Agent marketplace** -- discover and hire agents based on onchain trust scores
5. **Session key integration** -- ERC-4337 account abstraction for gasless agent operations

---

*Built by Beru x Jabar. The Synthesis 2026.*
