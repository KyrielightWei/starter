---
status: testing
phase: 01-critical-bug-fixes
source: 01-critical-bug-fixes-01-SUMMARY.md, 01-critical-bug-fixes-02-SUMMARY.md, 01-critical-bug-fixes-03-SUMMARY.md, 01-critical-bug-fixes-04-SUMMARY.md
started: 2026-04-19T15:50:00Z
updated: 2026-04-19T15:50:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 1
name: OpenCodeWriteConfig Does Not Crash
expected: |
  Running :OpenCodeWriteConfig completes without a Lua error or crash. The command generates config correctly using the dynamically loaded switcher-assigned component.
awaiting: user response

## Tests

### 1. OpenCodeWriteConfig Does Not Crash
expected: Running :OpenCodeWriteConfig completes without a Lua error or crash. The command generates config correctly using the dynamically loaded switcher-assigned component.
result: [pending]

### 2. Switch OpenCode to GSD — Restart — Commands Available
expected: After setting OpenCode's active component to GSD (`:OpenCodeSetComponent gsd` or equivalent), restarting Neovim, and checking — GSD commands are available in OpenCode.
result: [pending]

### 3. Switch Claude Code to ECC — Restart — Agents Available
expected: After setting Claude Code's active component to ECC (`:ClaudeCodeSetComponent ecc` or equivalent), restarting, and checking — ECC agents are available.
result: [pending]

### 4. list_outdated() Returns Non-Empty When Updates Available
expected: Calling Registry.list_outdated() returns a non-empty list when cached components have newer versions available. The function reads from Switcher.get_version_cache().
result: [pending]

### 5. ECC Uninstall Does Not Delete Non-ECC Content
expected: Running the ECC uninstaller only removes ECC-specific subdirectories (commands/ecc, agents/ecc, skills/ecc, hooks/ecc) without deleting parent directories or other tools' content.
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps

[none yet]
