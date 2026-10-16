CREATE MATERIALIZED VIEW IF NOT EXISTS clickhouse_course.tx_daily_mv
TO clickhouse_course.tx_daily_agg
AS
SELECT
    toDate(tx_time)            AS day,
    country,
    transaction_type,
    channel,
    currency,
    count()                    AS tx_count,
    sum(amount)                AS total_amount,
    uniqState(customer_id)     AS unique_customers,
    uniqState(account_id)      AS unique_accounts
FROM clickhouse_course.tx_raw
GROUP BY day, country, transaction_type, channel, currency;
