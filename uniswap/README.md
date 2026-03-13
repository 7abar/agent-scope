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
| AgentScope | `0xeA612874db3b85cB4f9BDb63Ab841713BaDCF525` |
| ScopeToken | `0xdF8DA20FEE63fE3AcF3b9231BE98c38116CDCacE` |
| DealEngine | `0x7F3e5B4047a947bFFD7b182015157521A42C6B63` |
| TrustAnchor | `0x3B18d5a139be283624e640214a4135692B535AA6` |

## Part of AgentScope

This module is part of the [AgentScope](https://github.com/7abar/agent-scope) protocol — the onchain operating system for AI agents. Built for The Synthesis Hackathon 2026.

## Live Proof (Base Mainnet)

**Swap TX:** [0x77d752fb...e3fd54c](https://basescan.org/tx/0x77d752fb431786737eed0613b067797f4b4f54926ce133fe997a999a8e3fd54c)

| | |
|---|---|
| Input | 0.0001 ETH |
| Output | 0.212275 USDC |
| Routing | CLASSIC (V3) |
| Router | Universal Router `0x6fF5...9b43` |
| Agent | `0xA5844eeF46b34894898b7050CEF5F4D225e92fbE` |
| API | Uniswap Developer Platform Trading API |

---

## License

MIT
