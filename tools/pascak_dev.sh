#!/data/data/com.termux/files/usr/bin/bash
# pascak_dev.sh — auto-restart wrapper for hot-reload development
#
# Usage:
#   tools/pascak_dev.sh <watch-spec> <script.pas> [extra pascak args]
#
# Examples:
#   tools/pascak_dev.sh . app.pas
#   tools/pascak_dev.sh "src/,lib/,app.pas" app.pas
#   tools/pascak_dev.sh . app.pas --hot
#
# Features:
#   - Graceful shutdown (v1.7.0 IsShuttingDown) with clean WS/H2 close
#   - Restart delay (default 1s) to let ports free up (avoids TIME_WAIT)
#   - Colored status output
#   - Ctrl+C exits cleanly (SIGTERM forwarded to child)
#   - Exit code 0 (file change) -> auto-restart
#   - Exit code 1 (script error) -> show error, wait, restart
#   - Exit code 130 (Ctrl+C) -> clean exit

set -u

PASCAK_BIN="${PASCAK_BIN:-$(command -v pascak || echo ./pascak_noASTnet)}"
RESTART_DELAY="${RESTART_DELAY:-1}"
WATCH_SPEC="${1:-.}"
SCRIPT="${2:-app.pas}"
shift 2 2>/dev/null || true
EXTRA_ARGS=("$@")

if [ ! -x "$PASCAK_BIN" ]; then
  echo "ERROR: pascak binary not found or not executable: $PASCAK_BIN" >&2
  echo "Set PASCAK_BIN=/path/to/pascak_noASTnet" >&2
  exit 1
fi

if [ ! -f "$SCRIPT" ]; then
  echo "ERROR: script not found: $SCRIPT" >&2
  exit 1
fi

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CHILD_PID=""

cleanup() {
  echo -e "\n${YELLOW}[dev] Ctrl+C — shutting down${NC}"
  if [ -n "$CHILD_PID" ] && kill -0 "$CHILD_PID" 2>/dev/null; then
    kill -TERM "$CHILD_PID" 2>/dev/null
    wait "$CHILD_PID" 2>/dev/null
  fi
  exit 130
}

trap cleanup INT TERM

RUN=0
while true; do
  RUN=$((RUN + 1))
  echo -e "${BLUE}[dev] run #$RUN — watching: $WATCH_SPEC${NC}"

  env PASCAK_EXEC_POLICY=allow-all \
    "$PASCAK_BIN" --dev --watch "$WATCH_SPEC" "$SCRIPT" "${EXTRA_ARGS[@]}" &
  CHILD_PID=$!
  wait "$CHILD_PID"
  EXIT_CODE=$?
  CHILD_PID=""

  case "$EXIT_CODE" in
    0)
      echo -e "${GREEN}[dev] file change detected — restarting in ${RESTART_DELAY}s${NC}"
      ;;
    1|2)
      echo -e "${RED}[dev] script error (exit $EXIT_CODE) — restarting in ${RESTART_DELAY}s${NC}"
      echo -e "${YELLOW}[dev] fix the error or Ctrl+C to abort${NC}"
      ;;
    130|143)
      echo -e "${YELLOW}[dev] terminated by signal — exiting${NC}"
      exit 0
      ;;
    *)
      echo -e "${YELLOW}[dev] exit $EXIT_CODE — restarting in ${RESTART_DELAY}s${NC}"
      ;;
  esac

  sleep "$RESTART_DELAY"
done
