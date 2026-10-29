#!/data/data/com.termux/files/usr/bin/bash
# Parser benchmark — time to parse pascak_engine.pas (~47K lines)
# Portable timing (no /usr/bin/time dependency)

set -u
cd "$(dirname "$0")/.."

BIN="${PASCAK_BIN:-./pascak_noASTnet}"
SRC="${1:-pascak_engine.pas}"

if [ ! -f "$SRC" ]; then
  echo "ERROR: $SRC not found" >&2
  exit 1
fi
if [ ! -x "$BIN" ]; then
  echo "ERROR: $BIN not executable" >&2
  exit 1
fi

echo "File: $SRC — $(wc -l < "$SRC") lines, $(wc -c < "$SRC") bytes"

time_ms() {
  local t0=$(date +%s%N)
  env PASCAK_EXEC_POLICY=allow-all "$BIN" --dev --check "$SRC" >/dev/null 2>&1
  local t1=$(date +%s%N)
  echo $(( (t1 - t0) / 1000000 ))
}

# Warm-up (bytecode cache priming)
echo -n "Warm-up... "
time_ms >/dev/null
echo "done"

# Measure 3 runs
echo ""
echo "Runs (wall clock, ms):"
TIMES=()
for i in 1 2 3; do
  MS=$(time_ms)
  TIMES+=("$MS")
  echo "  run $i: ${MS} ms"
done

SORTED=($(printf '%s\n' "${TIMES[@]}" | sort -n))
echo "  median: ${SORTED[1]} ms"
