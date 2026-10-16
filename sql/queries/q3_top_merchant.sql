-- Q3: Top 20 merchants by card payment amount
-- Date window: 30 days ending on the latest date currently in merchant_daily_agg.
-- Filters (date range, country, category) are all in the WHERE clause.
-- Drop the country / category lines when the dashboard filter is empty.

SELECT
    merchant_id,
    any(merchant_name)            AS merchant_name,
    any(merchant_category)        AS merchant_category,
    sum(tx_count)                 AS transactions,
    uniqMerge(customers_state)    AS unique_customers,
    sum(total_amount)             AS total,
    total / transactions          AS avg_amount
FROM clickhouse_course.merchant_daily_agg
WHERE day BETWEEN (SELECT max(day) - 30 FROM clickhouse_course.merchant_daily_agg)
               AND (SELECT max(day) FROM clickhouse_course.merchant_daily_agg)
  AND country = 'DE'
  AND clickhouse_course.merchant_daily_agg.merchant_category = 'grocery'
GROUP BY merchant_id
ORDER BY total DESC
LIMIT 20;


-- Naive baseline for Phase 5 (same answer, reads the raw table):
SELECT
    merchant_id,
    any(merchant_name)            AS merchant_name,
    any(merchant_category)        AS merchant_category,
    count()                       AS transactions,
    uniq(customer_id)             AS unique_customers,
    sum(amount)                   AS total,
    avg(amount)                   AS avg_amount
FROM clickhouse_course.tx_raw
WHERE transaction_type = 'card_payment'
  AND tx_time >= (SELECT toStartOfDay(max(tx_time)) - INTERVAL 30 DAY FROM clickhouse_course.tx_raw)
  AND tx_time <  (SELECT toStartOfDay(max(tx_time)) + INTERVAL 1 DAY FROM clickhouse_course.tx_raw)
  AND country = 'DE'
  AND clickhouse_course.tx_raw.merchant_category = 'grocery'
GROUP BY merchant_id
ORDER BY total DESC
LIMIT 20;
