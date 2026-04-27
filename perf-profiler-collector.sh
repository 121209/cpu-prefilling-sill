#!/usr/bin/env bash
set -euo pipefail

# Default config
FREQ="${PERF_FREQ:-49}"
SWITCH_DURATION="${PERF_SWITCH_DURATION:-300s}"
RETENTION_COUNT="${PERF_RETENTION_COUNT:-288}"
DATA_DIR="${PERF_DATA_DIR:-/var/cache/perf-profiler}"
EVENT="${PERF_EVENT:-cpu-clock}"
CALLGRAPH="${PERF_CALLGRAPH:-fp}"
PERF_BIN="${PERF_BIN:-/usr/local/bin/perf}"

# Load centralized config
if [ -f /etc/perf-profiler.conf ]; then
  # shellcheck disable=SC1091
  source /etc/perf-profiler.conf
fi

if [ ! -x "$PERF_BIN" ]; then
  if command -v perf >/dev/null 2>&1; then
    PERF_BIN="$(command -v perf)"
  else
    echo "[collector] ERROR: perf not found"
    exit 1
  fi
fi

mkdir -p "$DATA_DIR"

duration_to_seconds() {
  local d="$1"
  case "$d" in
    *s) echo "${d%s}" ;;
    *m) echo "$(( ${d%m} * 60 ))" ;;
    *h) echo "$(( ${d%h} * 3600 ))" ;;
    *) echo "$d" ;;
  esac
}

DURATION_SEC="$(duration_to_seconds "$SWITCH_DURATION")"

cleanup_old_files() {
  ls -1t "$DATA_DIR"/perf-*.data 2>/dev/null \
    | tail -n +"$((RETENTION_COUNT + 1))" \
    | xargs -r rm -f
}

echo "[collector] start perf blackbox collector"
echo "[collector] data dir        : $DATA_DIR"
echo "[collector] perf bin        : $PERF_BIN"
echo "[collector] freq            : $FREQ"
echo "[collector] event           : $EVENT"
echo "[collector] callgraph       : $CALLGRAPH"
echo "[collector] slice duration  : ${DURATION_SEC}s"
echo "[collector] retention count : $RETENTION_COUNT"

trap 'echo "[collector] stopped"; exit 0' INT TERM

while true; do
  TS="$(date +%Y%m%d.%H%M%S)"
  OUT_FILE="$DATA_DIR/perf-${TS}.data"

  echo "[collector] recording slice: $OUT_FILE"

  "$PERF_BIN" record \
    -F "$FREQ" \
    -a \
    -g \
    -e "$EVENT" \
    --call-graph "$CALLGRAPH" \
    -o "$OUT_FILE" \
    -- sleep "$DURATION_SEC" || {
      echo "[collector] perf record failed, retry after 5s"
      sleep 5
      continue
    }

  cleanup_old_files
done
