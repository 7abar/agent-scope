/**
 * AgentScope Protocol -- Deployment Configuration
 * Base Mainnet (v2 -- bug-fixed)
 */
export const CONTRACTS = {
  ScopeToken: "0xCef94f8f4f6f875C016c246EDfACDE8c0578D580" as const,
  AgentScope: "0x29Ff65DBA69Af3edEBC0570a7cd7f1000B66e1BA" as const,
  DealEngine: "0x377f2788a6A96064dF572a1A582717799d4023D6" as const,
  TrustAnchor: "0x07BD306226B598834D1d5C14C11575B5D196a885" as const,
} as const;

export const CHAIN_ID = 8453;
export const RPC_URL = "https://mainnet.base.org";
export const OWNER = "0x2012F75004C6e889405D078780AB41AE8606b85b" as const;
