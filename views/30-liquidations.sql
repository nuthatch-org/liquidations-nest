-- Every liquidation, one row per event, in one shape across six protocols. Amounts are in token
-- units; debt_usd is the debt repaid, priced at that hour's Chainlink close or at a dollar for a
-- stablecoin, and NULL when the debt asset is neither. liquidator is NULL where the event does not
-- name one (Sky's Bark and Liquity's TroveLiquidated).

CREATE VIEW maker_ilks AS
SELECT * FROM (VALUES
  ('0x4554482d41000000000000000000000000000000000000000000000000000000', 'ETH-A', 'ETH'),
  ('0x4554482d42000000000000000000000000000000000000000000000000000000', 'ETH-B', 'ETH'),
  ('0x4554482d43000000000000000000000000000000000000000000000000000000', 'ETH-C', 'ETH'),
  ('0x555344432d410000000000000000000000000000000000000000000000000000', 'USDC-A', 'USDC'),
  ('0x524554482d410000000000000000000000000000000000000000000000000000', 'RETH-A', 'rETH'),
  ('0x4c494e4b2d410000000000000000000000000000000000000000000000000000', 'LINK-A', 'LINK'),
  ('0x5753544554482d41000000000000000000000000000000000000000000000000', 'WSTETH-A', 'wstETH'),
  ('0x5753544554482d42000000000000000000000000000000000000000000000000', 'WSTETH-B', 'wstETH'),
  ('0x554e495632444149555344432d41000000000000000000000000000000000000', 'UNIV2DAIUSDC-A', 'UNI-V2 DAI/USDC'),
  ('0x574254432d410000000000000000000000000000000000000000000000000000', 'WBTC-A', 'WBTC'),
  ('0x574254432d420000000000000000000000000000000000000000000000000000', 'WBTC-B', 'WBTC'),
  ('0x574254432d430000000000000000000000000000000000000000000000000000', 'WBTC-C', 'WBTC'),
  ('0x475553442d410000000000000000000000000000000000000000000000000000', 'GUSD-A', 'GUSD'),
  ('0x554e495632555344434554482d41000000000000000000000000000000000000', 'UNIV2USDCETH-A', 'UNI-V2 USDC/ETH'),
  ('0x4d415449432d4100000000000000000000000000000000000000000000000000', 'MATIC-A', 'MATIC'),
  ('0x4c53452d4d4b522d410000000000000000000000000000000000000000000000', 'LSE-MKR-A', 'MKR'),
  ('0x435256563145544853544554482d410000000000000000000000000000000000', 'CRVV1ETHSTETH-A', 'Curve stETH LP'),
  ('0x5041585553442d41000000000000000000000000000000000000000000000000', 'PAXUSD-A', 'USDP'),
  ('0x47554e49563344414955534443312d4100000000000000000000000000000000', 'GUNIV3DAIUSDC1-A', 'G-UNI DAI/USDC'),
  ('0x47554e49563344414955534443322d4100000000000000000000000000000000', 'GUNIV3DAIUSDC2-A', 'G-UNI DAI/USDC')
) AS t(ilk, name, collateral);

CREATE VIEW comet_markets AS
SELECT * FROM (VALUES
  ('0xc3d688b66703497daa19211eedff47f25384cdc3', 'cUSDCv3', '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'),
  ('0xa17581a9e3356d9a858b789d68b4d866e593ae94', 'cWETHv3', '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'),
  ('0x5d409e56d886231adaf00c8775665ad0f9897b56', 'cUSDSv3', '0xdc035d45d973e3ec169d2276ddab16f1e407384f'),
  ('0x3d0bb1ccab520a66e607822fc55bc921738fafe3', 'cwstETHv3', '0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0')
) AS t(comet, market, base_asset);

CREATE VIEW liquidations_raw AS
-- Aave v3 and Spark share one event.
SELECT block_number, log_index, block_timestamp, tx_hash, 'Aave' AS protocol, 'Core' AS market,
       "user" AS borrower, liquidator, "collateralAsset" AS collateral_asset,
       CAST("liquidatedCollateralAmount" AS DOUBLE) AS collateral_raw,
       "debtAsset" AS debt_asset, CAST("debtToCover" AS DOUBLE) AS debt_raw,
       CAST(NULL AS DOUBLE) AS debt_usd_given, CAST(NULL AS VARCHAR) AS collateral_name, CAST(NULL AS VARCHAR) AS debt_name
FROM aave__liquidation_call
UNION ALL
SELECT block_number, log_index, block_timestamp, tx_hash, 'Aave', 'Prime', "user", liquidator, "collateralAsset",
       CAST("liquidatedCollateralAmount" AS DOUBLE), "debtAsset", CAST("debtToCover" AS DOUBLE), NULL, NULL, NULL
FROM aave_prime__liquidation_call
UNION ALL
SELECT block_number, log_index, block_timestamp, tx_hash, 'Aave', 'EtherFi', "user", liquidator, "collateralAsset",
       CAST("liquidatedCollateralAmount" AS DOUBLE), "debtAsset", CAST("debtToCover" AS DOUBLE), NULL, NULL, NULL
FROM aave_etherfi__liquidation_call
UNION ALL
SELECT block_number, log_index, block_timestamp, tx_hash, 'Spark', 'SparkLend', "user", liquidator, "collateralAsset",
       CAST("liquidatedCollateralAmount" AS DOUBLE), "debtAsset", CAST("debtToCover" AS DOUBLE), NULL, NULL, NULL
FROM spark__liquidation_call
UNION ALL
-- Morpho Blue: the market's tokens come from its CreateMarket, whose params arrive as a JSON string
-- of fixed shape, so each address sits at a fixed offset.
SELECT l.block_number, l.log_index, l.block_timestamp, l.tx_hash, 'Morpho', 'Blue', l.borrower, l.caller,
       substr(m."marketParams", 78, 42), CAST(l."seizedAssets" AS DOUBLE),
       substr(m."marketParams", 15, 42), CAST(l."repaidAssets" AS DOUBLE), NULL, NULL, NULL
FROM morpho__liquidate l
LEFT JOIN morpho__create_market m ON m.id = l.id
UNION ALL
-- Sky (Maker): Bark opens the auction for a vault. due is the debt in DAI at 45 decimals; ink the
-- collateral at 18, whatever the token.
SELECT b.block_number, b.log_index, b.block_timestamp, b.tx_hash, 'Sky', coalesce(i.name, b.ilk), b.urn, NULL,
       NULL, CAST(b.ink AS DOUBLE) / 1e18, '0x6b175474e89094c44da98b954eedeac495271d0f',
       CAST(b.due AS DOUBLE) / 1e27, CAST(b.due AS DOUBLE) / 1e45, coalesce(i.collateral, b.ilk), NULL
FROM maker__bark b
LEFT JOIN maker_ilks i ON i.ilk = b.ilk
UNION ALL
-- Liquity v1: ETH collateral, LUSD debt, both at 18 decimals.
SELECT block_number, log_index, block_timestamp, tx_hash, 'Liquity', 'v1', "_borrower", NULL,
       '0x0000000000000000000000000000000000000000', CAST("_coll" AS DOUBLE),
       '0x5f98805a4e8be255a32880fdec7f6728c6568ba0', CAST("_debt" AS DOUBLE), NULL, NULL, NULL
FROM liquity__trove_liquidated
UNION ALL
-- Compound v3: absorb writes one AbsorbDebt per borrower and one AbsorbCollateral per asset seized,
-- each with Compound's own value at 8 decimals, in the market's quote (ETH, not dollars, for cWETHv3).
-- The row names the largest collateral seized; the debt is the base asset, priced like any other.
SELECT d.block_number, d.log_index, d.block_timestamp, d.tx_hash, 'Compound', cm.market, d.borrower, d.absorber,
       c.asset, CAST(c."collateralAbsorbed" AS DOUBLE), cm.base_asset,
       CAST(d."basePaidOut" AS DOUBLE), NULL, NULL, NULL
FROM (
  SELECT block_number, log_index, block_timestamp, tx_hash, borrower, absorber, "basePaidOut", address AS comet FROM comet_usdc__absorb_debt
  UNION ALL SELECT block_number, log_index, block_timestamp, tx_hash, borrower, absorber, "basePaidOut", address FROM comet_weth__absorb_debt
  UNION ALL SELECT block_number, log_index, block_timestamp, tx_hash, borrower, absorber, "basePaidOut", address FROM comet_usds__absorb_debt
  UNION ALL SELECT block_number, log_index, block_timestamp, tx_hash, borrower, absorber, "basePaidOut", address FROM comet_wsteth__absorb_debt
) d
JOIN comet_markets cm ON cm.comet = d.comet
LEFT JOIN (
  SELECT tx_hash, borrower, asset, "collateralAbsorbed",
         row_number() OVER (PARTITION BY tx_hash, borrower ORDER BY CAST("usdValue" AS DOUBLE) DESC) AS rk
  FROM (
    SELECT tx_hash, borrower, asset, "collateralAbsorbed", "usdValue" FROM comet_usdc__absorb_collateral
    UNION ALL SELECT tx_hash, borrower, asset, "collateralAbsorbed", "usdValue" FROM comet_weth__absorb_collateral
    UNION ALL SELECT tx_hash, borrower, asset, "collateralAbsorbed", "usdValue" FROM comet_usds__absorb_collateral
    UNION ALL SELECT tx_hash, borrower, asset, "collateralAbsorbed", "usdValue" FROM comet_wsteth__absorb_collateral
  )
) c ON c.tx_hash = d.tx_hash AND c.borrower = d.borrower AND c.rk = 1;

CREATE VIEW liquidations AS
SELECT
  to_timestamp(r.block_timestamp) AS at,
  r.block_timestamp,
  r.block_number,
  r.log_index,
  r.tx_hash,
  r.protocol,
  CASE WHEN r.protocol = 'Morpho' THEN coalesce(ca.symbol, '?') || '/' || coalesce(da.symbol, '?') ELSE r.market END AS market,
  r.borrower,
  r.liquidator,
  coalesce(r.collateral_name, ca.symbol, r.collateral_asset) AS collateral,
  CASE WHEN r.collateral_name IS NOT NULL THEN r.collateral_raw
       ELSE r.collateral_raw / power(10, ca.decimals) END AS collateral_amount,
  coalesce(r.debt_name, da.symbol, r.debt_asset) AS debt,
  CASE WHEN r.debt_name IS NOT NULL THEN r.debt_raw / 1e18
       ELSE r.debt_raw / power(10, da.decimals) END AS debt_amount,
  coalesce(r.debt_usd_given, CASE da.priced
    WHEN 'usd' THEN r.debt_raw / power(10, da.decimals)
    WHEN 'eth' THEN r.debt_raw / power(10, da.decimals) * pe.close
    WHEN 'btc' THEN r.debt_raw / power(10, da.decimals) * pb.close
  END) AS debt_usd
FROM liquidations_raw r
LEFT JOIN assets ca ON ca.asset = r.collateral_asset
LEFT JOIN assets da ON da.asset = r.debt_asset
LEFT JOIN eth_usd_hourly pe ON pe.hour = date_trunc('hour', to_timestamp(r.block_timestamp))
LEFT JOIN btc_usd_hourly pb ON pb.hour = date_trunc('hour', to_timestamp(r.block_timestamp));
