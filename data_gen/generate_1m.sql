-- Phase 4: synthetic transactions into tx_raw (MVs fill aggs automatically).
-- Row count is supplied by the loader as the {rows:UInt64} query parameter.
-- Time window: 2026-09-01 .. 2026-09-30 (matches sample filters in sql/queries/).

INSERT INTO clickhouse_course.tx_raw
SELECT
    generateUUIDv4() AS transaction_id,
    tx_time,
    customer_id,
    account_id,
    transaction_type,
    channel,
    currency,
    status,
    amount,
    country,
    if(transaction_type = 'card_payment', mid, 0) AS merchant_id,
    if(transaction_type = 'card_payment', concat('Merchant_', toString(mid)), '') AS merchant_name,
    if(transaction_type = 'card_payment', mcat, '') AS merchant_category,
    if(
        transaction_type IN ('cash_deposit', 'atm_withdrawal', 'bank_transfer'),
        bid,
        0
    ) AS branch_id
FROM
(
    SELECT
        number,
        toDateTime('2026-09-01 00:00:00')
            + toIntervalSecond(number % (30 * 24 * 3600)) AS tx_time,
        1 + (number % 100000) AS customer_id,
        1 + (number % 150000) AS account_id,
        arrayElement(
            ['card_payment', 'bank_transfer', 'atm_withdrawal', 'cash_deposit'],
            1 + (number % 4)
        ) AS transaction_type,
        arrayElement(
            ['mobile', 'web', 'atm', 'branch', 'pos'],
            1 + (number % 5)
        ) AS channel,
        arrayElement(['EUR', 'USD', 'GBP'], 1 + (number % 3)) AS currency,
        arrayElement(
            ['completed', 'completed', 'completed', 'failed'],
            1 + (number % 4)
        ) AS status,
        round(10 + (number % 50000) / 100.0, 2) AS amount,
        arrayElement(['DE', 'FR', 'NL', 'AT', 'BE'], 1 + (number % 5)) AS country,
        1 + (number % 5000) AS mid,
        arrayElement(
            ['grocery', 'fuel', 'travel', 'electronics', 'restaurant'],
            1 + (number % 5)
        ) AS mcat,
        1 + (number % 200) AS bid
    FROM numbers({rows:UInt64})
);
