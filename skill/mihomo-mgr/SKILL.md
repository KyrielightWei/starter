---
name: mihomo-mgr
description: Manage a mihomo core process and control it via the external controller API. Query proxy status, switch nodes, test delays, manage connections, DNS, rules, config/data files, process lifecycle, and logs. Use when user mentions mihomo, proxy, VPN, nodes, or network proxy management.
---

# mihomo-mgr Skill

Manage a mihomo core process and control it via its external controller API.

## CLI Tool

`python3 {baseDir}/scripts/mihomo-mgr.py`

Run without arguments or with `--help` to see all commands grouped by category with examples.
Use `CMD --help` for per-command flags (e.g., `mihomo-mgr.py start --help`).

### Connection

Uses the HTTP API at `http://127.0.0.1:9090` by default.
If `MIHOMO_SOCK` or `--sock` is provided, uses that Unix socket instead.

Override via env vars: `MIHOMO_SOCK`, `MIHOMO_API`, `MIHOMO_SECRET`
Or CLI flags: `--sock`, `--api`, `--secret`

### Paths

Persistent manager config: `~/.config/mihomo-mgr/config.json`

When no paths are configured, mihomo config, bin, log, and pid paths default to the current working directory.

Persist paths with `config-set`, or override for one command via env vars: `MIHOMO_CONFIG_DIR`, `MIHOMO_BIN_DIR`, `MIHOMO_BIN`, `MIHOMO_LOG_FILE`, `MIHOMO_PID_FILE`
Or CLI flags: `--config-dir`, `--bin-dir`, `--bin`, `--log-file`, `--pid-file`

### Commands

```bash
# 交互式选择（最简单）
mm pick                   # 交互式选择器
                          # 1. 选择组 → 2. 组操作菜单 → 3. 选择节点 → 4. 节点操作
                          # 支持关键词过滤、/正则/ 匹配、编号选择
                          # 组级操作：测试所有节点、自动选最快、查看详情
                          # 节点级操作：切换、测速、详情

# 智能快捷方式（推荐）
mm                        # 查看状态
mm 节点                    # 列出节点（自动匹配组）
mm 切换 香港               # 自动选最快香港节点
mm 测速                    # 测试延迟

# 英文简写
mm p                      # pick（交互式选择）
mm s / st                 # status
mm n                      # nodes
mm g                      # groups
mm b                      # best
mm d                      # delay
mm c                      # conns
mm l                      # logs

# 核心命令
mm status                 # Overall status, including process PID
mm groups                 # List all proxy groups
mm nodes [group]          # List nodes (partial match: "节点" → "🚀 节点选择")
mm select [group] [node]  # Switch node
mm best [group] [keywords...]  # Auto-select fastest node
mm delay [target]         # Test delay (auto-detect group/node)

# 进程管理
mm start / stop / restart

# 配置管理（子命令）
mm config                 # Show config
mm config init            # Create config template
mm config set --key value # Set config
mm config clear           # Clear config

# 代理环境（子命令）
mm proxy                  # Show proxy status
mm proxy on               # Enable proxy (eval "$(mm proxy on)")
mm proxy off              # Disable proxy

# 日志管理
mm logs                   # Show recent logs
mm logs --clear           # Clear logs

# 订阅管理（子命令）
mm sub pull               # Pull subscription
mm sub show               # Show status

# 数据库文件
mm db                     # Check DB files
mm db --download          # Download missing files

# 连接管理
mm conns                  # List connections
mm conns --close          # Close all connections

# 正则模式（可选）
mm nodes "节点" --filter "IEPL.*港" --regex
mm select "节点" "IEPL.*港" --regex
mm best "节点" "日本|香港" --regex

# Shell completion
source <(mm completion bash)  # Enable tab completion
source <(mm completion zsh)

# 旧命令兼容（自动转换）
mm delay-group → mm delay
mm logs-clear → mm logs --clear
mm config-init → mm config init
mm proxy-on → mm proxy on
# ... 等等
```

## Notes

- No external dependencies (Python stdlib only)
- HTTP external controller is the default connection method
- Unix socket is supported when explicitly configured
- `config-init` creates an editable JSONC config template at `~/.config/mihomo-mgr/config.json`
- `sub-pull` caches raw subscription as `subscription.raw.yaml` and writes normalized `config.yaml`
- Generated config uses `mixed-port` (from `mixed_port` > `proxy_http_port` > `proxy_socks_port` > default `10808`), removes top-level `port`/`socks-port`, sets `allow-lan: false`, `bind-address`, and `external-controller`
- `start` records stdout/stderr to the configured log file
- `status` shows process PID and discovered mihomo processes
- `proxy-on` derives proxy host/ports from mihomo `/configs` when available; explicit args and persisted config take priority
- `proxy-on` and `proxy-off` print shell commands; use `eval "$(mihomo-mgr.py proxy-on)"` to affect the current terminal
- Proxy exports cover common lowercase/uppercase env vars plus npm, yarn, Cargo, rsync, and gRPC variables
- `db-check --download` downloads missing default files: `country.mmdb` and `geosite.dat`
- `--geodata` adds `geoip.dat`; `--asn` adds `GeoLite2-ASN.mmdb`; `--all` includes all db/dat/mmdb files (including lite editions)
- Group/node names with special characters (emoji, CJK) are supported
- **Group name partial match**: `nodes "节点"` automatically matches `🚀 节点选择` (no need for exact name or emoji)
- **Regex mode** (`--regex`): Group names and node filters support regex patterns. `nodes "节点" --regex` matches groups containing "节点"; `--filter "IEPL.*港" --regex` filters nodes with regex
- **Interactive picker** (`pick` / `p`): Two-level menu — group actions (test all, auto-select best, view details) and node actions (switch, test delay, view details). Supports keyword filtering and `/regex/` syntax at every step
- `best` filters nodes by region keywords (e.g. 日本 美国), tests delays concurrently, and auto-selects the fastest
- `best --watch` creates a url-test proxy group in config.yaml with the filtered nodes, reloads mihomo, and lets the native url-test mechanism handle health checks and failover automatically (no external polling needed); use `--watch-off` to remove the group and restore the original selection
- Default url-test parameters: `interval=15s` (health check every 15 seconds), `tolerance=50ms`, `timeout=2000ms`; configurable via `--interval`, `--tolerance`, `--health-timeout`
- `best --list` shows all active watch groups with their current node, delay, node count, and associated configuration
- `best --switch` switches a Selector to an existing watch group (e.g. `best "🚀 节点选择" 日本 美国 --switch`)
- `--dry-run` previews results without switching
- `delay-group` tests nodes concurrently (default 10 threads) — fast even for large groups
- `status --json` outputs machine-readable JSON for scripting
- `completion bash|zsh` generates shell completion scripts for tab-completing commands, group names, and node names
