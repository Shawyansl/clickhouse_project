#!/usr/bin/env bash
# Apply DDL, load ~1M rows + fraud hotspots, run sanity checks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CH=(docker exec -i clickhouse-course clickhouse-client --user course --password course --multiquery)

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

echo "==> Generating 1M rows (may take a minute)"
"${CH[@]}" < "$ROOT/data_gen/generate_1m.sql"

echo "==> Seeding Q5 fraud hotspots"
"${CH[@]}" < "$ROOT/data_gen/seed_fraud_hotspots.sql"

echo "==> Sanity checks"
"${CH[@]}" < "$ROOT/data_gen/sanity_checks.sql"

echo "==> Phase 4 load complete"
