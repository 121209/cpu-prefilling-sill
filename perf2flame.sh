#!/bin/bash
TIME_INPUT="${1:?Usage: $0 'YYYY-MM-DD HH:MM:SS' [output.svg]}"
OUTPUT="${2:-/tmp/flamegraph_$(date +%Y%m%d%H%M%S).svg}"
DATA_DIR="${PERF_DATA_DIR:-/var/cache/perf-profiler}"

command -v perf &>/dev/null || { echo "Need perf"; exit 1; }
command -v stackcollapse-perf.pl &>/dev/null || { echo "Need stackcollapse-perf.pl"; exit 1; }
command -v flamegraph.pl &>/dev/null || { echo "Need flamegraph.pl"; exit 1; }

TARGET_EPOCH=$(date -d "$TIME_INPUT" +%s)
FILES=($(ls -1 "$DATA_DIR"/perf-*.data* 2>/dev/null | sort))
SELECTED=""
for f in "${FILES[@]}"; do
    base=$(basename "$f")
    if [[ $base =~ perf-([0-9]{8}\.[0-9]{6}) ]]; then
        ts_str="${BASH_REMATCH[1]}"
        f_ts=$(date -d "${ts_str:0:8} ${ts_str:9:2}:${ts_str:11:2}:${ts_str:13:2}" +%s)
        [ "$f_ts" -le "$TARGET_EPOCH" ] && SELECTED="$f" || break
    fi
done

[ -z "$SELECTED" ] && { echo "No slice found for $TIME_INPUT"; exit 1; }
echo "Using slice: $SELECTED"

TEMP_SCRIPT=$(mktemp)
if [[ "$SELECTED" == *.zst ]]; then
    zstd -d -c "$SELECTED" | perf script -i - > "$TEMP_SCRIPT"
elif [[ "$SELECTED" == *.gz ]]; then
    gunzip -c "$SELECTED" | perf script -i - > "$TEMP_SCRIPT"
else
    perf script -i "$SELECTED" > "$TEMP_SCRIPT"
fi

stackcollapse-perf.pl "$TEMP_SCRIPT" | flamegraph.pl --title "CPU Flame @ $TIME_INPUT" > "$OUTPUT"
rm -f "$TEMP_SCRIPT"
echo "Flamegraph saved to $OUTPUT"
