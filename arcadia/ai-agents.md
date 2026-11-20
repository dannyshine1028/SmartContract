> For the complete documentation index, see [llms.txt](https://docs.arcadia.finance/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://docs.arcadia.finance/developers/integrations/ai-agents.md).

# For AI Agents

Integration guide for AI agents interacting with Arcadia Protocol: chain deployments, key contract addresses, common read operations, account queries, and programmatic docs access via llms.txt.

This page provides a structured reference for AI agents, bots, and automated systems that need to interact with Arcadia Protocol programmatically.

## Chain Deployments

| Chain     | Chain ID | Block Explorer                                             |
| --------- | -------- | ---------------------------------------------------------- |
| Base      | 8453     | [basescan.org](https://basescan.org)                       |
| Optimism  | 10       | [optimistic.etherscan.io](https://optimistic.etherscan.io) |
| Unichain  | 130      | [uniscan.xyz](https://uniscan.xyz)                         |
| Robinhood | 4663     | [robin.etherscan.io](https://robin.etherscan.io)           |

The core protocol contracts (Factory, Registry, Liquidator) share the same addresses across chains.

## Key Contract Addresses

These are the most commonly needed addresses for programmatic interaction. For the full list, see [Contract Addresses](/developers/contract-addresses.md).

| Contract          | Address                                      | Purpose                                                 |
| ----------------- | -------------------------------------------- | ------------------------------------------------------- |
| Factory           | `0xDa14Fdd72345c4d2511357214c5B89A919768e59` | Creates and manages Arcadia Accounts (ERC721)           |
| Registry          | `0xd0690557600eb8Be8391D1d97346e2aab5300d5f` | Asset/oracle module coordination, pricing orchestration |
| Liquidator        | `0xA4B0b9fD1d91fA2De44F6ABFd59cC14bA1E1a7Af` | Dutch auctions for unhealthy account liquidation        |
| LendingPool WETH  | `0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2` | WETH lending pool                                       |
| LendingPool USDC  | `0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1` | USDC lending pool                                       |
| LendingPool cbBTC | `0xa37E9b4369dc20940009030BfbC2088F09645e3B` | cbBTC lending pool                                      |

## Common Tokens (Base)

| Token            | Address                                      | Decimals |
| ---------------- | -------------------------------------------- | -------- |
| WETH             | `0x4200000000000000000000000000000000000006` | 18       |
| USDC             | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | 6        |
| cbBTC            | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | 8        |
| AERO (Aerodrome) | `0x940181a94A35A4569E4529A3CDfB74e38FD98631` | 18       |
| AERO (Aero)      | `0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee` | 18       |
| AAA              | `0xaaa843fb2916c0B57454270418E121C626402AAa` | 18       |
| stAAA            | `0xDeA1531d8a1505785eb517C7A28526443df223F3` | 18       |

## Common Read Operations

### Get total number of accounts

```solidity
Factory(0xDa14...8e59).allAccountsLength() → uint256
```

### Get account address by index

```solidity
Factory(0xDa14...8e59).allAccounts(uint256 index) → address
```

### Get account owner

```solidity
Factory(0xDa14...8e59).ownerOf(uint256 accountId) → address
```

### Check if an account is liquidatable

```solidity
AccountV1(accountAddress).isAccountLiquidatable() → bool
```

### Get account health (liquidation value vs used margin)

```solidity
AccountV1(accountAddress).getLiquidationValue() → uint256
AccountV1(accountAddress).getUsedMargin() → uint256
```

A healthy account has `liquidationValue > usedMargin`.

### Get account assets

```solidity
AccountV1(accountAddress).generateAssetData() → (address[] assets, uint256[] assetIds, uint256[] assetAmounts)
```

### Get asset value in a numeraire

```solidity
Registry(0xd069...d5f).getTotalValue(address numeraire, address creditor, address[] assets, uint256[] assetIds, uint256[] assetAmounts) → uint256
```

## Arcadia API

The Arcadia REST API provides off-chain data for accounts, pools, and asset prices. Base URL: `https://api.arcadia.finance/v1/api`

| Endpoint                                   | Description               |
| ------------------------------------------ | ------------------------- |
| `GET /pools?chain_id=8453`                 | List all lending pools    |
| `GET /assets?chain_id=8453`                | List all supported assets |
| `GET /price?chain_id=8453&asset=<address>` | Get asset price           |
| `GET /accounts?chain_id=8453`              | List all accounts         |

No API key is required.

## Programmatic Docs Access

The full documentation is available in machine-readable format:

* **Structured summary**: [docs.arcadia.finance/llms.txt](https://docs.arcadia.finance/llms.txt)
* **Full content**: [docs.arcadia.finance/llms-full.txt](https://docs.arcadia.finance/llms-full.txt)

## MCP Server

The [Arcadia MCP Server](/developers/integrations/mcp-server.md) lets AI agents interact with the protocol through the Model Context Protocol. It provides tools to read account data, pool stats, and strategies, and to build unsigned transactions for deposits, borrowing, liquidity management, and more. See the [MCP Server](/developers/integrations/mcp-server.md) page for setup instructions and the full tool reference.

## Source Code

| Repository                                                                       | Description                                                            |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| [accounts-v2](https://github.com/arcadia-finance/accounts-v2)                    | Account contracts, Registry, Asset Modules, Oracle Modules             |
| [lending-v2](https://github.com/arcadia-finance/lending-v2)                      | Lending Pools, Tranches, Liquidator                                    |
| [asset-managers](https://github.com/arcadia-finance/asset-managers)              | Compounders, Rebalancers, Yield Claimers, CoW Swapper, Merkl Operators |
| [mcp-server](https://github.com/arcadia-finance/mcp-server)                      | MCP Server for AI agent integration                                    |
| [whitepapers](https://github.com/arcadia-finance/whitepapers/blob/main/main.pdf) | Protocol whitepaper                                                    |
