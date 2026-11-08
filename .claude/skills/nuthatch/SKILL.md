---
name: nuthatch
description: Query this self-hosted nuthatch nest on mainnet - decoded events, balances, and read-only SQL. Use when asked about on-chain activity for these contracts.
---

# Querying the nuthatch nest

Contracts indexed on mainnet:
- `aave` = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2
- `aave_prime` = 0x4e033931ad43597d96D6bcc25c280717730B58B1
- `aave_etherfi` = 0x0AA97c284e98396202b6A04024F5E2c65026F3c0
- `spark` = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987
- `comet_usdc` = 0xc3d688B66703497DAA19211EEdff47f25384cdc3
- `comet_weth` = 0xA17581A9E3356d9A858b789D68B4d866e593aE94
- `comet_usds` = 0x5D409e56D886231aDAf00c8775665AD0f9897b56
- `comet_wsteth` = 0x3D0bb1ccaB520A66e607822fC55BC921738fAFE3
- `morpho` = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
- `maker` = 0x135954d155898D42C90D2a57824C690e0c7BEf1B
- `liquity` = 0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2
- `eth_usd_p5` = 0x37bC7498f4FF12C19678ee8fE19d713b87F6a9e6
- `eth_usd_p6` = 0xE62B71cf983019BFf55bC83B48601ce8419650CC
- `eth_usd_p7` = 0x7d4E742018fb52E48b08BE73d041C18B21de6Fb5
- `btc_usd_p5` = 0xAe74faA92cB67A95ebCAB07358bC222e33A34dA7
- `btc_usd_p6` = 0xdBe1941BFbe4410D6865b9b7078e0b49af144D2d
- `btc_usd_p7` = 0x4a3411ac2948B33c69666B35cc6d055B27Ea84f1

Data is local - never call an external API for it.

## Preferred: MCP
If a `nuthatch` MCP server is configured, use its tools. Call `schema` first to learn the
data model, then `sql` / `entity` / `balance` / `top_balances`.

## Fallback: HTTP (a `nuthatch dev` must be running)
- Recent rows:  `curl localhost:8288/entities?limit=20`
- Read-only SQL: `curl -G localhost:8288/sql --data-urlencode 'q=SELECT count(*) FROM aave__liquidation_call'`

`sql` reads hot and sealed rows together, so it covers the live tip. Each answer's
`provenance.sealed_through` is the block through which this nest has sealed history; newer rows
may still be hot, and it is not the chain's finality head.
