#!/usr/bin/env python3
"""mihomo-mgr - Control mihomo via its external controller API."""

VERSION = "1.3.0"

import argparse
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.request
import urllib.error
import urllib.parse
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

DEFAULT_SOCK = ""
DEFAULT_HTTP = "http://127.0.0.1:9090"
DEFAULT_BIN_NAME = "mihomo"
DEFAULT_LOG_NAME = "mihomo.log"
DEFAULT_PID_NAME = "mihomo.pid"
DEFAULT_CONFIG_NAME = "config.yaml"
DEFAULT_RAW_SUB_NAME = "subscription.raw.yaml"
DEFAULT_MGR_CONFIG_PATH = "~/.config/mihomo-mgr/config.json"
DEFAULT_PROXY_HOST = "127.0.0.1"
DEFAULT_HTTP_PROXY_PORT = "10808"
DEFAULT_SOCKS_PROXY_PORT = "10808"
DEFAULT_DB_FILES = ("country.mmdb", "geosite.dat")
PROXY_ENV_KEYS = (
    "http_proxy",
    "https_proxy",
    "ftp_proxy",
    "rsync_proxy",
    "all_proxy",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "FTP_PROXY",
    "RSYNC_PROXY",
    "ALL_PROXY",
    "no_proxy",
    "NO_PROXY",
    "npm_config_proxy",
    "npm_config_https_proxy",
    "NPM_CONFIG_PROXY",
    "NPM_CONFIG_HTTPS_PROXY",
    "yarn_proxy",
    "yarn_https_proxy",
    "YARN_PROXY",
    "YARN_HTTPS_PROXY",
    "CARGO_HTTP_PROXY",
    "grpc_proxy",
    "GRPC_PROXY",
    "GIT_PROXY_COMMAND",
)
DEFAULT_NO_PROXY = "localhost,127.0.0.1,::1,*.local"
DB_FILES = {
    name: [
        f"https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/{name}",
        f"https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/{name}",
        f"https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/{name}",
    ]
    for name in (
        "country.mmdb",
        "geoip.dat",
        "geoip.db",
        "geoip.metadb",
        "geosite.dat",
        "geosite.db",
        "GeoLite2-ASN.mmdb",
    )
}


def _get_args():
    """Get connection args from environment or defaults."""
    cfg = _load_mgr_config()
    sock = os.environ.get("MIHOMO_SOCK", _cfg_value(cfg, "sock", DEFAULT_SOCK))
    http = os.environ.get("MIHOMO_API", _cfg_value(cfg, "api", DEFAULT_HTTP))
    secret = os.environ.get("MIHOMO_SECRET", _cfg_value(cfg, "secret", ""))
    return sock, http, secret


def _get_paths():
    cfg = _load_mgr_config()
    cwd = Path.cwd()
    config_dir = Path(os.environ.get("MIHOMO_CONFIG_DIR", _cfg_value(cfg, "config_dir", str(cwd)))).expanduser()
    bin_dir = os.environ.get("MIHOMO_BIN_DIR", _cfg_value(cfg, "bin_dir", str(cwd)))
    bin_path = os.environ.get("MIHOMO_BIN", _cfg_value(cfg, "bin", ""))
    log_file = Path(os.environ.get("MIHOMO_LOG_FILE", str(config_dir / DEFAULT_LOG_NAME))).expanduser()
    pid_file = Path(os.environ.get("MIHOMO_PID_FILE", str(config_dir / DEFAULT_PID_NAME))).expanduser()
    config_file = Path(os.environ.get("MIHOMO_CONFIG", str(config_dir / DEFAULT_CONFIG_NAME))).expanduser()
    raw_sub_file = Path(os.environ.get("MIHOMO_RAW_SUB", str(config_dir / DEFAULT_RAW_SUB_NAME))).expanduser()
    if not bin_path:
        bin_path = str(Path(bin_dir).expanduser() / DEFAULT_BIN_NAME)
    return {
        "config_dir": config_dir,
        "bin_path": bin_path,
        "log_file": log_file,
        "pid_file": pid_file,
        "config_file": config_file,
        "raw_sub_file": raw_sub_file,
    }


class UnixHTTPHandler(urllib.request.AbstractHTTPHandler):
    """HTTP handler for Unix domain sockets."""

    def __init__(self, sock_path):
        super().__init__()
        self.sock_path = sock_path

    def http_open(self, req):
        return self.do_open(self._make_connection, req)

    def _make_connection(self, host, **kwargs):
        conn = UnixHTTPConnection(self.sock_path)
        return conn


class UnixHTTPConnection:
    """Minimal HTTP/1.1 over Unix socket."""

    def __init__(self, sock_path):
        self.sock_path = sock_path
        self._sock = None
        self._response = None
        self.timeout = 10

    def request(self, method, url, body=None, headers=None):
        headers = headers or {}
        self._sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._sock.settimeout(self.timeout)
        self._sock.connect(self.sock_path)
        path = url
        lines = [f"{method} {path} HTTP/1.1", "Host: localhost", "Connection: close"]
        if body:
            lines.append(f"Content-Length: {len(body)}")
        for k, v in headers.items():
            lines.append(f"{k}: {v}")
        lines.append("")
        lines.append("")
        raw = "\r\n".join(lines).encode()
        if body:
            raw = raw + (body.encode() if isinstance(body, str) else body)
        self._sock.sendall(raw)

    def getresponse(self):
        data = b""
        while True:
            chunk = self._sock.recv(65536)
            if not chunk:
                break
            data += chunk
        self._sock.close()
        return _RawResponse(data)


class _RawResponse:
    """Parse raw HTTP response."""

    def __init__(self, data):
        parts = data.split(b"\r\n\r\n", 1)
        header_block = parts[0].decode(errors="replace")
        self.body = parts[1] if len(parts) > 1 else b""
        first_line = header_block.split("\r\n")[0]
        self.status = int(first_line.split(" ", 2)[1])
        self.reason = first_line.split(" ", 2)[2] if len(first_line.split(" ", 2)) > 2 else ""
        self._headers = {}
        for line in header_block.split("\r\n")[1:]:
            if ": " in line:
                k, v = line.split(": ", 1)
                self._headers[k.lower()] = v
        # Handle chunked transfer encoding
        if self._headers.get("transfer-encoding", "").lower() == "chunked":
            self.body = self._decode_chunked(self.body)

    def _decode_chunked(self, data):
        result = b""
        while data:
            line_end = data.find(b"\r\n")
            if line_end == -1:
                break
            size_str = data[:line_end].decode().strip()
            if not size_str:
                data = data[line_end + 2:]
                continue
            chunk_size = int(size_str, 16)
            if chunk_size == 0:
                break
            result += data[line_end + 2:line_end + 2 + chunk_size]
            data = data[line_end + 2 + chunk_size + 2:]
        return result

    def read(self):
        return self.body

    def getheader(self, name, default=None):
        return self._headers.get(name.lower(), default)


# ── API Client ───────────────────────────────────────────────────────


def api(method, path, body=None, quiet=False):
    """Call mihomo API. Uses a configured Unix socket, otherwise HTTP."""
    sock, http_url, secret = _get_args()
    headers = {"Content-Type": "application/json"}
    if secret:
        headers["Authorization"] = f"Bearer {secret}"

    if sock and Path(sock).exists():
        conn = UnixHTTPConnection(sock)
        conn.request(method, path, body=json.dumps(body) if body else None, headers=headers)
        resp = conn.getresponse()
        raw = resp.read()
        if resp.status >= 400:
            if not quiet:
                print(f"API error {resp.status}: {raw.decode(errors='replace')}", file=sys.stderr)
            sys.exit(1)
        return (json.loads(raw) if raw.strip() else None) or {}
    else:
        url = http_url.rstrip("/") + path
        data = json.dumps(body).encode() if body else None
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                raw = resp.read()
                return (json.loads(raw) if raw.strip() else None) or {}
        except urllib.error.HTTPError as e:
            if not quiet:
                print(f"API error {e.code}: {e.read().decode(errors='replace')}", file=sys.stderr)
            sys.exit(1)
        except urllib.error.URLError as e:
            if not quiet:
                print(f"API connection error: {e}", file=sys.stderr)
            sys.exit(1)


# ── Commands ─────────────────────────────────────────────────────────


def cmd_status(args):
    """Show overall status."""
    try:
        ver = api("GET", "/version", quiet=True)
        cfg = api("GET", "/configs", quiet=True)
        conns = api("GET", "/connections", quiet=True)
        proxies_data = api("GET", "/proxies", quiet=True)
    except SystemExit:
        if args.json:
            json.dump({"error": "API unavailable"}, sys.stdout)
            print()
        else:
            _print_process_status()
            print("\nAPI: unavailable")
        return

    if args.json:
        # JSON output for scripting
        proxies = proxies_data.get("proxies") or {}
        group_types = ("Selector", "URLTest", "Fallback", "LoadBalance")
        groups = {}
        for name, g in proxies.items():
            if g.get("type") in group_types:
                groups[name] = {"type": g.get("type"), "now": g.get("now"), "all_count": len(g.get("all") or [])}
        result = {
            "version": ver.get("version"),
            "mode": cfg.get("mode"),
            "mixed_port": cfg.get("mixed-port"),
            "tun_enabled": (cfg.get("tun") or {}).get("enable", False),
            "log_level": cfg.get("log-level"),
            "connections_active": len(conns.get("connections") or []),
            "upload_bytes": conns.get("uploadTotal", 0),
            "download_bytes": conns.get("downloadTotal", 0),
            "proxy_groups": groups,
        }
        json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
        print()
        return

    # Human-readable output
    _print_process_status()

    nc = len(conns.get("connections") or [])
    up = conns.get("uploadTotal", 0)
    down = conns.get("downloadTotal", 0)

    print(f"\nMihomo {ver.get('version', '?')}")
    print(f"Mode: {cfg.get('mode', '?')}")
    print(f"Mixed port: {cfg.get('mixed-port', '?')}")
    tun = cfg.get("tun") or {}
    print(f"TUN: {'enabled' if tun.get('enable') else 'disabled'} ({tun.get('stack', '?')})")
    print(f"Log level: {cfg.get('log-level', '?')}")
    print(f"Connections: {nc} active")
    print(f"Traffic: ↑ {_fmt_bytes(up)}  ↓ {_fmt_bytes(down)}")

    # Show current proxy selections
    proxies = proxies_data.get("proxies") or {}
    group_types = ("Selector", "URLTest", "Fallback", "LoadBalance")
    groups = {k: v for k, v in proxies.items() if v.get("type") in group_types}
    if groups:
        print(f"\nProxy groups:")
        for name, g in sorted(groups.items()):
            now = g.get("now", "-")
            # Resolve chain: if 'now' is also a group, follow it
            chain = [now]
            seen = {name}
            cur = now
            while cur in proxies and proxies[cur].get("type") in group_types and cur not in seen:
                seen.add(cur)
                cur = proxies[cur].get("now", "")
                if cur:
                    chain.append(cur)
            chain_str = " → ".join(chain)
            print(f"  {name}: {chain_str}")


def cmd_mode(args):
    """Get or set proxy mode."""
    if args.value:
        api("PATCH", "/configs", {"mode": args.value})
        print(f"Mode set to: {args.value}")
    else:
        cfg = api("GET", "/configs")
        print(f"Mode: {cfg.get('mode', '?')}")


def cmd_groups(args):
    """List proxy groups."""
    data = api("GET", "/proxies")
    proxies = data.get("proxies") or {}
    group_types = ("Selector", "URLTest", "Fallback", "LoadBalance")
    groups = {k: v for k, v in proxies.items() if v.get("type") in group_types}
    for name, g in sorted(groups.items()):
        now = g.get("now", "-")
        n = len(g.get("all") or [])
        t = g.get("type", "?")
        print(f"  {name} ({t}): {now}  [{n} nodes]")


def _fetch_node_delay(node_name):
    """获取单个节点的延迟信息。返回 (name, delay_ms)。"""
    try:
        node_data = api("GET", f"/proxies/{_urlencode(node_name)}", quiet=True)
        history = node_data.get("history") or []
        delay = (history[-1].get("delay") or 0) if history else 0
        return node_name, delay
    except (SystemExit, Exception):
        return node_name, 0


def cmd_nodes(args):
    """List nodes in a proxy group."""
    data = api("GET", f"/proxies/{_urlencode(args.group)}")
    if "all" not in data:
        print(f"'{args.group}' is not a group or not found.", file=sys.stderr)
        sys.exit(1)
    now = data.get("now", "")
    all_nodes = data.get("all") or []
    print(f"Group: {args.group} ({data.get('type', '?')})")
    print(f"Current: {now}\n")
    # 并行获取节点延迟
    delays = {}
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(_fetch_node_delay, n): n for n in all_nodes}
        for future in as_completed(futures):
            name, delay = future.result()
            delays[name] = delay
    for node_name in all_nodes:
        marker = " ★" if node_name == now else ""
        delay = delays.get(node_name, 0)
        delay_str = f"{delay}ms" if delay > 0 else "N/A"
        print(f"  {node_name}{marker}  ({delay_str})")


def cmd_select(args):
    """Select a node in a proxy group."""
    api("PUT", f"/proxies/{_urlencode(args.group)}", {"name": args.node})
    print(f"Switched '{args.group}' → {args.node}")


def cmd_delay(args):
    """Test delay for a node or group."""
    url = args.url or "http://www.gstatic.com/generate_204"
    timeout = args.timeout or 1000
    target = args.target
    result = api("GET", f"/proxies/{_urlencode(target)}/delay?timeout={timeout}&url={_urlencode(url)}")
    d = result.get("delay") or 0
    if d > 0:
        print(f"{target}: {d}ms")
    else:
        print(f"{target}: timeout / unreachable")


def _test_node_delay(node_name, url, timeout):
    """Thread-safe node delay test. Returns (name, delay_ms)."""
    try:
        r = api("GET", f"/proxies/{_urlencode(node_name)}/delay?timeout={timeout}&url={_urlencode(url)}", quiet=True)
        return node_name, r.get("delay", 0) or 0
    except (SystemExit, Exception):
        return node_name, 0


def _display_width(s):
    """Calculate display width accounting for CJK wide characters."""
    import unicodedata
    w = 0
    for c in s:
        ea = unicodedata.east_asian_width(c)
        w += 2 if ea in ("W", "F") else 1
    return w


def _pad_display(s, width):
    """Pad string to given display width, handling CJK correctly."""
    dw = _display_width(s)
    if dw >= width:
        return s
    return s + " " * (width - dw)


def cmd_delay_group(args):
    """Test delay for all nodes in a group concurrently."""
    url = args.url or "http://www.gstatic.com/generate_204"
    timeout = args.timeout or 1000  # 1s default for faster results
    concurrency = args.concurrency or 10
    data = api("GET", f"/proxies/{_urlencode(args.group)}")
    if "all" not in data:
        print(f"'{args.group}' is not a group.", file=sys.stderr)
        sys.exit(1)
    # 从 API 获取所有策略组名，过滤掉非真实节点
    proxies_data = api("GET", "/proxies", quiet=True)
    proxies = proxies_data.get("proxies") or {}
    group_types = ("Selector", "URLTest", "Fallback", "LoadBalance")
    group_names = {k for k, v in proxies.items() if v.get("type") in group_types}
    _skip_exact = ("DIRECT", "REJECT", "GLOBAL")
    def _is_real_node(name):
        return name not in _skip_exact and name not in group_names
    all_nodes = [n for n in data.get("all") or [] if _is_real_node(n)]
    total = len(all_nodes)
    print(f"Testing {total} nodes in '{args.group}' (timeout={timeout}ms, concurrency={concurrency})...\n")
    results = []
    lock = threading.Lock()
    completed = 0
    start = time.time()
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = {executor.submit(_test_node_delay, n, url, timeout): n for n in all_nodes}
        for future in as_completed(futures):
            name, d = future.result()
            with lock:
                completed += 1
                results.append((name, d))
                elapsed = time.time() - start
                ds = f"{d}ms" if d > 0 else "timeout"
                print(f"\r  [{completed}/{total}] {name:<30} {ds:>8}  ({elapsed:.0f}s)    ", end="", flush=True)
    # Clear progress line
    print("\r" + " " * 80 + "\r", end="")
    elapsed = time.time() - start
    # Sort by delay (0 = timeout, put at end)
    results.sort(key=lambda x: (x[1] == 0, x[1]))
    now_name = data.get("now", "")
    alive = [(n, d) for n, d in results if d > 0]
    dead = [(n, d) for n, d in results if d == 0]
    # 3-column compact display for reachable nodes
    cols, col_w = 3, 30
    for i in range(0, len(alive), cols):
        line = ""
        for name, d in alive[i:i + cols]:
            marker = " ★" if name == now_name else ""
            s = f"{name}{marker}: {d}ms"
            # 超长名称截断以保持列对齐
            if _display_width(s) > col_w:
                suffix = f"{marker}: {d}ms"
                max_w = col_w - _display_width(suffix) - 2
                t = name
                while _display_width(t) > max_w and t:
                    t = t[:-1]
                s = f"{t}..{suffix}" if t else s[:col_w - 1] + "…"
            line += _pad_display(s, col_w)
        print("  " + line)
    # Timeout nodes: summary line
    if dead:
        dead_now = [f"{n} ★" if n == now_name else n for n, _ in dead]
        preview = ", ".join(dead_now[:4])
        tail = f" +{len(dead) - 4} more" if len(dead) > 4 else ""
        print(f"  timeout ({len(dead)}): {preview}{tail}")
    # Summary line
    avg = sum(d for _, d in alive) // len(alive) if alive else 0
    fastest = alive[0][1] if alive else "-"
    print(f"\n  {total} nodes │ {elapsed:.1f}s │ reachable: {len(alive)} │ fastest: {fastest}ms │ avg: {avg}ms │ timeout: {len(dead)}")


# ── best: YAML 配置操作 ──────────────────────────────────────────────

_BEST_GROUP_PREFIX = "🎯 best-"
_BEST_STATE_PATH = "~/.config/mihomo-mgr/best-watch.json"


def _best_group_name(keywords):
    """根据关键词生成 url-test 组名。"""
    return _BEST_GROUP_PREFIX + "".join(keywords)


def _best_state_path():
    return Path(_BEST_STATE_PATH).expanduser()


def _best_save_state(group, original_node, ut_group, keywords):
    """保存 watch 状态，用于 --watch-off 恢复。"""
    path = _best_state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    state = {
        "group": group,
        "original_node": original_node,
        "ut_group": ut_group,
        "keywords": keywords,
    }
    path.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n")


def _best_load_state():
    """加载 watch 状态。"""
    try:
        return json.loads(_best_state_path().read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def _best_clear_state():
    """清除 watch 状态。"""
    try:
        _best_state_path().unlink()
    except FileNotFoundError:
        pass


def _yaml_quote(name):
    """YAML flow format 引用名称（含特殊字符时用单引号）。"""
    if name and all(c.isalnum() or c in "-_." for c in name):
        return name
    return "'" + name.replace("'", "''") + "'"


def _line_is_group(line, group_name):
    """判断一行是否是目标 proxy-group 的定义（flow-style 单行格式）。"""
    stripped = line.strip()
    if not stripped.startswith("- {"):
        return False
    for fmt in [
        f"name: '{group_name}'",
        f'name: "{group_name}"',
        f"name: {group_name},",
        f"name: {group_name} ",
    ]:
        if fmt in stripped:
            return True
    return False


def _add_to_proxies_list(line, new_proxy_quoted):
    """在 proxies: [...] 的开头添加一个代理名。"""
    idx = line.find("proxies: [")
    if idx < 0:
        return line
    insert_at = idx + len("proxies: [")
    rest = line[insert_at:].lstrip()
    if rest.startswith("]"):
        return line[:insert_at] + new_proxy_quoted + line[insert_at:]
    return line[:insert_at] + new_proxy_quoted + ", " + line[insert_at:]


def _remove_from_proxies_list(line, group_name):
    """从 proxies: [...] 中删除一个代理名（处理各种引用格式和逗号）。"""
    for fmt in [
        f"'{group_name}', ",
        f'"{group_name}", ',
        f"{group_name}, ",
        f", '{group_name}'",
        f', "{group_name}"',
        f", {group_name}",
        f"'{group_name}'",
        f'"{group_name}"',
    ]:
        idx = line.find(fmt)
        if idx >= 0:
            return line[:idx] + line[idx + len(fmt):]
    return line


def _config_add_watch_group(raw, ut_group, filtered_nodes, url, interval, tolerance, timeout, target_group):
    """在 config.yaml 中添加 url-test 组，并加入目标 Selector 的 proxies 列表。
    返回修改后的 YAML 文本，如果找不到 proxy-groups 则返回 None。
    """
    proxies_str = ", ".join(_yaml_quote(n) for n in filtered_nodes)
    ut_line = (
        f"    - {{ name: '{ut_group}', type: url-test,"
        f" url: '{url}', interval: {interval}, tolerance: {tolerance}, timeout: {timeout},"
        f" proxies: [{proxies_str}] }}"
    )
    ut_quoted = _yaml_quote(ut_group)

    lines = raw.splitlines()
    out = []
    group_inserted = False
    proxy_added = False

    for line in lines:
        if not group_inserted and line.rstrip() == "proxy-groups:":
            out.append(line)
            out.append(ut_line)
            group_inserted = True
            continue
        if not proxy_added and _line_is_group(line, target_group):
            line = _add_to_proxies_list(line, ut_quoted)
            proxy_added = True
        out.append(line)

    if not group_inserted:
        return None
    return "\n".join(out) + "\n"


def _config_remove_watch_group(raw, ut_group, target_group):
    """从 config.yaml 中移除 url-test 组，并从目标 Selector 的 proxies 列表中删除。
    返回 (修改后的 YAML 文本, 是否找到了组)。
    """
    lines = raw.splitlines()
    out = []
    removed = False
    for line in lines:
        if _line_is_group(line, ut_group):
            removed = True
            continue
        if _line_is_group(line, target_group):
            line = _remove_from_proxies_list(line, ut_group)
        out.append(line)
    return "\n".join(out) + "\n", removed


def _config_has_group(raw, group_name):
    """检查 YAML 文本中是否包含指定名称的 proxy-group。"""
    return any(_line_is_group(line, group_name) for line in raw.splitlines())


def _api_raw(method, path, body=None):
    """调用 mihomo API，不退出程序。返回 (success: bool, data: dict|None)。"""
    sock, http_url, secret = _get_args()
    headers = {"Content-Type": "application/json"}
    if secret:
        headers["Authorization"] = f"Bearer {secret}"

    try:
        if sock and Path(sock).exists():
            conn = UnixHTTPConnection(sock)
            body_bytes = body if isinstance(body, bytes) else (body.encode() if body else None)
            conn.request(method, path, body=body_bytes, headers=headers)
            resp = conn.getresponse()
            raw = resp.read()
            if resp.status >= 400:
                return False, None
            return True, (json.loads(raw) if raw.strip() else None) or {}
        else:
            url = http_url.rstrip("/") + path
            data = body if isinstance(body, bytes) else (body.encode() if body else None)
            req = urllib.request.Request(url, data=data, headers=headers, method=method)
            with urllib.request.urlopen(req, timeout=10) as resp:
                raw = resp.read()
                return True, (json.loads(raw) if raw.strip() else None) or {}
    except Exception:
        return False, None


def _group_exists_in_api(group_name):
    """检查组是否在 mihomo 运行时中存在（不退出程序）。"""
    ok, data = _api_raw("GET", f"/proxies/{_urlencode(group_name)}")
    return ok and data is not None


def _reload_mihomo(wait_for_group=None, restart_process=False):
    """重载 mihomo 配置。
    如果 restart_process=True 或修改了 proxy-groups，需要重启进程。
    否则使用 PUT /configs 热重载。
    如果指定了 wait_for_group，还会等待该组出现在 proxies API 中。
    返回是否成功。
    """
    paths = _get_paths()
    config_file = paths["config_file"]

    if restart_process or not config_file.exists():
        # 重启进程：先停止，再启动
        pid_file = paths["pid_file"]
        pid = _read_pid(pid_file)
        if pid and _is_pid_running(pid):
            try:
                os.kill(pid, signal.SIGTERM)
                for _ in range(10):
                    time.sleep(0.5)
                    if not _is_pid_running(pid):
                        break
                else:
                    os.kill(pid, signal.SIGKILL)
                    time.sleep(0.5)
            except ProcessLookupError:
                pass
            except PermissionError:
                pass
        _unlink_if_exists(pid_file)

        # 启动新进程
        bin_path = paths["bin_path"]
        config_dir = paths["config_dir"]
        log_file = paths["log_file"]
        if not _binary_exists(bin_path):
            return False

        config_dir.mkdir(parents=True, exist_ok=True)
        log_file.parent.mkdir(parents=True, exist_ok=True)
        pid_file.parent.mkdir(parents=True, exist_ok=True)

        cmd = [bin_path, "-d", str(config_dir)]
        if config_file.exists():
            cmd.extend(["-f", str(config_file)])

        with log_file.open("ab") as log:
            proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        pid_file.write_text(str(proc.pid) + "\n")
    else:
        # 热重载：发送配置文件路径
        try:
            payload = json.dumps({"path": str(config_file)}).encode()
            ok, _ = _api_raw("PUT", "/configs", body=payload)
            if not ok:
                return False
        except Exception:
            return False

    # 等待 API 恢复
    api_ready = False
    for _ in range(30):
        time.sleep(0.5)
        ok, _ = _api_raw("GET", "/version")
        if ok:
            api_ready = True
            break
    if not api_ready:
        return False
    # 等待指定组出现
    if wait_for_group:
        for _ in range(30):
            time.sleep(0.5)
            if _group_exists_in_api(wait_for_group):
                return True
        return False
    return True


# ── best: 核心逻辑 ──────────────────────────────────────────────────


def _best_filter_nodes(group_name, keywords):
    """按关键词过滤策略组中的真实节点。返回 (filtered, group_data)。"""
    data = api("GET", f"/proxies/{_urlencode(group_name)}")
    if "all" not in data:
        print(f"'{group_name}' is not a group or not found.", file=sys.stderr)
        sys.exit(1)

    proxies_data = api("GET", "/proxies", quiet=True)
    proxies = proxies_data.get("proxies") or {}
    group_types = ("Selector", "URLTest", "Fallback", "LoadBalance")
    group_names = {k for k, v in proxies.items() if v.get("type") in group_types}
    _skip_exact = ("DIRECT", "REJECT", "GLOBAL")

    all_nodes = data.get("all") or []
    kw_lower = [k.lower() for k in keywords]
    filtered = [
        n for n in all_nodes
        if n not in _skip_exact
        and n not in group_names
        and any(kw in n.lower() for kw in kw_lower)
    ]

    if not filtered:
        print(f"No nodes matching {keywords} in '{group_name}'.")
        regions = set()
        for n in all_nodes:
            if n not in _skip_exact and n not in group_names:
                parts = n.split("-")
                if len(parts) >= 2:
                    region_name = "".join(c for c in parts[1] if not c.isdigit())
                    if region_name:
                        regions.add(region_name)
        if regions:
            print(f"  Available regions: {', '.join(sorted(regions))}")
        sys.exit(1)

    return filtered, data


def _best_test_all(filtered, url, timeout, concurrency, kw_display):
    """并发测试所有节点延迟，返回 (alive, dead, total)。"""
    total = len(filtered)
    results = []
    lock = threading.Lock()
    completed = 0
    start = time.time()
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = {executor.submit(_test_node_delay, n, url, timeout): n for n in filtered}
        for future in as_completed(futures):
            name, d = future.result()
            with lock:
                completed += 1
                results.append((name, d))
                elapsed = time.time() - start
                ds = f"{d}ms" if d > 0 else "timeout"
                print(f"\r  [{completed}/{total}] {name:<30} {ds:>8}  ({elapsed:.0f}s)    ", end="", flush=True)
    print("\r" + " " * 80 + "\r", end="")

    results.sort(key=lambda x: (x[1] == 0, x[1]))
    alive = [(n, d) for n, d in results if d > 0]
    dead = [(n, d) for n, d in results if d == 0]
    return alive, dead, total


def _best_print_results(alive, dead, total, kw_display):
    """打印测试结果。"""
    print(f"  Reachable nodes ({len(alive)}/{total}):")
    for i, (name, d) in enumerate(alive):
        marker = " ← best" if i == 0 else ""
        print(f"    {i+1:>2}. {name}: {d}ms{marker}")
    if dead:
        print(f"  Timeout ({len(dead)}): {', '.join(n for n, _ in dead[:5])}{'...' if len(dead) > 5 else ''}")


def _best_switch(group, node_name, dry_run=False):
    """切换策略组到指定节点。"""
    if dry_run:
        print(f"  (dry-run, would switch to {node_name})")
        return
    api("PUT", f"/proxies/{_urlencode(group)}", {"name": node_name})
    print(f"  ✓ Switched '{group}' → {node_name}")


def _best_list_watches():
    """列出所有活跃的 watch 组及其运行状态。"""
    # 从 API 获取所有 proxy groups
    try:
        proxies_data = api("GET", "/proxies", quiet=True)
    except SystemExit:
        print("Cannot connect to mihomo API.", file=sys.stderr)
        sys.exit(1)

    proxies = proxies_data.get("proxies") or {}

    # 过滤出 best- 前缀的 URLTest 组
    watch_groups = {}
    for name, g in proxies.items():
        if name.startswith(_BEST_GROUP_PREFIX) and g.get("type") == "URLTest":
            watch_groups[name] = g

    if not watch_groups:
        print("No active watch groups.")
        return

    # 加载状态文件
    state = _best_load_state()

    print(f"Active watch groups ({len(watch_groups)}):\n")

    for name, g in watch_groups.items():
        now = g.get("now", "-")
        all_nodes = g.get("all") or []
        node_count = len(all_nodes)

        # 获取当前节点的延迟
        delay = 0
        if now and now in proxies:
            node_data = proxies.get(now) or {}
            history = node_data.get("history") or []
            if history:
                delay = history[-1].get("delay") or 0

        # 从状态文件获取关联信息
        target_group = ""
        keywords = []
        original_node = ""
        if state and state.get("ut_group") == name:
            target_group = state.get("group", "")
            keywords = state.get("keywords", [])
            original_node = state.get("original_node", "")

        # 显示组信息
        print(f"  {name}")
        print(f"    Type: URLTest")
        print(f"    Nodes: {node_count}")
        print(f"    Current: {now}")
        if delay > 0:
            print(f"    Delay: {delay}ms")
        elif delay == 0 and now != "-":
            print(f"    Delay: timeout")

        if target_group:
            print(f"    Target: {target_group}")
        if keywords:
            print(f"    Keywords: {', '.join(keywords)}")
        if original_node:
            print(f"    Original: {original_node}")
        print()


def _best_watch_off(args, dry_run):
    """清理 watch 模式：移除 url-test 组，恢复原始选择。"""
    state = _best_load_state()

    if args.keywords:
        ut_group = _best_group_name(args.keywords)
        group = args.group
    elif state:
        ut_group = state["ut_group"]
        group = state["group"]
    else:
        print("No watch state found. Specify group and keywords, e.g.:")
        print('  mihomo-mgr.py best "\U0001f680 节点选择" 日本 美国 --watch-off')
        sys.exit(1)

    original_node = state.get("original_node", "") if state else ""
    print(f"Removing watch: {ut_group}")

    if dry_run:
        print(f"  (dry-run) Would remove '{ut_group}' from config")
        print(f"  (dry-run) Would reload mihomo")
        if original_node:
            print(f"  (dry-run) Would switch '{group}' → {original_node}")
        return

    paths = _get_paths()
    config_file = paths["config_file"]
    if not config_file.exists():
        print(f"  Config file not found: {config_file}", file=sys.stderr)
        _best_clear_state()
        return

    raw = config_file.read_text()
    new_raw, removed = _config_remove_watch_group(raw, ut_group, group)

    if not removed:
        print(f"  Group '{ut_group}' not found in config (already removed?).")
        _best_clear_state()
        return

    config_file.write_text(new_raw)
    print(f"  Removed '{ut_group}' from config.")

    print("  Restarting mihomo...")
    if not _reload_mihomo(restart_process=True):
        print("  ✗ Mihomo failed to restart.", file=sys.stderr)
        config_file.write_text(raw)
        print("  Config rolled back.", file=sys.stderr)
        sys.exit(1)
    print("  ✓ Mihomo restarted.")

    if original_node:
        try:
            api("PUT", f"/proxies/{_urlencode(group)}", {"name": original_node})
            print(f"  ✓ Switched '{group}' → {original_node}")
        except SystemExit:
            print(f"  Warning: could not switch back to '{original_node}'.", file=sys.stderr)

    _best_clear_state()
    print(f"\n  Watch removed.")


def cmd_best(args):
    """Filter nodes by keywords, test delays, and auto-select the fastest.

    With --watch, creates a url-test proxy group in config.yaml with the
    filtered nodes, reloads mihomo, and lets the native url-test mechanism
    handle health checks and failover — no external polling needed.
    """
    url = args.url or "http://www.gstatic.com/generate_204"
    timeout = args.timeout or 5000
    concurrency = args.concurrency or 10
    keywords = args.keywords
    kw_display = ", ".join(keywords)
    dry_run = args.dry_run

    # ── list: 列出所有 watch 组 ──
    if getattr(args, "list", False):
        _best_list_watches()
        return

    # ── switch: 切换到指定的 watch 组 ──
    if getattr(args, "switch", False):
        if not keywords:
            print("Error: keywords are required. Example: best \"\U0001f680 节点选择\" 日本 美国 --switch", file=sys.stderr)
            sys.exit(1)
        ut_group = _best_group_name(keywords)
        if dry_run:
            print(f"  (dry-run) Would switch '{args.group}' → {ut_group}")
            return
        try:
            api("PUT", f"/proxies/{_urlencode(args.group)}", {"name": ut_group})
            print(f"  ✓ Switched '{args.group}' → {ut_group}")
        except SystemExit:
            print(f"  ✗ Failed to switch. Group '{ut_group}' may not exist.", file=sys.stderr)
            print(f"  Create it first: mihomo-mgr.py best \"{args.group}\" {' '.join(keywords)} --watch", file=sys.stderr)
        return

    # ── watch-off: 清理模式 ──
    if getattr(args, "watch_off", False):
        _best_watch_off(args, dry_run)
        return

    if not keywords:
        print("Error: keywords are required. Example: best \"\U0001f680 节点选择\" 日本 美国", file=sys.stderr)
        sys.exit(1)

    # ── 过滤节点 ──
    filtered, data = _best_filter_nodes(args.group, keywords)
    total = len(filtered)
    now_name = data.get("now", "")

    # ── 初始测试 ──
    print(f"Filtering {total} nodes matching [{kw_display}] in '{args.group}'...")
    print(f"Testing delays (timeout={timeout}ms, concurrency={concurrency})...\n")

    alive, dead, total = _best_test_all(filtered, url, timeout, concurrency, kw_display)

    if not alive:
        print(f"All {total} nodes matching [{kw_display}] are unreachable.")
        sys.exit(1)

    _best_print_results(alive, dead, total, kw_display)
    best_name, best_delay = alive[0]
    print(f"\n  Best: {best_name} ({best_delay}ms)")

    # ── 非 watch 模式：直接选择最快节点 ──
    if not args.watch:
        if best_name == now_name:
            print(f"  Already selected — no change needed.")
        else:
            if now_name:
                print(f"  Previous: {now_name}")
            _best_switch(args.group, best_name, dry_run)
        return

    # ── watch 模式：创建 url-test 组，让 mihomo 原生接管 ──
    ut_group = _best_group_name(keywords)
    interval = args.interval or 15
    tolerance = args.tolerance or 50
    health_timeout = args.health_timeout or 2000

    if dry_run:
        print(f"\n  (dry-run) Would create url-test group: {ut_group}")
        print(f"  (dry-run) Nodes: {len(alive)}, interval={interval}s, tolerance={tolerance}ms, timeout={health_timeout}ms")
        print(f"  (dry-run) Would switch '{args.group}' → {ut_group}")
        return

    # 读取 config.yaml
    paths = _get_paths()
    config_file = paths["config_file"]
    if not config_file.exists():
        print(f"\n  Config file not found: {config_file}", file=sys.stderr)
        print("  Watch mode requires a config file. Run 'sub-pull' first.", file=sys.stderr)
        sys.exit(1)

    raw = config_file.read_text()

    if _config_has_group(raw, ut_group):
        print(f"\n  url-test group '{ut_group}' already exists in config.")
        # 检查 mihomo 运行时是否已加载该组
        if _group_exists_in_api(ut_group):
            print(f"  Group already loaded in mihomo.")
        else:
            # 组在 config 里但 mihomo 没加载，需要重启进程
            print(f"  Group not loaded in mihomo, restarting...")
            if not _reload_mihomo(wait_for_group=ut_group, restart_process=True):
                print("  ✗ Mihomo failed to restart.", file=sys.stderr)
                sys.exit(1)
            print("  ✓ Mihomo restarted.")
    else:
        alive_names = [n for n, _ in alive]
        new_raw = _config_add_watch_group(
            raw, ut_group, alive_names, url, interval, tolerance, health_timeout, args.group,
        )
        if new_raw is None:
            print(f"\n  Failed to parse config: proxy-groups section not found.", file=sys.stderr)
            sys.exit(1)

        config_file.write_text(new_raw)
        print(f"\n  Added url-test group '{ut_group}' ({len(alive)} nodes, interval={interval}s, timeout={health_timeout}ms)")

        # 重启 mihomo，等待新组出现
        print("  Restarting mihomo...")
        if not _reload_mihomo(wait_for_group=ut_group, restart_process=True):
            print("  ✗ Mihomo failed to restart.", file=sys.stderr)
            config_file.write_text(raw)
            print("  Config rolled back.", file=sys.stderr)
            sys.exit(1)
        print("  ✓ Mihomo restarted.")

    # 切换策略组到 url-test 组
    api("PUT", f"/proxies/{_urlencode(args.group)}", {"name": ut_group})
    print(f"  ✓ Switched '{args.group}' → {ut_group}")

    # 保存状态（用于 --watch-off 恢复）
    _best_save_state(args.group, now_name, ut_group, keywords)

    print(f"\n  Watch active. Mihomo natively handles health checks and failover.")
    print(f"  To stop: mihomo-mgr.py best \"{args.group}\" --watch-off")


def cmd_conns(args):
    """List active connections."""
    data = api("GET", "/connections")
    conns = data.get("connections") or []
    if not conns:
        print("No active connections.")
        return
    up = data.get("uploadTotal", 0)
    down = data.get("downloadTotal", 0)
    print(f"Total: {len(conns)} connections  ↑ {_fmt_bytes(up)}  ↓ {_fmt_bytes(down)}\n")
    # Sort by download speed desc
    conns.sort(key=lambda c: c.get("download", 0), reverse=True)
    limit = args.limit or 20
    for c in conns[:limit]:
        meta = c.get("metadata") or {}
        host = (meta.get("host") or meta.get("destinationIP", "?"))
        port = meta.get("destinationPort", "")
        chain = " → ".join(c.get("chains") or [])
        rule = c.get("rule", "")
        dl = _fmt_bytes(c.get("download", 0))
        ul = _fmt_bytes(c.get("upload", 0))
        print(f"  {host}:{port}  ↑{ul} ↓{dl}  [{chain}]  ({rule})")


def cmd_conns_close(args):
    """Close connections."""
    if args.id:
        api("DELETE", f"/connections/{args.id}")
        print(f"Closed connection {args.id}")
    else:
        api("DELETE", "/connections")
        print("Closed all connections.")


def cmd_rules(args):
    """List rules."""
    data = api("GET", "/rules")
    rules = data.get("rules") or []
    limit = args.limit or 30
    print(f"Total: {len(rules)} rules (showing first {limit})\n")
    for r in rules[:limit]:
        print(f"  {r.get('type','?')}: {r.get('payload','')} → {r.get('proxy','')}")


def cmd_dns(args):
    """Query DNS resolution."""
    result = api("GET", f"/dns/query?name={_urlencode(args.domain)}&type={args.type}")
    answers = result.get("Answer") or []
    if not answers:
        print(f"No DNS records for {args.domain}")
        return
    for a in answers:
        print(f"  {a.get('Name','')}  {a.get('Type','')}  {a.get('data','')}")


def cmd_flush_dns(args):
    """Flush DNS cache."""
    api("POST", "/cache/flushdns")
    print("DNS cache flushed.")


def cmd_restart(args):
    """Restart mihomo core."""
    api("PUT", "/restart")
    print("Core restarting...")


def cmd_upgrade_geo(args):
    """Update GeoIP/GeoSite databases."""
    api("POST", "/configs/geo")
    print("GeoIP/GeoSite update triggered.")


def cmd_db_check(args):
    """Check required mihomo database files."""
    names = _selected_db_files(args)
    missing = _missing_db_files(names)
    if not missing:
        print("DB files: ok")
        return

    print("Missing DB files:")
    for name in missing:
        print(f"  {name}")
    if args.download:
        _download_db_files(missing)


def cmd_db_download(args):
    """Download missing or requested mihomo database files."""
    names = _selected_db_files(args)
    missing = names if args.force else _missing_db_files(names)
    if not missing:
        print("DB files: ok")
        return
    _download_db_files(missing)


def cmd_start(args):
    """Start mihomo as a background process."""
    paths = _get_paths()
    if _read_running_pid(paths["pid_file"]):
        print(f"mihomo is already running (pid {_read_pid(paths['pid_file'])})")
        return

    paths["config_dir"].mkdir(parents=True, exist_ok=True)
    paths["log_file"].parent.mkdir(parents=True, exist_ok=True)
    paths["pid_file"].parent.mkdir(parents=True, exist_ok=True)

    if not _binary_exists(paths["bin_path"]):
        print(f"mihomo binary not found: {paths['bin_path']}", file=sys.stderr)
        sys.exit(1)

    if not args.skip_db_check:
        missing = _missing_db_files(DEFAULT_DB_FILES)
        if missing:
            _download_db_files(missing)

    # 启动前把 config.json 的参数同步到 config.yaml
    if not args.no_patch:
        if _patch_config_yaml(_load_mgr_config(), paths):
            print("Patched config.yaml with config-set values")

    cmd = [paths["bin_path"], "-d", str(paths["config_dir"])]
    if args.config:
        cmd.extend(["-f", str(Path(args.config).expanduser())])
    elif paths["config_file"].exists():
        cmd.extend(["-f", str(paths["config_file"])])

    with paths["log_file"].open("ab") as log:
        proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    paths["pid_file"].write_text(str(proc.pid) + "\n")
    print(f"Started mihomo pid {proc.pid}")
    print(f"Log: {paths['log_file']}")


def cmd_stop(args):
    """Stop mihomo process started by mihomo-mgr."""
    paths = _get_paths()
    pid = _read_pid(paths["pid_file"])
    if not pid or not _is_pid_running(pid):
        print("mihomo is not running")
        _unlink_if_exists(paths["pid_file"])
        return

    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        _unlink_if_exists(paths["pid_file"])
        print(f"Stopped mihomo pid {pid} (already exited)")
        return
    deadline = time.time() + args.timeout
    while time.time() < deadline:
        if not _is_pid_running(pid):
            _unlink_if_exists(paths["pid_file"])
            print(f"Stopped mihomo pid {pid}")
            return
        time.sleep(0.2)

    if args.force:
        os.kill(pid, signal.SIGKILL)
        _unlink_if_exists(paths["pid_file"])
        print(f"Killed mihomo pid {pid}")
    else:
        print(f"mihomo pid {pid} did not stop within {args.timeout}s")


def cmd_restart_proc(args):
    """Restart mihomo process."""
    cmd_stop(args)
    cmd_start(args)


def cmd_logs(args):
    """Show recent mihomo log lines."""
    paths = _get_paths()
    log_path = paths["log_file"]
    if not log_path.exists():
        print(f"Log file not found: {log_path}")
        return

    if args.follow:
        print(f"Following {log_path} (Ctrl-C to stop)...")
        try:
            subprocess.run(["tail", "-n", str(args.lines), "-f", str(log_path)], check=False)
        except KeyboardInterrupt:
            print()
        return

    size = _fmt_bytes(log_path.stat().st_size)
    with log_path.open("rb") as f:
        line_count = sum(1 for _ in f)
    print(f"Log: {log_path} ({size}, {line_count} lines)")
    if line_count == 0:
        return
    print()
    for line in _tail(log_path, args.lines):
        print(line, end="")


def cmd_logs_clear(args):
    """Truncate or trim the mihomo log file."""
    paths = _get_paths()
    log_path = paths["log_file"]
    if not log_path.exists():
        print(f"Log file not found: {log_path}")
        return

    if args.keep:
        lines = _tail(log_path, args.keep)
        log_path.write_text("".join(lines))
        print(f"Trimmed {log_path} to last {args.keep} lines ({_fmt_bytes(log_path.stat().st_size)})")
    else:
        log_path.write_text("")
        print(f"Cleared {log_path}")


def cmd_config(args):
    """Show persisted mihomo-mgr configuration."""
    cfg = _load_mgr_config()
    paths = _get_paths()
    print(f"Config store: {_mgr_config_path()}")
    if cfg:
        print("Persisted:")
        for key in sorted(cfg):
            print(f"  {key}: {cfg[key]}")
    else:
        print("Persisted: none")
    print("Effective:")
    print(f"  config_dir: {paths['config_dir']}")
    print(f"  bin: {paths['bin_path']}")
    print(f"  log_file: {paths['log_file']}")
    print(f"  pid_file: {paths['pid_file']}")
    print(f"  raw_sub_file: {paths['raw_sub_file']}")
    print(f"  config_file: {paths['config_file']}")
    sock, api_url, secret = _get_args()
    print(f"  api: {api_url}")
    print(f"  sock: {sock or '-'}")
    print(f"  secret: {'set' if secret else '-'}")
    http_url, socks_url, no_proxy = _proxy_values(argparse.Namespace(
        host=None,
        http_port=None,
        socks_port=None,
        http=None,
        socks=None,
        no_proxy=None,
    ))
    mixed_port = _cfg_value(cfg, "mixed_port", "-")
    print(f"  mixed_port: {mixed_port}")
    print(f"  proxy_http: {http_url}")
    print(f"  proxy_socks: {socks_url}")
    print(f"  no_proxy: {no_proxy}")


def cmd_config_init(args):
    """Create an editable default configuration file."""
    path = _mgr_config_path()
    if path.exists() and not args.force:
        print(f"Config already exists: {path}")
        print("Use --force to overwrite it.")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(_default_mgr_config_text())
    print(f"Created {path}")
    print("Edit this file to set subscription URL, paths, proxy ports, and API settings.")


def cmd_config_set(args):
    """Persist mihomo-mgr configuration."""
    cfg = _load_mgr_config()
    updates = {
        "config_dir": args.persist_config_dir,
        "bin_dir": args.persist_bin_dir,
        "bin": args.persist_bin,
        "log_file": args.persist_log_file,
        "pid_file": args.persist_pid_file,
        "api": args.persist_api,
        "sock": args.persist_sock,
        "sub_url": args.persist_sub_url,
        "proxy_host": args.persist_proxy_host,
        "mixed_port": args.persist_mixed_port,
        "proxy_http_port": args.persist_proxy_http_port,
        "proxy_socks_port": args.persist_proxy_socks_port,
        "proxy_http": args.persist_proxy_http,
        "proxy_socks": args.persist_proxy_socks,
        "no_proxy": args.persist_no_proxy,
    }
    # 校验端口值
    for key in ("mixed_port", "proxy_http_port", "proxy_socks_port"):
        val = updates.get(key)
        if val:
            try:
                port = int(val)
                if not (1 <= port <= 65535):
                    raise ValueError
            except ValueError:
                print(f"Invalid port value for {key}: {val} (must be 1-65535)", file=sys.stderr)
                sys.exit(1)
    for key, value in updates.items():
        if value:
            cfg[key] = str(Path(value).expanduser()) if key.endswith("_dir") or key.endswith("_file") or key == "bin" else value
    if args.persist_secret is not None:
        cfg["secret"] = args.persist_secret
    _save_mgr_config(cfg)
    _invalidate_config_cache()
    print(f"Saved {_mgr_config_path()}")


def cmd_config_clear(args):
    """Remove persisted mihomo-mgr configuration."""
    _unlink_if_exists(_mgr_config_path())
    _invalidate_config_cache()
    print(f"Removed {_mgr_config_path()}")


def cmd_proxy_status(args):
    """Show proxy variables configured in the current terminal environment."""
    active = []
    missing = []
    for key in PROXY_ENV_KEYS:
        value = os.environ.get(key)
        if value:
            active.append((key, value))
        else:
            missing.append(key)

    print("Proxy environment:")
    if active:
        for key, value in active:
            print(f"  {key}={value}")
    else:
        print("  none")

    coverage_keys = ("http_proxy", "https_proxy", "all_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY")
    coverage = sum(1 for key in coverage_keys if os.environ.get(key))
    print(f"Coverage: {coverage}/{len(coverage_keys)} core variables configured")
    http_url, socks_url, no_proxy = _proxy_values(argparse.Namespace(
        host=None,
        http_port=None,
        socks_port=None,
        http=None,
        socks=None,
        no_proxy=None,
    ))
    print("Proxy-on target:")
    print(f"  http: {http_url}")
    print(f"  socks: {socks_url}")
    print(f"  no_proxy: {no_proxy}")
    if missing and args.verbose:
        print("Missing:")
        for key in missing:
            print(f"  {key}")


def cmd_proxy_on(args):
    """Print shell exports for a temporary proxy environment."""
    http_url, socks_url, no_proxy = _proxy_values(args)
    exports = {
        "http_proxy": http_url,
        "https_proxy": http_url,
        "ftp_proxy": http_url,
        "rsync_proxy": http_url,
        "all_proxy": socks_url,
        "HTTP_PROXY": http_url,
        "HTTPS_PROXY": http_url,
        "FTP_PROXY": http_url,
        "RSYNC_PROXY": http_url,
        "ALL_PROXY": socks_url,
        "no_proxy": no_proxy,
        "NO_PROXY": no_proxy,
        "npm_config_proxy": http_url,
        "npm_config_https_proxy": http_url,
        "NPM_CONFIG_PROXY": http_url,
        "NPM_CONFIG_HTTPS_PROXY": http_url,
        "yarn_proxy": http_url,
        "yarn_https_proxy": http_url,
        "YARN_PROXY": http_url,
        "YARN_HTTPS_PROXY": http_url,
        "CARGO_HTTP_PROXY": http_url,
        "grpc_proxy": http_url,
        "GRPC_PROXY": http_url,
    }
    for key, value in exports.items():
        print(f"export {key}={_shell_quote(value)}")
    if not args.quiet:
        print("# Apply with: eval \"$(mihomo-mgr.py proxy-on)\"")


def cmd_proxy_off(args):
    """Print shell commands that unset proxy variables."""
    for key in PROXY_ENV_KEYS:
        print(f"unset {key}")
    if not args.quiet:
        print("# Apply with: eval \"$(mihomo-mgr.py proxy-off)\"")


def cmd_sub_pull(args):
    """Pull subscription and generate normalized config.yaml."""
    cfg = _load_mgr_config()
    paths = _get_paths()
    url = args.url or _cfg_value(cfg, "sub_url")
    if not url:
        print("Subscription URL is not configured.", file=sys.stderr)
        print("Set it with: mihomo-mgr.py config-set --sub-url '<url>'", file=sys.stderr)
        sys.exit(1)

    paths["config_dir"].mkdir(parents=True, exist_ok=True)
    raw = _fetch_subscription(url)
    paths["raw_sub_file"].write_text(raw)
    normalized = _normalize_subscription_config(raw, cfg)
    paths["config_file"].write_text(normalized)

    print("Subscription pulled.")
    print(f"Raw cache: {paths['raw_sub_file']}")
    print(f"Generated config: {paths['config_file']}")
    print(f"Source: {_redact_url(url)}")


def cmd_sub_show(args):
    """Show subscription cache paths and status."""
    cfg = _load_mgr_config()
    paths = _get_paths()
    url = _cfg_value(cfg, "sub_url")
    print(f"Subscription URL: {_redact_url(url) if url else '-'}")
    print(f"Raw cache: {paths['raw_sub_file']} ({_file_status(paths['raw_sub_file'])})")
    print(f"Generated config: {paths['config_file']} ({_file_status(paths['config_file'])})")


# ── Helpers ──────────────────────────────────────────────────────────


def _fmt_bytes(n):
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024:
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}TB"


def _urlencode(s):
    return urllib.parse.quote(s, safe="")


def _print_process_status():
    paths = _get_paths()
    pid = _read_pid(paths["pid_file"])
    discovered = _find_mihomo_processes()
    running = bool((pid and _is_pid_running(pid)) or discovered)
    display_pid = pid or (discovered[0]["pid"] if discovered else None)
    print("Process:")
    print(f"  Running: {'yes' if running else 'no'}")
    print(f"  PID: {display_pid if display_pid else '-'}")
    if discovered:
        print("  Discovered:")
        for item in discovered:
            print(f"    {item['pid']}: {item['cmd']}")
    missing = _missing_db_files(DEFAULT_DB_FILES)
    if missing:
        print(f"  DB files: missing {', '.join(missing)}")
    else:
        print("  DB files: ok")


def _mgr_config_path():
    return Path(os.environ.get("MIHOMO_MGR_CONFIG", DEFAULT_MGR_CONFIG_PATH)).expanduser()


_mgr_config_cache = None


def _load_mgr_config():
    global _mgr_config_cache
    if _mgr_config_cache is not None:
        return _mgr_config_cache
    try:
        _mgr_config_cache = json.loads(_strip_json_comments(_mgr_config_path().read_text()))
    except (FileNotFoundError, json.JSONDecodeError):
        _mgr_config_cache = {}
    return _mgr_config_cache


def _invalidate_config_cache():
    global _mgr_config_cache
    _mgr_config_cache = None


def _cfg_value(cfg, key, default=None):
    value = cfg.get(key)
    return value if value not in (None, "") else default


def _save_mgr_config(cfg):
    path = _mgr_config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cfg, indent=2, sort_keys=True) + "\n")


def _strip_json_comments(text):
    lines = []
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("//") or stripped.startswith("#"):
            continue
        lines.append(line)
    return "\n".join(lines)


def _default_mgr_config_text():
    return """{
  // mihomo-mgr configuration.
  // This file may be edited by hand. Lines beginning with // are ignored.

  // REQUIRED after subscription support is used:
  // Subscription URL. Treat it as a secret if it contains a token.
  // Leave empty until you want mihomo-mgr to pull/generate config.yaml from a subscription.
  "sub_url": "",

  // RECOMMENDED:
  // mihomo working directory. subscription cache, config.yaml, logs, and pid live here by default.
  // If empty, the current working directory is used.
  "config_dir": "",

  // Generated subscription files under config_dir:
  // - subscription.raw.yaml keeps the unmodified subscription response.
  // - config.yaml is generated from the raw subscription with local runtime settings.

  // RECOMMENDED when using start/stop/restart:
  // Directory containing the mihomo binary. If empty, the current working directory is used.
  "bin_dir": "",

  // OPTIONAL:
  // Absolute mihomo binary path. If set, this overrides bin_dir.
  "bin": "",

  // OPTIONAL:
  // Explicit log/pid files. Empty means <config_dir>/mihomo.log and <config_dir>/mihomo.pid.
  "log_file": "",
  "pid_file": "",

  // RECOMMENDED:
  // mihomo external controller HTTP API. Keep this aligned with generated config.yaml.
  "api": "http://127.0.0.1:9090",

  // OPTIONAL:
  // Unix socket path. If set and the socket exists, it is used instead of api.
  "sock": "",

  // OPTIONAL:
  // External controller secret. Leave empty if mihomo has no secret configured.
  "secret": "",

  // RECOMMENDED:
  // mihomo mixed-port for HTTP+SOCKS. Also used as fallback for terminal proxy ports.
  // Set this to override the port in generated config.yaml.
  "mixed_port": "10808",

  // Generated mihomo config policy. 10808 means HTTP and SOCKS share the mixed-port.
  "proxy_host": "127.0.0.1",

  // OPTIONAL: separate terminal proxy ports. When empty, mixed_port is used.
  "proxy_http_port": "",
  "proxy_socks_port": "",

  // OPTIONAL:
  // Full proxy URLs. Usually leave empty so mihomo-mgr builds them from host/ports
  // or reads ports from mihomo /configs.
  "proxy_http": "",
  "proxy_socks": "",

  // RECOMMENDED:
  // Hosts that should bypass terminal proxy environment variables.
  "no_proxy": "localhost,127.0.0.1,::1,*.local"
}
"""


def _read_pid(pid_file):
    try:
        raw = pid_file.read_text().strip()
        return int(raw) if raw else None
    except (FileNotFoundError, ValueError):
        return None


def _read_running_pid(pid_file):
    pid = _read_pid(pid_file)
    return pid if pid and _is_pid_running(pid) else None


def _is_pid_running(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def _unlink_if_exists(path):
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def _missing_db_files(names):
    config_dir = _get_paths()["config_dir"]
    return [name for name in names if not (config_dir / name).exists()]


def _selected_db_files(args):
    if getattr(args, "all", False):
        return list(DB_FILES.keys())
    names = list(DEFAULT_DB_FILES)
    if getattr(args, "geodata", False):
        names.append("geoip.dat")
    if getattr(args, "asn", False):
        names.append("GeoLite2-ASN.mmdb")
    return names


def _binary_exists(bin_path):
    path = Path(bin_path).expanduser()
    if path.parent != Path("."):
        return path.exists() and os.access(path, os.X_OK)
    return shutil.which(bin_path) is not None


def _download_db_files(names):
    config_dir = _get_paths()["config_dir"]
    config_dir.mkdir(parents=True, exist_ok=True)
    failed = []
    for name in names:
        target = config_dir / name
        urls = DB_FILES[name]
        for url in urls:
            try:
                print(f"Downloading {name}: {url}")
                tmp = target.with_suffix(target.suffix + ".tmp")
                with urllib.request.urlopen(url, timeout=30) as resp:
                    tmp.write_bytes(resp.read())
                tmp.replace(target)
                print(f"Saved {target}")
                break
            except Exception as e:
                print(f"  failed: {e}", file=sys.stderr)
        else:
            failed.append(name)
    if failed:
        print(f"Failed to download: {', '.join(failed)}", file=sys.stderr)
        sys.exit(1)


def _proxy_values(args):
    cfg = _load_mgr_config()
    # 配置已提供完整端口和主机时跳过 mihomo API（避免未运行时 10s 超时）
    _has_port = _cfg_value(cfg, "mixed_port") or (
        _cfg_value(cfg, "proxy_http_port") and _cfg_value(cfg, "proxy_socks_port")
    )
    if _has_port and _cfg_value(cfg, "proxy_host"):
        mihomo_cfg = {}
    else:
        mihomo_cfg = _get_mihomo_config_quiet()
    host = args.host or _cfg_value(cfg, "proxy_host") or _proxy_host_from_mihomo(mihomo_cfg) or DEFAULT_PROXY_HOST
    http_port = str(
        args.http_port
        or _cfg_value(cfg, "mixed_port")
        or _cfg_value(cfg, "proxy_http_port")
        or _proxy_http_port_from_mihomo(mihomo_cfg)
        or DEFAULT_HTTP_PROXY_PORT
    )
    socks_port = str(
        args.socks_port
        or _cfg_value(cfg, "mixed_port")
        or _cfg_value(cfg, "proxy_socks_port")
        or _proxy_socks_port_from_mihomo(mihomo_cfg)
        or DEFAULT_SOCKS_PROXY_PORT
    )
    no_proxy = args.no_proxy or _cfg_value(cfg, "no_proxy", DEFAULT_NO_PROXY)
    http_url = args.http or _cfg_value(cfg, "proxy_http", f"http://{host}:{http_port}")
    socks_url = args.socks or _cfg_value(cfg, "proxy_socks", f"socks5://{host}:{socks_port}")
    return http_url, socks_url, no_proxy


def _get_mihomo_config_quiet():
    try:
        return api("GET", "/configs", quiet=True)
    except SystemExit:
        return {}


def _proxy_host_from_mihomo(cfg):
    bind = cfg.get("bind-address") or cfg.get("interface-name") or ""
    if bind and bind not in ("*", "0.0.0.0", "::"):
        return bind
    return None


def _proxy_http_port_from_mihomo(cfg):
    return cfg.get("mixed-port") or cfg.get("port")


def _proxy_socks_port_from_mihomo(cfg):
    return cfg.get("mixed-port") or cfg.get("socks-port")


def _shell_quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"


def _fetch_subscription(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "mihomo-mgr/1.0",
            "Accept": "text/yaml,application/yaml,text/plain,*/*",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
    except (urllib.error.URLError, OSError) as e:
        print(f"Subscription fetch failed: {e}", file=sys.stderr)
        sys.exit(1)
    return data.decode("utf-8-sig", errors="replace")


def _build_config_updates(cfg):
    """构建 config.yaml 的覆盖项（mixed-port、bind-address 等）。"""
    host = _cfg_value(cfg, "proxy_host", DEFAULT_PROXY_HOST)
    mixed_port = _cfg_value(cfg, "mixed_port") or _cfg_value(cfg, "proxy_http_port") or _cfg_value(cfg, "proxy_socks_port") or DEFAULT_HTTP_PROXY_PORT
    api_url = _cfg_value(cfg, "api", DEFAULT_HTTP)
    controller = _controller_from_api(api_url)
    secret = _cfg_value(cfg, "secret", "")

    updates = {
        "mixed-port": str(mixed_port),
        "bind-address": _yaml_quote(host),
        "external-controller": _yaml_quote(controller),
    }
    if secret:
        updates["secret"] = _yaml_quote(secret)
    return updates


def _normalize_subscription_config(raw, cfg):
    updates = _build_config_updates(cfg)
    # sub-pull 额外覆盖策略性设置
    updates["port"] = None
    updates["socks-port"] = None
    updates["allow-lan"] = "false"
    return _update_top_level_yaml(raw, updates)


def _update_top_level_yaml(raw, updates):
    lines = raw.splitlines()
    found = set()
    out = []
    for line in lines:
        key = _top_level_yaml_key(line)
        if key in updates:
            if updates[key] is not None:
                out.append(f"{key}: {updates[key]}")
            found.add(key)
        else:
            out.append(line)

    missing = [key for key in updates if key not in found and updates[key] is not None]
    if missing:
        if out and out[-1].strip():
            out.append("")
        out.append("# Generated by mihomo-mgr")
        for key in missing:
            out.append(f"{key}: {updates[key]}")
    return "\n".join(out).rstrip() + "\n"


def _top_level_yaml_key(line):
    if not line or line[0].isspace() or line.lstrip().startswith("#"):
        return None
    if ":" not in line:
        return None
    key = line.split(":", 1)[0].strip()
    return key or None


def _patch_config_yaml(cfg, paths):
    """启动前把 config.json 的可配置参数同步写入现有 config.yaml。

    覆盖 config-set 管理的 key，同时移除与 mixed-port 冲突的 port/socks-port。
    不动 allow-lan / mode 等策略性设置。
    返回是否发生了修改。
    """
    config_file = paths["config_file"]
    if not config_file.exists():
        return False
    raw = config_file.read_text()

    updates = _build_config_updates(cfg)
    # 移除与 mixed-port 冲突的独立端口
    updates["port"] = None
    updates["socks-port"] = None

    patched = _update_top_level_yaml(raw, updates)
    if patched != raw:
        config_file.write_text(patched)
        return True
    return False


def _yaml_quote(value):
    value = str(value)
    if not value:
        return '""'
    if all(c.isalnum() or c in ".:_-/" for c in value):
        return value
    return json.dumps(value, ensure_ascii=False)


def _controller_from_api(api_url):
    parsed = urllib.parse.urlparse(api_url)
    if parsed.netloc:
        return parsed.netloc
    return api_url.replace("http://", "").replace("https://", "").strip("/")


def _redact_url(url):
    parsed = urllib.parse.urlparse(url)
    if not parsed.query and not parsed.password:
        return url
    netloc = parsed.hostname or ""
    if parsed.port:
        netloc = f"{netloc}:{parsed.port}"
    redacted = parsed._replace(netloc=netloc, query="<redacted>")
    return urllib.parse.urlunparse(redacted)


def _file_status(path):
    if not path.exists():
        return "missing"
    size = path.stat().st_size
    mtime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(path.stat().st_mtime))
    return f"{size} bytes, updated {mtime}"


def _tail(path, lines):
    if lines <= 0:
        return []
    with path.open("rb") as f:
        f.seek(0, os.SEEK_END)
        end = f.tell()
        block_size = 8192
        data = b""
        while end > 0 and data.count(b"\n") <= lines:
            step = min(block_size, end)
            end -= step
            f.seek(end)
            data = f.read(step) + data
        return [line.decode(errors="replace") for line in data.splitlines(keepends=True)[-lines:]]


def _find_mihomo_processes():
    try:
        proc = subprocess.run(
            ["ps", "-eo", "pid=,comm=,args="],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except OSError:
        return []

    current_pid = os.getpid()
    results = []
    for line in proc.stdout.splitlines():
        parts = line.strip().split(None, 2)
        if len(parts) < 2:
            continue
        try:
            pid = int(parts[0])
        except ValueError:
            continue
        comm = parts[1]
        cmd = parts[2] if len(parts) > 2 else comm
        if pid == current_pid or "mihomo-mgr.py" in cmd:
            continue
        if comm == "mihomo" or cmd.endswith("/mihomo") or " mihomo " in f" {cmd} ":
            results.append({"pid": pid, "cmd": cmd})
    return results


# ── Help ────────────────────────────────────────────────────────────


def _get_api_groups():
    """Fetch proxy group names from mihomo API (returns empty list if unavailable)."""
    try:
        data = api("GET", "/proxies", quiet=True)
    except SystemExit:
        return []
    proxies = data.get("proxies") or {}
    group_types = ("Selector", "URLTest", "Fallback", "LoadBalance")
    return sorted(k for k, v in proxies.items() if v.get("type") in group_types)


def _get_api_nodes(group):
    """Fetch node names in a group from mihomo API (returns empty list if unavailable)."""
    try:
        data = api("GET", f"/proxies/{_urlencode(group)}", quiet=True)
    except SystemExit:
        return []
    return sorted(data.get("all") or []) if "all" in data else []


def _get_all_api_nodes():
    """Fetch all node names from mihomo API (returns empty list if unavailable)."""
    try:
        data = api("GET", "/proxies", quiet=True)
    except SystemExit:
        return []
    proxies = data.get("proxies") or {}
    group_types = ("Selector", "URLTest", "Fallback", "LoadBalance")
    all_nodes = set()
    for k, v in proxies.items():
        if v.get("type") in group_types:
            for n in (v.get("all") or []):
                all_nodes.add(n)
    return sorted(all_nodes)


# Map of commands to their completion logic:
# key → (arg_index, completer_type)
# completer_type: "group" | "node" | "all_nodes" | "mode" | None
_COMPLETE_MAP = {
    "nodes": [(1, "group")],
    "select": [(1, "group"), (2, "node")],
    "best": [(1, "group")],
    "delay": [(1, "all_nodes")],
    "delay-group": [(1, "group")],
    "mode": [(1, "mode")],
}


def cmd_completion(args):
    """Generate shell completion script."""
    script_path = os.path.abspath(sys.argv[0])
    # Subcommands and dynamic completions — keep in sync with dispatch
    subcmds = " ".join(sorted([
        "status", "mode", "groups", "nodes", "select", "best", "delay",
        "delay-group", "conns", "conns-close", "rules", "dns",
        "flush-dns", "api-restart", "upgrade-geo",
        "db-check", "db-download",
        "start", "stop", "restart",
        "logs", "logs-clear",
        "sub-pull", "sub-show",
        "config", "config-init", "config-set", "config-clear",
        "proxy-status", "proxy-on", "proxy-off",
        "completion",
    ]))
    dynamic_cmds = "nodes|select|best|delay|delay-group|mode"

    bash_script = f"""# mihomo-mgr bash completion — source this file or add to ~/.bashrc
_mihomo_mgr_complete() {{
    local cur prev words cword cmd result
    COMPREPLY=()
    cur="${{COMP_WORDS[COMP_CWORD]}}"
    prev="${{COMP_WORDS[COMP_CWORD-1]}}"

    # Collect non-flag words as positional args
    words=()
    for w in "${{COMP_WORDS[@]:1}}"; do
        [[ "$w" != -* ]] && words+=("$w")
    done

    cmd="${{words[0]:-}}"

    # First word: subcommand
    if [[ ${{#words[@]}} -eq 0 || ( ${{#words[@]}} -eq 1 && -z "$cur" ) ]]; then
        COMPREPLY=($(compgen -W "{subcmds}" -- "$cur"))
        return
    fi

    # Dynamic completion via API for known commands
    case "$cmd" in
        {dynamic_cmds})
            result=$({script_path} __complete "$cmd" "${{words[@]:1}}" 2>/dev/null)
            if [[ -n "$result" ]]; then
                COMPREPLY=($(compgen -W "$result" -- "$cur"))
            fi
            ;;
    esac
}}
complete -F _mihomo_mgr_complete {script_path}
complete -F _mihomo_mgr_complete mihomo-mgr.py
"""

    zsh_script = f"""# mihomo-mgr zsh completion — source this file or add to ~/.zshrc
_mihomo_mgr_complete() {{
    local -a words
    words=(${{(@)words:#-*}})
    local cmd="${{words[1]:-}}"

    if [[ -z "$cmd" ]]; then
        local cmds=({subcmds})
        _describe 'command' cmds
        return
    fi

    case "$cmd" in
        {dynamic_cmds})
            local result
            result=$({script_path} __complete "$cmd" "${{words[@]:2}}" 2>/dev/null)
            if [[ -n "$result" ]]; then
                local -a candidates
                candidates=(${{(f)result}})
                _describe 'value' candidates
            fi
            ;;
    esac
}}
compdef _mihomo_mgr_complete {script_path}
compdef _mihomo_mgr_complete mihomo-mgr.py
"""

    if args.shell == "bash":
        print(bash_script)
        print("# Install: source <(mihomo-mgr.py completion bash)")
    elif args.shell == "zsh":
        print(zsh_script)
        print("# Install: source <(mihomo-mgr.py completion zsh)")


def cmd_internal_complete(args):
    """Internal completion handler (hidden from help, used by shell completion)."""
    cmd = args.complete_cmd
    # Get all positional args after the command (stripping flags)
    positional = [a for a in args.complete_args if not a.startswith("-")]
    arg_index = len(positional)

    spec = _COMPLETE_MAP.get(cmd, [])
    candidates = []
    for idx, ctype in spec:
        if arg_index == idx:
            if ctype == "group":
                candidates = _get_api_groups()
            elif ctype == "node":
                group_name = positional[0] if positional else ""
                candidates = _get_api_nodes(group_name) if group_name else []
            elif ctype == "all_nodes":
                candidates = _get_all_api_nodes()
            elif ctype == "mode":
                candidates = ["rule", "global", "direct"]
            break

    for c in candidates:
        print(c)


CMD_GROUPS = OrderedDict([
    ("Status & Monitoring", [
        ("status", "Show overall process and proxy status"),
        ("mode", "Get/set proxy mode (rule|global|direct)"),
        ("groups", "List all proxy groups"),
        ("nodes", "List nodes in a group"),
        ("conns", "List active connections"),
        ("rules", "List routing rules"),
        ("dns", "Query DNS resolution"),
        ("logs", "Show recent mihomo logs"),
        ("logs-clear", "Clear or trim the mihomo log file"),
    ]),
    ("Control", [
        ("select", "Switch node in a proxy group"),
        ("best", "Auto-select fastest node matching keywords"),
        ("delay", "Test node delay"),
        ("delay-group", "Test all nodes in a group"),
        ("conns-close", "Close connections"),
        ("flush-dns", "Flush DNS cache"),
    ]),
    ("Process", [
        ("start", "Start mihomo in background"),
        ("stop", "Stop mihomo gracefully"),
        ("restart", "Restart mihomo process"),
    ]),
    ("Configuration", [
        ("config", "Show persisted and effective config"),
        ("config-init", "Create editable default config file"),
        ("config-set", "Persist configuration values"),
        ("config-clear", "Remove persisted configuration"),
    ]),
    ("Subscription", [
        ("sub-pull", "Pull subscription and generate config.yaml"),
        ("sub-show", "Show subscription cache status"),
    ]),
    ("Database", [
        ("db-check", "Check required DB files"),
        ("db-download", "Download DB files"),
    ]),
    ("Terminal Proxy", [
        ("proxy-status", "Show current terminal proxy vars"),
        ("proxy-on", "Print shell exports to enable proxy"),
        ("proxy-off", "Print shell commands to disable proxy"),
    ]),
    ("Maintenance", [
        ("api-restart", "Restart mihomo core via API"),
        ("upgrade-geo", "Update GeoIP/GeoSite databases"),
        ("completion", "Generate shell completion script"),
    ]),
])

HELP_EXAMPLES = [
    ("Show overall status", "mihomo-mgr.py status"),
    ("Switch proxy node", 'mihomo-mgr.py select "\U0001f680 节点选择" "S-IEPL-香港7"'),
    ("Auto-select fastest JP/US node", 'mihomo-mgr.py best "\U0001f680 节点选择" 日本 美国'),
    ("Watch & auto-failover JP/US nodes", 'mihomo-mgr.py best "\U0001f680 节点选择" 日本 美国 --watch'),
    ("List active watch groups", 'mihomo-mgr.py best --list'),
    ("Switch to watch group", 'mihomo-mgr.py best "\U0001f680 节点选择" 日本 美国 --switch'),
    ("Enable terminal proxy", 'eval "$(mihomo-mgr.py proxy-on)"'),
    ("Disable terminal proxy", 'eval "$(mihomo-mgr.py proxy-off)"'),
    ("Start mihomo", "mihomo-mgr.py start"),
    ("Configure bin path", "mihomo-mgr.py config-set --bin ~/clash/mihomo"),
    ("Pull subscription", 'mihomo-mgr.py sub-pull --url "https://..."'),
    ("Download required DB files", "mihomo-mgr.py db-download"),
    ("Show per-command help", "mihomo-mgr.py CMD --help"),
]


def _print_help(cmd=None):
    """Print user-friendly help with grouped commands and examples."""
    if cmd:
        subprocess.run([sys.executable, sys.argv[0], cmd, "--help"])
        return

    print("mihomo-mgr – manage a mihomo core process and control it via API")
    print()
    print("Usage: mihomo-mgr.py [GLOBAL-FLAGS] COMMAND [ARGS...]")
    print()
    print("Global flags:")
    print("  --sock PATH       Unix socket path for API")
    print("  --api URL         HTTP API URL (default: http://127.0.0.1:9090)")
    print("  --secret SECRET   API secret")
    print("  --config-dir DIR  mihomo config directory")
    print("  --bin-dir DIR     directory containing mihomo binary")
    print("  --bin PATH        mihomo binary path or command")
    print("  --log-file PATH   mihomo log file")
    print("  --pid-file PATH   mihomo pid file")
    print("  --version          show version and exit")
    print()
    print("Commands:")

    for group, cmds in CMD_GROUPS.items():
        print(f"  {group}:")
        for name, desc in cmds:
            print(f"    {name:<20}  {desc}")
        print()

    print("Quick examples:")
    for desc, example in HELP_EXAMPLES:
        print(f"  # {desc}")
        print(f"  $ {example}")
        print()
    print("Configuration:  ~/.config/mihomo-mgr/config.json")
    print("Use 'mihomo-mgr.py CMD --help' for per-command flags.")


# ── Main ─────────────────────────────────────────────────────────────


def main():
    # 内部补全命令：在 argparse 之前处理，不暴露给用户
    if len(sys.argv) >= 2 and sys.argv[1] == "__complete":
        ns = argparse.Namespace(
            complete_cmd=sys.argv[2] if len(sys.argv) > 2 else "",
            complete_args=sys.argv[3:] if len(sys.argv) > 3 else [],
        )
        cmd_internal_complete(ns)
        return

    p = argparse.ArgumentParser(description="mihomo-mgr - control mihomo via API")
    p.add_argument("--sock", help="Unix socket path")
    p.add_argument("--api", help=f"HTTP API URL (default: {DEFAULT_HTTP})")
    p.add_argument("--secret", help="API secret")
    p.add_argument("--config-dir", help="mihomo config directory")
    p.add_argument("--bin-dir", help="directory containing the mihomo binary")
    p.add_argument("--bin", help="mihomo binary path or command")
    p.add_argument("--log-file", help="mihomo log file")
    p.add_argument("--pid-file", help="mihomo pid file")
    p.add_argument("--version", action="version", version=f"mihomo-mgr {VERSION}")
    sub = p.add_subparsers(dest="cmd")

    s = sub.add_parser("status",
        help="Show overall process and proxy status",
        description="Display mihomo process status, version, mode, TUN, traffic, connection count, and proxy group selections.",
        epilog="Examples:\n  mihomo-mgr.py status\n  mihomo-mgr.py status --json",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--json", action="store_true", help="Output in JSON format")

    s = sub.add_parser("mode",
        help="Get/set proxy mode (rule|global|direct)",
        description="Get or set the proxy mode. When a value is given, updates it via the API. Otherwise prints the current mode.",
        epilog="Examples:\n  mihomo-mgr.py mode          # Show current mode\n  mihomo-mgr.py mode global   # Switch to global mode",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("value", nargs="?", choices=["rule", "global", "direct"],
        help="proxy mode to set (omit to show current)")

    sub.add_parser("groups",
        help="List all proxy groups with current node",
        description="List all proxy groups with their current node selection and node count.",
        epilog="Examples:\n  mihomo-mgr.py groups",
        formatter_class=argparse.RawDescriptionHelpFormatter)

    s = sub.add_parser("nodes",
        help="List nodes in a group with delay info",
        description="List all nodes in a proxy group, showing their current selection and last-known delay.",
        epilog="Examples:\n  mihomo-mgr.py nodes \"\U0001f680 节点选择\"",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("group", help="Group name")

    s = sub.add_parser("select",
        help="Switch node in a proxy group",
        description="Switch a proxy group to use a different node.",
        epilog="Examples:\n  mihomo-mgr.py select \"\U0001f680 节点选择\" \"S-IEPL-香港7\"",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("group", help="Group name")
    s.add_argument("node", help="Node name")

    s = sub.add_parser("best",
        help="Auto-select fastest node matching keywords",
        description="Filter nodes in a proxy group by one or more keywords (region names),\n"
                    "test their delays concurrently, and automatically select the fastest one.\n"
                    "Keywords are matched case-insensitively against node names.\n\n"
                    "With --watch, creates a url-test proxy group in config.yaml with the\n"
                    "filtered nodes, reloads mihomo, and lets the native url-test mechanism\n"
                    "handle health checks and failover — no external polling needed.\n"
                    "Use --watch-off to remove the url-test group and restore the original.",
        epilog='Examples:\n'
               '  mihomo-mgr.py best "\U0001f680 节点选择" 日本 美国\n'
               '  mihomo-mgr.py best "\U0001f680 节点选择" 香港 --timeout 3000\n'
               '  mihomo-mgr.py best "\U0001f680 节点选择" 日本 美国 --watch\n'
               '  mihomo-mgr.py best "\U0001f680 节点选择" 日本 --watch --interval 30\n'
               '  mihomo-mgr.py best --list\n'
               '  mihomo-mgr.py best "\U0001f680 节点选择" 日本 美国 --switch\n'
               '  mihomo-mgr.py best "\U0001f680 节点选择" --watch-off\n'
               '  mihomo-mgr.py best "\U0001f680 节点选择" 日本 --dry-run',
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("group", nargs="?", help="Proxy group name")
    s.add_argument("keywords", nargs="*", help="Region keywords to filter nodes (e.g. 日本 美国 香港)")
    s.add_argument("--url", help="Test URL (default: http://www.gstatic.com/generate_204)")
    s.add_argument("--timeout", type=int, help="Delay test timeout in ms (default: 5000)")
    s.add_argument("--concurrency", type=int, help="Max concurrent requests (default: 10)")
    s.add_argument("--dry-run", action="store_true", help="Only show results, do not switch node")
    s.add_argument("--watch", action="store_true",
        help="Create a url-test group in config and let mihomo handle failover natively")
    s.add_argument("--watch-off", action="store_true",
        help="Remove the watch url-test group and restore original selection")
    s.add_argument("--list", action="store_true",
        help="List all active watch groups and their status")
    s.add_argument("--switch", action="store_true",
        help="Switch to an existing watch group (e.g. best \"group\" 日本 美国 --switch)")
    s.add_argument("--interval", type=int, metavar="SECS",
        help="Health check interval for url-test group in seconds (default: 15)")
    s.add_argument("--tolerance", type=int, metavar="MS",
        help="Latency tolerance in ms to prevent flapping (default: 50)")
    s.add_argument("--health-timeout", type=int, metavar="MS",
        help="Health check timeout per node in ms (default: 2000)")

    s = sub.add_parser("delay",
        help="Test latency of a single node",
        description="Test the latency of a single node or group using a configurable URL and timeout.",
        epilog="Examples:\n  mihomo-mgr.py delay \"S-IEPL-香港7\"\n  mihomo-mgr.py delay DIRECT --url http://www.gstatic.com/generate_204",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("target", help="Node or group name")
    s.add_argument("--url", help="Test URL")
    s.add_argument("--timeout", type=int, help="Timeout in ms (default: 1000)")

    s = sub.add_parser("delay-group",
        help="Test latency of all nodes in a group",
        description="Test the latency of all nodes in a proxy group, sorted fastest first.",
        epilog="Examples:\n  mihomo-mgr.py delay-group \"\U0001f680 节点选择\"",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("group", help="Group name")
    s.add_argument("--url", help="Test URL")
    s.add_argument("--timeout", type=int, help="Timeout in ms (default: 1000)")
    s.add_argument("--concurrency", type=int, help="Max concurrent requests (default: 10)")

    s = sub.add_parser("conns",
        help="List active connections with traffic info",
        description="List active connections showing source, destination, rule, chain, and traffic statistics.",
        epilog="Examples:\n  mihomo-mgr.py conns\n  mihomo-mgr.py conns --limit 50",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--limit", type=int, help="Max connections to show (default: 20)")

    s = sub.add_parser("conns-close",
        help="Close one or all connections",
        description="Close a single connection by ID, or all active connections if no ID is given.",
        epilog="Examples:\n  mihomo-mgr.py conns-close         # Close all\n  mihomo-mgr.py conns-close --id 42  # Close one",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--id", help="Connection ID (omit to close all)")

    s = sub.add_parser("rules",
        help="List routing rules",
        description="List routing rules showing type, payload, and target proxy.\nThese rules determine how traffic is matched and routed.",
        epilog="Examples:\n  mihomo-mgr.py rules\n  mihomo-mgr.py rules --limit 100",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--limit", type=int, help="Max rules to show (default: 30)")

    s = sub.add_parser("dns",
        help="Query DNS through mihomo",
        description="Query DNS resolution through mihomo's internal DNS resolver.",
        epilog="Examples:\n  mihomo-mgr.py dns google.com\n  mihomo-mgr.py dns google.com --type AAAA",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("domain", help="Domain to query")
    s.add_argument("--type", default="A", help="Record type (default: A)")

    sub.add_parser("flush-dns",
        help="Flush DNS cache",
        description="Clear mihomo's internal DNS cache. Useful after upstream DNS changes.",
        epilog="Examples:\n  mihomo-mgr.py flush-dns",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub.add_parser("api-restart",
        help="Restart mihomo core via API",
        description="Restart the mihomo core process via its external controller API.\nDoes not restart the OS-level process; use 'restart' for that.",
        epilog="Examples:\n  mihomo-mgr.py api-restart",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub.add_parser("upgrade-geo",
        help="Update GeoIP/GeoSite databases",
        description="Trigger an update of GeoIP and GeoSite databases through the mihomo API.",
        epilog="Examples:\n  mihomo-mgr.py upgrade-geo",
        formatter_class=argparse.RawDescriptionHelpFormatter)

    s = sub.add_parser("db-check",
        help="Check required database files",
        description="Check if required database files (country.mmdb, geosite.dat) are present.\nUse --download to fetch missing ones, --geodata/--asn/--all to include optional files.",
        epilog="Examples:\n  mihomo-mgr.py db-check\n  mihomo-mgr.py db-check --download\n  mihomo-mgr.py db-check --geodata --download",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--download", action="store_true", help="Download missing DB files")
    s.add_argument("--geodata", action="store_true", help="Also include geoip.dat for geodata-mode: true")
    s.add_argument("--asn", action="store_true", help="Also include GeoLite2-ASN.mmdb for ASN rules")
    s.add_argument("--all", action="store_true", help="Include all db/dat/mmdb files (including lite editions)")

    s = sub.add_parser("db-download",
        help="Download database files",
        description="Download missing or requested database files to the config directory.\nUse --force to re-download all, --geodata/--asn/--all for optional files.",
        epilog="Examples:\n  mihomo-mgr.py db-download\n  mihomo-mgr.py db-download --all --force",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--force", action="store_true", help="Download selected DB files even if present")
    s.add_argument("--geodata", action="store_true", help="Also include geoip.dat for geodata-mode: true")
    s.add_argument("--asn", action="store_true", help="Also include GeoLite2-ASN.mmdb for ASN rules")
    s.add_argument("--all", action="store_true", help="Include all db/dat/mmdb files (including lite editions)")

    s = sub.add_parser("start",
        help="Start mihomo as background process",
        description="Start mihomo as a background process. Creates necessary directories,\ndownloads missing DB files (unless --skip-db-check),\npatches config.yaml with config-set values (unless --no-patch), and writes pid/log files.",
        epilog="Examples:\n  mihomo-mgr.py start\n  mihomo-mgr.py start --config /path/to/config.yaml",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--config", help="config file path")
    s.add_argument("--skip-db-check", action="store_true", help="Do not download missing DB files before start")
    s.add_argument("--no-patch", action="store_true", help="Skip config.yaml patching before start")

    s = sub.add_parser("stop",
        help="Stop mihomo process gracefully",
        description="Stop a mihomo process previously started by mihomo-mgr.\nSends SIGTERM, then SIGKILL on --force if graceful shutdown times out.",
        epilog="Examples:\n  mihomo-mgr.py stop\n  mihomo-mgr.py stop --timeout 10 --force",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--timeout", type=float, default=5.0, help="Graceful stop timeout in seconds")
    s.add_argument("--force", action="store_true", help="Kill if graceful stop times out")

    s = sub.add_parser("restart",
        help="Restart mihomo process",
        description="Stop then start the mihomo process.\nSupports --config, --skip-db-check, --no-patch (from start)\nand --timeout, --force (from stop).\nBefore starting, patches config.yaml with config-set values.",
        epilog="Examples:\n  mihomo-mgr.py restart\n  mihomo-mgr.py restart --config /path/to/config.yaml",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--config", help="config file path")
    s.add_argument("--skip-db-check", action="store_true", help="Do not download missing DB files before start")
    s.add_argument("--no-patch", action="store_true", help="Skip config.yaml patching before start")
    s.add_argument("--timeout", type=float, default=5.0, help="Graceful stop timeout in seconds")
    s.add_argument("--force", action="store_true", help="Kill if graceful stop times out")

    s = sub.add_parser("logs",
        help="Show recent mihomo log lines",
        description="Show recent lines from the mihomo log file. Useful for debugging\nconnection failures, rule matching, and proxy errors.\n\nShows file metadata (path, size, line count) before the log content.",
        epilog="Examples:\n  mihomo-mgr.py logs\n  mihomo-mgr.py logs -n 200\n  mihomo-mgr.py logs -f           # Follow (tail -f)",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("-n", "--lines", type=int, default=50, help="Number of lines to show")
    s.add_argument("-f", "--follow", action="store_true", help="Follow log output like tail -f")

    s = sub.add_parser("logs-clear",
        help="Clear or trim the mihomo log file",
        description="Truncate the mihomo log file, or keep only the last N lines with --keep.",
        epilog="Examples:\n  mihomo-mgr.py logs-clear           # Clear completely\n  mihomo-mgr.py logs-clear --keep 100 # Keep last 100 lines",
        formatter_class=argparse.RawDescriptionHelpFormatter)

    s.add_argument("--keep", type=int, help="Keep last N lines instead of clearing all")

    s = sub.add_parser("sub-pull",
        help="Pull subscription and generate config.yaml",
        description="Pull a subscription from the configured URL (or a one-off --url) and\ngenerate a normalized config.yaml with local runtime settings applied.",
        epilog="Examples:\n  mihomo-mgr.py sub-pull\n  mihomo-mgr.py sub-pull --url 'https://example.com/sub'",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--url", help="subscription URL for this pull only")

    sub.add_parser("sub-show",
        help="Show subscription cache status",
        description="Show the subscription URL, raw cache file path, and generated config file with sizes and timestamps.",
        epilog="Examples:\n  mihomo-mgr.py sub-show",
        formatter_class=argparse.RawDescriptionHelpFormatter)

    sub.add_parser("config",
        help="Show persisted and effective configuration",
        description="Display the persisted manager configuration (JSON) and the effective runtime paths.",
        epilog="Examples:\n  mihomo-mgr.py config",
        formatter_class=argparse.RawDescriptionHelpFormatter)

    s = sub.add_parser("config-init",
        help="Create editable default config file",
        description="Create an editable JSONC-style config template at ~/.config/mihomo-mgr/config.json.\nAdd --force to overwrite an existing file.",
        epilog="Examples:\n  mihomo-mgr.py config-init\n  mihomo-mgr.py config-init --force",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--force", action="store_true", help="Overwrite existing configuration file")

    s = sub.add_parser("config-set",
        help="Persist configuration values",
        description="Persist configuration values to ~/.config/mihomo-mgr/config.json.\nOnly provided flags are saved; omitted values keep their existing settings.",
        epilog="Examples:\n  mihomo-mgr.py config-set --mixed-port 7890\n  mihomo-mgr.py config-set --sub-url 'https://...' --api http://127.0.0.1:9090\n  mihomo-mgr.py config-set --config-dir ~/.config/mihomo --bin-dir /usr/local/bin",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--config-dir", dest="persist_config_dir", metavar="DIR", help="mihomo config directory")
    s.add_argument("--bin-dir", dest="persist_bin_dir", metavar="DIR", help="directory containing the mihomo binary")
    s.add_argument("--bin", dest="persist_bin", metavar="PATH", help="mihomo binary path or command")
    s.add_argument("--log-file", dest="persist_log_file", metavar="PATH", help="mihomo log file")
    s.add_argument("--pid-file", dest="persist_pid_file", metavar="PATH", help="mihomo pid file")
    s.add_argument("--api", dest="persist_api", metavar="URL", help="HTTP API URL")
    s.add_argument("--sock", dest="persist_sock", metavar="PATH", help="Unix socket path")
    s.add_argument("--secret", dest="persist_secret", metavar="SECRET", help="API secret")
    s.add_argument("--sub-url", dest="persist_sub_url", metavar="URL", help="subscription URL")
    s.add_argument("--proxy-host", dest="persist_proxy_host", metavar="HOST", help="proxy host")
    s.add_argument("--mixed-port", dest="persist_mixed_port", metavar="PORT", help="mihomo mixed-port (primary port for config.yaml and proxy-on)")
    s.add_argument("--proxy-http-port", dest="persist_proxy_http_port", metavar="PORT", help="HTTP proxy port (overrides mixed-port for HTTP)")
    s.add_argument("--proxy-socks-port", dest="persist_proxy_socks_port", metavar="PORT", help="SOCKS proxy port (overrides mixed-port for SOCKS)")
    s.add_argument("--proxy-http", dest="persist_proxy_http", metavar="URL", help="full HTTP proxy URL")
    s.add_argument("--proxy-socks", dest="persist_proxy_socks", metavar="URL", help="full SOCKS proxy URL")
    s.add_argument("--no-proxy", dest="persist_no_proxy", metavar="HOSTS", help="no_proxy value")

    sub.add_parser("config-clear",
        help="Remove persisted configuration",
        description="Delete the persisted config file at ~/.config/mihomo-mgr/config.json.",
        epilog="Examples:\n  mihomo-mgr.py config-clear",
        formatter_class=argparse.RawDescriptionHelpFormatter)

    s = sub.add_parser("proxy-status",
        help="Show current terminal proxy variables",
        description="Show which proxy environment variables are currently set, plus the\nvalues that proxy-on would export.",
        epilog="Examples:\n  mihomo-mgr.py proxy-status\n  mihomo-mgr.py proxy-status -v",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("-v", "--verbose", action="store_true", help="Show missing proxy variables")

    s = sub.add_parser("proxy-on",
        help="Print shell exports to enable proxy",
        description="Print shell export commands for temporary proxy environment variables.\nPipe through eval to apply to the current shell.\n\nProxy host/ports are derived from:\n  CLI args > mixed_port > proxy_http/socks_port > mihomo /configs > defaults",
        epilog="Examples:\n  eval \"$(mihomo-mgr.py proxy-on)\"\n  eval \"$(mihomo-mgr.py proxy-on --host 127.0.0.1 --http-port 7890)\"",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--host", help=f"proxy host (fallback: {DEFAULT_PROXY_HOST})")
    s.add_argument("--http-port", help=f"HTTP proxy port (fallback: mixed_port > {DEFAULT_HTTP_PROXY_PORT})")
    s.add_argument("--socks-port", help=f"SOCKS proxy port (fallback: mixed_port > {DEFAULT_SOCKS_PROXY_PORT})")
    s.add_argument("--http", help="full HTTP proxy URL")
    s.add_argument("--socks", help="full SOCKS proxy URL")
    s.add_argument("--no-proxy", help=f"no_proxy value (default: {DEFAULT_NO_PROXY})")
    s.add_argument("--quiet", action="store_true", help="Do not print usage hint comments")

    s = sub.add_parser("proxy-off",
        help="Print shell commands to disable proxy",
        description="Print shell unset commands that clear all proxy environment variables.\nPipe through eval to apply to the current shell.",
        epilog="Examples:\n  eval \"$(mihomo-mgr.py proxy-off)\"",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("--quiet", action="store_true", help="Do not print usage hint comments")

    s = sub.add_parser("completion",
        help="Generate shell completion script",
        description="Generate bash or zsh completion script for mihomo-mgr.\nSource the output to enable tab completion for commands, group names, and node names.",
        epilog="Examples:\n  source <(mihomo-mgr.py completion bash)  # Enable for current shell\n  mihomo-mgr.py completion zsh               # Print zsh script",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    s.add_argument("shell", choices=["bash", "zsh"], help="Target shell")

    args = p.parse_args()

    # Override env from CLI args
    if getattr(args, "persist_sock", None):
        args.sock = None
    if getattr(args, "persist_api", None):
        args.api = None
    if getattr(args, "persist_secret", None):
        args.secret = None
    if getattr(args, "persist_config_dir", None):
        args.config_dir = None
    if getattr(args, "persist_bin_dir", None):
        args.bin_dir = None
    if getattr(args, "persist_bin", None):
        args.bin = None
    if getattr(args, "persist_log_file", None):
        args.log_file = None
    if getattr(args, "persist_pid_file", None):
        args.pid_file = None

    if args.sock:
        os.environ["MIHOMO_SOCK"] = args.sock
    if args.api:
        os.environ["MIHOMO_API"] = args.api
    if args.secret:
        os.environ["MIHOMO_SECRET"] = args.secret
    if args.config_dir:
        os.environ["MIHOMO_CONFIG_DIR"] = args.config_dir
    if args.bin_dir:
        os.environ["MIHOMO_BIN_DIR"] = args.bin_dir
    if args.bin:
        os.environ["MIHOMO_BIN"] = args.bin
    if args.log_file:
        os.environ["MIHOMO_LOG_FILE"] = args.log_file
    if args.pid_file:
        os.environ["MIHOMO_PID_FILE"] = args.pid_file

    dispatch = {
        "status": cmd_status, "mode": cmd_mode, "groups": cmd_groups,
        "nodes": cmd_nodes, "select": cmd_select, "best": cmd_best, "delay": cmd_delay,
        "delay-group": cmd_delay_group, "conns": cmd_conns,
        "conns-close": cmd_conns_close, "rules": cmd_rules,
        "dns": cmd_dns, "flush-dns": cmd_flush_dns,
        "api-restart": cmd_restart, "upgrade-geo": cmd_upgrade_geo,
        "db-check": cmd_db_check, "db-download": cmd_db_download,
        "start": cmd_start, "stop": cmd_stop, "restart": cmd_restart_proc,
        "logs": cmd_logs, "logs-clear": cmd_logs_clear, "sub-pull": cmd_sub_pull, "sub-show": cmd_sub_show,
        "config": cmd_config, "config-init": cmd_config_init,
        "config-set": cmd_config_set, "config-clear": cmd_config_clear,
        "proxy-status": cmd_proxy_status, "proxy-on": cmd_proxy_on,
        "proxy-off": cmd_proxy_off,
        "completion": cmd_completion, "__complete": cmd_internal_complete,
    }
    if args.cmd in dispatch:
        dispatch[args.cmd](args)
    else:
        _print_help()


if __name__ == "__main__":
    main()
