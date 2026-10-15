CREATE MATERIALIZED VIEW tx_daily_mv TO tx_daily_agg AS
SELECT
    toDate(event_time)       AS day,
    country, transaction_type, channel, currency,
    count()                  AS tx_count,
    sum(amount)              AS total_amount,
    uniqState(customer_id)   AS unique_customers,
    uniqState(account_id)    AS unique_accounts
FROM tx_raw
GROUP BY day, country, transaction_type, channel, currency;