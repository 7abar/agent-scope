# AgentScope x Uniswap Trading API

Scope-gated DeFi for AI agents. Uses the official [Uniswap Developer Platform API](https://developers.uniswap.org) with [AgentScope](https://github.com/7abar/agent-scope) permission enforcement.

## How It Works

Before an AI agent can swap tokens, it must hold the right **scope tokens** (ERC-1155 capabilities):

```
Agent wants to swap ETH -> USDC
  |
  v
[1] Check INTERACT scope token  --> Does agent have permission to call Uniswap?
[2] Check SPEND scope token     --> Does agent have spending allowance?
  |
  v  (both granted)
[3] Uniswap API /check_approval --> Permit2 approval status
[4] Uniswap API /quote          --> Best route (Classic or UniswapX)
[5] Sign Permit2 message         --> If needed
[6] AgentScope.interact()        --> Scope-gated execution + onchain receipt
  |
  v
Swap complete. Receipt #N recorded onchain.
```

Every swap is **receipted** — an immutable onchain record that the agent acted within its granted permissions.

## Key Integration Points

| Component | Role |
|---|---|
| **Uniswap Trading API** | Routing, quotes, calldata generation, MEV protection |
| **AgentScope.interact()** | Permission check + onchain execution + receipt |
| **ScopeToken (ERC-1155)** | INTERACT + SPEND capabilities that gate what agents can do |
| **Permit2** | Token approval management (Uniswap standard) |

## Quick Start

```bash
npm install
PRIVATE_KEY=0x... UNISWAP_API_KEY=... npm run demo
```

## API Flow

### 1. Get Quote

```typescript
const uniswap = new UniswapClient({ apiKey: UNISWAP_API_KEY });

const quote = await uniswap.getQuote({
  swapper: agentAddress,
  tokenIn: WETH,
  tokenOut: USDC,
  amount: "100000000000000", // 0.0001 ETH in wei
  tokenInChainId: 8453,     // Base
  tokenOutChainId: 8453,
  type: "EXACT_INPUT",
});
```

### 2. Scope-Gated Swap (Full)

```typescript
const agent = new ScopeGatedSwap({
  privateKey: "0x...",
  uniswapApiKey: "your-api-key",
});

const result = await agent.swapETHForUSDC("0.0001");
// result.success, result.txHash, result.receiptId, result.routing
```

## Architecture

```
agent-scope-uniswap/
├── src/
│   ├── uniswap-client.ts      ← Uniswap Trading API wrapper
│   ├── scope-gated-swap.ts    ← AgentScope + Uniswap integration
│   ├── demo.ts                ← Live demo script
│   ├── index.ts               ← Exports
│   └── uniswap-client.test.ts ← Tests (6 passing)
├── package.json
└── tsconfig.json
```

## Requirements

- [Uniswap API key](https://developers.uniswap.org/dashboard/)
- AgentScope agent with INTERACT + SPEND scope tokens
- Base mainnet ETH for gas

## Contracts (Base Mainnet)

| Contract | Address |
|---|---|
| AgentScope | `0x29Ff65DBA69Af3edEBC0570a7cd7f1000B66e1BA` |
| ScopeToken | `0xCef94f8f4f6f875C016c246EDfACDE8c0578D580` |
| DealEngine | `0x377f2788a6A96064dF572a1A582717799d4023D6` |
| TrustAnchor | `0x07BD306226B598834D1d5C14C11575B5D196a885` |

## Part of AgentScope

This module is part of the [AgentScope](https://github.com/7abar/agent-scope) protocol — the onchain operating system for AI agents. Built for The Synthesis Hackathon 2026.

## License

MIT
