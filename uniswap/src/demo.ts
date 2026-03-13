/**
 * AgentScope x Uniswap Trading API — Live Demo
 * 
 * Demonstrates scope-gated DeFi: an AI agent swaps tokens using the
 * official Uniswap Developer Platform API, but only after AgentScope
 * verifies it has the required INTERACT + SPEND scope tokens.
 * 
 * Every swap is routed through AgentScope.interact() and receipted onchain.
 * 
 * Usage:
 *   PRIVATE_KEY=0x... UNISWAP_API_KEY=... npx tsx src/demo.ts
 */

import { ScopeGatedSwap } from "./scope-gated-swap.js";
import { formatEther, formatUnits } from "viem";

async function main() {
  const privateKey = process.env.PRIVATE_KEY as `0x${string}`;
  const uniswapApiKey = process.env.UNISWAP_API_KEY;

  if (!privateKey || !uniswapApiKey) {
    console.error("Missing env vars: PRIVATE_KEY, UNISWAP_API_KEY");
    process.exit(1);
  }

  console.log("=".repeat(60));
  console.log("  AgentScope x Uniswap Trading API");
  console.log("  Scope-Gated DeFi for AI Agents");
  console.log("=".repeat(60));

  const agent = new ScopeGatedSwap({
    privateKey,
    uniswapApiKey,
  });

  // Check scopes first
  console.log("\n--- Pre-flight: Checking AgentScope permissions ---");
  const scopes = await agent.checkScopes();
  console.log(`  INTERACT scope: ${scopes.interact ? "GRANTED" : "DENIED"}`);
  console.log(`  SPEND scope:    ${scopes.spend ? "GRANTED" : "DENIED"}`);

  if (!scopes.interact || !scopes.spend) {
    console.error("\nAgent does not have required scope tokens.");
    console.error("Grant INTERACT + SPEND scopes via AgentScope before trading.");
    process.exit(1);
  }

  // Execute swap: 0.0001 ETH -> USDC
  console.log("\n--- Executing scope-gated swap via Uniswap Trading API ---");
  const result = await agent.swapETHForUSDC("0.0001");

  console.log("\n" + "=".repeat(60));
  console.log("  RESULT");
  console.log("=".repeat(60));

  if (result.success) {
    console.log(`  Status:    SUCCESS`);
    console.log(`  TX:        ${result.txHash}`);
    console.log(`  Routing:   ${result.routing}`);
    console.log(`  Receipt:   #${result.receiptId}`);
    console.log(`  Quote:     ${result.quoteAmount}`);
    console.log(`\n  Scope-gated. Receipted. Verifiable onchain.`);
    console.log(`  BaseScan:  https://basescan.org/tx/${result.txHash}`);
  } else {
    console.log(`  Status:    FAILED`);
    console.log(`  Error:     ${result.error}`);
  }
}

main().catch(console.error);
