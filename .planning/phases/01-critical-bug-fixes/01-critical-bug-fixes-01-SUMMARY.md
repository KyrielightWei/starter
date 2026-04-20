---
phase: 01-critical-bug-fixes
plan: 01
subsystem: ai-opencode
tags: [fix, dynamic-loading, dead-code-removal]
dependency_graph:
  requires: []
  provides: [FIX-01, FIX-02]
  affects: [lua/ai/opencode.lua, switcher-integration]
tech_stack:
  added: []
  patterns: [dynamic-require, switcher-guard]
key_files:
  created: []
  modified: [lua/ai/opencode.lua]
decisions:
  - Used Switcher.get_active() + Registry.is_registered() for security validation (T-01-01)
  - Error-and-exit on missing component (ED-01), not silent fallback
  - Error messages show current state + repair hints (ED-02)
  - format_notification called only if component implements it (safe fallback)
metrics:
  duration: ~5min
  completed_date: "2026-04-19T15:45:00Z"
---

# Phase 01 Plan 01: Remove dead code + dynamic component loading for OpenCode Summary

**One-liner:** Removed orphaned duplicate code block crashing opencode.lua at load and refactored write_config() to dynamically load the switcher-assigned component with error handling.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Remove dead code block (FIX-01) | `b3e0841` | `lua/ai/opencode.lua` (-65 lines) |
| 2 | Dynamic component loading (FIX-02) | `befb898` | `lua/ai/opencode.lua` (+54/-6 lines) |

## Decisions Made

## Deviations from Plan

### Deviation 1 (Rule 3 - Blocking): Safe `format_notification` call
- **Found during:** Task 2 implementation
- **Issue:** The plan assumed `Component.format_notification(ecc)` exists, but not all components may implement this method. Without a guard, calling it on a component that lacks the method would crash.
- **Fix:** Wrapped in `if Component.format_notification then` check before calling.
- **Files modified:** `lua/ai/opencode.lua`
- **Commit:** `befb898`

## Verification Results

- `nvim -l lua/ai/opencode.lua` exits cleanly — **PASS**
- `grep -c "require.*ai\.ecc"` returns 0 — **PASS** (no hardcoded ECC references)
- `grep 'Switcher.get_active'` returns 1 — **PASS** (switcher read present)
- File line count: 661 (> 500 minimum) — **PASS**
- Module loads with `pcall(require, 'ai.opencode')` — **PASS**

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag:dynamic-require | lua/ai/opencode.lua | Component name from switcher state used in require path; mitigated via Registry.is_registered() validation before dynamic load (T-01-01) |

## Self-Check: PASSED
