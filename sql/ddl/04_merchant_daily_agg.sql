-- Q3: Top merchants by card payment amount
-- Target table: one row (partial result) per day / country / category / merchant

CREATE TABLE IF NOT EXISTS clickhouse_course.merchant_daily_agg
(
    day               Date,
    country           LowCardinality(String),
    merchant_category LowCardinality(String),
    merchant_id       UInt64,
    merchant_name     SimpleAggregateFunction(any, String),
    tx_count          SimpleAggregateFunction(sum, UInt64),
    total_amount      SimpleAggregateFunction(sum, Decimal(18, 2)),
    customers_state   AggregateFunction(uniq, UInt64)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(day)
ORDER BY (country, merchant_category, day, merchant_id);


-- MV: runs on every INSERT into tx_raw (only new rows, no backfill)
CREATE MATERIALIZED VIEW IF NOT EXISTS clickhouse_course.merchant_daily_agg_mv
TO clickhouse_course.merchant_daily_agg
AS
SELECT
    toDate(tx_time)             AS day,
    country,
    merchant_category,
    merchant_id,
    any(merchant_name)          AS merchant_name,
    count()                     AS tx_count,
    sum(amount)                 AS total_amount,
    uniqState(customer_id)      AS customers_state
FROM clickhouse_course.tx_raw
WHERE transaction_type = 'card_payment'
  -- AND status = 'completed'   -- DECISION: should failed payments count?
GROUP BY day, country, merchant_category, merchant_id;


-- Backfill for rows that existed BEFORE the MV was created:
-- run the same SELECT as an INSERT ... SELECT once.
-- INSERT INTO clickhouse_course.merchant_daily_agg
-- SELECT ... (same SELECT as above)