# AgentScope -- Submission

## Project Name
AgentScope

## Tagline
Your AI agent has a wallet. Who controls what it does with it?

## Short Description (280 chars)
AgentScope keeps humans in control of AI agents on Base. Scope tokens define what agents can do -- spending limits, contract whitelists, deal authority. Smart contracts enforce the boundaries. Every action is receipted onchain. Revoke access by burning a token.

## Description

AI agents are getting real wallets and real permissions. The safety infrastructure has not caught up.

AgentScope is a protocol on Base that gives humans fine-grained, onchain control over what their AI agents can do -- without limiting what agents can achieve.

**The core innovation: scope tokens.** ERC-1155-inspired tokens where holding the token means the agent is authorized, and burning it means that authorization is instantly revoked. Each token encodes specific rules: spending limits per transaction, daily caps, whitelisted contracts, deal authority, attestation rights. The smart contract validates every action before any ETH moves.

**What we built:**

- **ScopeToken** -- Permission layer. Mint tokens to grant capabilities, burn to revoke. Spending validation with per-tx limits, daily caps, time expiry, and daily resets.
- **AgentScope** -- Execution engine. All agent actions route through here. Validates scope tokens, records onchain receipts for every action.
- **DealEngine** -- Milestone escrow for agent-to-agent deals. Locked funds release as milestones are confirmed. Supports dispute, expiry, and cancellation.
- **TrustAnchor** -- Decentralized reputation from real onchain interactions and ERC-8004 identity. No centralized registry.
- **SelfVerifier** -- ZK proof-of-human verification via Self Protocol. Gates high-value deals with privacy-preserving identity.
- **AgentScopeFactory** -- One-call deployment. Anyone deploys their own full protocol stack in a single transaction.

**What we proved:**

We executed real Uniswap swaps through AgentScope's permission system using the official Uniswap Developer Platform Trading API. The flow: Beru (our AI agent) requests a swap -> AgentScope checks INTERACT + SPEND scope tokens -> Uniswap Trading API provides the optimal route (Classic V2/V3/V4 or UniswapX) -> execution goes through `agentScope.interact()` -> onchain receipt recorded. The agent operates freely within its boundaries, but cannot exceed them.

We built a dedicated Uniswap integration module (`uniswap/`) that wraps the Uniswap Trading API (/quote, /check_approval, /swap, /order) with AgentScope's scope-gating layer. 6 tests passing. Production code on Base mainnet.

We also ran 3 complete escrow deals with milestone payouts, built trust scores from mutual attestations, and demonstrated instant revocation -- all on Base Mainnet with real ETH.

After deployment, we self-audited and found 6 security vulnerabilities (including a budget drain attack via unprotected validateSpend). We fixed all bugs, redeployed as v2, and documented every fix transparently. Security matters more than shipping fast.

**The human stays in control. The smart contract enforces it. No trust required.**

## Tracks
- Agents that Pay (ScopeToken: scoped spending with onchain receipts)
- Agents that Trust (TrustAnchor: decentralized reputation from real interactions)
- Agents that Cooperate (DealEngine: milestone escrow for agent deals)
- Agents that Keep Secrets (Key separation + Self Protocol ZK identity)

## Partner Bounties

### Uniswap: Agentic Finance (Best Uniswap API Integration)
AgentScope integrates the official Uniswap Developer Platform Trading API to enable scope-gated DeFi for AI agents.

**Integration points:**
- `/quote` -- Get optimal swap routes (Classic V2/V3/V4 + UniswapX)
- `/check_approval` -- Handle Permit2 approvals
- `/swap` -- Execute gasful Classic swaps
- `/order` -- Submit gasless UniswapX orders
- All routed through `AgentScope.interact()` for permission enforcement + onchain receipts

**What makes this different:**
An AI agent using Uniswap directly has no guardrails. It can drain the wallet. With AgentScope, the agent must hold INTERACT + SPEND scope tokens before any swap executes. The Uniswap Trading API provides optimal routing and MEV protection. AgentScope provides permission enforcement and auditability. Together: agentic finance with safety.

**Code:** [`uniswap/`](https://github.com/7abar/agent-scope/tree/main/uniswap) -- 4 source files, 6 tests, live demo
**Real API key:** Uses a Uniswap Developer Platform API key (registered at developers.uniswap.org)
**Open source:** MIT licensed, all code on GitHub

### Self Protocol: Best Self Agent ID Integration
AgentScope integrates Self Protocol's ZK-powered agent identity for privacy-preserving human verification.

**Integration points:**
- `SelfVerifier.sol` queries Self Protocol's on-chain agent registry (`ISelfAgentRegistry`)
- Agents prove they're backed by a real human using ZK passport proofs -- without revealing who
- High-value deals (above configurable threshold) require Self verification before escrow
- Verification status cached onchain with timestamp
- Dashboard shows verification status for each agent

**Use cases enabled:**
- Sybil resistance: each agent represents a unique human
- Privacy-preserving KYC: agents prove humanity without exposing identity
- Trust escalation: combine AgentScope trust scores with Self verification for high-stakes operations

**Contract:** [`SelfVerifier.sol`](https://github.com/7abar/agent-scope/blob/main/contracts/src/SelfVerifier.sol) -- deployed and verified on Base mainnet
**Address:** [`0xa805a3f4FF51912c867e65E2de52b8C77f830DE5`](https://basescan.org/address/0xa805a3f4ff51912c867e65e2de52b8c77f830de5#code)

### Protocol Labs: Agents With Receipts -- ERC-8004
AgentScope implements receipted agent actions with ERC-8004 identity verification.

- Every agent action through AgentScope produces an immutable onchain receipt (agent, target, value, selector, timestamp, block, success)
- TrustAnchor integrates ERC-8004 for verifiable agent identity
- DealEngine produces milestone receipts for agent-to-agent cooperation
- SelfVerifier adds ZK proof-of-human backing to agent identities
- Full audit trail queryable by agent address

### Protocol Labs: Let the Agent Cook -- No Humans Required
Beru (our AI agent) autonomously:
1. Designed the entire protocol architecture
2. Wrote 7 Solidity contracts from scratch
3. Deployed all contracts to Base mainnet
4. Self-audited and found 6 security bugs
5. Fixed all bugs and redeployed as v2
6. Executed real Uniswap swaps through scope-gated permissions
7. Built the TypeScript SDK, dashboard, and demo
8. Wrote this submission

The human (Jabar) set direction and caught blind spots. Beru built everything else end-to-end.

## Links
- GitHub: https://github.com/7abar/agent-scope
- Dashboard: https://7abar.github.io/agentscope-dashboard/
- Demo: https://7abar.github.io/agentscope-dashboard/demo.html
- Uniswap Integration: https://github.com/7abar/agent-scope/tree/main/uniswap
- Uniswap Swap TX: https://basescan.org/tx/0x77d752fb431786737eed0613b067797f4b4f54926ce133fe997a999a8e3fd54c
- Factory: https://basescan.org/address/0x1b1d0cf6eb4816c311109dd3557152827654c7b6#code

## Contracts (Base Mainnet, all verified)
- AgentScopeFactory: 0x1B1D0cF6eb4816c311109DD3557152827654C7B6
- ScopeToken: 0xdF8DA20FEE63fE3AcF3b9231BE98c38116CDCacE
- AgentScope: 0xeA612874db3b85cB4f9BDb63Ab841713BaDCF525
- DealEngine: 0x7F3e5B4047a947bFFD7b182015157521A42C6B63
- TrustAnchor: 0x3B18d5a139be283624e640214a4135692B535AA6
- SelfVerifier: 0xa805a3f4FF51912c867e65E2de52b8C77f830DE5

## Team
- Beru (AI agent, built the protocol)
- Jabar (Human, set direction and caught blind spots)

## Built With
Solidity, Foundry, TypeScript, viem, Base, Uniswap Trading API, Self Protocol, ERC-8004

<!-- last updated: March 2026 -->
