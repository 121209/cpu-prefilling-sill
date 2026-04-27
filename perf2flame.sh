#!/usr/bin/env bash
set -euo pipefail

TIME_INPUT="${1:?Usage: $0 'YYYY-MM-DD HH:MM:SS' [output.svg]}"
OUTPUT="${2:-./flamegraph.svg}"

DATA_DIR="${PERF_DATA_DIR:-/var/cache/perf-profiler}"
SWITCH_DURATION="${PERF_SWITCH_DURATION:-300s}"
PERF_BIN="${PERF_BIN:-/usr/local/bin/perf}"

if [ -f /etc/perf-profiler.conf ]; then
  # shellcheck disable=SC1091
  source /etc/perf-profiler.conf
fi

if [ ! -x "$PERF_BIN" ]; then
  if command -v perf >/dev/null 2>&1; then
    PERF_BIN="$(command -v perf)"
  else
    echo "Need perf. Tried: $PERF_BIN"
    exit 1
  fi
fi

command -v stackcollapse-perf.pl >/dev/null || { echo "Need stackcollapse-perf.pl"; exit 1; }
command -v flamegraph.pl >/dev/null || { echo "Need flamegraph.pl"; exit 1; }

duration_to_seconds() {
  local d="$1"
  case "$d" in
    *s) echo "${d%s}" ;;
    *m) echo "$(( ${d%m} * 60 ))" ;;
    *h) echo "$(( ${d%h} * 3600 ))" ;;
    *) echo "$d" ;;
  esac
}

TARGET_EPOCH="$(date -d "$TIME_INPUT" +%s)"
DURATION_SEC="$(duration_to_seconds "$SWITCH_DURATION")"
NOW_EPOCH="$(date +%s)"

SELECTED=""

shopt -s nullglob
FILES=("$DATA_DIR"/perf-*.data)
shopt -u nullglob

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No perf data files found in $DATA_DIR"
  exit 1
fi

for f in "${FILES[@]}"; do
  base="$(basename "$f")"

  if [[ "$base" =~ perf-([0-9]{8})\.([0-9]{6})\.data ]]; then
    date_part="${BASH_REMATCH[1]}"
    time_part="${BASH_REMATCH[2]}"

    start_epoch="$(date -d "${date_part} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}" +%s)"
    end_epoch="$((start_epoch + DURATION_SEC))"

    # 跳过仍在写入或刚刚结束的切片，避免 perf script 解析 data size = 0 的文件
    if [ "$NOW_EPOCH" -lt "$((end_epoch + 3))" ]; then
      continue
    fi

    if [ "$TARGET_EPOCH" -ge "$start_epoch" ] && [ "$TARGET_EPOCH" -lt "$end_epoch" ]; then
      SELECTED="$f"
      break
    fi

    # 如果目标时间晚于该切片，则记录一个最近的已完成切片作为兜底
    if [ "$start_epoch" -le "$TARGET_EPOCH" ]; then
      SELECTED="$f"
    fi
  fi
done

if [ -z "$SELECTED" ]; then
  echo "No completed slice found for $TIME_INPUT"
  echo "Available slices:"
  ls -lh "$DATA_DIR" || true
  echo
  echo "Hint: wait for the current perf slice to finish, or query a time at least 30 seconds ago."
  exit 1
fi

echo "Using slice: $SELECTED"

TMP_PERF_SCRIPT="$(mktemp)"
TMP_FOLDED="$(mktemp)"

"$PERF_BIN" script -i "$SELECTED" > "$TMP_PERF_SCRIPT"

if [ ! -s "$TMP_PERF_SCRIPT" ]; then
  echo "perf script output is empty."
  echo "Possible reasons:"
  echo "  1. perf did not capture samples."
  echo "  2. WSL2 perf support is limited."
  echo "  3. The selected time slice has no CPU activity."
  rm -f "$TMP_PERF_SCRIPT" "$TMP_FOLDED"
  exit 1
fi

stackcollapse-perf.pl "$TMP_PERF_SCRIPT" > "$TMP_FOLDED"
flamegraph.pl --title "CPU Flame @ $TIME_INPUT" "$TMP_FOLDED" > "$OUTPUT"

rm -f "$TMP_PERF_SCRIPT" "$TMP_FOLDED"

echo "Flamegraph saved to $OUTPUT"
