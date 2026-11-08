# liquidations

Every lending liquidation on Ethereum mainnet since 1 January 2023, in one table: Aave v3 (Core, Prime,
EtherFi), Spark, Compound v3 (USDC, WETH, USDS, wstETH), Morpho Blue, Sky (Maker) and Liquity v1. It is
the nest behind [nuthatch-indexer.com/analytics](https://nuthatch-indexer.com/analytics/).

```sh
nuthatch init --from https://github.com/nuthatch-org/liquidations-nest
nuthatch dev --dir liquidations-nest --rpc $YOUR_RPC
nuthatch sql "SELECT protocol, count(*), sum(debt_usd) FROM liquidations GROUP BY 1"
```

## What is in it

- `abis/`: event-only ABIs, written by hand, so decoding does not depend on a proxy's current
  implementation.
- `views/10-assets.sql`: every token seen in a liquidation, with the symbol and decimals it reports.
  Pricing is by address, never by symbol: Morpho markets are permissionless, and more than one token
  here calls itself USDC.
- `views/20-prices.sql`: Chainlink ETH/USD and BTC/USD closes per hour, read from each feed's phase
  aggregators, since the proxies emit nothing.
- `views/30-liquidations.sql`: `liquidations`, one row per liquidation across all six protocols.
- `queries.toml`: the two declared queries a public deployment answers.

## What it does not do

- `debt_usd` prices the debt repaid at that hour's Chainlink close, or at a dollar for a stablecoin.
  Anything else is NULL rather than guessed.
- A Sky row is an auction opened by `Bark`; its debt is what the auction set out to cover.
- `liquidator` is NULL where the event does not name one (Sky, Liquity).
- A Morpho market's tokens come from its `CreateMarket`. A `--backfill` that starts after a market was
  created leaves that market's rows unpriced; index from the start block for full coverage.
