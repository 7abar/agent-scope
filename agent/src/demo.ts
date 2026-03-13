/**
 * AgentScope Demo -- Beru in Action
 *
 * This demo shows the full lifecycle:
 * 1. Owner registers Beru as an agent
 * 2. Owner grants scoped permissions (spend, deal, attest)
 * 3. Beru checks its status and available scopes
 * 4. Beru verifies a counterparty's trust score
 * 5. Beru records an attestation
 * 6. Beru checks its onchain receipts
 *
 * All actions produce onchain receipts on Base Mainnet.
 */

import { AgentScopeSDK } from "./sdk.js";

const PRIVATE_KEY = process.env.BERU_PRIVATE_KEY as `0x${string}`;

if (!PRIVATE_KEY) {
  console.error("Set BERU_PRIVATE_KEY environment variable");
  process.exit(1);
}

async function main() {
  console.log("========================================");
  console.log("  AgentScope Protocol -- Beru Demo");
  console.log("  Built by Beru x Jabar");
  console.log("  The Synthesis Hackathon 2026");
  console.log("========================================\n");

  // Initialize SDK (owner and agent are the same key for demo)
  const beru = new AgentScopeSDK({ privateKey: PRIVATE_KEY });

  // --- Step 1: Check Status ---
  console.log("[Step 1] Checking Beru's current status...\n");
  await beru.status();

  // --- Step 2: Register Beru as Agent ---
  console.log("[Step 2] Registering Beru as an agent...");
  try {
    const regTx = await beru.registerAgent(beru.address, "Beru");
    console.log(`Waiting for confirmation...`);
    await beru.publicClient.waitForTransactionReceipt({ hash: regTx });
    console.log("Beru registered onchain.\n");
  } catch (e: any) {
    console.log("Already registered or error:", e.message?.slice(0, 100), "\n");
  }

  // --- Step 3: Grant Scopes ---
  console.log("[Step 3] Granting scoped permissions to Beru...");
  try {
    // Spend scope: max 0.001 ETH per tx, 0.005 ETH per day
    const spendTx = await beru.grantSpendScope(beru.address, "0.001", "0.005");
    await beru.publicClient.waitForTransactionReceipt({ hash: spendTx });
    console.log("Spend scope granted: 0.001 ETH/tx, 0.005 ETH/day");

    // Deal scope: max 0.01 ETH escrow, up to 3 concurrent deals
    const dealTx = await beru.grantDealScope(beru.address, "0.01", 3);
    await beru.publicClient.waitForTransactionReceipt({ hash: dealTx });
    console.log("Deal scope granted: 0.01 ETH max escrow, 3 concurrent deals");

    // Attest scope
    const attestTx = await beru.grantAttestScope(beru.address);
    await beru.publicClient.waitForTransactionReceipt({ hash: attestTx });
    console.log("Attest scope granted.\n");
  } catch (e: any) {
    console.log("Scope error:", e.message?.slice(0, 100), "\n");
  }

  // --- Step 4: Check Updated Status ---
  console.log("[Step 4] Status after scope grants...\n");
  await beru.status();

  // --- Step 5: Verify ERC-8004 Identity ---
  console.log("[Step 5] Verifying Beru's ERC-8004 identity...");
  try {
    const verifyTx = await beru.verifyERC8004(beru.address);
    await beru.publicClient.waitForTransactionReceipt({ hash: verifyTx });
    console.log("ERC-8004 verified onchain.\n");
  } catch (e: any) {
    console.log("Verify error:", e.message?.slice(0, 100), "\n");
  }

  // --- Step 6: Record Attestation ---
  console.log("[Step 6] Recording an attestation...");
  try {
    const attestTx = await beru.attest(
      beru.address,
      "positive",
      "Self-attestation: Beru operational and compliant with all scoped boundaries"
    );
    await beru.publicClient.waitForTransactionReceipt({ hash: attestTx });
    console.log("Attestation recorded onchain.\n");
  } catch (e: any) {
    console.log("Attest error:", e.message?.slice(0, 100), "\n");
  }

  // --- Step 7: Check Trust Score ---
  console.log("[Step 7] Checking Beru's trust score...");
  const trustScore = await beru.getTrustScore(beru.address);
  console.log(`Trust Score: ${trustScore}/100`);

  const profile = await beru.getTrustProfile(beru.address);
  console.log(`Profile: ${profile.positive} positive, ${profile.negative} negative, ${profile.total} total`);
  console.log(`ERC-8004 Verified: ${profile.erc8004Verified}\n`);

  // --- Step 8: Check Remaining Budget ---
  console.log("[Step 8] Budget check...");
  const remaining = await beru.getRemainingBudget();
  console.log(`Remaining daily budget: ${remaining} ETH\n`);

  // --- Summary ---
  console.log("========================================");
  console.log("  Demo Complete");
  console.log("  ");
  console.log("  Beru demonstrated:");
  console.log("  - Agent registration with onchain identity");
  console.log("  - Scoped spending permissions (ERC-1155 tokens)");
  console.log("  - ERC-8004 identity verification");
  console.log("  - Onchain attestation and trust scoring");
  console.log("  - Full auditability via action receipts");
  console.log("  ");
  console.log("  All actions verifiable on BaseScan.");
  console.log("========================================");
}

main().catch(console.error);
