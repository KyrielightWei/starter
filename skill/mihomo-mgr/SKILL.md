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
# Overall status, including process PID
mihomo-mgr.py status

# Persistent configuration
mihomo-mgr.py config
mihomo-mgr.py config-init
mihomo-mgr.py config-set --config-dir /path/to/config --bin-dir /path/to/bin
mihomo-mgr.py config-set --sub-url "https://example.com/sub"
mihomo-mgr.py config-set --proxy-host 127.0.0.1 --proxy-http-port 10808 --proxy-socks-port 10808
mihomo-mgr.py config-clear

# Subscription config
mihomo-mgr.py sub-show
mihomo-mgr.py sub-pull
mihomo-mgr.py sub-pull --url "https://example.com/sub"

# Terminal proxy environment
mihomo-mgr.py proxy-status
eval "$(mihomo-mgr.py proxy-on)"
eval "$(mihomo-mgr.py proxy-off)"

# Process lifecycle
mihomo-mgr.py start
mihomo-mgr.py stop
mihomo-mgr.py restart

# Logs
mihomo-mgr.py logs              # Show recent 50 lines with file info
mihomo-mgr.py logs -n 200       # Show recent 200 lines
mihomo-mgr.py logs -f           # Follow log (tail -f style)
mihomo-mgr.py logs-clear        # Clear log file
mihomo-mgr.py logs-clear --keep 100  # Keep last 100 lines

# Config data files
mihomo-mgr.py db-check                  # Check country.mmdb + geosite.dat
mihomo-mgr.py db-check --download       # Download missing default files
mihomo-mgr.py db-check --geodata        # Also check geoip.dat
mihomo-mgr.py db-check --asn            # Also check GeoLite2-ASN.mmdb
mihomo-mgr.py db-download --all         # Download all db/dat/mmdb files

# Proxy mode (rule/global/direct)
mihomo-mgr.py mode              # Get current mode
mihomo-mgr.py mode rule         # Set mode

# Proxy groups & nodes
mihomo-mgr.py groups            # List all proxy groups
mihomo-mgr.py nodes <group>     # List nodes in a group
mihomo-mgr.py select <group> <node>  # Switch node

# Delay testing
mihomo-mgr.py delay <node>      # Test single node
mihomo-mgr.py delay-group <group>    # Test all nodes in group

# Connections
mihomo-mgr.py conns [--limit N]      # List active connections
mihomo-mgr.py conns-close [--id ID]  # Close one or all connections

# Rules
mihomo-mgr.py rules [--limit N]

# DNS
mihomo-mgr.py dns <domain> [--type A|AAAA|CNAME]
mihomo-mgr.py flush-dns

# Maintenance
mihomo-mgr.py api-restart       # Restart mihomo core via API
mihomo-mgr.py upgrade-geo       # Update GeoIP/GeoSite databases

# Shell completion
source <(mihomo-mgr.py completion bash)  # Enable tab completion (group/node/mode names)
source <(mihomo-mgr.py completion zsh)   # Same for zsh

# Scripting
mihomo-mgr.py status --json     # Machine-readable JSON output
```

## Notes

- No external dependencies (Python stdlib only)
- HTTP external controller is the default connection method
- Unix socket is supported when explicitly configured
- `config-init` creates an editable JSONC config template at `~/.config/mihomo-mgr/config.json`
- `sub-pull` caches raw subscription as `subscription.raw.yaml` and writes normalized `config.yaml`
- Generated config uses `mixed-port`, removes top-level `port`/`socks-port`, sets `allow-lan: false`, `bind-address`, and `external-controller`
- `start` records stdout/stderr to the configured log file
- `status` shows process PID and discovered mihomo processes
- `proxy-on` derives proxy host/ports from mihomo `/configs` when available; explicit args and persisted config take priority
- `proxy-on` and `proxy-off` print shell commands; use `eval "$(mihomo-mgr.py proxy-on)"` to affect the current terminal
- Proxy exports cover common lowercase/uppercase env vars plus npm, yarn, Cargo, rsync, and gRPC variables
- `db-check --download` downloads missing default files: `country.mmdb` and `geosite.dat`
- `--geodata` adds `geoip.dat`; `--asn` adds `GeoLite2-ASN.mmdb`; `--all` includes all db/dat/mmdb files (including lite editions)
- Group/node names with special characters (emoji, CJK) are supported
- `delay-group` tests nodes sequentially — may take a while for large groups
- `status --json` outputs machine-readable JSON for scripting
- `completion bash|zsh` generates shell completion scripts for tab-completing commands, group names, and node names
