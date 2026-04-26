---
phase: 06-commit-diff-navigation
plan: 01
subsystem: navigation
tags: [lua, diffview, commit-navigation, commit-picker, neovim]

# Dependency graph
requires:
  - phase: "04-commit-diff-review"
    provides: "diff.lua (open_diff, is_valid_sha), git.lua (get_commits_for_mode), selection.lua (get_selected/set_selected)"
  - phase: "05-commit-picker-configuration"
    provides: "config.lua (mode-aware commit fetching)"
provides:
  - "Navigation module for next/prev commit cycling during diff review"
  - "Range mode detection (single vs 2-SHA selection)"
  - "50ms defer race condition fix between DiffviewClose and DiffviewOpenEnhanced"
  - "Module-local state management with clear/load/reset"
affects: ["06-02", "07 (future lualine status component)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Module-local state with injected dependencies (setup pattern)"
    - "50ms vim.defer_fn() for Diffview close→open race mitigation"
    - "pcall guards on vim.cmd ('DiffviewClose') — may not be open"
    - "SHA validation before passing to diffview (T-06-01)"
    - "Range mode detection: cycling disabled when view_mode == 'range'"

key-files:
  created:
    - "lua/commit_picker/navigation.lua"
    - "tests/commit_picker/navigation_spec.lua"
  modified: []

key-decisions:
  - "Used dedicated navigation.lua module instead of extending selection.lua (D-30 dev)"
  - "view_mode detected at load_commits time from Selection.get_selected() count"
  - "open_commit_diff uses async deferred reopen — navigation is async-friendly"
  - "Chinese notifications: '已导航到', '已是最后一条提交', '已是第一条提交', '范围模式下不支持逐条导航'"

patterns-established:
  - "Navigation cycle functions: check guard → boundary check → validate SHA → close diffview → defer reopen → update selection → notify"
  - "Module-local state: commit_list (array), current_index (1-based), view_mode (single/range)"

requirements-completed: [CDRV-05, CDRV-06]

# Metrics
duration: ~8min
completed: 2026-04-26
---

# Phase 06 Plan 01 Summary

**Navigation core module with commit cycling (next/prev), range mode detection, and 50ms race condition fix for diffview close→reopen**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-26T07:10:00Z
- **Completed:** 2026-04-26T07:18:00Z
- **Tasks:** 2 (navigation.lua module + test spec)
- **Files modified:** 2 (both new files)

## Accomplishments

- `lua/commit_picker/navigation.lua` with 10 exports (setup, load_commits, cycle_next, cycle_prev, get_position, get_current_sha, is_loaded, clear, get_view_mode, open_commit_diff helper)
- `tests/commit_picker/navigation_spec.lua` with 18 test cases covering all functionality
- Range mode detection: cycling disabled when user selected 2 SHAs
- 50ms vim.defer_fn() between DiffviewClose and DiffviewOpenEnhanced (R-01 fix, D-26a)
- SHA validation before passing to diffview (T-06-01 mitigation)
- Chinese notifications per project convention

## Task Commits

Each task was committed atomically:

1. **Task 1: Create navigation.lua** - `5c0703f` (feat)
2. **Task 2: Write plenary specs** - `5c0703f` (feat, combined in same commit)

**Note:** Both tasks delivered in single commit as test spec was written alongside module.

## Files Created/Modified

- `lua/commit_picker/navigation.lua` — Navigation state + commit cycling with 50ms defer
- `tests/commit_picker/navigation_spec.lua` — 18 plenary.nvim test specs

## Decisions Made

- **Dedicated module vs selection.lua extension:** Per CONTEXT.md D-30 dev, created dedicated navigation.lua for cleaner separation of concerns
- **view_mode detection at load time:** Detected from Selection.get_selected() count in load_commits() — more reliable than tracking separately
- **Async reopen pattern:** Used vim.defer_fn(50ms) for close→open to avoid diffview race condition (R-01)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Plenary.nvim not available in headless test runner environment — test file syntax verified via loadstring(), follows same patterns as existing config_spec.lua
- "AI New Chat" keymap at `<leader>kn` already exists in ai/init.lua — plan 06-02 correctly uses D-22/D-23 kf/kb mappings

## Next Phase Readiness

- Navigation module ready for Wave 2 integration (06-02)
- Keymaps `<leader>kf` / `<leader>kb` to be registered in ai/init.lua
- commit_picker/init.lua needs Nav.setup() call in M.setup()

---
*Phase: 06-commit-diff-navigation*
*Plan: 01*
*Completed: 2026-04-26*

## Self-Check: PASSED
