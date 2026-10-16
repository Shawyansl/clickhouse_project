-- Q6: Country dashboard for the latest 30 days in each serving aggregate
-- (frequent — served from aggs, not tx_raw)
-- Panels reuse existing tables; top branches uses country_branch_daily_agg.
-- Change country / date range in every panel together.

-- ---------------------------------------------------------------------------
-- Panel 1: daily amount, daily count, unique customers
-- ---------------------------------------------------------------------------
SELECT
    day,
    sum(tx_count)                      AS tx_count,
    sum(total_amount)                  AS total_amount,
    uniqMerge(unique_customers)        AS unique_customers
FROM clickhouse_course.tx_daily_agg
WHERE country = 'DE'
  AND day BETWEEN (SELECT max(day) - 30 FROM clickhouse_course.tx_daily_agg)
              AND (SELECT max(day) FROM clickhouse_course.tx_daily_agg)
GROUP BY day
ORDER BY day;


-- ---------------------------------------------------------------------------
-- Panel 2: top transaction types
-- ---------------------------------------------------------------------------
SELECT
    transaction_type,
    sum(tx_count)                      AS tx_count,
    sum(total_amount)                  AS total_amount
FROM clickhouse_course.tx_daily_agg
WHERE country = 'DE'
  AND day BETWEEN (SELECT max(day) - 30 FROM clickhouse_course.tx_daily_agg)
              AND (SELECT max(day) FROM clickhouse_course.tx_daily_agg)
GROUP BY transaction_type
ORDER BY total_amount DESC
LIMIT 10;


-- ---------------------------------------------------------------------------
-- Panel 3: top merchants
-- ---------------------------------------------------------------------------
SELECT
    merchant_id,
    any(merchant_name)                 AS merchant_name,
    any(merchant_category)             AS merchant_category,
    sum(tx_count)                      AS tx_count,
    sum(total_amount)                  AS total_amount
FROM clickhouse_course.merchant_daily_agg
WHERE country = 'DE'
  AND day BETWEEN (SELECT max(day) - 30 FROM clickhouse_course.merchant_daily_agg)
              AND (SELECT max(day) FROM clickhouse_course.merchant_daily_agg)
GROUP BY merchant_id
ORDER BY total_amount DESC
LIMIT 10;


-- ---------------------------------------------------------------------------
-- Panel 4: top branches
-- ---------------------------------------------------------------------------
SELECT
    branch_id,
    sum(tx_count)                      AS tx_count,
    sum(total_amount)                  AS total_amount
FROM clickhouse_course.country_branch_daily_agg
WHERE country = 'DE'
  AND day BETWEEN (SELECT max(day) - 30 FROM clickhouse_course.country_branch_daily_agg)
              AND (SELECT max(day) FROM clickhouse_course.country_branch_daily_agg)
GROUP BY branch_id
ORDER BY total_amount DESC
LIMIT 10;


-- ---------------------------------------------------------------------------
-- Naive baseline for Phase 5 (one combined raw scan — NOT for production)
-- ---------------------------------------------------------------------------
SELECT
    toDate(tx_time) AS day,
    count() AS tx_count,
    sum(amount) AS total_amount,
    uniq(customer_id) AS unique_customers
FROM clickhouse_course.tx_raw
WHERE country = 'DE'
  AND tx_time >= (SELECT toStartOfDay(max(tx_time)) - INTERVAL 30 DAY FROM clickhouse_course.tx_raw)
  AND tx_time <  (SELECT toStartOfDay(max(tx_time)) + INTERVAL 1 DAY FROM clickhouse_course.tx_raw)
GROUP BY day
ORDER BY day;
