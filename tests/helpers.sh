#!/data/data/com.termux/files/usr/bin/bash
# Shared helpers for tests/run.sh

set -u

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Find binary (repo root pascak_noASTnet, or PASCAK_BIN env)
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TESTS_DIR/.." && pwd)"
PASCAK_BIN="${PASCAK_BIN:-$REPO_DIR/pascak_noASTnet}"

# NOTE: /storage/emulated/0/ is mounted noexec — `test -x` on files there
# returns false even when mode bits are 111. Use `-f` (readable file exists),
# then copy to $HOME where exec works.
if [ ! -f "$PASCAK_BIN" ]; then
  echo -e "${RED}ERROR: pascak binary not found: $PASCAK_BIN${NC}" >&2
  echo "  Set PASCAK_BIN=/path/to/pascak_noASTnet" >&2
  exit 1
fi

# Copy to $HOME (executable — /storage/ = noexec)
HOME_BIN="$HOME/pascak_test"
if [ ! -f "$HOME_BIN" ] || [ "$PASCAK_BIN" -nt "$HOME_BIN" ]; then
  cp "$PASCAK_BIN" "$HOME_BIN"
  chmod +x "$HOME_BIN"
fi

# Verify HOME_BIN is actually executable (sanity)
if [ ! -x "$HOME_BIN" ]; then
  echo -e "${RED}ERROR: copy to $HOME_BIN failed or not executable${NC}" >&2
  exit 1
fi

# Run a test .pas file (from $HOME cwd for safe sandbox)
# Usage: run_pas_test <pas-file> <expected-marker>
run_pas_test() {
  local file="$1"
  local marker="${2:-}"
  local timeout="${TEST_TIMEOUT:-20}"
  local abs_file
  abs_file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"

  local out
  out=$(cd "$HOME" && timeout "$timeout" \
    env PASCAK_EXEC_POLICY=allow-all "$HOME_BIN" --dev "$abs_file" 2>&1)
  local exit=$?

  if [ $exit -ne 0 ]; then
    echo -e "${RED}FAIL${NC} $file (exit=$exit)"
    echo "$out" | head -5 | sed 's/^/    /'
    return 1
  fi

  if [ -n "$marker" ] && ! echo "$out" | grep -q "$marker"; then
    echo -e "${RED}FAIL${NC} $file (missing marker: '$marker')"
    echo "$out" | tail -3 | sed 's/^/    /'
    return 1
  fi

  echo -e "${GREEN}PASS${NC} $(basename "$file")"
  return 0
}
