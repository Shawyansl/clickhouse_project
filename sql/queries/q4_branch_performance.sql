-- Q4: Branch performance for the 30 days ending on the latest branch data date
-- Columns: day, branch_id, count, unique customers,
--          total deposit, total withdrawal, total transfer

SELECT
    day,
    branch_id,
    sum(tx_count)                   AS transactions,
    uniqMerge(customers_state)      AS unique_customers,
    sum(deposit_amount)             AS total_deposit,
    sum(withdrawal_amount)          AS total_withdrawal,
    sum(transfer_amount)            AS total_transfer
FROM clickhouse_course.branch_daily_agg
WHERE branch_id = 42
  AND day >= (SELECT max(day) - 30 FROM clickhouse_course.branch_daily_agg)
GROUP BY day, branch_id
ORDER BY day;


-- Naive baseline for Phase 5 (same answer, reads the raw table):
SELECT
    toDate(tx_time) AS day,
    branch_id,
    count() AS transactions,
    uniq(customer_id) AS unique_customers,
    sumIf(amount, transaction_type = 'cash_deposit')    AS total_deposit,
    sumIf(amount, transaction_type = 'atm_withdrawal')  AS total_withdrawal,
    sumIf(amount, transaction_type = 'bank_transfer')   AS total_transfer
FROM clickhouse_course.tx_raw
WHERE branch_id = 42
  AND tx_time >= (SELECT toStartOfDay(max(tx_time)) - INTERVAL 30 DAY FROM clickhouse_course.tx_raw)
  AND transaction_type IN ('cash_deposit', 'atm_withdrawal', 'bank_transfer')
GROUP BY day, branch_id
ORDER BY day;
