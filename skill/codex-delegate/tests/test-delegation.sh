#!/usr/bin/env bash
# Validate that the codex-delegate skill documents MCP-first delegation.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL_FILE="$ROOT_DIR/skill/codex-delegate/SKILL.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "== Codex delegate skill contract validation =="

test -f "$SKILL_FILE" || fail "missing SKILL.md"

grep -q "Primary.*MCP" "$SKILL_FILE" \
  || fail "SKILL.md must make MCP the primary invocation path"
grep -q "mcp.call('codex')" "$SKILL_FILE" \
  || fail "SKILL.md must show the initial codex MCP call"
grep -q "mcp.call('codex-reply')" "$SKILL_FILE" \
  || fail "SKILL.md must show the follow-up codex-reply MCP call"
grep -q "Fallback.*codex exec" "$SKILL_FILE" \
  || fail "SKILL.md must describe codex exec only as a fallback"

if grep -q -- "codex exec --quiet" "$SKILL_FILE"; then
  fail "SKILL.md contains unsupported codex exec --quiet"
fi

if grep -q -- "codex exec --resume" "$SKILL_FILE"; then
  fail "SKILL.md contains unsupported codex exec --resume syntax"
fi

if grep -q -- "codex exec resume --last" "$SKILL_FILE"; then
  fail "SKILL.md must not recommend resume --last"
fi

echo "OK: Skill delegates through MCP first and avoids stale CLI syntax"
