#!/bin/bash
set -e

echo "=== Installing Perf Profiler Skill ==="

# 安装系统依赖
apt-get update
apt-get install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r) zstd git stress || true
if ! command -v perf &>/dev/null; then
    PERF=$(find /usr/lib/linux-tools -name perf -type f | head -1)
    [ -n "$PERF" ] && ln -sf "$PERF" /usr/local/bin/perf
fi

# 安装 FlameGraph
if [ ! -d /opt/FlameGraph ]; then
    git clone --depth=1 https://github.com/brendangregg/FlameGraph.git /opt/FlameGraph
fi
ln -sf /opt/FlameGraph/stackcollapse-perf.pl /usr/local/bin/
ln -sf /opt/FlameGraph/flamegraph.pl /usr/local/bin/

# 复制脚本和配置
cp perf-profiler-collector.sh /usr/local/bin/
cp perf2flame.sh /usr/local/bin/
chmod +x /usr/local/bin/perf-profiler-collector.sh /usr/local/bin/perf2flame.sh
cp perf-profiler.conf /etc/

# 建立数据目录
mkdir -p /var/cache/perf-profiler

# 内核参数
sysctl -w kernel.perf_event_paranoid=-1
echo "kernel.perf_event_paranoid = -1" > /etc/sysctl.d/99-perf-profiler.conf

# 安装 systemd 服务（若可用）
if command -v systemctl &>/dev/null; then
    cp perf-profiler.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable perf-profiler.service
    systemctl start perf-profiler.service
    echo "=== Service started via systemd ==="
else
    echo "systemd not found, start manually:"
    echo "  nohup /usr/local/bin/perf-profiler-collector.sh &"
fi
echo "=== Install complete. Use 'perf2flame.sh \"YYYY-MM-DD HH:MM:SS\"' to generate flamegraph. ==="
