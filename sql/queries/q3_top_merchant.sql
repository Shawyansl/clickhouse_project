-- Q3: Top 20 merchants by card payment amount
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
WHERE day BETWEEN toDate('2026-09-01') AND toDate('2026-09-30')
  AND country = 'DE'
  AND merchant_category = 'grocery'
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
  AND tx_time >= toDateTime('2026-09-01 00:00:00')
  AND tx_time <  toDateTime('2026-10-01 00:00:00')
  AND country = 'DE'
  AND merchant_category = 'grocery'
GROUP BY merchant_id
ORDER BY total DESC
LIMIT 20;