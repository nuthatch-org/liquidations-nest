-- Chainlink closes per UTC hour, 8 decimals. Each feed's proxy emits nothing; its phase aggregators do,
-- so the phases live since 2023 are read together. One row per hour that had an update.
CREATE VIEW eth_usd_hourly AS
SELECT date_trunc('hour', to_timestamp(block_timestamp)) AS hour,
       last_value(CAST(current AS DOUBLE) ORDER BY block_number, log_index) / 1e8 AS close
FROM (
  SELECT block_number, log_index, block_timestamp, current FROM eth_usd_p5__answer_updated
  UNION ALL SELECT block_number, log_index, block_timestamp, current FROM eth_usd_p6__answer_updated
  UNION ALL SELECT block_number, log_index, block_timestamp, current FROM eth_usd_p7__answer_updated
)
GROUP BY 1;

CREATE VIEW btc_usd_hourly AS
SELECT date_trunc('hour', to_timestamp(block_timestamp)) AS hour,
       last_value(CAST(current AS DOUBLE) ORDER BY block_number, log_index) / 1e8 AS close
FROM (
  SELECT block_number, log_index, block_timestamp, current FROM btc_usd_p5__answer_updated
  UNION ALL SELECT block_number, log_index, block_timestamp, current FROM btc_usd_p6__answer_updated
  UNION ALL SELECT block_number, log_index, block_timestamp, current FROM btc_usd_p7__answer_updated
)
GROUP BY 1;
