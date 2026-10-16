# Phase 5 — Query benchmarks

## How to reproduce

Start the ClickHouse container, ensure Phase 4 data is loaded, then run:

```bash
python3 benchmarks/run_phase5.py
```

The runner executes each serving query and embedded raw-table baseline, records `query_duration_ms`, `read_rows`, and `read_bytes` from `system.query_log`, and saves `EXPLAIN indexes = 1` output for the serving queries. Q6 panels are measured separately. Q4 and Q5 use benchmark-only date windows inside the September sample period; the saved application queries keep their relative date filters.

## Results

Run the benchmark runner to populate this section and `benchmarks/results/` with raw outputs and metrics.

| Query | Serving table | Serving duration (ms) | Serving rows read | Serving bytes read | Raw duration (ms) | Raw rows read | Raw bytes read | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| Q1 | `tx_daily_agg` | 37 | 1,440 | 297,158 | 31 | 2,000,000 | 64,000,000 | Aggregate cuts scanned rows sharply; on this small, warm run the raw query was slightly faster. |
| Q2 | `tx_raw` | 4 | 32,768 | 374,900 | N/A | N/A | N/A | 20 rows returned for customer 12345. No separate raw baseline is defined. |
| Q3 | `merchant_daily_agg` | 10 | 30,000 | 4,198,616 | 25 | 2,000,000 | 66,388,800 | Aggregate read about 67× fewer rows and ran faster. |
| Q4 | `branch_daily_agg` | 13 | 3,600 | 540,000 | 12 | 2,000,000 | 50,000,000 | Aggregate read about 556× fewer rows; elapsed times were similar at this scale. |
| Q5 | `atm_hourly_agg` | 3 | 40 | 1,760 | 4 | 600 | 17,460 | Aggregate read 15× fewer rows; both returned 20 seeded hotspots. |
| Q6 | multiple aggregate tables | Panel 1: 27; P2: 4; P3: 5; P4: 3 | P1: 1,442; P2: 1,442; P3: 30,000; P4: 1,820 | P1: 165,982; P2: 40,770; P3: 1,553,616; P4: 56,478 | 37 (daily panel) | 2,000,600 | 42,012,636 | Four panels measured separately; raw baseline covers only daily panel. |

## Interpretation

The aggregate tables greatly reduce rows and bytes read for Q1 and Q3–Q6. Q3, Q5, and Q6's daily panel were also faster in this run. Q1 and Q4 had comparable or slower elapsed times despite much lower reads; with only about two million rows, query startup, aggregation overhead, and cache state are a large share of runtime. Q2 is already organized for customer lookups and completed quickly, but the sample returns only 20 rows for the chosen customer, not the requested 100.

Treat durations as one-run observations, not stable latency guarantees. Hardware, cache state, concurrent load, and dataset size affect them; repeat warm and cold runs before drawing precise timing conclusions. The row and byte counts are the stronger evidence at this small scale.

## Data caveat

At the time of this run, `tx_raw` contains 2,000,600 rows rather than the expected 1,000,300. The Phase 4 script inserts another full dataset when rerun, while its DDL uses `IF NOT EXISTS`. This makes data loading non-idempotent and duplicates the synthetic records. The generated million-row portion spans September 1–12; the separate fraud seed supplies September 28 rows. Q4 and Q5 benchmark windows were adjusted to overlap those records without changing the saved application queries. The benchmark results describe the current 2,000,600-row dataset.
