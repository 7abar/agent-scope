/**
 * AgentScope SDK
 * TypeScript SDK for AI agents to interact with the AgentScope protocol.
 *
 * Usage:
 *   const sdk = new AgentScopeSDK({ privateKey, rpcUrl });
 *   await sdk.spend("0xRecipient", "0.01");
 *   await sdk.createDeal("0xCounterparty", "build frontend", 2, 7);
 *   const score = await sdk.getTrustScore("0xAddress");
 */

import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  formatEther,
  keccak256,
  toHex,
  type Address,
  type Hash,
  type PublicClient,
  type WalletClient,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base } from "viem/chains";

import { CONTRACTS, RPC_URL } from "./config.js";

import ScopeTokenABI from "./abi/ScopeToken.json" assert { type: "json" };
import AgentScopeABI from "./abi/AgentScope.json" assert { type: "json" };
import DealEngineABI from "./abi/DealEngine.json" assert { type: "json" };
import TrustAnchorABI from "./abi/TrustAnchor.json" assert { type: "json" };

// --- Types ---

export interface AgentScopeConfig {
  privateKey: `0x${string}`;
  rpcUrl?: string;
}

export interface SpendScope {
  maxPerTx: bigint;
  maxPerDay: bigint;
  validUntil: number;
}

export interface ActionReceipt {
  agent: Address;
  target: Address;
  value: bigint;
  selector: string;
  timestamp: bigint;
  blockNumber: bigint;
  success: boolean;
}

export interface Deal {
  initiator: Address;
  counterparty: Address;
  amount: bigint;
  termsHash: Hash;
  deadline: bigint;
  status: number;
  milestoneCount: bigint;
  milestonesCompleted: bigint;
  createdAt: bigint;
}

export interface TrustProfile {
  positive: bigint;
  negative: bigint;
  total: bigint;
  erc8004Verified: boolean;
}

// --- SDK ---

export class AgentScopeSDK {
  public readonly address: Address;
  public readonly publicClient: PublicClient;
  public readonly walletClient: WalletClient;

  constructor(config: AgentScopeConfig) {
    const account = privateKeyToAccount(config.privateKey);
    this.address = account.address;

    this.publicClient = createPublicClient({
      chain: base,
      transport: http(config.rpcUrl || RPC_URL),
    });

    this.walletClient = createWalletClient({
      account,
      chain: base,
      transport: http(config.rpcUrl || RPC_URL),
    });
  }

  // ============================================================
  //                    SPENDING (Agents that Pay)
  // ============================================================

  /**
   * Spend ETH from the AgentScope vault within scoped limits.
   */
  async spend(to: Address, ethAmount: string): Promise<Hash> {
    const value = parseEther(ethAmount);
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.AgentScope,
      abi: AgentScopeABI,
      functionName: "spend",
      args: [to, value],
    });
    console.log(`[Beru] Spent ${ethAmount} ETH to ${to} | tx: ${hash}`);
    return hash;
  }

  /**
   * Interact with a contract through the AgentScope vault.
   */
  async interact(target: Address, value: string, data: `0x${string}`): Promise<Hash> {
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.AgentScope,
      abi: AgentScopeABI,
      functionName: "interact",
      args: [target, parseEther(value), data],
    });
    console.log(`[Beru] Interacted with ${target} | tx: ${hash}`);
    return hash;
  }

  /**
   * Get remaining daily budget for this agent.
   */
  async getRemainingBudget(): Promise<string> {
    const remaining = await this.publicClient.readContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "getRemainingDailyBudget",
      args: [this.address],
    }) as bigint;
    return formatEther(remaining);
  }

  /**
   * Get spend scope for this agent.
   */
  async getSpendScope(): Promise<SpendScope> {
    const scope = await this.publicClient.readContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "getSpendScope",
      args: [this.address],
    }) as any;
    return {
      maxPerTx: scope.maxPerTx,
      maxPerDay: scope.maxPerDay,
      validUntil: Number(scope.validUntil),
    };
  }

  /**
   * Check if this agent has a specific scope.
   */
  async hasScope(scopeId: number): Promise<boolean> {
    return await this.publicClient.readContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "hasScope",
      args: [this.address, BigInt(scopeId)],
    }) as boolean;
  }

  /**
   * Get action receipts for this agent.
   */
  async getReceipts(offset = 0, limit = 10): Promise<ActionReceipt[]> {
    return await this.publicClient.readContract({
      address: CONTRACTS.AgentScope,
      abi: AgentScopeABI,
      functionName: "getAgentReceipts",
      args: [this.address, BigInt(offset), BigInt(limit)],
    }) as ActionReceipt[];
  }

  /**
   * Get total receipt count for this agent.
   */
  async getReceiptCount(): Promise<number> {
    const count = await this.publicClient.readContract({
      address: CONTRACTS.AgentScope,
      abi: AgentScopeABI,
      functionName: "getAgentReceiptCount",
      args: [this.address],
    }) as bigint;
    return Number(count);
  }

  // ============================================================
  //                    DEALS (Agents that Cooperate)
  // ============================================================

  /**
   * Create an escrow deal with another agent.
   */
  async createDeal(
    counterparty: Address,
    terms: string,
    milestones: number,
    deadlineDays: number,
  ): Promise<{ hash: Hash; dealId: bigint }> {
    const termsHash = keccak256(toHex(terms));
    const deadline = BigInt(Math.floor(Date.now() / 1000) + deadlineDays * 86400);

    // For demo: we call createDeal with a small amount
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.DealEngine,
      abi: DealEngineABI,
      functionName: "createDeal",
      args: [counterparty, termsHash, BigInt(milestones), deadline],
      value: parseEther("0.001"), // Demo escrow amount
    });

    console.log(`[Beru] Deal created with ${counterparty} | ${milestones} milestones | tx: ${hash}`);

    // Get deal count to derive ID
    const dealCount = await this.publicClient.readContract({
      address: CONTRACTS.DealEngine,
      abi: DealEngineABI,
      functionName: "dealCount",
    }) as bigint;

    return { hash, dealId: dealCount - 1n };
  }

  /**
   * Accept a deal as counterparty.
   */
  async acceptDeal(dealId: bigint): Promise<Hash> {
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.DealEngine,
      abi: DealEngineABI,
      functionName: "acceptDeal",
      args: [dealId],
    });
    console.log(`[Beru] Accepted deal #${dealId} | tx: ${hash}`);
    return hash;
  }

  /**
   * Submit milestone evidence.
   */
  async submitMilestone(dealId: bigint, milestoneIndex: number, evidence: string): Promise<Hash> {
    const evidenceHash = keccak256(toHex(evidence));
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.DealEngine,
      abi: DealEngineABI,
      functionName: "submitMilestone",
      args: [dealId, BigInt(milestoneIndex), evidenceHash],
    });
    console.log(`[Beru] Submitted milestone #${milestoneIndex} for deal #${dealId} | tx: ${hash}`);
    return hash;
  }

  /**
   * Confirm a milestone (releases funds).
   */
  async confirmMilestone(dealId: bigint, milestoneIndex: number): Promise<Hash> {
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.DealEngine,
      abi: DealEngineABI,
      functionName: "confirmMilestone",
      args: [dealId, BigInt(milestoneIndex)],
    });
    console.log(`[Beru] Confirmed milestone #${milestoneIndex} for deal #${dealId} | tx: ${hash}`);
    return hash;
  }

  /**
   * Get deal details.
   */
  async getDeal(dealId: bigint): Promise<Deal> {
    return await this.publicClient.readContract({
      address: CONTRACTS.DealEngine,
      abi: DealEngineABI,
      functionName: "getDeal",
      args: [dealId],
    }) as Deal;
  }

  // ============================================================
  //                    TRUST (Agents that Trust)
  // ============================================================

  /**
   * Get trust score for an address.
   */
  async getTrustScore(subject: Address): Promise<number> {
    const score = await this.publicClient.readContract({
      address: CONTRACTS.TrustAnchor,
      abi: TrustAnchorABI,
      functionName: "trustScore",
      args: [subject],
    }) as bigint;
    return Number(score);
  }

  /**
   * Check if an address meets a minimum trust threshold.
   */
  async isTrusted(subject: Address, minScore: number): Promise<boolean> {
    return await this.publicClient.readContract({
      address: CONTRACTS.TrustAnchor,
      abi: TrustAnchorABI,
      functionName: "isTrusted",
      args: [subject, BigInt(minScore)],
    }) as boolean;
  }

  /**
   * Record an attestation about a counterparty.
   */
  async attest(
    subject: Address,
    outcome: "positive" | "neutral" | "negative",
    evidence: string,
  ): Promise<Hash> {
    const outcomeMap = { positive: 0, neutral: 1, negative: 2 };
    const evidenceHash = keccak256(toHex(evidence));
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.TrustAnchor,
      abi: TrustAnchorABI,
      functionName: "attest",
      args: [subject, outcomeMap[outcome], evidenceHash],
    });
    console.log(`[Beru] Attested ${outcome} for ${subject} | tx: ${hash}`);
    return hash;
  }

  /**
   * Get trust profile for an address.
   */
  async getTrustProfile(subject: Address): Promise<TrustProfile> {
    return await this.publicClient.readContract({
      address: CONTRACTS.TrustAnchor,
      abi: TrustAnchorABI,
      functionName: "getProfile",
      args: [subject],
    }) as TrustProfile;
  }

  // ============================================================
  //                    OWNER FUNCTIONS
  // ============================================================

  /**
   * Register an agent (owner only).
   */
  async registerAgent(agent: Address, name: string): Promise<Hash> {
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.AgentScope,
      abi: AgentScopeABI,
      functionName: "registerAgent",
      args: [agent, name],
    });
    console.log(`[Owner] Registered agent ${name} (${agent}) | tx: ${hash}`);
    return hash;
  }

  /**
   * Grant spending scope to an agent (owner only).
   */
  async grantSpendScope(
    agent: Address,
    maxPerTxEth: string,
    maxPerDayEth: string,
    validForSeconds: number = 0,
  ): Promise<Hash> {
    const validUntil = validForSeconds > 0
      ? Math.floor(Date.now() / 1000) + validForSeconds
      : 0;

    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "grantSpendScope",
      args: [agent, parseEther(maxPerTxEth), parseEther(maxPerDayEth), validUntil],
    });
    console.log(`[Owner] Granted spend scope to ${agent}: ${maxPerTxEth}/tx, ${maxPerDayEth}/day | tx: ${hash}`);
    return hash;
  }

  /**
   * Grant deal scope to an agent (owner only).
   */
  async grantDealScope(
    agent: Address,
    maxEscrowEth: string,
    maxDeals: number,
    validForSeconds: number = 0,
  ): Promise<Hash> {
    const validUntil = validForSeconds > 0
      ? Math.floor(Date.now() / 1000) + validForSeconds
      : 0;

    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "grantDealScope",
      args: [agent, parseEther(maxEscrowEth), BigInt(maxDeals), validUntil],
    });
    console.log(`[Owner] Granted deal scope to ${agent} | tx: ${hash}`);
    return hash;
  }

  /**
   * Grant attest scope to an agent (owner only).
   */
  async grantAttestScope(agent: Address): Promise<Hash> {
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "grantAttestScope",
      args: [agent],
    });
    console.log(`[Owner] Granted attest scope to ${agent} | tx: ${hash}`);
    return hash;
  }

  /**
   * Revoke all scopes from an agent (owner only).
   */
  async revokeAll(agent: Address): Promise<Hash> {
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.ScopeToken,
      abi: ScopeTokenABI,
      functionName: "revokeAll",
      args: [agent],
    });
    console.log(`[Owner] Revoked all scopes from ${agent} | tx: ${hash}`);
    return hash;
  }

  /**
   * Verify an address as ERC-8004 registered (owner only).
   */
  async verifyERC8004(subject: Address): Promise<Hash> {
    const hash = await this.walletClient.writeContract({
      address: CONTRACTS.TrustAnchor,
      abi: TrustAnchorABI,
      functionName: "verifyERC8004",
      args: [subject],
    });
    console.log(`[Owner] Verified ERC-8004 for ${subject} | tx: ${hash}`);
    return hash;
  }

  // ============================================================
  //                    UTILITIES
  // ============================================================

  /**
   * Get vault balance.
   */
  async getVaultBalance(): Promise<string> {
    const balance = await this.publicClient.getBalance({
      address: CONTRACTS.AgentScope,
    });
    return formatEther(balance);
  }

  /**
   * Get agent's own balance.
   */
  async getBalance(): Promise<string> {
    const balance = await this.publicClient.getBalance({
      address: this.address,
    });
    return formatEther(balance);
  }

  /**
   * Print agent status.
   */
  async status(): Promise<void> {
    const balance = await this.getBalance();
    const vaultBalance = await this.getVaultBalance();
    const hasSpend = await this.hasScope(1);
    const hasDeal = await this.hasScope(3);
    const hasAttest = await this.hasScope(4);

    console.log("\n=== Beru Agent Status ===");
    console.log(`Address:       ${this.address}`);
    console.log(`Balance:       ${balance} ETH`);
    console.log(`Vault Balance: ${vaultBalance} ETH`);
    console.log(`Scopes:`);
    console.log(`  SPEND:    ${hasSpend ? "GRANTED" : "NONE"}`);
    console.log(`  DEAL:     ${hasDeal ? "GRANTED" : "NONE"}`);
    console.log(`  ATTEST:   ${hasAttest ? "GRANTED" : "NONE"}`);

    if (hasSpend) {
      const remaining = await this.getRemainingBudget();
      console.log(`  Remaining Daily Budget: ${remaining} ETH`);
    }

    const receiptCount = await this.getReceiptCount();
    console.log(`Receipts:      ${receiptCount} onchain actions recorded`);
    console.log("=========================\n");
  }
}
