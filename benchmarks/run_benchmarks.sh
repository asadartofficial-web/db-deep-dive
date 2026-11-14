#!/usr/bin/env bash
# Benchmark harness for the analysis query set.
#
# Usage:  ./run_benchmarks.sh <label>
# Example: ./run_benchmarks.sh before      # baseline, FK indexes only
#          ./run_benchmarks.sh after       # after adding candidate indexes
#
# Each run writes the full EXPLAIN (ANALYZE, BUFFERS) plan to
# output/<query>_<label>.txt and appends one summary row per query to
# results.csv. Plans are kept, not just timings: the plan is the evidence,
# the millisecond number is the summary.
set -u

PSQL="/c/Program Files/PostgreSQL/18/bin/psql.exe"
DB="stackexchange"
LABEL="${1:?usage: run_benchmarks.sh <label> (e.g. before, after)}"

cd "$(dirname "$0")"
mkdir -p output

CSV="results.csv"
if [ ! -f "$CSV" ]; then
  echo "query,label,planning_ms,execution_ms" > "$CSV"
fi

for q in ../sql/queries/q0*.sql; do
  name="$(basename "$q" .sql)"
  out="output/${name}_${LABEL}.txt"

  # Strip comment lines, flatten to one line, wrap in EXPLAIN.
  sql="$(grep -v '^\s*---' "$q" | tr '\n' ' ')"

  "$PSQL" -U postgres -h localhost -d "$DB" -qAt \
    -c "EXPLAIN (ANALYZE, BUFFERS) $sql" > "$out" 2>&1

  planning=$(grep 'Planning Time:' "$out" | tail -1 | sed 's/[^0-9.]//g')
  execution=$(grep 'Execution Time:' "$out" | tail -1 | sed 's/[^0-9.]//g')

  if [ -z "$execution" ]; then
    echo "$name: FAILED — see $out" >&2
    echo "$name,$LABEL,ERROR,ERROR" >> "$CSV"
  else
    echo "$name: ${execution} ms (planning ${planning:-0} ms)"
    echo "$name,$LABEL,${planning:-0},$execution" >> "$CSV"
  fi
done
