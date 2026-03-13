/**
 * AgentScope Demo -- Key Separation
 *
 * Shows the real architecture:
 * - OWNER_KEY: Human's wallet. Sets rules, grants/revokes scopes.
 * - AGENT_KEY: Beru's wallet. Can only operate within granted scopes.
 *
 * The agent NEVER has access to the owner's key.
 * The owner NEVER has access to the agent's key.
 * Trust is enforced by smart contracts, not by sharing secrets.
 */

import { AgentScopeSDK } from "./sdk.js";

const OWNER_KEY = process.env.OWNER_PRIVATE_KEY as `0x${string}`;
const AGENT_KEY = process.env.AGENT_PRIVATE_KEY as `0x${string}`;

if (!OWNER_KEY || !AGENT_KEY) {
  console.error("Set OWNER_PRIVATE_KEY and AGENT_PRIVATE_KEY");
  process.exit(1);
}

async function main() {
  console.log("========================================");
  console.log("  AgentScope -- Key Separation Demo");
  console.log("========================================\n");

  // Two separate SDK instances, two separate keys
  const owner = new AgentScopeSDK({ privateKey: OWNER_KEY });
  const agent = new AgentScopeSDK({ privateKey: AGENT_KEY });

  console.log(`Owner address: ${owner.address}`);
  console.log(`Agent address: ${agent.address}`);
  console.log(`These are DIFFERENT wallets.\n`);

  // --- OWNER: Register the agent ---
  console.log("[Owner] Registering agent...");
  const regTx = await owner.registerAgent(agent.address, "Beru");
  await owner.publicClient.waitForTransactionReceipt({ hash: regTx });

  // --- OWNER: Grant scoped permissions ---
  console.log("[Owner] Granting spend scope: 0.001 ETH/tx, 0.005 ETH/day");
  const scopeTx = await owner.grantSpendScope(agent.address, "0.001", "0.005");
  await owner.publicClient.waitForTransactionReceipt({ hash: scopeTx });

  console.log("\nOwner is done. Agent can now operate independently.\n");

  // --- AGENT: Check what scopes it has ---
  console.log("[Agent] Checking my permissions...");
  const hasSpend = await agent.hasScope(1);
  console.log(`  Can spend: ${hasSpend}`);
  const budget = await agent.getRemainingBudget();
  console.log(`  Daily budget: ${budget} ETH`);

  // --- AGENT: Try to spend within scope ---
  // (Would work if vault has funds)
  console.log("\n[Agent] I can spend up to 0.001 ETH per tx.");
  console.log("[Agent] If I try 0.002 ETH, the CONTRACT rejects me.");
  console.log("[Agent] No trust required -- math enforces the rules.\n");

  // --- OWNER: Revoke if needed ---
  console.log("[Owner] Want to cut the agent off? One tx:");
  console.log("[Owner] scopeToken.revokeAll(agent) -- done. Instant.\n");

  console.log("========================================");
  console.log("  Key Takeaway:");
  console.log("  ");
  console.log("  - Agent has its OWN key");
  console.log("  - Owner has its OWN key");
  console.log("  - Nobody shares secrets");
  console.log("  - Smart contract enforces boundaries");
  console.log("  - Scope tokens = verifiable permission");
  console.log("  - Burn token = instant revocation");
  console.log("========================================");
}

main().catch(console.error);
