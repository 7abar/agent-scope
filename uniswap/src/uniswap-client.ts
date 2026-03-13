/**
 * Uniswap Trading API Client
 * Uses the official Uniswap Developer Platform API for quotes and swaps.
 * 
 * API docs: https://api-docs.uniswap.org
 * Base URL: https://trade-api.gateway.uniswap.org/v1
 */

const API_BASE = "https://trade-api.gateway.uniswap.org/v1";

export interface UniswapConfig {
  apiKey: string;
}

export interface QuoteRequest {
  swapper: string;
  tokenIn: string;
  tokenOut: string;
  amount: string;
  tokenInChainId: number;
  tokenOutChainId: number;
  type: "EXACT_INPUT" | "EXACT_OUTPUT";
  protocols?: string[];
  slippageTolerance?: string;
}

export interface QuoteResponse {
  quote: any;
  routing: "CLASSIC" | "DUTCH_V2" | "DUTCH_V3" | "PRIORITY" | "WRAP" | "UNWRAP" | "BRIDGE";
  permitData?: {
    domain: any;
    types: any;
    values: any;
  };
}

export interface ApprovalRequest {
  walletAddress: string;
  token: string;
  amount: string;
  chainId: number;
  tokenOut?: string;
  tokenOutChainId?: number;
}

export interface SwapRequest {
  quote: any;
  signature?: string;
  permitData?: any;
  simulateTransaction?: boolean;
}

export interface SwapResponse {
  swap: {
    to: string;
    data: string;
    value: string;
    gasLimit?: string;
  };
  gasFee?: string;
}

export class UniswapClient {
  private headers: Record<string, string>;

  constructor(config: UniswapConfig) {
    this.headers = {
      "x-api-key": config.apiKey,
      "accept": "application/json",
      "content-type": "application/json",
    };
  }

  /**
   * Check if wallet has Permit2 approval for the token.
   * Returns approval tx if needed, null if already approved.
   */
  async checkApproval(params: ApprovalRequest): Promise<{ approval?: any }> {
    const res = await fetch(`${API_BASE}/check_approval`, {
      method: "POST",
      headers: this.headers,
      body: JSON.stringify(params),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Uniswap check_approval failed (${res.status}): ${err}`);
    }

    return res.json();
  }

  /**
   * Get a swap quote from Uniswap's routing engine.
   * Returns the optimal route (Classic or UniswapX) and permit data if needed.
   */
  async getQuote(params: QuoteRequest): Promise<QuoteResponse> {
    const res = await fetch(`${API_BASE}/quote`, {
      method: "POST",
      headers: this.headers,
      body: JSON.stringify({
        ...params,
        protocols: params.protocols || ["V2", "V3", "V4"],
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Uniswap quote failed (${res.status}): ${err}`);
    }

    return res.json();
  }

  /**
   * Submit a swap (gasful, classic routing).
   */
  async createSwap(params: SwapRequest): Promise<SwapResponse> {
    const res = await fetch(`${API_BASE}/swap`, {
      method: "POST",
      headers: this.headers,
      body: JSON.stringify(params),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Uniswap swap failed (${res.status}): ${err}`);
    }

    return res.json();
  }

  /**
   * Submit a gasless UniswapX order.
   */
  async createOrder(params: { quote: any; signature: string }): Promise<any> {
    const res = await fetch(`${API_BASE}/order`, {
      method: "POST",
      headers: this.headers,
      body: JSON.stringify(params),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Uniswap order failed (${res.status}): ${err}`);
    }

    return res.json();
  }
}
