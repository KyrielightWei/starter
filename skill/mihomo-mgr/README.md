# mihomo-mgr Skill

A CLI tool to manage a mihomo core process and control it via the external controller API.

Pure Python, zero dependencies. Uses the mihomo HTTP API by default and supports Unix sockets when configured.

## Features

- **Status** — View process PID, core version, mode, TUN status, traffic stats
- **Process** — Start, stop, and restart mihomo
- **Logs** — Record mihomo stdout/stderr and show recent lines
- **Terminal Proxy** — Detect, enable, and clear temporary proxy environment variables
- **Subscription** — Pull subscription YAML, cache raw response, and generate normalized `config.yaml`
- **Config Data** — Check and download required database files
- **Proxy Groups** — List groups, view nodes, switch selections
- **Delay Testing** — Test individual nodes or entire groups
- **Connections** — Monitor active connections, close by ID or all
- **DNS** — Query resolution, flush cache
- **Rules** — Inspect active routing rules
- **Maintenance** — Restart core, update GeoIP/GeoSite

## Prerequisites

- mihomo core binary in the current working directory, or configured with `config-set`
- mihomo config directory in the current working directory, or configured with `config-set`
- Python 3.8+
- No additional dependencies

## Installation

### Manual

```bash
python3 skill/mihomo-mgr/scripts/mihomo-mgr.py status
```

## Quick Start

```bash
alias mm="python3 /path/to/scripts/mihomo-mgr.py"

mm status                    # Overall status
mm config                    # Show persisted and effective config
mm config-init               # Create editable default config template
mm config-set --config-dir /path/to/config --bin-dir /path/to/bin
mm config-set --sub-url "https://example.com/sub"
mm sub-show                  # Show subscription cache status
mm sub-pull                  # Pull subscription and generate config.yaml
mm proxy-status              # Show current terminal proxy variables
eval "$(mm proxy-on)"        # Enable temporary proxy env in current shell
eval "$(mm proxy-off)"       # Clear temporary proxy env in current shell
mm start                     # Start mihomo
mm stop                      # Stop mihomo
mm restart                   # Restart mihomo process
mm logs -n 100               # Show recent logs
mm db-check --download       # Check and download default DB files
mm db-check --geodata        # Also check geoip.dat
mm db-check --asn            # Also check GeoLite2-ASN.mmdb
mm groups                    # List proxy groups
mm nodes "Proxy"             # List nodes in a group
mm select "Proxy" "US Node"  # Switch node
mm delay "US Node"           # Test delay
mm conns                     # Active connections
mm mode rule                 # Set proxy mode
```

## Connection

The tool connects to the mihomo external controller:

1. **HTTP API** (default): `http://127.0.0.1:9090`
2. **Unix socket**: enabled only when `MIHOMO_SOCK` or `--sock` is provided

Override via environment variables or CLI flags:

```bash
export MIHOMO_API=http://127.0.0.1:9090
export MIHOMO_SECRET=your-secret
export MIHOMO_SOCK=/path/to/mihomo.sock
```

## Paths

Persistent manager configuration is stored at:

```bash
~/.config/mihomo-mgr/config.json
```

Create an editable template:

```bash
mm config-init
```

The generated file is JSONC-style JSON with `//` comments. You can edit it directly to set paths, subscription URL, external controller settings, and proxy ports. The template labels fields as required, recommended, or optional.

When no path is configured, the script uses the current working directory for mihomo config, bin, log, and pid files. It expects:

- `./mihomo`
- `./config.yaml`
- `./mihomo.log`
- `./mihomo.pid`

Persist paths once:

```bash
mm config-set --config-dir ~/.config/mihomo --bin-dir /usr/local/bin
mm config
```

Equivalent manual config:

```jsonc
{
  // mihomo working directory
  "config_dir": "~/.config/mihomo",

  // Directory containing mihomo, or set "bin" to an absolute binary path.
  "bin_dir": "/usr/local/bin",
  "bin": "",

  // Subscription URL. Treat it as a secret if it contains a token.
  "sub_url": "",

  // Use one mixed port for terminal HTTP and SOCKS proxy variables.
  "proxy_host": "127.0.0.1",
  "proxy_http_port": "10808",
  "proxy_socks_port": "10808",

  "api": "http://127.0.0.1:9090",
  "sock": "",
  "secret": ""
}
```

Field guidance:

- Required for subscription pulling: `sub_url`
- Recommended: `config_dir`, `bin_dir`, `api`, `proxy_host`, `proxy_http_port`, `proxy_socks_port`, `no_proxy`
- Optional: `bin`, `log_file`, `pid_file`, `sock`, `secret`, `proxy_http`, `proxy_socks`

## Subscription

Set the subscription URL once:

```bash
mm config-set --sub-url "https://example.com/sub"
```

Then pull and generate local config:

```bash
mm sub-pull
mm sub-show
```

With `config_dir` configured, files are written under that directory:

```text
<config_dir>/subscription.raw.yaml
<config_dir>/config.yaml
```

`subscription.raw.yaml` keeps the unmodified subscription response. `config.yaml` is generated from it with local runtime settings:

- removes top-level `port` and `socks-port`
- sets `mixed-port` from `proxy_http_port`, usually `10808`
- sets `allow-lan: false`
- sets `bind-address` from `proxy_host`, usually `127.0.0.1`
- sets `external-controller` from `api`, usually `127.0.0.1:9090`
- sets `secret` only when configured

For a one-off pull without saving the URL:

```bash
mm sub-pull --url "https://example.com/sub"
```

You can still override paths for one command with environment variables:

```bash
MIHOMO_CONFIG_DIR=~/.config/mihomo mm status
MIHOMO_BIN=/usr/local/bin/mihomo mm start
```

Or pass CLI flags:

```bash
mm --config-dir ~/.config/mihomo --bin-dir /usr/local/bin status
mm --config-dir ~/.config/mihomo --bin /usr/local/bin/mihomo start
```

## Terminal Proxy

`proxy-status` checks whether the current terminal environment already has proxy variables configured.

```bash
mm proxy-status
mm proxy-status --verbose
```

`proxy-on` and `proxy-off` print shell commands. Use `eval` so the output changes the current shell instead of only the child process:

```bash
eval "$(mm proxy-on)"
eval "$(mm proxy-off)"
```

`proxy-on` derives host and ports from the mihomo `/configs` API when available. The priority is:

1. Explicit `proxy-on` arguments
2. Persisted `config-set` proxy values
3. mihomo `/configs`
4. Fallback values

Fallback values:

- HTTP proxy: `http://127.0.0.1:10808`
- SOCKS proxy: `socks5://127.0.0.1:10808`
- No proxy: `localhost,127.0.0.1,::1,*.local`

Override for one use:

```bash
eval "$(mm proxy-on --host 127.0.0.1 --http-port 10808 --socks-port 10808)"
eval "$(mm proxy-on --http http://127.0.0.1:10808 --socks socks5://127.0.0.1:10808)"
```

Persist defaults:

```bash
mm config-set --proxy-host 127.0.0.1 --proxy-http-port 10808 --proxy-socks-port 10808
```

The generated environment covers common lowercase and uppercase proxy variables plus npm, yarn, Cargo, rsync, and gRPC variables. Some applications ignore environment proxies and require their own config, but this covers the common terminal tooling path.

## Database Files

By default, `db-check` verifies only the files needed by common mihomo configs:

- `country.mmdb`
- `geosite.dat`

Optional files are available when your config needs them:

- `geoip.dat`: use `--geodata` when `geodata-mode: true`
- `GeoLite2-ASN.mmdb`: use `--asn` when using ASN rules
- `geoip.db`, `geoip.metadb`, `geosite.db`: use `--all` only when you explicitly need these alternate formats

Use `db-check --download` or `db-download` to download missing selected files. The script uses the jsDelivr links from the MetaCubeX `meta-rules-dat` README first:

```text
https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/<file>
```

It then falls back to the jsDelivr-CF URL and the upstream GitHub release URL.

Examples:

```bash
mm db-check
mm db-check --download
mm db-download --geodata
mm db-download --asn
mm db-download --all
```

## Process Logs

`start` runs mihomo in the background and writes stdout/stderr to the configured log file.

```bash
mm logs
mm logs -n 200
mm logs -f                  # Follow log (tail -f style)
mm logs-clear               # Clear log file
mm logs-clear --keep 100    # Keep last 100 lines
```

## License

MIT
