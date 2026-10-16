#!/usr/bin/env bash
# Apply DDL, load TX_ROWS synthetic transactions + fraud hotspots, run checks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CH=(docker exec -i clickhouse-course clickhouse-client --user course --password course --multiquery)
TX_ROWS="${TX_ROWS:-1000000}"
MAX_TX_ROWS=100000000

if [[ ! "$TX_ROWS" =~ ^[1-9][0-9]*$ ]] || (( TX_ROWS > MAX_TX_ROWS )); then
  echo "TX_ROWS must be a positive integer no greater than $MAX_TX_ROWS." >&2
  exit 2
fi

if ! docker exec clickhouse-course clickhouse-client --user course --password course --query 'SELECT 1' >/dev/null; then
  echo "ClickHouse is not reachable. Start it first with: docker compose up -d" >&2
  exit 1
fi

# MergeTree does not enforce uniqueness. Refuse a second load before applying
# DDL or inserting anything; otherwise each rerun duplicates the sample data.
TABLE_EXISTS="$(docker exec clickhouse-course clickhouse-client --user course --password course --query 'EXISTS TABLE clickhouse_course.tx_raw')"
if [[ "$TABLE_EXISTS" == "1" ]]; then
  RAW_ROWS="$(docker exec clickhouse-course clickhouse-client --user course --password course --query 'SELECT count() FROM clickhouse_course.tx_raw')"
  if (( RAW_ROWS > 0 )); then
    echo "Refusing to load: clickhouse_course.tx_raw already contains $RAW_ROWS rows." >&2
    echo "To start over, first remove the ClickHouse volume with 'docker compose down -v', then run 'docker compose up -d'. This permanently deletes database data." >&2
    exit 3
  fi
fi

echo "==> Applying DDL"
for f in \
  "$ROOT/sql/ddl/01_tx_raw.sql" \
  "$ROOT/sql/ddl/02_tx_daily_agg.sql" \
  "$ROOT/sql/ddl/03_tx_daily_mv.sql" \
  "$ROOT/sql/ddl/04_merchant_daily_agg.sql" \
  "$ROOT/sql/ddl/05_branch_daily_agg.sql" \
  "$ROOT/sql/ddl/06_atm_hourly_agg.sql" \
  "$ROOT/sql/ddl/07_country_branch_daily_agg.sql"
do
  echo "    $f"
  "${CH[@]}" < "$f"
done

echo "==> Generating $TX_ROWS rows (larger loads can take a while)"
"${CH[@]}" --param_rows="$TX_ROWS" < "$ROOT/data_gen/generate_1m.sql"

echo "==> Seeding Q5 fraud hotspots"
"${CH[@]}" < "$ROOT/data_gen/seed_fraud_hotspots.sql"

echo "==> Sanity checks"
"${CH[@]}" < "$ROOT/data_gen/sanity_checks.sql"

echo "==> Phase 4 load complete"
