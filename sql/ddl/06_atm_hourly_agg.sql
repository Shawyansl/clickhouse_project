-- Q5: Fraud — ATM withdrawals per customer/account per calendar hour
-- Decisions:
--   1) "within one hour" + output column "Hour" = calendar hour (toStartOfHour),
--      not a sliding window (sliding would not produce a single Hour column).
--   2) Grain = (hour, customer_id, account_id) — matches GROUP BY + HAVING.
--   3) MV keeps only transaction_type = 'atm_withdrawal' (tiny vs full fact).
--   4) AggregatingMergeTree: tx_count + total_amount; HAVING applied at query time
--      so thresholds (10 / 5000) can change without rebuilding the table.
--   5) ORDER BY (hour, customer_id, account_id): last-7-days filter hits hour first.
--   6) Not served by tx_raw alone: raw ORDER BY is customer-first; a global
--      time-range fraud scan would read far more data than this narrow agg.

CREATE TABLE IF NOT EXISTS clickhouse_course.atm_hourly_agg
(
    hour            DateTime,
    customer_id     UInt64,
    account_id      UInt64,
    tx_count        SimpleAggregateFunction(sum, UInt64),
    total_amount    SimpleAggregateFunction(sum, Decimal(18, 2))
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(hour)
ORDER BY (hour, customer_id, account_id);


CREATE MATERIALIZED VIEW IF NOT EXISTS clickhouse_course.atm_hourly_agg_mv
TO clickhouse_course.atm_hourly_agg
AS
SELECT
    toStartOfHour(tx_time) AS hour,
    customer_id,
    account_id,
    count()                AS tx_count,
    sum(amount)            AS total_amount
FROM clickhouse_course.tx_raw
WHERE transaction_type = 'atm_withdrawal'
GROUP BY hour, customer_id, account_id;


-- Backfill (run once if tx_raw already has data before the MV existed):
-- INSERT INTO clickhouse_course.atm_hourly_agg
-- SELECT
--     toStartOfHour(tx_time) AS hour,
--     customer_id,
--     account_id,
--     count()                AS tx_count,
--     sum(amount)            AS total_amount
-- FROM clickhouse_course.tx_raw
-- WHERE transaction_type = 'atm_withdrawal'
-- GROUP BY hour, customer_id, account_id;
