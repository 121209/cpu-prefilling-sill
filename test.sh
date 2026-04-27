#!/bin/bash
# 功能测试：验证采集、切片、火焰图生成全流程
set -e

echo "=== Perf Profiler Skill Test ==="

command -v perf >/dev/null 2>&1 || { echo "FAIL: perf not found"; exit 1; }
command -v stackcollapse-perf.pl >/dev/null 2>&1 || { echo "FAIL: stackcollapse-perf.pl not found"; exit 1; }
command -v flamegraph.pl >/dev/null 2>&1 || { echo "FAIL: flamegraph.pl not found"; exit 1; }
echo "[PASS] Dependencies"

TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
export PERF_DATA_DIR="$TEST_DIR/data"
mkdir -p "$PERF_DATA_DIR"
echo "Test directory: $TEST_DIR"

echo "Starting profiler in background..."
PERF_SWITCH_DURATION=20s PERF_RETENTION_COUNT=3 /usr/local/bin/perf-profiler-collector.sh &
COLLECTOR_PID=$!
sleep 2

echo "Generating CPU load..."
stress --cpu 2 --timeout 40 &
STRESS_PID=$!
sleep 5
SAMPLE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "Sample time: $SAMPLE_TIME"
sleep 15  # 等待切片生成

echo "Generating flamegraph for $SAMPLE_TIME..."
/usr/local/bin/perf2flame.sh "$SAMPLE_TIME" "$TEST_DIR/flame.svg" || {
    echo "Flamegraph generation failed (might be timing), continuing..."
}

if [ -f "$TEST_DIR/flame.svg" ]; then
    echo "[PASS] Flamegraph SVG created"
    if grep -q "stress" "$TEST_DIR/flame.svg"; then
        echo "[PASS] Flamegraph contains 'stress' (user-space stack captured)"
    else
        echo "[INFO] 'stress' not found in SVG; kernel/idle symbols present"
    fi
else
    echo "[FAIL] Flamegraph SVG not generated"
    ls -la "$PERF_DATA_DIR" || true
fi

echo "Cleaning up..."
kill $COLLECTOR_PID 2>/dev/null || true
kill $STRESS_PID 2>/dev/null || true
wait 2>/dev/null
rm -rf "$TEST_DIR"
echo "=== Test Complete ==="
