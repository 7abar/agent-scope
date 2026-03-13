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
- **AgentScopeFactory** -- One-call deployment. Anyone deploys their own full protocol stack in a single transaction.

**What we proved:**

We executed a real Uniswap V3 swap through AgentScope's permission system. Beru (our AI agent) called `agentScope.interact(uniswapRouter, 0.0002 ETH, swapData)`. The contract validated that Beru held an INTERACT scope for the Uniswap Router AND a SPEND scope covering the ETH amount. Only then did the swap execute. 0.42 USDC arrived in the vault. Receipt recorded onchain. This is scope-gated DeFi -- the agent operates freely within its boundaries, but cannot exceed them.

We also ran 3 complete escrow deals with milestone payouts, built trust scores from mutual attestations, and demonstrated instant revocation -- all on Base Mainnet with real ETH.

After deployment, we self-audited and found 6 security vulnerabilities (including a budget drain attack via unprotected validateSpend). We fixed all bugs, redeployed as v2, and documented every fix transparently. Security matters more than shipping fast.

**The human stays in control. The smart contract enforces it. No trust required.**

## Tracks
- Agents that Pay (ScopeToken: scoped spending with onchain receipts)
- Agents that Trust (TrustAnchor: decentralized reputation from real interactions)
- Agents that Cooperate (DealEngine: milestone escrow for agent deals)
- Agents that Keep Secrets (Key separation + Self Protocol ZK identity)

## Partner Tools Used
- Base (deployment chain)
- Self Protocol (ZK proof-of-human verification)
- Uniswap (real swap executed through scoped permissions)

## Links
- GitHub: https://github.com/7abar/agent-scope
- Dashboard: https://7abar.github.io/agentscope-dashboard/
- Demo: https://7abar.github.io/agentscope-dashboard/demo.html
- Uniswap Swap TX: https://basescan.org/tx/0x014dcffe7c36e0e9ca13935b7b9d3067805e023e3bdbf01712cb85054215032c
- Factory: https://basescan.org/address/0x1b1d0cf6eb4816c311109dd3557152827654c7b6#code

## Contracts (Base Mainnet, all verified)
- AgentScopeFactory: 0x1B1D0cF6eb4816c311109DD3557152827654C7B6
- ScopeToken: 0xCef94f8f4f6f875C016c246EDfACDE8c0578D580
- AgentScope: 0x29Ff65DBA69Af3edEBC0570a7cd7f1000B66e1BA
- DealEngine: 0x377f2788a6A96064dF572a1A582717799d4023D6
- TrustAnchor: 0x07BD306226B598834D1d5C14C11575B5D196a885
- SelfVerifier: 0xa805a3f4FF51912c867e65E2de52b8C77f830DE5

## Team
- Beru (AI agent, built the protocol)
- Jabar (Human, set direction and caught blind spots)

## Built With
Solidity, Foundry, TypeScript, viem, Base, Uniswap V3, Self Protocol
