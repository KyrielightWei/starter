#!/usr/bin/env bash
# Validate multi-turn guidance for Codex MCP thread handling.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL_FILE="$ROOT_DIR/skill/codex-delegate/SKILL.md"
EXAMPLE_FILE="$ROOT_DIR/skill/codex-delegate/examples/multiturn-conversation.md"
USAGE_DOC="$ROOT_DIR/docs/codex-integration/skill-usage.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "== Codex multi-turn guidance validation =="

grep -q "threadId" "$SKILL_FILE" || fail "SKILL.md must mention threadId"
grep -q "codex-reply" "$SKILL_FILE" || fail "SKILL.md must mention codex-reply"
grep -q "threadId" "$EXAMPLE_FILE" || fail "multi-turn example must include threadId"
grep -q "codex-reply" "$EXAMPLE_FILE" || fail "multi-turn example must use codex-reply"

if grep -q "OMP 会自动保存 threadId" "$USAGE_DOC"; then
  fail "usage doc must not promise automatic threadId persistence without an implementation"
fi

if grep -R -n --include='*.md' -- "--resume last\\|--quiet" "$ROOT_DIR/skill/codex-delegate/SKILL.md" "$ROOT_DIR/skill/codex-delegate/examples" >/tmp/codex-delegate-stale-cli.txt; then
  cat /tmp/codex-delegate-stale-cli.txt >&2
  fail "skill files contain stale Codex CLI syntax"
fi

echo "OK: Multi-turn docs consistently use MCP threadId/codex-reply guidance"
