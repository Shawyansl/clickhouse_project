-- Q6 panel: top branches by country
-- branch_daily_agg is ordered by (branch_id, day) for Q4 — it has no country
-- and is the wrong ORDER BY for a country dashboard. This table fills that gap.
-- Decisions:
--   1) Grain = (day, country, branch_id)
--   2) Metrics: tx_count + total_amount (enough to rank "top branches")
--   3) Same row filter as Q4 branch MV (branch-relevant txs only)
--   4) ORDER BY (country, day, branch_id): country + date range first

CREATE TABLE IF NOT EXISTS clickhouse_course.country_branch_daily_agg
(
    day             Date,
    country         LowCardinality(String),
    branch_id       UInt32,
    tx_count        SimpleAggregateFunction(sum, UInt64),
    total_amount    SimpleAggregateFunction(sum, Decimal(38, 2))
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(day)
ORDER BY (country, day, branch_id);


CREATE MATERIALIZED VIEW IF NOT EXISTS clickhouse_course.country_branch_daily_agg_mv
TO clickhouse_course.country_branch_daily_agg
AS
SELECT
    toDate(tx_time) AS day,
    country,
    branch_id,
    count()         AS tx_count,
    sum(amount)     AS total_amount
FROM clickhouse_course.tx_raw
WHERE branch_id != 0
  AND transaction_type IN ('cash_deposit', 'atm_withdrawal', 'bank_transfer')
GROUP BY day, country, branch_id;


-- Backfill (run once if tx_raw already has data before the MV existed):
-- INSERT INTO clickhouse_course.country_branch_daily_agg
-- SELECT
--     toDate(tx_time) AS day,
--     country,
--     branch_id,
--     count()         AS tx_count,
--     sum(amount)     AS total_amount
-- FROM clickhouse_course.tx_raw
-- WHERE branch_id != 0
--   AND transaction_type IN ('cash_deposit', 'atm_withdrawal', 'bank_transfer')
-- GROUP BY day, country, branch_id;
