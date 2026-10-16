# NovaBank ClickHouse Analytics

Query-first analytical model for NovaBank's transaction workloads. The project uses ClickHouse for an append-oriented transaction fact table, materialized views for incremental rollups, and purpose-built aggregate tables for dashboard and fraud queries.

## Run the project: beginner walkthrough

This repository is a small ClickHouse analytics demo, not a web application. Docker runs the ClickHouse database server. The SQL files create tables and ask questions of that database. The Python benchmark script automates running queries and collecting performance measurements; Python is not needed to start ClickHouse or run a single query.

### What you need

- Docker Desktop, or Docker Engine, with the Docker Compose plugin.
- Python 3.10 or newer **only if you want to run the benchmark script**.
- A terminal opened in this repository's folder.

The benchmark script uses Python's standard library only; there are no Python packages to install. It calls Docker to connect to the ClickHouse container, so Docker must be running and available to your user.

### 1. Start ClickHouse

```bash
docker compose up -d
docker compose ps
```

`up -d` starts the database in the background. `ps` shows whether the `clickhouse` service is up. The first start may take a little time while Docker downloads the ClickHouse image. The database is available on localhost port `8123` (HTTP) and `9000` (native client).

### 2. Load the project tables and sample data

Do this only when using a **fresh, empty database volume**:

```bash
bash data_gen/run_phase4.sh
```

This script creates the raw and aggregate tables, creates materialized views, inserts about one million synthetic transactions and 300 extra fraud examples, then runs sanity checks. A materialized view automatically updates the aggregate tables when new rows are inserted into `tx_raw`.

**Do not run the loader again on a database that already has project data.** The table creation statements use `IF NOT EXISTS`, but the inserts still happen each time, so each rerun adds duplicates. The database in this workspace already has 2,000,600 rows because the loader was run twice. For a clean start, you can delete the Docker volume and all its data with `docker compose down -v`, start ClickHouse again, then run the loader once. This deletion cannot be undone.

### 3. Open ClickHouse and check the tables

Start an interactive SQL prompt:

```bash
docker exec -it clickhouse-course clickhouse-client \
  --user course --password course --database clickhouse_course
```

At the `clickhouse_course :)` prompt, enter SQL such as:

```sql
SHOW TABLES;
SELECT count() FROM tx_raw;
```

Each SQL statement ends with a semicolon. Type `exit` to leave the prompt. You can also run one SQL command without opening an interactive prompt:

```bash
docker exec clickhouse-course clickhouse-client \
  --user course --password course --query "SELECT count() FROM clickhouse_course.tx_raw"
```

### 4. Run one of the example queries

Each file in `sql/queries/` contains a saved query. Q1 and Q3–Q6 also include a raw-table comparison after the main query, so use the `--multiquery` option to run every statement in those files:

```bash
docker exec -i clickhouse-course clickhouse-client \
  --user course --password course --multiquery \
  < sql/queries/q1_daily_dashboard.sql
```

For Q2, which has one statement, the same command works with this filename:

```bash
docker exec -i clickhouse-course clickhouse-client \
  --user course --password course \
  < sql/queries/q2_last_onehundred_transactions.sql
```

The six files are:

- `q1_daily_dashboard.sql` — daily count, amount, and unique customer/account metrics.
- `q2_last_onehundred_transactions.sql` — a customer's most recent transaction details.
- `q3_top_merchant.sql` — top merchants by card-payment amount.
- `q4_branch_performance.sql` — daily metrics for a selected branch.
- `q5_atm_fraud.sql` — high-count, high-value ATM withdrawals within calendar hours.
- `q6_country_dashboard.sql` — four country dashboard panels.

These SQL files contain example dates, countries, and IDs that you can edit to explore different filters. The Q4 and Q5 application queries use relative dates, so they may return no rows when the loaded synthetic data is from an older date range.

### 5. What is the Python file, and when should I run it?

`benchmarks/run_phase5.py` is a command-line program written in Python. It is a helper that automates Phase 5; it does not start the database, generate the project data, or provide a user interface. Run it from the repository root after ClickHouse is up and the tables/data have been loaded:

```bash
python3 --version
python3 benchmarks/run_phase5.py
```

The script reads the saved query files, runs the serving queries and available raw-table comparisons, and asks ClickHouse for each query's duration, rows read, and bytes read. It also runs `EXPLAIN indexes = 1` for the serving queries. Q6 has four panels, so each panel is measured separately. For Q4 and Q5 it uses benchmark-only date windows that overlap the September sample data; it does not edit the application query files for those date adjustments.

The measurements and query results are written to `benchmarks/results/`. The human-readable summary is `benchmarks/results.md`. You can open the `.out` files to see query results, `.json` files to see metrics, and `_explain.txt` files to see ClickHouse's index/partition pruning explanation. Re-running the benchmark replaces these result files with a new run.

If you only want to use ClickHouse and try the saved SQL, you can skip Python entirely. Python is only needed for the automated benchmark command above.

### Stop or restart ClickHouse

Stop the service and keep its data:

```bash
docker compose down
```

Start it again later with `docker compose up -d`; the database volume is retained. `docker compose down -v` also deletes the volume and all stored project data.

## Query patterns and physical design

The raw table is ordered for customer history, while the aggregate tables use separate sort orders for dashboard access. One physical order cannot efficiently serve both access patterns, so Q1–Q6 use the following paths:

| Query | Shape | Serving table(s) |
|---|---|---|
| Q1 — Daily transaction dashboard | Filtered daily aggregation | `tx_daily_agg` |
| Q2 — Last 100 transactions per customer | Customer point lookup, newest first | `tx_raw` |
| Q3 — Top merchants | Filtered aggregate and top-N | `merchant_daily_agg` |
| Q4 — Branch performance by day | Branch and date aggregation | `branch_daily_agg` |
| Q5 — ATM withdrawal anomalies | Hourly customer/account aggregation | `atm_hourly_agg` |
| Q6 — Country dashboard | Multi-panel daily and top-N aggregation | `tx_daily_agg`, `merchant_daily_agg`, `country_branch_daily_agg` |

All tables are in the `clickhouse_course` database. Unless called out, the primary key is the leading prefix of `ORDER BY`; ClickHouse uses `ORDER BY` as the primary key by default when no separate `PRIMARY KEY` is specified.

## Table specifications

### `tx_raw` — transaction fact table

1. **Purpose:** Append-only, denormalized transaction detail; source for all materialized views and the serving table for Q2.
2. **Main columns and types:** `transaction_id UUID`; `tx_time DateTime`; `customer_id`, `account_id UInt64`; `transaction_type`, `channel`, `currency`, `status`, `country`, `merchant_category LowCardinality(String)`; `amount Decimal(18,2)`; `merchant_id`, `branch_id UInt32`; `merchant_name String`.
3. **Engine:** `MergeTree`.
4. **ORDER BY:** `(customer_id, tx_time, transaction_id)` puts each customer's records together and supports newest-first history reads.
5. **PARTITION BY:** `toYYYYMM(tx_time)` enables monthly pruning and retention operations.
6. **PRIMARY KEY:** Same as `ORDER BY` (implicit).
7. **Denormalized columns:** `country`, merchant ID/name/category, and `branch_id` are stored at ingest to avoid query-time joins.
8. **LowCardinality:** Transaction type, channel, currency, status, country, and merchant category. High-cardinality IDs and merchant names are not encoded this way.
9. **Pre-aggregation:** Source for the materialized views below; no projection is used. The customer-leading order is intentionally optimized for Q2.
10. **Queries served:** Q2 directly; source for Q1, Q3, Q4, Q5, and Q6 rollups.

### `tx_daily_agg` — daily transaction rollup

1. **Purpose:** Daily counts, amount, and distinct customer/account states by country and transaction dimensions.
2. **Main columns and types:** `day Date`; country/type/channel/currency as `LowCardinality(String)`; `tx_count SimpleAggregateFunction(sum, UInt64)`; `total_amount SimpleAggregateFunction(sum, Decimal(38,2))`; unique customer/account columns as `AggregateFunction(uniq, UInt64)` states.
3. **Engine:** `AggregatingMergeTree`.
4. **ORDER BY:** `(day, country, transaction_type, channel, currency)` leads with the common date filter, followed by dashboard dimensions.
5. **PARTITION BY:** `toYYYYMM(day)`.
6. **PRIMARY KEY:** Same as `ORDER BY` (implicit).
7. **Denormalized columns:** Country and transaction dimensions are copied from `tx_raw` into each rollup key.
8. **LowCardinality:** Country, transaction type, currency, and channel.
9. **Pre-aggregation:** `tx_daily_mv` groups each inserted block by day and dimensions; it stores sum values and `uniqState` values for later merging.
10. **Queries served:** Q1 and Q6 panels 1–2.

### `merchant_daily_agg` — daily card merchant rollup

1. **Purpose:** Merchant totals and distinct customer states for ranking merchants.
2. **Main columns and types:** `day Date`; country/category `LowCardinality(String)`; `merchant_id UInt64`; `merchant_name SimpleAggregateFunction(any, String)`; count `SimpleAggregateFunction(sum, UInt64)`; amount `SimpleAggregateFunction(sum, Decimal(38,2))`; customers `AggregateFunction(uniq, UInt64)` state.
3. **Engine:** `AggregatingMergeTree`.
4. **ORDER BY:** `(country, merchant_category, day, merchant_id)` supports country/category/date filtering before ranking merchants.
5. **PARTITION BY:** `toYYYYMM(day)`.
6. **PRIMARY KEY:** Same as `ORDER BY` (implicit).
7. **Denormalized columns:** Country, merchant category, and name come from the transaction row; no dimension join is needed at read time.
8. **LowCardinality:** Country and merchant category.
9. **Pre-aggregation:** `merchant_daily_agg_mv` includes card payments and aggregates by day, country, category, and merchant.
10. **Queries served:** Q3 and Q6 panel 3.

### `branch_daily_agg` — daily branch operations rollup

1. **Purpose:** Daily branch transaction count, distinct customer state, and separate deposit, withdrawal, and transfer amounts.
2. **Main columns and types:** `day Date`; `branch_id UInt32`; count `SimpleAggregateFunction(sum, UInt64)`; customer state `AggregateFunction(uniq, UInt64)`; each amount `SimpleAggregateFunction(sum, Decimal(38,2))`.
3. **Engine:** `AggregatingMergeTree`.
4. **ORDER BY:** `(branch_id, day)` supports branch-specific history.
5. **PARTITION BY:** `toYYYYMM(day)`.
6. **PRIMARY KEY:** Same as `ORDER BY` (implicit).
7. **Denormalized columns:** Branch ID is carried from `tx_raw`; country is omitted because Q4 filters by branch.
8. **LowCardinality:** None; the table has no string columns.
9. **Pre-aggregation:** `branch_daily_agg_mv` filters to nonzero branches and deposit, ATM withdrawal, or transfer transactions; it uses `sumIf` for the three amount columns.
10. **Queries served:** Q4.

### `atm_hourly_agg` — hourly ATM activity rollup

1. **Purpose:** Narrow hourly rollup for detecting high-frequency, high-value ATM withdrawals.
2. **Main columns and types:** `hour DateTime`; `customer_id`, `account_id UInt64`; count `SimpleAggregateFunction(sum, UInt64)`; amount `SimpleAggregateFunction(sum, Decimal(38,2))`.
3. **Engine:** `AggregatingMergeTree`.
4. **ORDER BY:** `(hour, customer_id, account_id)` makes time-window scans the leading access pattern.
5. **PARTITION BY:** `toYYYYMM(hour)`.
6. **PRIMARY KEY:** Same as `ORDER BY` (implicit).
7. **Denormalized columns:** Customer and account IDs are copied into the hourly grouping key; no other dimensions are needed for Q5.
8. **LowCardinality:** None; the table has no string columns.
9. **Pre-aggregation:** `atm_hourly_agg_mv` keeps only `atm_withdrawal` transactions and groups them into calendar hours. Thresholds stay in the query's `HAVING` clause.
10. **Queries served:** Q5.

### `country_branch_daily_agg` — daily branch rollup by country

1. **Purpose:** Country-filtered branch ranking for the country dashboard.
2. **Main columns and types:** `day Date`; `country LowCardinality(String)`; `branch_id UInt32`; count `SimpleAggregateFunction(sum, UInt64)`; amount `SimpleAggregateFunction(sum, Decimal(38,2))`.
3. **Engine:** `AggregatingMergeTree`.
4. **ORDER BY:** `(country, day, branch_id)` leads with the country and date filters in Q6.
5. **PARTITION BY:** `toYYYYMM(day)`.
6. **PRIMARY KEY:** Same as `ORDER BY` (implicit).
7. **Denormalized columns:** Country and branch ID are included in the rollup key from `tx_raw`.
8. **LowCardinality:** Country.
9. **Pre-aggregation:** `country_branch_daily_agg_mv` filters to nonzero branch IDs and relevant transaction types, then aggregates by day, country, and branch.
10. **Queries served:** Q6 panel 4.

## Materialized view behavior and operations

The views write aggregate rows for newly inserted `tx_raw` data. Creating a view does not automatically backfill older rows; the commented `INSERT ... SELECT` examples in the DDL files show the one-time backfill shape if the tables are created after data already exists. Avoid running a backfill on rows already processed by a view, or totals will be duplicated.

Amounts in aggregate tables use `Decimal(38,2)` for ClickHouse 26.8 `SimpleAggregateFunction(sum, ...)` compatibility. Unique counts use aggregate states and must be read with `uniqMerge` (or a matching merge function), not by summing state values.

## Benchmark summary

Phase 5 measurements used the available 2,000,600-row dataset. The rollups reduced rows and bytes read substantially for the dashboard and fraud queries. At this small scale, elapsed time varied: Q1 and Q4's raw versions were about as fast as their aggregate versions despite scanning much more data. See [benchmark details](benchmarks/results.md), including the date-window adjustments, individual query metrics, and `EXPLAIN indexes = 1` outputs.

## Project files

- `docs/access_patterns.md` — query access-pattern analysis.
- `docs/design.md` — physical design rationale and trade-offs.
- `sql/ddl/` — table and materialized view definitions.
- `sql/queries/` — Q1–Q6 serving queries and raw comparison queries.
- `data_gen/` — synthetic data, fraud seed, loader, and sanity checks.
- `benchmarks/` — Phase 5 runner, measurements, and explain output.
