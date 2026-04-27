#!/usr/bin/env bash
set -euo pipefail

echo "=== Basic test: dependency, syntax and config check ==="

PASS_COUNT=0

pass() {
  echo "[PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

echo "[1/5] Check shell script syntax"
bash -n perf-profiler-collector.sh
bash -n perf2flame.sh
bash -n install.sh
bash -n uninstall.sh
bash -n test-e2e.sh
pass "Shell syntax"

echo "[2/5] Check required commands"
command -v bash >/dev/null
command -v date >/dev/null
command -v find >/dev/null
command -v stress >/dev/null
command -v stackcollapse-perf.pl >/dev/null
command -v flamegraph.pl >/dev/null
pass "Dependencies"

echo "[3/5] Check perf binary"
if [ -x /usr/local/bin/perf ]; then
  /usr/local/bin/perf --version
else
  perf --version
fi
pass "Perf binary"

echo "[4/5] Check config file"
test -f perf-profiler.conf
grep -q "PERF_FREQ" perf-profiler.conf
grep -q "PERF_SWITCH_DURATION" perf-profiler.conf
grep -q "PERF_RETENTION_COUNT" perf-profiler.conf
grep -q "PERF_DATA_DIR" perf-profiler.conf
grep -q "PERF_EVENT" perf-profiler.conf
grep -q "PERF_CALLGRAPH" perf-profiler.conf
pass "Config"

echo "[5/5] Check executable bits"
test -x perf-profiler-collector.sh
test -x perf2flame.sh
test -x install.sh
test -x uninstall.sh
test -x test-e2e.sh
pass "Executable permissions"

echo
echo "Basic test passed: ${PASS_COUNT}/5 checks passed"
echo "Note: perf recording is validated by ./test-e2e.sh because system-wide perf sampling requires sudo/root permission."
