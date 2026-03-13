import { describe, it, expect, vi, beforeEach } from "vitest";
import { UniswapClient } from "./uniswap-client.js";

const MOCK_API_KEY = "test-api-key";

describe("UniswapClient", () => {
  let client: UniswapClient;

  beforeEach(() => {
    client = new UniswapClient({ apiKey: MOCK_API_KEY });
  });

  it("should initialize with API key", () => {
    expect(client).toBeDefined();
  });

  it("should call /check_approval with correct params", async () => {
    const mockResponse = { approval: null };
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(mockResponse),
    });

    const result = await client.checkApproval({
      walletAddress: "0x1234567890123456789012345678901234567890",
      token: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      amount: "1000000",
      chainId: 8453,
    });

    expect(result.approval).toBeNull();
    expect(fetch).toHaveBeenCalledWith(
      "https://trade-api.gateway.uniswap.org/v1/check_approval",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          "x-api-key": MOCK_API_KEY,
        }),
      })
    );
  });

  it("should call /quote with correct params", async () => {
    const mockQuote = {
      quote: { input: {}, output: {} },
      routing: "CLASSIC",
      permitData: null,
    };

    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(mockQuote),
    });

    const result = await client.getQuote({
      swapper: "0x1234567890123456789012345678901234567890",
      tokenIn: "0x4200000000000000000000000000000000000006",
      tokenOut: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      amount: "100000000000000",
      tokenInChainId: 8453,
      tokenOutChainId: 8453,
      type: "EXACT_INPUT",
    });

    expect(result.routing).toBe("CLASSIC");
    const fetchCall = vi.mocked(fetch).mock.calls[0];
    const body = JSON.parse(fetchCall[1]!.body as string);
    expect(body.protocols).toEqual(["V2", "V3", "V4"]);
  });

  it("should call /swap for classic routing", async () => {
    const mockSwap = {
      swap: {
        to: "0x2626664c2603336E57B271c5C0b26F421741e481",
        data: "0xabcdef",
        value: "100000000000000",
      },
    };

    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(mockSwap),
    });

    const result = await client.createSwap({
      quote: { routing: "CLASSIC" },
      signature: "0xsignature",
    });

    expect(result.swap.to).toBe("0x2626664c2603336E57B271c5C0b26F421741e481");
  });

  it("should throw on API error", async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: () => Promise.resolve("Unauthorized"),
    });

    await expect(
      client.getQuote({
        swapper: "0x1234",
        tokenIn: "0x4200",
        tokenOut: "0x8335",
        amount: "100",
        tokenInChainId: 8453,
        tokenOutChainId: 8453,
        type: "EXACT_INPUT",
      })
    ).rejects.toThrow("Uniswap quote failed (401)");
  });

  it("should call /order for UniswapX routing", async () => {
    const mockOrder = { orderId: "test-order-123" };
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(mockOrder),
    });

    const result = await client.createOrder({
      quote: { routing: "DUTCH_V2" },
      signature: "0xsig",
    });

    expect(result.orderId).toBe("test-order-123");
    expect(fetch).toHaveBeenCalledWith(
      "https://trade-api.gateway.uniswap.org/v1/order",
      expect.anything()
    );
  });
});
