#!/data/data/com.termux/files/usr/bin/bash
# Unified test runner for Pascak VM
# Usage:
#   ./tests/run.sh                    # run all (lang + integration)
#   ./tests/run.sh lang               # language tests only
#   ./tests/run.sh integration        # integration tests only
#   ./tests/run.sh <file.pas>         # run single file
#   PASCAK_BIN=/path/to/bin ./tests/run.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/helpers.sh"

PASS=0
FAIL=0
FAILED_FILES=()

# ── Language tests (deterministic, no external deps) ──
run_lang_tests() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE} Language Tests${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"

  # Marker per file (must contain this string in output)
  declare -A markers=(
    [phase1_optchain_nullcoalesce.pas]="false ?? 42"
    [phase2_enum.pas]="Color.Red"
    [phase3_destructure.pas]="pi_val"
    [v120_defaults_enumscope.pas]="getC"
    [v121_array_rest.pas]="tail2"
    [v121_enum_iter.pas]="Green"
    [v122_nested_1level.pas]="N10"
    [v123_nested_2level.pas]="R3"
    [v124_arbitrary_depth.pas]="R3"
    [v124_array_root_nested.pas]="R4"
    [v125_object_rest.pas]="R3"
    [v126_rest_in_nested.pas]="R5"
    [v127_optional_method.pas]="R3"
    [v160_param_destructure.pas]="mixed"
    [v161_rest_in_param.pas]="reg(no rest)"
    [v162_nullsafe_assign.pas]="o2.y"
  )

  for file in "$TESTS_DIR"/lang/*.pas; do
    [ -f "$file" ] || continue
    local base
    base=$(basename "$file")
    local marker="${markers[$base]:-}"
    if run_pas_test "$file" "$marker"; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1))
      FAILED_FILES+=("lang/$base")
    fi
  done
}

# ── Integration tests (need mock servers, GUI, network) ──
run_integration_tests() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE} Integration Tests${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${YELLOW}SKIP${NC} (integration tests require manual mock server setup; see tests/README.md)"
  echo "  - h2_*.pas:      need tests/fixtures/mock_server.py running"
  echo "  - hotreload_*.pas: need file watcher trigger"
  echo "  - lsp_sighelp.py:  need Python h2 + LSP client"
  echo ""
  echo "  Run manually:"
  echo "    python3 tests/fixtures/mock_server.py &"
  echo "    ./tests/run.sh integration/manual"
}

# ── Run single file ──
run_single() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "ERROR: file not found: $file"
    exit 1
  fi
  echo ""
  echo -e "${BLUE}Running: $file${NC}"
  if run_pas_test "$file" ""; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
}

# ── Main dispatch ──
MODE="${1:-all}"

case "$MODE" in
  lang)         run_lang_tests ;;
  integration)  run_integration_tests ;;
  all)          run_lang_tests; run_integration_tests ;;
  *.pas)        run_single "$MODE" ;;
  *)
    echo "Usage: $0 {all|lang|integration|<file.pas>}"
    exit 1
    ;;
esac

# ── Summary ──
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "  PASS: ${GREEN}$PASS${NC}  FAIL: ${RED}$FAIL${NC}"
if [ ${#FAILED_FILES[@]} -gt 0 ]; then
  echo -e "  ${RED}Failed files:${NC}"
  for f in "${FAILED_FILES[@]}"; do
    echo "    - $f"
  done
fi
echo -e "${BLUE}════════════════════════════════════════${NC}"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
