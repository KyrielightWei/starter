#!/usr/bin/env bash
# Validate the local Codex MCP configuration without making a network/API call.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MCP_CONFIG="${MCP_CONFIG:-$HOME/.config/mcp/mcp.json}"
TMP_CODEX_HOME="$(mktemp -d "${TMPDIR:-/tmp}/codex-mcp-test.XXXXXX")"
trap 'rm -rf "$TMP_CODEX_HOME"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

echo "== Codex MCP config validation =="

require_cmd codex
require_cmd jq

test -f "$MCP_CONFIG" || fail "MCP config not found: $MCP_CONFIG"
jq empty "$MCP_CONFIG" || fail "MCP config is not valid JSON"

jq -e '.mcpServers.codex.type == "stdio"' "$MCP_CONFIG" >/dev/null \
  || fail "mcpServers.codex.type must be stdio"
jq -e '.mcpServers.codex.command == "codex"' "$MCP_CONFIG" >/dev/null \
  || fail "mcpServers.codex.command must be codex"
jq -e '.mcpServers.codex.args == ["mcp-server"]' "$MCP_CONFIG" >/dev/null \
  || fail "mcpServers.codex.args must be [\"mcp-server\"]"

MCP_RESPONSE="$(
  printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"codex-delegate-test","version":"1.0"}}}' \
    '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
    | CODEX_HOME="$TMP_CODEX_HOME" timeout 10 codex mcp-server
)"
MCP_JSON_LINES="$(printf '%s\n' "$MCP_RESPONSE" | sed -n '/^{/p')"

echo "$MCP_JSON_LINES" | jq -s -e 'any(.[]; .id == 1 and .result.serverInfo.name == "codex-mcp-server")' >/dev/null \
  || fail "initialize response did not come from codex-mcp-server"
echo "$MCP_JSON_LINES" | jq -s -e 'any(.[]; .id == 2 and any(.result.tools[]; .name == "codex"))' >/dev/null \
  || fail "codex MCP tool is missing"
echo "$MCP_JSON_LINES" | jq -s -e 'any(.[]; .id == 2 and any(.result.tools[]; .name == "codex-reply"))' >/dev/null \
  || fail "codex-reply MCP tool is missing"
echo "$MCP_JSON_LINES" | jq -s -e 'any(.[]; .id == 2 and any(.result.tools[]; .name == "codex" and .outputSchema.required == ["threadId","content"]))' >/dev/null \
  || fail "codex tool must return threadId and content"

if find -L "$ROOT_DIR/skill/codex-delegate" -maxdepth 3 -type f >/dev/null 2>&1; then
  :
else
  fail "skill/codex-delegate contains a recursive symlink or unreadable file tree"
fi

echo "OK: Codex MCP config and tool schema are valid"
