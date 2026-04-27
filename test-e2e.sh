#!/usr/bin/env bash
set -euo pipefail

echo "=== E2E test: perf blackbox collector + flamegraph ==="

DATA_DIR="/var/cache/perf-profiler"
OUT_SVG="./flame-e2e-result.svg"
LOG_FILE="./test-e2e-results.txt"

sudo pkill -f perf-profiler-collector.sh 2>/dev/null || true
sudo pkill -f "perf record" 2>/dev/null || true

sudo rm -rf "$DATA_DIR"
sudo mkdir -p "$DATA_DIR"
rm -f "$OUT_SVG" "$LOG_FILE"

echo "[1/6] Check dependencies"
command -v /usr/local/bin/perf
command -v stackcollapse-perf.pl
command -v flamegraph.pl
command -v stress

echo "[2/6] Start collector in background"
sudo PERF_SWITCH_DURATION=20s \
     PERF_RETENTION_COUNT=8 \
     PERF_DATA_DIR="$DATA_DIR" \
     PERF_BIN="/usr/local/bin/perf" \
     /usr/local/bin/perf-profiler-collector.sh \
     > /tmp/perf-profiler-e2e.log 2>&1 &

COLLECTOR_PID=$!

cleanup() {
  sudo kill "$COLLECTOR_PID" 2>/dev/null || true
  sudo pkill -f perf-profiler-collector.sh 2>/dev/null || true
  sudo pkill -f "perf record" 2>/dev/null || true
}
trap cleanup EXIT

sleep 5

if ! ps -p "$COLLECTOR_PID" >/dev/null 2>&1; then
  echo "Collector failed to start"
  cat /tmp/perf-profiler-e2e.log
  exit 1
fi

echo "[3/6] Generate CPU workload"
stress --cpu 2 --timeout 70 &
STRESS_PID=$!

wait "$STRESS_PID" || true

echo "[4/6] Wait for perf slices to finish"
sleep 35

echo "[5/6] List perf slices"
sudo ls -lh "$DATA_DIR"

mapfile -t SLICES < <(sudo find "$DATA_DIR" -maxdepth 1 -type f -name 'perf-*.data' | sort)

if [ "${#SLICES[@]}" -lt 2 ]; then
  echo "Not enough perf slices generated"
  echo "Collector log:"
  cat /tmp/perf-profiler-e2e.log
  exit 1
fi

# 选择倒数第二个切片，避免选中正在写入的最后一个切片
SELECTED_SLICE="${SLICES[$((${#SLICES[@]} - 2))]}"
SLICE_BASE="$(basename "$SELECTED_SLICE")"

if [[ "$SLICE_BASE" =~ perf-([0-9]{8})\.([0-9]{6})\.data ]]; then
  DATE_PART="${BASH_REMATCH[1]}"
  TIME_PART="${BASH_REMATCH[2]}"

  START_EPOCH="$(date -d "${DATE_PART} ${TIME_PART:0:2}:${TIME_PART:2:2}:${TIME_PART:4:2}" +%s)"
  SAMPLE_EPOCH="$((START_EPOCH + 5))"
  SAMPLE_TIME="$(date -d "@$SAMPLE_EPOCH" '+%Y-%m-%d %H:%M:%S')"
else
  echo "Failed to parse slice filename: $SLICE_BASE"
  exit 1
fi

echo "selected_slice=$SELECTED_SLICE"
echo "sample_time=$SAMPLE_TIME"

echo "[6/6] Generate flamegraph"
sudo PERF_SWITCH_DURATION=20s \
     PERF_DATA_DIR="$DATA_DIR" \
     PERF_BIN="/usr/local/bin/perf" \
     perf2flame.sh "$SAMPLE_TIME" "$OUT_SVG"

if [ ! -s "$OUT_SVG" ]; then
  echo "Flamegraph was not generated"
  exit 1
fi

ls -lh "$OUT_SVG"

{
  echo "E2E test passed"
  echo "sample_time=$SAMPLE_TIME"
  echo "selected_slice=$SELECTED_SLICE"
  echo "output_svg=$OUT_SVG"
  echo
  echo "perf slices:"
  sudo ls -lh "$DATA_DIR"
  echo
  echo "flamegraph:"
  ls -lh "$OUT_SVG"
  echo
  echo "collector log tail:"
  tail -n 20 /tmp/perf-profiler-e2e.log || true
} | tee "$LOG_FILE"

echo "=== E2E test passed ==="
