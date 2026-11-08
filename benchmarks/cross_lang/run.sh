#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASCAK_BIN="${PASCAK_BIN:-pascak}"

bench() {
  local name="$1"; shift
  local start=$(date +%s%N)
  "$@" > /dev/null 2>&1
  local end=$(date +%s%N)
  local ms=$(( (end - start) / 1000000 ))
  printf "%-10s %6d ms\n" "$name:" "$ms"
}

echo "=== Test 1: Startup Time (minimal script) ==="
bench "Pascak" "$PASCAK_BIN" "$SCRIPT_DIR/startup.pas"
command -v python3 &>/dev/null && bench "Python" python3 "$SCRIPT_DIR/startup.py"
command -v node &>/dev/null && bench "Node" node "$SCRIPT_DIR/startup.js"
for L in lua lua5.4; do
  command -v "$L" &>/dev/null && { bench "Lua" $L "$SCRIPT_DIR/startup.lua"; break; }
done
echo ""

echo "=== Test 2: Arithmetic Loop (1M iterations) ==="
bench "Pascak" "$PASCAK_BIN" "$SCRIPT_DIR/arith.pas"
command -v python3 &>/dev/null && bench "Python" python3 "$SCRIPT_DIR/arith.py"
command -v node &>/dev/null && bench "Node" node "$SCRIPT_DIR/arith.js"
for L in lua lua5.4; do
  command -v "$L" &>/dev/null && { bench "Lua" $L "$SCRIPT_DIR/arith.lua"; break; }
done
