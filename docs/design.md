# Design decisions (Phase 2)

## 1. Group queries by shape — who shares a table, who fights

| Conflict | Why | Resolution |
|----------|-----|------------|
| **Q1 vs Q2** | Q1 wants filters on day/country/type…; Q2 wants `customer_id` first | **Do not share one physical order.** Raw fact optimized for Q2; Q1 on `tx_daily_agg` |
| **Q3 vs Q2** | Merchant ranking vs customer history | Separate `merchant_daily_agg` |
| **Q4 vs Q6 (branches)** | Q4 filters `branch_id`; Q6 filters `country` then ranks branches | `branch_daily_agg` for Q4; `country_branch_daily_agg` for Q6 |
| **Q5 vs everyone** | Needs hour grain + ATM-only + global time window | Dedicated `atm_hourly_agg` |
| **Q6 vs raw** | Frequent country+date scan on customer-ordered raw is slow | Compose existing daily aggs |

Shared intentionally:

- **Q1 + Q6 panels 1–2** → `tx_daily_agg`
- **Q3 + Q6 panel 3** → `merchant_daily_agg`

---

## 2. Tables

### `tx_raw` (fact)

| Item | Choice |
|------|--------|
| Purpose | Append-only denormalized transactions; detail for Q2; source for all MVs |
| Engine | `MergeTree` |
| `ORDER BY` | `(customer_id, tx_time, transaction_id)` — Q2 point lookup |
| `PARTITION BY` | `toYYYYMM(tx_time)` — time pruning / retention |
| `PRIMARY KEY` | same as `ORDER BY` (default) |

### `tx_daily_agg` + `tx_daily_mv`

| Item | Choice |
|------|--------|
| Purpose | Q1 dashboard; Q6 daily + top types |
| Engine | `AggregatingMergeTree` |
| `ORDER BY` | `(day, country, transaction_type, channel, currency)` |
| `PARTITION BY` | `toYYYYMM(day)` |
| Grain | day × country × type × channel × currency |

### `merchant_daily_agg` + MV

| Item | Choice |
|------|--------|
| Purpose | Q3 top merchants; Q6 top merchants |
| Engine | `AggregatingMergeTree` |
| `ORDER BY` | `(country, merchant_category, day, merchant_id)` |
| `PARTITION BY` | `toYYYYMM(day)` |
| Grain | day × country × category × merchant |
| MV filter | `transaction_type = 'card_payment'` |

### `branch_daily_agg` + MV

| Item | Choice |
|------|--------|
| Purpose | Q4 branch performance |
| Engine | `AggregatingMergeTree` |
| `ORDER BY` | `(branch_id, day)` |
| `PARTITION BY` | `toYYYYMM(day)` |
| Grain | day × branch |
| Amounts | `sumIf` → deposit / withdrawal / transfer columns |
| MV filter | `branch_id != 0` and types in deposit/withdrawal/transfer |

### `atm_hourly_agg` + MV

| Item | Choice |
|------|--------|
| Purpose | Q5 fraud hourly buckets |
| Engine | `AggregatingMergeTree` |
| `ORDER BY` | `(hour, customer_id, account_id)` |
| `PARTITION BY` | `toYYYYMM(hour)` |
| Grain | calendar hour × customer × account |
| Note | “Within one hour” = `toStartOfHour` (matches output column Hour); thresholds in `HAVING` |

### `country_branch_daily_agg` + MV

| Item | Choice |
|------|--------|
| Purpose | Q6 top branches by country |
| Engine | `AggregatingMergeTree` |
| `ORDER BY` | `(country, day, branch_id)` |
| `PARTITION BY` | `toYYYYMM(day)` |
| Grain | day × country × branch |

---

## 3. Denormalized columns (on `tx_raw` at ingest)

Joined in at write time so query paths avoid OLTP joins:

| Column | Source idea | Why |
|--------|-------------|-----|
| `country` | customer (or account) country | Q1/Q3/Q6 filters |
| `merchant_id` / `merchant_name` / `merchant_category` | merchants | Q2 detail + Q3/Q6 without JOIN |
| `branch_id` | branch of the event | Q4/Q6 branch panels |

---

## 4. `LowCardinality` candidates

Applied (or intended) on low-cardinality strings:

`transaction_type`, `channel`, `currency`, `status`, `country`, `merchant_category`

Not used on high-cardinality ids (`customer_id`, `account_id`, `merchant_id`, `transaction_id`).

---

## 5. Pre-aggregation strategy

| Mechanism | Where | Role |
|-----------|--------|------|
| **Aggregate table + MV** | all `*_agg` tables | Incremental rollup on insert into `tx_raw` |
| **Raw query** | Q2 only (primary) | Detail rows; customer-ordered fact |
| **Projection** | not used | Aggs already isolate conflicting `ORDER BY`s; keep model simpler for the course |
| **Backfill** | `INSERT … SELECT` once | Required for rows inserted before an MV existed |

Which queries run on raw:

- **Primary:** Q2  
- **Baseline only (Phase 5):** Q1, Q3, Q4, Q5, Q6 naive variants  

---

## 6. Trade-offs

| Trade-off | Choice | Cost |
|-----------|--------|------|
| Storage vs speed | Extra agg tables + denormalized fact | More disk; much less scan at query time |
| Write amplification | One insert → raw + several MVs | Higher ingest CPU/IO |
| Data duplication | Names/categories on every tx; rollups copy metrics | Acceptable for analytics |
| Threshold flexibility (Q5) | Store all ATM hour buckets; filter in `HAVING` | Slightly larger agg; no rebuild when 10/5000 change |
| Calendar hour vs sliding window (Q5) | Calendar hour | Misses some sliding-window patterns; matches assignment “Hour” column |
| Q4 vs Q6 branch `ORDER BY` | Two tables | Duplicated branch rollup storage; both dashboards stay fast |

---

## 7. Query → table map

| Query | Primary table(s) |
|-------|------------------|
| Q1 | `tx_daily_agg` |
| Q2 | `tx_raw` |
| Q3 | `merchant_daily_agg` |
| Q4 | `branch_daily_agg` |
| Q5 | `atm_hourly_agg` |
| Q6 | `tx_daily_agg` + `merchant_daily_agg` + `country_branch_daily_agg` |
