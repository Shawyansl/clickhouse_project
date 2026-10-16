#!/usr/bin/env python3
"""Run saved serving queries and embedded raw baselines, recording ClickHouse metrics."""
from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import re
import subprocess
import sys
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "benchmarks" / "results"
CONTAINER = os.environ.get("CLICKHOUSE_CONTAINER", "clickhouse-course")
USER = os.environ.get("CLICKHOUSE_USER", "course")
PASSWORD = os.environ.get("CLICKHOUSE_PASSWORD", "course")


def client(sql: str, *, query_id: str | None = None, fmt: str = "TSVWithNames") -> str:
    cmd = ["docker", "exec", "-i", CONTAINER, "clickhouse-client", "--user", USER,
           "--password", PASSWORD, "--format", fmt]
    if query_id:
        cmd += ["--query_id", query_id]
    cmd += ["--query", sql]
    return subprocess.run(cmd, check=True, text=True, capture_output=True).stdout


def statements(section: str) -> list[str]:
    section = re.sub(r"(?m)^\s*--.*$", "", section)
    return [s.strip() for s in section.split(";") if s.strip()]


def run(label: str, sql: str) -> dict:
    qid = f"phase5_{label}_{uuid.uuid4().hex[:12]}"
    started = dt.datetime.now(dt.timezone.utc).isoformat()
    output = client(sql, query_id=qid, fmt="TabSeparatedWithNamesAndTypes")
    (OUT / f"{label}.out").write_text(output)
    client("SYSTEM FLUSH LOGS", fmt="Null")
    metric_sql = f"""SELECT query_id, query_duration_ms, read_rows, read_bytes,
result_rows, result_bytes, exception
FROM system.query_log
WHERE type = 'QueryFinish' AND query_id = '{qid}'
ORDER BY event_time_microseconds DESC LIMIT 1 FORMAT JSONEachRow"""
    rows = client(metric_sql, fmt="JSONEachRow").strip()
    metric = json.loads(rows) if rows else {"query_id": qid, "error": "No QueryFinish row found"}
    metric["label"] = label
    metric["recorded_at_utc"] = started
    (OUT / f"{label}.json").write_text(json.dumps(metric, indent=2) + "\n")
    print(json.dumps(metric))
    return metric


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    client("SELECT 1", fmt="Null")
    results = []
    for q in range(1, 7):
        matches = list((ROOT / "sql" / "queries").glob(f"q{q}_*.sql"))
        source = matches[0].read_text()
        parts = re.split(r"(?im)^\s*--\s*Naive baseline[^\n]*", source, maxsplit=1)
        optimized = statements(parts[0])
        baseline = statements(parts[1]) if len(parts) > 1 else []
        if q == 5:
            # The shipped sample data is fixed to September 2026. Keep Q5's
            # seven-day window inside that data range for a useful benchmark.
            optimized = [s.replace("toStartOfHour(now() - INTERVAL 7 DAY)",
                                    "toDateTime('2026-09-21 00:00:00')") for s in optimized]
            baseline = [s.replace("now() - INTERVAL 7 DAY",
                                  "toDateTime('2026-09-21 00:00:00')") for s in baseline]
        if q == 4:
            # Current date is after the generated September sample; benchmark
            # the same branch query over the sample's full month.
            optimized = [s.replace("day >= today() - 30",
                                    "day >= toDate('2026-09-01')") for s in optimized]
            baseline = [s.replace("toStartOfDay(today() - 30)",
                                  "toDateTime('2026-09-01 00:00:00')") for s in baseline]
        # Q6 is a multi-panel dashboard: measure each panel independently.
        for i, sql in enumerate(optimized, 1):
            label = f"q{q}_optimized" + (f"_panel{i}" if q == 6 else "")
            results.append(run(label, sql))
            explain = client("EXPLAIN indexes = 1 " + sql, fmt="TSVWithNames")
            (OUT / f"{label}_explain.txt").write_text(explain)
        for i, sql in enumerate(baseline, 1):
            label = f"q{q}_raw_baseline" + (f"_panel{i}" if q == 6 else "")
            results.append(run(label, sql))
    (OUT / "metrics.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"Saved outputs and metrics under {OUT}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as exc:
        print(exc.stderr or str(exc), file=sys.stderr)
        sys.exit(exc.returncode)
