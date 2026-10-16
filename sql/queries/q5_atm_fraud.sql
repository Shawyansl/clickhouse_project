-- Q5: Fraud — customers with >10 ATM withdrawals in one calendar hour
--      and total amount > 5000, in the seven days before the latest ATM data.
-- Output: Customer ID, Account ID, Hour, Count, Total

SELECT
    customer_id,
    account_id,
    hour,
    sum(tx_count)       AS tx_count,
    sum(total_amount)   AS total_amount
FROM clickhouse_course.atm_hourly_agg
WHERE hour >= (SELECT max(hour) - INTERVAL 7 DAY FROM clickhouse_course.atm_hourly_agg)
GROUP BY customer_id, account_id, hour
HAVING tx_count > 10
   AND total_amount > 5000
ORDER BY hour DESC, total_amount DESC;


-- Naive baseline for Phase 5 (same answer, reads the raw table):
SELECT
    customer_id,
    account_id,
    toStartOfHour(tx_time) AS hour,
    count()                AS tx_count,
    sum(amount)            AS total_amount
FROM clickhouse_course.tx_raw
WHERE transaction_type = 'atm_withdrawal'
  AND tx_time >= (SELECT max(tx_time) - INTERVAL 7 DAY FROM clickhouse_course.tx_raw)
GROUP BY customer_id, account_id, hour
HAVING tx_count > 10
   AND total_amount > 5000
ORDER BY hour DESC, total_amount DESC;
