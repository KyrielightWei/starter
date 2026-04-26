---
phase: 04-commit-diff-review
plan: 01
subsystem: commit-picker
tags: [git, fzf-lua, picker, foundation]
dependency_graph:
  requires: []
  provides: [commit-data, picker-ui]
  affects: [commit_picker, fzf-lua]
tech-stack:
  added: []
  patterns: [vim.system()-sync-wait, fzf-lua-fzf_exec, pcall-guard]
key-files:
  created:
    - lua/commit_picker/git.lua
    - lua/commit_picker/display.lua
    - lua/commit_picker/__init__.lua
  modified: []
decisions:
  - Used vim.system() instead of io.popen() (per execution rules) with sync wait() for simple API
  - SHA mapped to full hash in display layer, parsed back on selection
  - Preview uses git show --stat via vim.system({}):wait()
  - highlight_callback used for SHA coloring via ANSI escape in fzf-lua
metrics:
  duration_minutes: 8
  created_date: "2026-04-26"
---

# Phase 04 Plan 01: Git Module + fzf-lua Picker Summary

## One-liner

Git commit fetching with fallback behavior and fzf-lua picker display supporting colored SHA, multi-select, and commit preview — foundation for Phase 4 commit diff review.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create git.lua with fallback and error handling | 3d0e8cd | lua/commit_picker/git.lua |
| 2 | Create display.lua for fzf-lua picker | 3d0e8cd | lua/commit_picker/display.lua |

## Verification Results

- git.lua: get_ahead_behind() → { ahead = 89, behind = 0 } ✅
- display.lua: show_picker and close functions exported ✅
- End-to-end: SHA extraction from display line matches short_sha ✅
- git.lua NUL-separated parsing works correctly ✅
- 92 unpushed commits detected in current repo ✅

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Modernization] Used vim.system() instead of io.popen()**
- **Found during:** Task 1 execution
- **Plan said:** "Use io.popen() to run git commands"
- **Execution rules said:** "Use vim.system() async pattern (not io.popen())"
- **Fix:** Used vim.system() with :wait() for synchronous API while maintaining async safety per project standards (Phase 3 patterns)
- **Files modified:** lua/commit_picker/git.lua
- **Commit:** 3d0e8cd

**2. [Rule 1 - Bug Prevention] NUL-separated git format for robust parsing**
- **Found during:** Task 1 design
- **Issue:** Traditional newline-separated git log format breaks with multi-line commit subjects
- **Fix:** Used %x00 (NUL) as field delimiter with --format="%H\x00%h\x00%s\x00%cr\x00%d" for bulletproof parsing
- **Files modified:** lua/commit_picker/git.lua
- **Commit:** 3d0e8cd

## Self-Check: PASSED
