-- Sanity checks after load

SELECT 'tx_raw_rows' AS check, count() AS value FROM clickhouse_course.tx_raw
UNION ALL
SELECT 'tx_daily_agg_rows', count() FROM clickhouse_course.tx_daily_agg
UNION ALL
SELECT 'merchant_daily_agg_rows', count() FROM clickhouse_course.merchant_daily_agg
UNION ALL
SELECT 'branch_daily_agg_rows', count() FROM clickhouse_course.branch_daily_agg
UNION ALL
SELECT 'atm_hourly_agg_rows', count() FROM clickhouse_course.atm_hourly_agg
UNION ALL
SELECT 'country_branch_daily_agg_rows', count() FROM clickhouse_course.country_branch_daily_agg;

SELECT
    transaction_type,
    count() AS n
FROM clickhouse_course.tx_raw
GROUP BY transaction_type
ORDER BY n DESC;

SELECT
    country,
    count() AS n
FROM clickhouse_course.tx_raw
GROUP BY country
ORDER BY n DESC;

-- Q5 should find the seeded hotspots
SELECT
    customer_id,
    account_id,
    hour,
    sum(tx_count) AS tx_count,
    sum(total_amount) AS total_amount
FROM clickhouse_course.atm_hourly_agg
WHERE hour >= toDateTime('2026-09-21 00:00:00')
GROUP BY customer_id, account_id, hour
HAVING tx_count > 10 AND total_amount > 5000
ORDER BY customer_id
LIMIT 25;
