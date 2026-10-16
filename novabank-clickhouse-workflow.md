# NovaBank ClickHouse: Project Workflow

Homework: HW_L7_02_CLICKHOUSE. Design a query-first analytical data model in ClickHouse for a digital bank (NovaBank).

## How we work in this project

- Claude acts as a **senior data engineer / mentor**.
- Mentorship style: give direction, hints and questions. Give full solutions or code **only when explicitly asked**.
- Always decide from the **query pattern**, never by copying the PostgreSQL schema.
- At the start of every new chat: read this file, check the **Progress Tracker** at the bottom, and continue from the first unchecked item.

## Source system (OLTP, PostgreSQL)

Customers | Accounts | Cards | Transactions | Merchants | Branches

- transaction_type: card_payment | bank_transfer | atm_withdrawal | cash_deposit
- channel: mobile | web | atm | branch | pos
- Transactions table holds billions of rows.

## The 6 queries (summary)

| # | Query | Filters / key needs |
|---|-------|---------------------|
| Q1 | Daily transactions dashboard: count, total amount, unique customers, unique accounts, avg amount, per day | country, transaction_type, currency, channel |
| Q2 | Customer history: last 100 transactions by customer_id (Transaction ID, Timestamp, Account ID, Type, Channel, Currency, Amount, Merchant Name, Status) | customer_id, must be fast on billions of rows |
| Q3 | Top 20 merchants by card payment amount (ID, Name, Category, Count, Unique Customers, Total, Avg) | date range, country, merchant category |
| Q4 | Branch performance, last 30 days by default, per branch per day: count, unique customers, total deposit, total withdrawal, total transfer | branch, date |
| Q5 | Fraud: customers with more than 10 ATM withdrawals within one hour and total > 5,000, last 7 days (Customer ID, Account ID, Hour, Count, Total) | transaction_type = atm_withdrawal, last 7 days |
| Q6 | Country dashboard (frequent, must be fast): daily amount, daily count, unique customers, top transaction types, top merchants, top branches | country, date range |

## Phases

### Phase 0: Setup
- [ ] Docker Compose with ClickHouse (optional: Postgres as source for comparison)
- [ ] Repo structure: `docs/`, `sql/ddl/`, `sql/queries/`, `data_gen/`, `benchmarks/`
- [ ] Verify connection with `clickhouse-client`

### Phase 1: Access-pattern matrix (before any DDL)
For each of Q1 to Q6 write down:
- filters, group-by, time range
- expected frequency (rare / frequent / real-time)
- latency target
- shape: point lookup, scan, or aggregation
- cardinality of the key columns

Deliverable: `docs/access_patterns.md`

### Phase 2: Design decisions
- [ ] Group queries by shape. Which can share one table? Which fight over `ORDER BY`? (compare Q1 and Q2)
- [ ] For each table: purpose, engine, `ORDER BY`, `PARTITION BY`, `PRIMARY KEY` (if different)
- [ ] Denormalized columns (what is joined in at ingest time and why)
- [ ] `LowCardinality` candidates
- [ ] Pre-aggregation: Aggregate Table / Materialized View / Projection, and which queries run on raw data
- [ ] Trade-offs written down: storage vs. speed, write amplification, data duplication

Deliverable: `docs/design.md`

### Phase 3: DDL
- [ ] One `.sql` file per table
- [ ] Materialized view targets and the MVs themselves
- [ ] Final version of the 6 queries rewritten for the new model in `sql/queries/`

### Phase 4: Data
- [ ] Synthetic data generator (Python or ClickHouse `generateRandom`)
- [ ] Load ~1M rows first, then scale to 50-100M so the differences show
- [ ] Sanity checks on distributions (some customers with many ATM withdrawals so Q5 returns rows)

### Phase 5: Prove it
- [ ] Run all 6 queries and record `read_rows`, `read_bytes`, `query_duration_ms` from `system.query_log`
- [ ] `EXPLAIN indexes = 1` for each query
- [ ] Compare against a naive baseline (raw table, poor `ORDER BY`)
- [ ] Short conclusion per query

Deliverable: `benchmarks/results.md`

### Phase 6: Document
For each table, answer the 10 points the assignment requires:
1. Table name and purpose
2. Main columns and data types
3. Table engine
4. `ORDER BY` and why
5. `PARTITION BY` and why
6. `PRIMARY KEY` (if different from `ORDER BY`)
7. Denormalized columns
8. `LowCardinality` columns
9. Proposed Aggregate Table / MV / Projection
10. Which queries the table serves

Deliverable: final `README.md`

## Progress Tracker

- [x] Phase 0: Setup
- [x] Phase 1: Access-pattern matrix (`docs/access_patterns.md`)
- [x] Phase 2: Design decisions (`docs/design.md`)
- [x] Phase 3: DDL + queries Q1–Q6
- [x] Phase 4: Data (~1M + fraud hotspots via `data_gen/run_phase4.sh`)
- [x] Phase 5: Benchmarks (`benchmarks/results.md`; runner and raw outputs in `benchmarks/`)
- [x] Phase 6: Documentation (`README.md`)

Notes / decisions made so far:
- `tx_raw` ORDER BY customer-first for Q2; dashboards on separate AggregatingMergeTree + MVs
- Q1/Q6 share `tx_daily_agg`; Q3/Q6 share `merchant_daily_agg`
- Q4 vs Q6 branches: two tables (`branch_daily_agg` vs `country_branch_daily_agg`)
- Q5: calendar hour ATM agg; thresholds in HAVING
- Q6: compose aggs, not raw
- Agg `sum` amount columns use `Decimal(38, 2)` (ClickHouse 26.8 SimpleAggregateFunction requirement)
- Phase 4: the intended load is 1,000,300 rows in Sept 2026; the loader now refuses to add a second copy. Seeded customers 900001–900020 provide Q5 cases. `TX_ROWS` can scale the generated portion up to 100M rows.
