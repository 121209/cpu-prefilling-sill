#!/bin/bash
set -euo pipefail

# 默认配置
FREQ=${PERF_FREQ:-49}
SWITCH_DURATION=${PERF_SWITCH_DURATION:-5m}
RETENTION_COUNT=${PERF_RETENTION_COUNT:-288}
DATA_DIR=${PERF_DATA_DIR:-/var/cache/perf-profiler}
COMPRESS=${PERF_COMPRESS:-zstd}

# 读取外部配置文件覆盖
[ -f /etc/perf-profiler.conf ] && source /etc/perf-profiler.conf

mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

exec perf record \
    -F "$FREQ" \
    -g \
    --call-graph dwarf,fp,stack \
    --switch-output="$SWITCH_DURATION" \
    --timestamp \
    -e cpu-clock \
    --compression="$COMPRESS" \
    -o perf- &
PID=$!

# 清理旧切片，保留最新的 RETENTION_COUNT 个
cleanup() {
    while true; do
        ls -1t perf-*.data* 2>/dev/null | tail -n +$((RETENTION_COUNT+1)) | xargs -r rm -f
        sleep 60
    done
}
cleanup &
CLEAN_PID=$!

wait $PID
kill $CLEAN_PID 2>/dev/null || true
