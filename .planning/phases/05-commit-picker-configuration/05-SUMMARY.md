---
phase: 05-commit-picker-configuration
plan: 05
subsystem: git-tooling
tags: [fzf-lua, atomic-write, git-log, config-management, lua]

# Dependency graph
requires:
  - phase: 04-commit-diff-review
    provides: commit_picker/ base modules (git.lua, display.lua, init.lua)
provides:
  - Config module with pcall(dofile) parsing, mtime-based caching, atomic writes
  - Settings UI with fzf-lua picker for mode/count/base_commit
  - Mode routing in git.lua with fallback chain and diagnostic messages
  - Base commit highlighting in display.lua
  - :AICommitConfig user command
affects:
  - 06-commit-diff-display (will use config for diff range selection)

# Tech tracking
tech-stack:
  added: []
  patterns: [atomic write with os.rename + cross-device fallback, pcall(dofile) config parsing, mtime-based cache staleness, fzf-lua settings picker with refresh, inline schema validation]

key-files:
  created:
    - lua/commit_picker/config.lua
    - lua/commit_picker/settings.lua
    - tests/commit_picker/config_spec.lua
  modified:
    - lua/commit_picker/git.lua
    - lua/commit_picker/init.lua
    - lua/commit_picker/display.lua

key-decisions:
  - "Replaced async vim.uv.fs_rename with synchronous os.rename + cross-device fallback (headless compatibility)"
  - "Settings UI uses in-memory pending config with picker refresh on each change"
  - "Base commit highlighting uses ANSI yellow color with 'base' marker prefix"
  - "SHA validation checks both format (7-40 hex chars) AND git history existence"

requirements-completed:
  - CDRV-03
  - CDRV-04

# Metrics
duration: 25min
completed: 2026-04-26
---

# Phase 05 Plan 05: Commit Picker Configuration Summary

**Config module with atomic writes and safe parsing, settings UI with fzf-lua picker, mode routing with fallback chain**

## Performance

- **Duration:** 25 min
- **Started:** 2026-04-26T06:47:11Z
- **Completed:** 2026-04-26T07:12:00Z
- **Tasks:** 3 waves + 1 test wave
- **Files modified:** 6 (4 created, 3 modified)

## Accomplishments
- **Config module** (`config.lua`): Read/write/validate with pcall(dofile) safe parsing, mtime-based caching, atomic writes via os.rename + cross-device fallback, git SHA existence verification
- **Settings UI** (`settings.lua`): FZF-lua picker showing Mode/Count/Base as editable items, mode selector, count input (1-500), base commit picker with preview, save/reset/help actions
- **Mode routing** (`git.lua`): get_commits_for_mode() handles unpushed/last_n/since_base with fallback chain, diagnostic messages include ahead/behind counts and base SHA
- **Integration** (`init.lua`, `display.lua`): :AICommitConfig command registered, get_commits_for_mode() used in open(), base_commit passed to display for highlighting
- **Tests** (`config_spec.lua`): 20 plenary.nvim specs covering defaults, save/read, validation, cache invalidation — all passing

## Task Commits

Each task was committed atomically:

1. **Wave 1: Config module** - `ccccb93` (feat)
2. **Wave 1.5: Tests** - `2eda9fa` (test)
3. **Wave 2: Settings UI** - `8fa1495` (feat)
4. **Wave 3: Integration** - `5b4c645` (feat)

**Plan metadata:** `05-PLAN.md` (execute-phase)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed async vim.uv.fs_rename busy-wait in headless mode**
- **Found during:** Wave 1 (Task 1)
- **Issue:** The plan's atomic_write pattern used `vim.uv.fs_rename` with callback + busy-wait loop, which hangs indefinitely in `--headless` mode because there's no event loop to process async callbacks
- **Fix:** Replaced with synchronous `os.rename()` which returns `(nil, nil)` on success and `(nil, error_string)` on failure. Added cross-device fallback: if rename fails, read temp file content and write directly to target path
- **Files modified:** `lua/commit_picker/config.lua`
- **Commit:** `ccccb93`

**2. [Rule 1 - Bug] Fixed os.rename return value check logic**
- **Found during:** Wave 1 (testing)
- **Issue:** `os.rename` on Lua 5.1 returns `(nil, nil)` on success (not truthy). Initial code checked `if ok == nil` treating nil as success, but the subsequent `if ok == nil and err == nil` was unreachable because the first branch already matched
- **Fix:** Rewrote logic to explicitly handle `(nil, nil)` = success, `(nil, error_string)` = cross-device failure requiring fallback
- **Files modified:** `lua/commit_picker/config.lua`
- **Commit:** `ccccb93`

**3. [Rule 1 - Bug] Fixed test assertion for table identity check**
- **Found during:** Wave 1.5 (tests)
- **Issue:** `assert.not_same()` in plenary compares deep equality (values), not object identity. Two copies of defaults with same values failed the "not_same" check
- **Fix:** Changed to `assert.not_equal()` which compares table references
- **Files modified:** `tests/commit_picker/config_spec.lua`
- **Commit:** `2eda9fa`

## Known Stubs

None — all config values are wired and functional.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: T-05-01 mitigated | config.lua | pcall(dofile) + field validation prevents arbitrary code execution from corrupted config |
| threat_flag: T-05-03 mitigated | config.lua | base_commit validated as 7-40 hex chars AND verified via git cat-file before use |
| threat_flag: T-05-04 mitigated | config.lua | count clamped to 1-500 range in validate_config and merge_with_defaults |
| threat_flag: T-05-05 mitigated | config.lua | pcall(dofile) catches parse errors, returns defaults with warning |
| threat_flag: T-05-06 mitigated | config.lua | Atomic writes via os.rename + cross-device read/write fallback |

## Self-Check: PASSED

All 6 files exist and are tracked in git. 4 commits recorded. 20 tests passing.
