# Perf Profiler Skill – 7×24 CPU BlackBox

> 像黑匣子一样常驻后台持续采样，任意时间点一键生成当时 CPU 火焰图，快速定位性能根因。

## 设计说明
利用 Linux 内核自带的 `perf` 工具，以低频（默认 49Hz）持续采样调用栈，并按固定时间间隔（默认 5 分钟）自动切分输出文件（切片）。每个切片文件名带有精确时间戳，形成时间序列数据库。当生产环境出现性能问题时，只需给出时间点，工具会找到该时刻所属的切片并解析出完整的调用栈，最后生成交互式火焰图，实现“黑匣子”式的回溯分析。

- **持续采样**：`perf record -F 49 -g --switch-output=5m`  
- **滑动窗口保留**：只保留最新 N 个切片（默认 288 个，即 24 小时），旧文件自动删除  
- **时间点查询**：根据输入时间，匹配最近且 ≤ 目标时间的切片  
- **火焰图生成**：使用 Brendan Gregg 的 FlameGraph 工具链输出 SVG  
- **生产可靠性**：由 systemd 管理，自动重启、CPU 配额 ≤ 5%、内存限制、配置集中管理
## 文件说明
README.md                     项目说明文档
install.sh                    安装脚本
uninstall.sh                  卸载脚本
perf-profiler-collector.sh    持续 perf 采集器
perf2flame.sh                 时间点查询与火焰图生成工具
perf-profiler.conf            配置文件
perf-profiler.service         systemd 后台服务文件
test.sh                       基础测试
test-e2e.sh                   端到端测试
test-results.txt              基础测试结果
test-e2e-results.txt          端到端测试结果
flame-e2e-result.svg          端到端测试生成的火焰图
## 使用说明
### 1、安装 perf
sudo apt update
sudo apt install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r)
#### 1.1 WSL2 环境
WSL2 中出现：
WARNING: perf not found for kernel x.x.x-microsoft-standard-WSL2
可以查找已有 perf：
find /usr/lib/linux-tools -name perf 2>/dev/null
如果找到类似：
/usr/lib/linux-tools/6.8.0-110-generic/perf
可以创建软链接：
sudo ln -sf $(find /usr/lib/linux-tools -name perf | head -n 1) /usr/local/bin/perf
验证：
perf --version
### 2、安装 FlameGraph
sudo git clone --depth=1 https://github.com/brendangregg/FlameGraph.git /opt/FlameGraph
sudo ln -sf /opt/FlameGraph/stackcollapse-perf.pl /usr/local/bin/stackcollapse-perf.pl
sudo ln -sf /opt/FlameGraph/flamegraph.pl /usr/local/bin/flamegraph.pl
sudo chmod +x /opt/FlameGraph/*.pl
验证：
stackcollapse-perf.pl --help | head
flamegraph.pl --help | head
### 3、一键安装
sudo ./install.sh
### 4、使用方式：systemd 生产模式
启动服务：
sudo systemctl start perf-profiler
查看状态：
sudo systemctl status perf-profiler --no-pager
查看日志：
sudo journalctl -u perf-profiler -n 30 --no-pager
设置开机自启：
sudo systemctl enable perf-profiler
停止服务：
sudo systemctl stop perf-profiler
查看是否生成切片：
sleep 30
sudo ls -lh /var/cache/perf-profiler

