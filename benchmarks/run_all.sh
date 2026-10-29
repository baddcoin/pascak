#!/data/data/com.termux/files/usr/bin/bash
# Run all benchmarks, produce summary
# Uses bash builtin `time` (portable, no /usr/bin/time dependency)

set -u
cd "$(dirname "$0")/.."

BIN="${PASCAK_BIN:-./pascak_noASTnet}"
if [ ! -x "$BIN" ]; then
  echo "ERROR: $BIN not executable" >&2
  echo "Set PASCAK_BIN=/path/to/pascak_noASTnet" >&2
  exit 1
fi

# Export for subprocess use
export PASCAK_EXEC_POLICY=allow-all
export PASCAK_BIN="$BIN"

WARMUP=1
RUNS=3

# Portable timer: use `date +%s%N` if supported, else `date +%s`
if date +%s%N 2>/dev/null | grep -qv 'N'; then
  TIME_CMD() { local t=$(date +%s%N); "$@" >/dev/null 2>&1; echo $((($(date +%s%N) - t) / 1000000)); }
else
  TIME_CMD() { local t=$(date +%s); "$@" >/dev/null 2>&1; echo $((($(date +%s) - t) * 1000)); }
fi

run_bench() {
  local name="$1"
  local file="$2"
  local ops="$3"

  echo "═══ $name ($ops ops) ═══"

  # warm-up
  for w in $(seq 1 $WARMUP); do
    "$BIN" --dev "$file" >/dev/null 2>&1 || { echo "  FAIL: warm-up exit $?"; return; }
  done

  # measure
  local times=()
  for r in $(seq 1 $RUNS); do
    local ms=$(TIME_CMD "$BIN" --dev "$file")
    times+=("$ms")
    echo "  run $r: ${ms} ms"
  done

  # compute median (sort, take middle)
  local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
  local mid=$((RUNS / 2))
  echo "  median: ${sorted[$mid]} ms"
  echo ""
}

echo "════════════════════════════════════════"
echo "Pascak VM Benchmark Suite — v1.8.0"
echo "Binary: $BIN"
echo "Runs: $RUNS + $WARMUP warm-up each"
echo "Date: $(date '+%Y-%m-%d %H:%M %Z')"
echo "════════════════════════════════════════"
echo ""

run_bench "VM arithmetic"     benchmarks/bench_arith.pas     "100K loops"
run_bench "Function calls"    benchmarks/bench_calls.pas     "100K calls"
run_bench "Dict set+get"      benchmarks/bench_dict.pas      "200K ops"
run_bench "Array push+iter"   benchmarks/bench_array.pas     "10K push + 10K iter"
run_bench "String concat"     benchmarks/bench_string.pas    "10K concat"
run_bench "JSON parse+stringify" benchmarks/bench_json.pas "1000 round-trips"

echo "═══ Parser (engine.pas compile) ═══"
if [ -f benchmarks/bench_parser.sh ]; then
  bash benchmarks/bench_parser.sh pascak_engine.pas 2>&1 | tail -10
fi
