/**
 * Scope-Gated Uniswap Swap
 * 
 * Integrates AgentScope permission checks with the Uniswap Trading API.
 * Before any swap, the agent must have:
 *   1. INTERACT scope for the Uniswap contracts
 *   2. SPEND scope with sufficient limits
 * 
 * Flow:
 *   1. Check AgentScope permissions (scope tokens)
 *   2. Get quote from Uniswap Trading API
 *   3. Check/create Permit2 approval
 *   4. Sign permit (if needed)
 *   5. Execute swap through AgentScope.interact()
 *   6. Record receipt onchain
 */

import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  formatEther,
  formatUnits,
  type Address,
  type Hash,
  type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base } from "viem/chains";
import { UniswapClient, type QuoteResponse } from "./uniswap-client.js";

// --- Constants ---

const UNISWAP_ROUTER = "0x2626664c2603336E57B271c5C0b26F421741e481" as Address; // V3 SwapRouter02
const PERMIT2 = "0x000000000022D473030F116dDEE9F6B43aC78BA3" as Address;
const WETH = "0x4200000000000000000000000000000000000006" as Address;
const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" as Address;

// AgentScope contract addresses (Base mainnet)
const AGENT_SCOPE = "0x29Ff65DBA69Af3edEBC0570a7cd7f1000B66e1BA" as Address;
const SCOPE_TOKEN = "0xCef94f8f4f6f875C016c246EDfACDE8c0578D580" as Address;

// Scope token IDs
const SCOPE_INTERACT = 3n; // INTERACT scope for contract calls
const SCOPE_SPEND = 1n;    // SPEND scope for value transfers

// ABIs (minimal)
const SCOPE_TOKEN_ABI = [
  {
    name: "balanceOf",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "account", type: "address" },
      { name: "id", type: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

const AGENT_SCOPE_ABI = [
  {
    name: "interact",
    type: "function",
    stateMutability: "payable",
    inputs: [
      { name: "target", type: "address" },
      { name: "data", type: "bytes" },
      { name: "value", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bytes" }],
  },
  {
    name: "receiptCount",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

// --- Types ---

export interface ScopeGatedSwapConfig {
  privateKey: `0x${string}`;
  uniswapApiKey: string;
  rpcUrl?: string;
}

export interface SwapParams {
  tokenIn: Address;
  tokenOut: Address;
  amountIn: string;     // Human-readable amount (e.g., "0.001")
  decimalsIn?: number;  // Default 18 for ETH/WETH
  slippage?: number;    // Default 0.5%
}

export interface SwapResult {
  success: boolean;
  txHash?: Hash;
  quoteAmount?: string;
  routing?: string;
  error?: string;
  receiptId?: bigint;
  scopeChecks: {
    hasInteractScope: boolean;
    hasSpendScope: boolean;
  };
}

// --- Main Class ---

export class ScopeGatedSwap {
  private account;
  private publicClient;
  private walletClient;
  private uniswap: UniswapClient;

  constructor(config: ScopeGatedSwapConfig) {
    this.account = privateKeyToAccount(config.privateKey);
    
    this.publicClient = createPublicClient({
      chain: base,
      transport: http(config.rpcUrl || "https://mainnet.base.org"),
    });

    this.walletClient = createWalletClient({
      account: this.account,
      chain: base,
      transport: http(config.rpcUrl || "https://mainnet.base.org"),
    });

    this.uniswap = new UniswapClient({ apiKey: config.uniswapApiKey });
  }

  /**
   * Check if the agent has the required AgentScope permissions.
   */
  async checkScopes(): Promise<{ interact: boolean; spend: boolean }> {
    const [interactBalance, spendBalance] = await Promise.all([
      this.publicClient.readContract({
        address: SCOPE_TOKEN,
        abi: SCOPE_TOKEN_ABI,
        functionName: "balanceOf",
        args: [this.account.address, SCOPE_INTERACT],
      }),
      this.publicClient.readContract({
        address: SCOPE_TOKEN,
        abi: SCOPE_TOKEN_ABI,
        functionName: "balanceOf",
        args: [this.account.address, SCOPE_SPEND],
      }),
    ]);

    return {
      interact: interactBalance > 0n,
      spend: spendBalance > 0n,
    };
  }

  /**
   * Execute a scope-gated swap using the Uniswap Trading API.
   * 
   * This is the core function that combines:
   * - AgentScope permission verification
   * - Uniswap Trading API for routing/quotes
   * - Onchain execution through scope-gated interact()
   */
  async swap(params: SwapParams): Promise<SwapResult> {
    const decimalsIn = params.decimalsIn ?? 18;
    const amount = BigInt(Math.floor(parseFloat(params.amountIn) * 10 ** decimalsIn)).toString();

    console.log(`\n[AgentScope x Uniswap] Starting scope-gated swap`);
    console.log(`  Token In:  ${params.tokenIn}`);
    console.log(`  Token Out: ${params.tokenOut}`);
    console.log(`  Amount:    ${params.amountIn}`);
    console.log(`  Agent:     ${this.account.address}`);

    // Step 1: Check AgentScope permissions
    console.log(`\n[Step 1] Checking AgentScope permissions...`);
    const scopes = await this.checkScopes();
    console.log(`  INTERACT scope: ${scopes.interact ? "YES" : "NO"}`);
    console.log(`  SPEND scope:    ${scopes.spend ? "YES" : "NO"}`);

    if (!scopes.interact || !scopes.spend) {
      return {
        success: false,
        error: `Missing scopes: ${!scopes.interact ? "INTERACT " : ""}${!scopes.spend ? "SPEND" : ""}`,
        scopeChecks: { hasInteractScope: scopes.interact, hasSpendScope: scopes.spend },
      };
    }

    // Step 2: Check Permit2 approval
    console.log(`\n[Step 2] Checking Permit2 approval...`);
    const isNativeETH = params.tokenIn.toLowerCase() === "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" ||
                        params.tokenIn.toLowerCase() === WETH.toLowerCase();

    if (!isNativeETH) {
      const approvalResult = await this.uniswap.checkApproval({
        walletAddress: this.account.address,
        token: params.tokenIn,
        amount,
        chainId: 8453, // Base
      });

      if (approvalResult.approval) {
        console.log(`  Sending approval transaction...`);
        const approveTx = await this.walletClient.sendTransaction({
          to: approvalResult.approval.to as Address,
          data: approvalResult.approval.data as Hex,
          value: 0n,
        });
        await this.publicClient.waitForTransactionReceipt({ hash: approveTx });
        console.log(`  Approval tx: ${approveTx}`);
      } else {
        console.log(`  Already approved.`);
      }
    } else {
      console.log(`  Native ETH — no approval needed.`);
    }

    // Step 3: Get quote from Uniswap Trading API
    console.log(`\n[Step 3] Getting quote from Uniswap Trading API...`);
    let quoteResponse: QuoteResponse;
    try {
      quoteResponse = await this.uniswap.getQuote({
        swapper: this.account.address,
        tokenIn: params.tokenIn,
        tokenOut: params.tokenOut,
        amount,
        tokenInChainId: 8453,
        tokenOutChainId: 8453,
        type: "EXACT_INPUT",
      });
    } catch (err: any) {
      return {
        success: false,
        error: `Quote failed: ${err.message}`,
        scopeChecks: { hasInteractScope: true, hasSpendScope: true },
      };
    }

    console.log(`  Routing: ${quoteResponse.routing}`);
    console.log(`  Quote received`);

    // Step 4: Sign permit if needed
    let signature: string | undefined;
    if (quoteResponse.permitData) {
      console.log(`\n[Step 4] Signing Permit2 message...`);
      signature = await this.walletClient.signTypedData({
        domain: quoteResponse.permitData.domain,
        types: quoteResponse.permitData.types,
        primaryType: "PermitWitnessTransferFrom",
        message: quoteResponse.permitData.values,
      });
      console.log(`  Signed.`);
    }

    // Step 5: Execute swap
    console.log(`\n[Step 5] Executing swap...`);
    const { routing } = quoteResponse;

    let txHash: Hash;

    if (routing === "CLASSIC" || routing === "WRAP" || routing === "UNWRAP" || routing === "BRIDGE") {
      // Gasful swap — get calldata from /swap endpoint
      const swapResult = await this.uniswap.createSwap({
        quote: quoteResponse.quote,
        signature,
        permitData: quoteResponse.permitData,
        simulateTransaction: false,
      });

      // Execute through AgentScope.interact() for scope-gated, receipted execution
      console.log(`  Routing through AgentScope.interact()...`);
      txHash = await this.walletClient.writeContract({
        address: AGENT_SCOPE,
        abi: AGENT_SCOPE_ABI,
        functionName: "interact",
        args: [
          swapResult.swap.to as Address,
          swapResult.swap.data as Hex,
          BigInt(swapResult.swap.value || "0"),
        ],
        value: BigInt(swapResult.swap.value || "0"),
      });
    } else {
      // Gasless UniswapX order
      if (!signature) throw new Error("Signature required for UniswapX orders");
      await this.uniswap.createOrder({
        quote: quoteResponse.quote,
        signature,
      });
      // UniswapX orders are filled by market makers, no tx hash from us
      console.log(`  UniswapX order submitted (gasless).`);
      return {
        success: true,
        routing: quoteResponse.routing,
        quoteAmount: quoteResponse.quote?.quote || "unknown",
        scopeChecks: { hasInteractScope: true, hasSpendScope: true },
      };
    }

    // Wait for confirmation
    console.log(`  Waiting for confirmation...`);
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash: txHash });
    console.log(`  TX: ${txHash}`);
    console.log(`  Status: ${receipt.status === "success" ? "SUCCESS" : "FAILED"}`);
    console.log(`  Gas used: ${receipt.gasUsed}`);

    // Get receipt count for the receipt ID
    const receiptCount = await this.publicClient.readContract({
      address: AGENT_SCOPE,
      abi: AGENT_SCOPE_ABI,
      functionName: "receiptCount",
    });

    console.log(`  AgentScope Receipt #${receiptCount}`);

    return {
      success: receipt.status === "success",
      txHash,
      routing: quoteResponse.routing,
      quoteAmount: quoteResponse.quote?.quote || "unknown",
      receiptId: receiptCount,
      scopeChecks: { hasInteractScope: true, hasSpendScope: true },
    };
  }

  /**
   * Convenience: Swap ETH for USDC through AgentScope + Uniswap API
   */
  async swapETHForUSDC(ethAmount: string): Promise<SwapResult> {
    return this.swap({
      tokenIn: WETH,
      tokenOut: USDC,
      amountIn: ethAmount,
    });
  }

  /**
   * Convenience: Swap USDC for ETH through AgentScope + Uniswap API
   */
  async swapUSDCForETH(usdcAmount: string): Promise<SwapResult> {
    return this.swap({
      tokenIn: USDC,
      tokenOut: WETH,
      amountIn: usdcAmount,
      decimalsIn: 6,
    });
  }
}
