-- Q1: Daily transactions dashboard
-- Metrics per day: count, total amount, unique customers, unique accounts, avg amount
-- Date window: 30 days ending on the latest date currently in tx_daily_agg.
-- Optional filters: country, transaction_type, currency, channel
-- Served from tx_daily_agg (not tx_raw).

SELECT
    day,
    sum(tx_count)                   AS tx_count,
    sum(total_amount)               AS total_amount,
    uniqMerge(unique_customers)     AS unique_customers,
    uniqMerge(unique_accounts)      AS unique_accounts,
    total_amount / tx_count         AS avg_amount
FROM clickhouse_course.tx_daily_agg
WHERE day BETWEEN (SELECT max(day) - 30 FROM clickhouse_course.tx_daily_agg)
               AND (SELECT max(day) FROM clickhouse_course.tx_daily_agg)
  AND country = 'DE'
  AND transaction_type = 'card_payment'
  AND currency = 'EUR'
  AND channel = 'mobile'
GROUP BY day
ORDER BY day;


-- Naive baseline for Phase 5 (same answer, reads the raw table):
SELECT
    toDate(tx_time) AS day,
    count() AS tx_count,
    sum(amount) AS total_amount,
    uniq(customer_id) AS unique_customers,
    uniq(account_id) AS unique_accounts,
    avg(amount) AS avg_amount
FROM clickhouse_course.tx_raw
WHERE tx_time >= (SELECT toStartOfDay(max(tx_time)) - INTERVAL 30 DAY FROM clickhouse_course.tx_raw)
  AND tx_time <  (SELECT toStartOfDay(max(tx_time)) + INTERVAL 1 DAY FROM clickhouse_course.tx_raw)
  AND country = 'DE'
  AND transaction_type = 'card_payment'
  AND currency = 'EUR'
  AND channel = 'mobile'
GROUP BY day
ORDER BY day;
