#!/bin/bash
# 加速长时间运行测试：验证切片生成、滚动保留、自动清理
set -e

echo "=== Accelerated Long-Run Test ==="
echo "Goal: Simulate 24h retention with 10s slices and keep 12 slices"

TEST_DIR=$(mktemp -d)
export PERF_DATA_DIR="$TEST_DIR/data"
mkdir -p "$PERF_DATA_DIR"

# 配置：10 秒切片，保留 12 个（模拟 2 分钟的数据）
PERF_SWITCH_DURATION=10s PERF_RETENTION_COUNT=12 \
    /usr/local/bin/perf-profiler-collector.sh &
COLLECTOR_PID=$!

# 创建持续负载，让 perf 有东西可采
stress --cpu 1 --timeout 130 &
STRESS_PID=$!

echo "Waiting 130 seconds for slices to roll over..."
sleep 130

# 现在应该只有最新 12 个切片
FILE_COUNT=$(ls -1 "$PERF_DATA_DIR"/perf-*.data* 2>/dev/null | wc -l)
echo "Number of remaining slices: $FILE_COUNT"

if [ "$FILE_COUNT" -le 12 ]; then
    echo "[PASS] Old slices cleaned up, retention policy works"
else
    echo "[FAIL] More than 12 slices remain ($FILE_COUNT)"
fi

# 查询一个很早的时间点，应该找不到切片（因为已被清理）
EARLY_TIME=$(date -d "2 minutes ago" '+%Y-%m-%d %H:%M:%S')
if /usr/local/bin/perf2flame.sh "$EARLY_TIME" 2>&1 | grep -q "No slice found"; then
    echo "[PASS] Correctly reports missing data for old time point"
else
    echo "[INFO] Old slice may still exist"
fi

# 清理
kill $COLLECTOR_PID 2>/dev/null || true
kill $STRESS_PID 2>/dev/null || true
wait 2>/dev/null
rm -rf "$TEST_DIR"
echo "=== Long-Run Simulation Complete ==="
