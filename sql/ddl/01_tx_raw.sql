CREATE TABLE IF NOT EXISTS clickhouse_course.tx_raw
(
    transaction_id    UUID,
    tx_time           DateTime,
    customer_id       UInt64,
    account_id        UInt64,

    transaction_type  LowCardinality(String),  -- card_payment | bank_transfer | atm_withdrawal | cash_deposit
    channel           LowCardinality(String),  -- mobile | web | atm | branch | pos
    currency          LowCardinality(String),
    status            LowCardinality(String),
    amount            Decimal(18, 2),

    -- denormalized at ingest time (no JOINs at query time)
    country           LowCardinality(String),  -- customer country
    merchant_id       UInt32 DEFAULT 0,
    merchant_name     String DEFAULT '',
    merchant_category LowCardinality(String) DEFAULT '',
    branch_id         UInt32 DEFAULT 0
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(tx_time)
ORDER BY (customer_id, tx_time, transaction_id);