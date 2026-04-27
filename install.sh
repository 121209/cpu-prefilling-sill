#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Linux Continuous CPU Profiler Skill ==="

apt-get update

apt-get install -y \
  git \
  curl \
  ca-certificates \
  stress \
  zstd \
  linux-tools-common \
  linux-tools-generic || true

apt-get install -y "linux-tools-$(uname -r)" || true

# Resolve perf binary
if ! command -v perf >/dev/null 2>&1; then
  PERF_BIN="$(find /usr/lib/linux-tools -name perf -type f 2>/dev/null | head -n 1 || true)"
  if [ -n "$PERF_BIN" ]; then
    ln -sf "$PERF_BIN" /usr/local/bin/perf
  fi
fi

# For WSL2 or environments where /usr/bin/perf wrapper is broken
if [ ! -x /usr/local/bin/perf ]; then
  PERF_BIN="$(find /usr/lib/linux-tools -name perf -type f 2>/dev/null | head -n 1 || true)"
  if [ -n "$PERF_BIN" ]; then
    ln -sf "$PERF_BIN" /usr/local/bin/perf
  fi
fi

if [ ! -x /usr/local/bin/perf ] && ! command -v perf >/dev/null 2>&1; then
  echo "ERROR: perf is not available."
  echo "On WSL2, perf may require a matching WSL2 kernel perf build."
  echo "For production validation, native Ubuntu Linux is recommended."
  exit 1
fi

# Install FlameGraph
if [ ! -d /opt/FlameGraph ]; then
  git clone --depth=1 https://github.com/brendangregg/FlameGraph.git /opt/FlameGraph
fi

ln -sf /opt/FlameGraph/stackcollapse-perf.pl /usr/local/bin/stackcollapse-perf.pl
ln -sf /opt/FlameGraph/flamegraph.pl /usr/local/bin/flamegraph.pl
chmod +x /opt/FlameGraph/*.pl

# Install commands
cp perf-profiler-collector.sh /usr/local/bin/perf-profiler-collector.sh
cp perf2flame.sh /usr/local/bin/perf2flame.sh
chmod +x /usr/local/bin/perf-profiler-collector.sh
chmod +x /usr/local/bin/perf2flame.sh

# Install config
cp perf-profiler.conf /etc/perf-profiler.conf

# Data directory
mkdir -p /var/cache/perf-profiler

# perf permission
sysctl -w kernel.perf_event_paranoid=1 || true
echo "kernel.perf_event_paranoid = 1" > /etc/sysctl.d/99-perf-profiler.conf || true

# Install systemd service
cp perf-profiler.service /etc/systemd/system/perf-profiler.service

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload
  systemctl enable perf-profiler.service || true

  echo
  echo "Systemd service installed:"
  echo "  sudo systemctl start perf-profiler"
  echo "  sudo systemctl status perf-profiler"
  echo "  journalctl -u perf-profiler -f"
else
  echo
  echo "systemd is not available. Start manually:"
  echo "  sudo /usr/local/bin/perf-profiler-collector.sh"
fi

echo
echo "=== Install complete ==="
echo "Generate flamegraph:"
echo "  sudo perf2flame.sh \"YYYY-MM-DD HH:MM:SS\" ./flame.svg"
