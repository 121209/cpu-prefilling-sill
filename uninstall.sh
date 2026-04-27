#!/bin/bash
set -e

echo "=== Uninstalling Perf Profiler Skill ==="

if systemctl is-active --quiet perf-profiler.service; then
    systemctl stop perf-profiler.service
    systemctl disable perf-profiler.service
    rm -f /etc/systemd/system/perf-profiler.service
    systemctl daemon-reload
fi

rm -f /usr/local/bin/perf-profiler-collector.sh
rm -f /usr/local/bin/perf2flame.sh
rm -f /etc/perf-profiler.conf
rm -rf /var/cache/perf-profiler
rm -f /etc/sysctl.d/99-perf-profiler.conf

echo "=== Uninstall complete ==="
