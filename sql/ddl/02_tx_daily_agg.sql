CREATE TABLE IF NOT EXISTS clickhouse_course.tx_daily_agg
(
    day               Date,
    country           LowCardinality(String),
    transaction_type  LowCardinality(String),
    currency          LowCardinality(String),
    channel           LowCardinality(String),
    tx_count          SimpleAggregateFunction(sum, UInt64),
    total_amount      SimpleAggregateFunction(sum, Decimal(38, 2)),
    unique_customers  AggregateFunction(uniq, UInt64),
    unique_accounts   AggregateFunction(uniq, UInt64)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(day)
ORDER BY (day, country, transaction_type, channel, currency);
