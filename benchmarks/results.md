# Phase 5 — Query benchmarks

## How to reproduce

Start the ClickHouse container, ensure Phase 4 data is loaded, then run:

```bash
python3 benchmarks/run_phase5.py
```

The runner executes each serving query and embedded raw-table baseline, records `query_duration_ms`, `read_rows`, and `read_bytes` from `system.query_log`, and saves `EXPLAIN indexes = 1` output for the serving queries. Q6 panels are measured separately. The saved queries anchor their rolling windows to the latest date in the loaded data, so the sample dates do not go stale as the calendar advances.

## Results

The table below records the latest run on the local 1,000,300-row dataset. Run the benchmark command above to refresh the raw outputs and metrics under `benchmarks/results/`; the runner does not edit this Markdown summary automatically.

| Query | Serving table | Serving duration (ms) | Serving rows read | Serving bytes read | Raw duration (ms) | Raw rows read | Raw bytes read | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| Q1 | `tx_daily_agg` | 39 | 724 | 148,643 | 40 | 1,000,304 | 32,001,052 | Aggregate read about 1,380× fewer rows; elapsed times were similar at this scale. |
| Q2 | `tx_raw` | 3 | 16,384 | 187,450 | N/A | N/A | N/A | 10 rows returned for customer 12345; the sample has fewer than 100 transactions for this customer. |
| Q3 | `merchant_daily_agg` | 12 | 15,002 | 2,096,840 | 36 | 1,000,304 | 33,195,144 | Aggregate read about 67× fewer rows and ran faster. |
| Q4 | `branch_daily_agg` | 13 | 1,802 | 270,032 | 30 | 1,000,002 | 25,000,048 | Aggregate read about 555× fewer rows and ran faster. |
| Q5 | `atm_hourly_agg` | 4 | 22 | 928 | 5 | 302 | 8,778 | Aggregate read about 14× fewer rows; both returned 20 seeded hotspots. |
| Q6 | multiple aggregate tables | Panel 1: 32; P2: 5; P3: 5; P4: 5 | P1: 725; P2: 725; P3: 15,002; P4: 1,824 | P1: 83,055; P2: 20,449; P3: 776,840; P4: 56,560 | 21 (daily panel) | 1,000,304 | 21,006,414 | Four panels measured separately; raw baseline covers only daily panel. |

## Interpretation

The aggregate tables greatly reduce rows and bytes read for Q1 and Q3–Q6. Q3, Q4, and Q5 completed faster than their raw baselines in this run. Q1 and Q6's daily panel were roughly even or slower despite reading much less data. With about one million rows, query startup, aggregation overhead, and cache state still affect elapsed time. Q2 is organized for customer lookups and completed quickly, but the chosen customer has only 10 sample transactions, not the requested 100.

Treat durations as one-run observations, not stable latency guarantees. Hardware, cache state, concurrent load, and dataset size affect them; repeat warm and cold runs before drawing precise timing conclusions. The row and byte counts are the stronger evidence at this small scale.

## Data caveat

This run used the expected 1,000,300 rows: one million generated transactions plus 300 fraud examples. The generated portion spans September 1–12; the fraud seed supplies September 28 rows. The Phase 4 loader now checks for existing raw rows and refuses another load. The current queries select date windows relative to the latest records, so they keep returning data even though this sample is from September 2026.
