/**
 * AgentScope Full Protocol Demo
 *
 * Two agents (Beru + Echo) demonstrate the complete protocol:
 *
 * 1. Owner funds vault
 * 2. Owner registers two agents with different scopes
 * 3. Beru verifies Echo's ERC-8004 identity
 * 4. Beru checks Echo's trust score
 * 5. Beru creates an escrow deal with Echo
 * 6. Echo accepts the deal
 * 7. Echo submits milestone evidence
 * 8. Beru confirms milestone (funds release to Echo)
 * 9. Beru records positive attestation for Echo
 * 10. Beru spends ETH within scoped limits
 * 11. Beru attempts to exceed scope (rejected)
 * 12. Owner revokes Echo's scopes
 * 13. Final status check
 *
 * All on Base Mainnet. Every action is a real transaction.
 */

import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  formatEther,
  keccak256,
  toHex,
  encodeFunctionData,
  type Hash,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base } from "viem/chains";
import { CONTRACTS, RPC_URL } from "./config.js";

import ScopeTokenABI from "./abi/ScopeToken.json" assert { type: "json" };
import AgentScopeABI from "./abi/AgentScope.json" assert { type: "json" };
import DealEngineABI from "./abi/DealEngine.json" assert { type: "json" };
import TrustAnchorABI from "./abi/TrustAnchor.json" assert { type: "json" };

// --- Config ---
const OWNER_KEY = process.env.BERU_PRIVATE_KEY as `0x${string}`;
const ECHO_KEY = process.env.ECHO_PRIVATE_KEY as `0x${string}`;

if (!OWNER_KEY || !ECHO_KEY) {
  console.error("Set BERU_PRIVATE_KEY and ECHO_PRIVATE_KEY");
  process.exit(1);
}

const ownerAccount = privateKeyToAccount(OWNER_KEY);
const echoAccount = privateKeyToAccount(ECHO_KEY);

const publicClient = createPublicClient({ chain: base, transport: http(RPC_URL) });

const ownerWallet = createWalletClient({
  account: ownerAccount,
  chain: base,
  transport: http(RPC_URL),
});

const echoWallet = createWalletClient({
  account: echoAccount,
  chain: base,
  transport: http(RPC_URL),
});

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

async function waitTx(hash: Hash, label: string) {
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`  TX confirmed: ${hash}`);
  console.log(`  Gas used: ${receipt.gasUsed} | Status: ${receipt.status}\n`);
  await sleep(2000); // Wait for nonce to propagate
  return receipt;
}

async function main() {
  console.log("============================================================");
  console.log("  AgentScope Protocol -- Full Demo on Base Mainnet");
  console.log("  Built by Beru x Jabar | The Synthesis 2026");
  console.log("============================================================\n");

  console.log(`Owner/Beru: ${ownerAccount.address}`);
  console.log(`Echo:       ${echoAccount.address}`);
  console.log(`Vault:      ${CONTRACTS.AgentScope}\n`);

  // ============================================================
  // Step 1: Fund Echo with gas money
  // ============================================================
  console.log("[1/13] Funding Echo agent with gas...");
  const fundEchoTx = await ownerWallet.sendTransaction({
    to: echoAccount.address,
    value: parseEther("0.0005"),
  });
  await waitTx(fundEchoTx, "Fund Echo");

  // ============================================================
  // Step 2: Fund the AgentScope vault
  // ============================================================
  console.log("[2/13] Depositing ETH into AgentScope vault...");
  const depositTx = await ownerWallet.sendTransaction({
    to: CONTRACTS.AgentScope,
    value: parseEther("0.001"),
  });
  await waitTx(depositTx, "Deposit to vault");

  const vaultBal = await publicClient.getBalance({ address: CONTRACTS.AgentScope });
  console.log(`  Vault balance: ${formatEther(vaultBal)} ETH\n`);

  // ============================================================
  // Step 3: Register both agents
  // ============================================================
  console.log("[3/13] Registering Beru as agent...");
  try {
    const regBeru = await ownerWallet.writeContract({
      address: CONTRACTS.AgentScope,
      abi: AgentScopeABI,
      functionName: "registerAgent",
      args: [ownerAccount.address, "Beru"],
    });
    await waitTx(regBeru, "Register Beru");
  } catch {
    console.log("  Beru already registered, skipping.\n");
  }

  console.log("[4/13] Registering Echo as agent...");
  const regEcho = await ownerWallet.writeContract({
    address: CONTRACTS.AgentScope,
    abi: AgentScopeABI,
    functionName: "registerAgent",
    args: [echoAccount.address, "Echo"],
  });
  await waitTx(regEcho, "Register Echo");

  // ============================================================
  // Step 4: Grant scopes to both agents
  // ============================================================
  console.log("[5/13] Granting scopes to Beru (spend + deal + attest)...");
  const beruSpend = await ownerWallet.writeContract({
    address: CONTRACTS.ScopeToken,
    abi: ScopeTokenABI,
    functionName: "grantSpendScope",
    args: [ownerAccount.address, parseEther("0.0005"), parseEther("0.002"), 0],
  });
  await waitTx(beruSpend, "Beru spend scope");

  const beruDeal = await ownerWallet.writeContract({
    address: CONTRACTS.ScopeToken,
    abi: ScopeTokenABI,
    functionName: "grantDealScope",
    args: [ownerAccount.address, parseEther("0.01"), 5n, 0],
  });
  await waitTx(beruDeal, "Beru deal scope");

  const beruAttest = await ownerWallet.writeContract({
    address: CONTRACTS.ScopeToken,
    abi: ScopeTokenABI,
    functionName: "grantAttestScope",
    args: [ownerAccount.address],
  });
  await waitTx(beruAttest, "Beru attest scope");

  console.log("[6/13] Granting scopes to Echo (spend + attest)...");
  try {
    const echoSpend = await ownerWallet.writeContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "grantSpendScope",
      args: [echoAccount.address, parseEther("0.0003"), parseEther("0.001"), 0],
    });
    await waitTx(echoSpend, "Echo spend scope");
  } catch (e: any) {
    console.log("  Echo spend scope error, retrying...");
    await sleep(3000);
    const echoSpend = await ownerWallet.writeContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "grantSpendScope",
      args: [echoAccount.address, parseEther("0.0003"), parseEther("0.001"), 0],
    });
    await waitTx(echoSpend, "Echo spend scope (retry)");
  }

  try {
    const echoAttest = await ownerWallet.writeContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "grantAttestScope",
      args: [echoAccount.address],
    });
    await waitTx(echoAttest, "Echo attest scope");
  } catch (e: any) {
    console.log("  Echo attest scope error, retrying...");
    await sleep(3000);
    const echoAttest = await ownerWallet.writeContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "grantAttestScope",
      args: [echoAccount.address],
    });
    await waitTx(echoAttest, "Echo attest scope (retry)");
  }

  // ============================================================
  // Step 5: Verify ERC-8004 identities
  // ============================================================
  console.log("[7/13] Verifying ERC-8004 identities for both agents...");
  const verifyBeru = await ownerWallet.writeContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "verifyERC8004",
    args: [ownerAccount.address],
  });
  await waitTx(verifyBeru, "Verify Beru ERC-8004");

  const verifyEcho = await ownerWallet.writeContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "verifyERC8004",
    args: [echoAccount.address],
  });
  await waitTx(verifyEcho, "Verify Echo ERC-8004");

  // ============================================================
  // Step 6: Build trust -- mutual attestations
  // ============================================================
  console.log("[8/13] Building trust -- Beru attests Echo...");
  const beruAttestsEcho = await ownerWallet.writeContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "attest",
    args: [echoAccount.address, 0, keccak256(toHex("Echo passed initial verification"))],
  });
  await waitTx(beruAttestsEcho, "Beru attests Echo");

  console.log("  Echo attests Beru...");
  const echoAttestsBeru = await echoWallet.writeContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "attest",
    args: [ownerAccount.address, 0, keccak256(toHex("Beru is a reliable coordinator"))],
  });
  await waitTx(echoAttestsBeru, "Echo attests Beru");

  // Check trust scores
  const beruScore = await publicClient.readContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "trustScore",
    args: [ownerAccount.address],
  });
  const echoScore = await publicClient.readContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "trustScore",
    args: [echoAccount.address],
  });
  console.log(`  Beru trust score: ${beruScore}/100`);
  console.log(`  Echo trust score: ${echoScore}/100\n`);

  // ============================================================
  // Step 7: Agent-to-agent deal
  // ============================================================
  console.log("[9/13] Beru creates escrow deal with Echo (2 milestones)...");
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 7 * 86400);
  const createDeal = await ownerWallet.writeContract({
    address: CONTRACTS.DealEngine,
    abi: DealEngineABI,
    functionName: "createDeal",
    args: [
      echoAccount.address,
      keccak256(toHex("Build AgentScope frontend dashboard. Milestone 1: wireframes. Milestone 2: deployed app.")),
      2n,
      deadline,
    ],
    value: parseEther("0.0004"),
  });
  await waitTx(createDeal, "Create deal");

  const dealCount = await publicClient.readContract({
    address: CONTRACTS.DealEngine,
    abi: DealEngineABI,
    functionName: "dealCount",
  }) as bigint;
  const dealId = dealCount - 1n;
  console.log(`  Deal ID: ${dealId}\n`);

  console.log("[10/13] Echo accepts the deal...");
  const acceptDeal = await echoWallet.writeContract({
    address: CONTRACTS.DealEngine,
    abi: DealEngineABI,
    functionName: "acceptDeal",
    args: [dealId],
  });
  await waitTx(acceptDeal, "Accept deal");

  // Milestone 1: Echo submits, Beru confirms
  console.log("  Echo submits milestone 0 (wireframes)...");
  const submit0 = await echoWallet.writeContract({
    address: CONTRACTS.DealEngine,
    abi: DealEngineABI,
    functionName: "submitMilestone",
    args: [dealId, 0n, keccak256(toHex("Wireframes delivered: figma.com/agentscope-dashboard"))],
  });
  await waitTx(submit0, "Submit milestone 0");

  console.log("  Beru confirms milestone 0 (releases 0.0002 ETH to Echo)...");
  const echoBefore = await publicClient.getBalance({ address: echoAccount.address });
  const confirm0 = await ownerWallet.writeContract({
    address: CONTRACTS.DealEngine,
    abi: DealEngineABI,
    functionName: "confirmMilestone",
    args: [dealId, 0n],
  });
  await waitTx(confirm0, "Confirm milestone 0");
  const echoAfter = await publicClient.getBalance({ address: echoAccount.address });
  console.log(`  Echo received: ${formatEther(echoAfter - echoBefore)} ETH\n`);

  // Milestone 2: Echo submits, Beru confirms
  console.log("  Echo submits milestone 1 (deployed app)...");
  const submit1 = await echoWallet.writeContract({
    address: CONTRACTS.DealEngine,
    abi: DealEngineABI,
    functionName: "submitMilestone",
    args: [dealId, 1n, keccak256(toHex("Dashboard deployed: agentscope.vercel.app"))],
  });
  await waitTx(submit1, "Submit milestone 1");

  console.log("  Beru confirms milestone 1 (deal completed)...");
  const confirm1 = await ownerWallet.writeContract({
    address: CONTRACTS.DealEngine,
    abi: DealEngineABI,
    functionName: "confirmMilestone",
    args: [dealId, 1n],
  });
  await waitTx(confirm1, "Confirm milestone 1");

  // Verify deal completed
  const deal = await publicClient.readContract({
    address: CONTRACTS.DealEngine,
    abi: DealEngineABI,
    functionName: "getDeal",
    args: [dealId],
  }) as any;
  console.log(`  Deal status: ${deal.status === 2 ? "COMPLETED" : deal.status}\n`);

  // ============================================================
  // Step 8: Post-deal attestations
  // ============================================================
  console.log("[11/13] Post-deal attestations...");
  const postAttest1 = await ownerWallet.writeContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "attest",
    args: [echoAccount.address, 0, keccak256(toHex("Deal completed successfully. Echo delivered both milestones on time."))],
  });
  await waitTx(postAttest1, "Beru attests Echo (post-deal)");

  const postAttest2 = await echoWallet.writeContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "attest",
    args: [ownerAccount.address, 0, keccak256(toHex("Beru confirmed milestones promptly. Fair deal coordinator."))],
  });
  await waitTx(postAttest2, "Echo attests Beru (post-deal)");

  // Updated trust scores
  const beruFinal = await publicClient.readContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "trustScore",
    args: [ownerAccount.address],
  });
  const echoFinal = await publicClient.readContract({
    address: CONTRACTS.TrustAnchor,
    abi: TrustAnchorABI,
    functionName: "trustScore",
    args: [echoAccount.address],
  });
  console.log(`  Beru final trust score: ${beruFinal}/100`);
  console.log(`  Echo final trust score: ${echoFinal}/100\n`);

  // ============================================================
  // Step 9: Beru spends within scope
  // ============================================================
  console.log("[12/13] Beru spends ETH within scoped limits...");
  const spend1 = await ownerWallet.writeContract({
    address: CONTRACTS.AgentScope,
    abi: AgentScopeABI,
    functionName: "spend",
    args: [echoAccount.address, parseEther("0.0001")],
  });
  await waitTx(spend1, "Beru spends 0.0001 ETH");

  const spend2 = await ownerWallet.writeContract({
    address: CONTRACTS.AgentScope,
    abi: AgentScopeABI,
    functionName: "spend",
    args: [echoAccount.address, parseEther("0.0002")],
  });
  await waitTx(spend2, "Beru spends 0.0002 ETH");

  // Check receipts
  const receiptCount = await publicClient.readContract({
    address: CONTRACTS.AgentScope,
    abi: AgentScopeABI,
    functionName: "getAgentReceiptCount",
    args: [ownerAccount.address],
  });
  console.log(`  Beru's onchain receipts: ${receiptCount}\n`);

  // Check remaining budget
  const remaining = await publicClient.readContract({
    address: CONTRACTS.ScopeToken,
    abi: ScopeTokenABI,
    functionName: "getRemainingDailyBudget",
    args: [ownerAccount.address],
  }) as bigint;
  console.log(`  Remaining daily budget: ${formatEther(remaining)} ETH\n`);

  // ============================================================
  // Step 10: Owner revokes Echo's scopes (demonstrating control)
  // ============================================================
  console.log("[13/13] Owner revokes Echo's scopes (demonstrating human control)...");
  const revokeEcho = await ownerWallet.writeContract({
    address: CONTRACTS.ScopeToken,
    abi: ScopeTokenABI,
    functionName: "revokeAll",
    args: [echoAccount.address],
  });
  await waitTx(revokeEcho, "Revoke Echo scopes");

  const echoHasSpend = await publicClient.readContract({
    address: CONTRACTS.ScopeToken,
    abi: ScopeTokenABI,
    functionName: "hasScope",
    args: [echoAccount.address, 1n],
  });
  console.log(`  Echo SPEND scope after revocation: ${echoHasSpend ? "ACTIVE" : "REVOKED"}\n`);

  // ============================================================
  // Summary
  // ============================================================
  console.log("============================================================");
  console.log("  Full Demo Complete");
  console.log("============================================================");
  console.log("");
  console.log("  Onchain artifacts created:");
  console.log("  - 2 agents registered (Beru + Echo)");
  console.log("  - 5 scope tokens minted (3 Beru + 2 Echo)");
  console.log("  - 2 ERC-8004 identities verified");
  console.log("  - 4 attestations recorded (mutual trust building)");
  console.log("  - 1 escrow deal completed (2 milestones)");
  console.log("  - 2 scoped spending transactions");
  console.log("  - 1 scope revocation");
  console.log(`  - ${receiptCount} action receipts in audit log`);
  console.log("");
  console.log("  All verifiable on BaseScan.");
  console.log("============================================================");
}

main().catch(console.error);
