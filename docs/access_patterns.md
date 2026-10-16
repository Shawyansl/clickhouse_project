# Access-pattern matrix (Phase 1)

Query-first analysis for NovaBank ClickHouse. Decisions below drive DDL — not the PostgreSQL OLTP schema.

Cardinality assumptions (synthetic / typical digital bank):

| Column | Approx. cardinality | Notes |
|--------|---------------------|--------|
| `customer_id` | 10⁵–10⁷ | High |
| `account_id` | ~1–3× customers | High |
| `transaction_id` | = row count | Unique |
| `merchant_id` | 10³–10⁵ | Medium |
| `branch_id` | 10²–10⁴ | Low–medium |
| `country` | ~10–50 | Low → `LowCardinality` |
| `transaction_type` | 4 | Low |
| `channel` | 5 | Low |
| `currency` | ~10–30 | Low |
| `merchant_category` | ~20–100 | Low |
| `status` | ~3–5 | Low |

---

## Q1 — Daily transactions dashboard

| Field | Value |
|-------|--------|
| **Filters** | `country`, `transaction_type`, `currency`, `channel`, date range |
| **Group by** | `day` (+ optional filter dimensions already in WHERE) |
| **Time range** | typically days–months |
| **Frequency** | frequent (ops / product dashboard) |
| **Latency target** | &lt; 1–2 s on warm cache; must stay fast at 100M+ raw rows |
| **Shape** | aggregation |
| **Key cardinalities** | low dims (`country`, type, channel, currency) × days |
| **Served by** | `tx_daily_agg` via MV from `tx_raw` |

---

## Q2 — Customer last 100 transactions

| Field | Value |
|-------|--------|
| **Filters** | `customer_id` (= point) |
| **Group by** | none |
| **Time range** | implicit “latest”; sort by `tx_time DESC` |
| **Frequency** | frequent (customer support / app history) |
| **Latency target** | tens of ms; must work on billions of rows |
| **Shape** | **point lookup** + ordered limit |
| **Key cardinalities** | one `customer_id`; ~10–10⁴ txs per customer |
| **Served by** | `tx_raw` with `ORDER BY (customer_id, tx_time, transaction_id)` |

---

## Q3 — Top 20 merchants (card payment amount)

| Field | Value |
|-------|--------|
| **Filters** | date range, `country`, `merchant_category` |
| **Group by** | `merchant_id` (rank by total amount) |
| **Time range** | days–months |
| **Frequency** | medium–frequent |
| **Latency target** | &lt; 1–2 s |
| **Shape** | aggregation + top-N |
| **Key cardinalities** | merchants medium; category/country low |
| **Served by** | `merchant_daily_agg` (card_payment only in MV) |

---

## Q4 — Branch performance

| Field | Value |
|-------|--------|
| **Filters** | `branch_id`, date (default last 30 days) |
| **Group by** | `branch_id`, `day` |
| **Time range** | ~30 days default |
| **Frequency** | medium (branch ops) |
| **Latency target** | &lt; 1–2 s |
| **Shape** | aggregation |
| **Key cardinalities** | branches low–medium; days small window |
| **Served by** | `branch_daily_agg` |

---

## Q5 — ATM fraud (hourly)

| Field | Value |
|-------|--------|
| **Filters** | `transaction_type = atm_withdrawal`, last 7 days; `HAVING` count &gt; 10 and total &gt; 5000 |
| **Group by** | `customer_id`, `account_id`, calendar `hour` |
| **Time range** | last 7 days |
| **Frequency** | medium (risk jobs / alerts) |
| **Latency target** | seconds OK; must not full-scan all history |
| **Shape** | aggregation + filter (`HAVING`) |
| **Key cardinalities** | many customers × ~168 hours; sparse ATM activity |
| **Served by** | `atm_hourly_agg` |

---

## Q6 — Country dashboard

| Field | Value |
|-------|--------|
| **Filters** | `country`, date range |
| **Group by** | panel-dependent: `day`; `transaction_type`; `merchant_id`; `branch_id` |
| **Time range** | days–months |
| **Frequency** | **frequent**, must be fast |
| **Latency target** | &lt; 1–2 s per panel |
| **Shape** | multi-panel aggregation / top-N |
| **Key cardinalities** | one country × days; tops over medium merchant/branch sets |
| **Served by** | compose `tx_daily_agg` + `merchant_daily_agg` + `country_branch_daily_agg` (not raw) |

---

## Summary: shape groups

| Shape | Queries | Implication |
|-------|---------|-------------|
| Point lookup | Q2 | Needs customer-leading `ORDER BY` on raw fact |
| Daily / dimensional agg | Q1, Q3, Q4, Q6 | Dedicated `AggregatingMergeTree` + MV |
| Hourly anomaly scan | Q5 | Narrow ATM-only hourly agg; thresholds in query |
| Multi-panel dashboard | Q6 | Reuse aggs; do not fight one `ORDER BY` on raw |
