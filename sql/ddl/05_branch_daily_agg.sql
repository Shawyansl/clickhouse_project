-- Q4: Branch performance per branch per day
-- Decisions:
--   1) Grain = (day, branch_id)
--   2) Three amount columns via sumIf (deposit / withdrawal / transfer)
--   3) MV only keeps branch-relevant rows:
--        branch_id != 0
--        AND transaction_type IN (cash_deposit, atm_withdrawal, bank_transfer)
--   4) unique customers = across all those types for that branch/day

CREATE TABLE IF NOT EXISTS clickhouse_course.branch_daily_agg
(
    day                 Date,
    branch_id           UInt32,
    tx_count            SimpleAggregateFunction(sum, UInt64),
    customers_state     AggregateFunction(uniq, UInt64),
    deposit_amount      SimpleAggregateFunction(sum, Decimal(38, 2)),
    withdrawal_amount   SimpleAggregateFunction(sum, Decimal(38, 2)),
    transfer_amount     SimpleAggregateFunction(sum, Decimal(38, 2))
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(day)
ORDER BY (branch_id, day);


CREATE MATERIALIZED VIEW IF NOT EXISTS clickhouse_course.branch_daily_agg_mv
TO clickhouse_course.branch_daily_agg
AS
SELECT
    toDate(tx_time) AS day,
    branch_id,
    count() AS tx_count,
    uniqState(customer_id) AS customers_state,
    sumIf(amount, transaction_type = 'cash_deposit')    AS deposit_amount,
    sumIf(amount, transaction_type = 'atm_withdrawal')  AS withdrawal_amount,
    sumIf(amount, transaction_type = 'bank_transfer')   AS transfer_amount
FROM clickhouse_course.tx_raw
WHERE branch_id != 0
  AND transaction_type IN ('cash_deposit', 'atm_withdrawal', 'bank_transfer')
GROUP BY day, branch_id;


-- Backfill (run once if tx_raw already has data before the MV existed):
-- INSERT INTO clickhouse_course.branch_daily_agg
-- SELECT
--     toDate(tx_time) AS day,
--     branch_id,
--     count() AS tx_count,
--     uniqState(customer_id) AS customers_state,
--     sumIf(amount, transaction_type = 'cash_deposit')    AS deposit_amount,
--     sumIf(amount, transaction_type = 'atm_withdrawal')  AS withdrawal_amount,
--     sumIf(amount, transaction_type = 'bank_transfer')   AS transfer_amount
-- FROM clickhouse_course.tx_raw
-- WHERE branch_id != 0
--   AND transaction_type IN ('cash_deposit', 'atm_withdrawal', 'bank_transfer')
-- GROUP BY day, branch_id;
