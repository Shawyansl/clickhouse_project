-- Q1: Daily transactions dashboard
-- Metrics per day: count, total amount, unique customers, unique accounts, avg amount
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
WHERE day BETWEEN toDate('2026-09-01') AND toDate('2026-09-30')
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
WHERE tx_time >= toDateTime('2026-09-01 00:00:00')
  AND tx_time <  toDateTime('2026-10-01 00:00:00')
  AND country = 'DE'
  AND transaction_type = 'card_payment'
  AND currency = 'EUR'
  AND channel = 'mobile'
GROUP BY day
ORDER BY day;
