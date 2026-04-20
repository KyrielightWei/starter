---
phase: 01-critical-bug-fixes
plan: 02
subsystem: ai-claude-code
tags: [fix, dynamic-loading]
dependency_graph:
  requires: []
  provides: [FIX-03]
  affects: [lua/ai/claude_code.lua, switcher-integration]
tech_stack:
  added: []
  patterns: [dynamic-require, switcher-guard]
key_files:
  created: []
  modified: [lua/ai/claude_code.lua]
decisions:
  - Renamed get_ecc_status() → get_active_component_status() to reflect dynamic behavior
  - Updated get_status() return key from 'ecc' to 'component'
  - Error handling mirrors opencode.lua pattern (ED-01/ED-02/ED-03)
  - check_dependencies() only adds component entry when switcher has an active assignment
metrics:
  duration: ~5min
  completed_date: "2026-04-19T15:46:00Z"
---

# Phase 01 Plan 02: Dynamic component loading for Claude Code Summary

**One-liner:** Refactored claude_code.lua write_settings(), get_status(), and check_dependencies() to dynamically resolve the switcher-assigned component instead of hardcoding ECC.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Dynamic component loading for write_settings, get_ecc_status, check_dependencies (FIX-03) | `e8bd626` | `lua/ai/claude_code.lua` (+88/-22 lines) |

## Decisions Made

- Renamed `M.get_ecc_status()` → `M.get_active_component_status()` for clarity since it's no longer ECC-specific
- Changed `get_status()` return field from `ecc` to `component` to reflect the dynamic nature
- Used `pcall` for component require in `check_dependencies()` to handle cases where the component module doesn't exist
- Only adds component dependency entry when switcher has an active claude assignment and component is registered

## Deviations from Plan

### Deviation 1 (Rule 3 - Blocking): Safe `format_notification` call in write_settings
- **Found during:** Task 1 implementation
- **Issue:** Same pattern as opencode — `Component.format_notification` may not exist on all components.
- **Fix:** Wrapped in `if Component.format_notification then` guard.
- **Files modified:** `lua/ai/claude_code.lua`
- **Commit:** `e8bd626`

### Deviation 2 (Rule 2 - Missing critical functionality): Added `install_hint` fallback in check_dependencies
- **Found during:** Task 1 implementation
- **Issue:** Not all components implement `install_hint()`. Without a fallback, check_dependencies would crash.
- **Fix:** Added `Component.install_hint and Component.install_hint() or "Run :XXXDeployTools"` fallback.
- **Files modified:** `lua/ai/claude_code.lua`
- **Commit:** `e8bd626`

## Verification Results

- `nvim -l lua/ai/claude_code.lua` exits cleanly — **PASS**
- `grep "ai\.ecc"` returns 0 — **PASS** (no hardcoded ECC references)
- `grep -c 'Switcher.get_active'` returns 3 — **PASS** (write_settings, get_active_component_status, check_dependencies)
- `pcall(require, 'ai.claude_code')` — **PASS**
- File line count: 765 (> 600 minimum) — **PASS**

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag:dynamic-require | lua/ai/claude_code.lua | Component name from switcher used in require path; mitigated via Registry.is_registered() validation (T-01-04) |

## Self-Check: PASSED
