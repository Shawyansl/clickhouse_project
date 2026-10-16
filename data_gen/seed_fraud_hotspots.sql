-- Guarantee Q5 returns rows: a few customers with >10 ATM withdrawals
-- in the same calendar hour, total amount > 5000, inside last-7-days-of-September.

INSERT INTO clickhouse_course.tx_raw
SELECT
    generateUUIDv4() AS transaction_id,
    toDateTime('2026-09-28 14:00:00') + toIntervalSecond(number % 3500) AS tx_time,
    900001 + intDiv(number, 15) AS customer_id,   -- customers 900001..900020
    800001 + intDiv(number, 15) AS account_id,
    'atm_withdrawal' AS transaction_type,
    'atm' AS channel,
    'EUR' AS currency,
    'completed' AS status,
    400.00 AS amount,                             -- 15 * 400 = 6000 > 5000
    'DE' AS country,
    0 AS merchant_id,
    '' AS merchant_name,
    '' AS merchant_category,
    1 + (intDiv(number, 15) % 50) AS branch_id
FROM numbers(300);   -- 20 customers × 15 withdrawals
