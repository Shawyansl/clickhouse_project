SELECT
    transaction_id,
    tx_time,
    account_id,
    transaction_type,
    channel,
    currency,
    amount,
    merchant_name,
    status
FROM clickhouse_course.tx_raw
WHERE customer_id = 12345
ORDER BY tx_time DESC
LIMIT 100;