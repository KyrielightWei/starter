---
phase: 05-commit-picker-configuration
uat_date: 2026-04-26T07:30:00Z
verifier: gsd-verifier
status: passed
score: 2/2 success criteria verified
requirements:
  - CDRV-03: SATISFIED
  - CDRV-04: SATISFIED
tests: 20/20 passing
implementation_decisions_verified: 5/5
---

# Phase 05: Commit Picker Configuration — UAT Report

**Phase Goal:** Users can customize the commit picker display range and boundaries
**Verified:** 2026-04-26T07:30:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Success Criteria Verification

### SC-1: User can configure how many commits appear in the picker (counting from newest backward)

**Verdict: ✓ PASS**

**Evidence:**
- `lua/commit_picker/config.lua` — `save_config()` accepts `count` field, validates it's an integer 1-500, clamps on read
- `lua/commit_picker/config.lua` — `get_config()` returns `count` from persisted file or default `20`
- `lua/commit_picker/settings.lua` — `_input_count()` provides vim.ui.input dialog for numeric entry with validation
- `lua/commit_picker/git.lua` — `get_commits_for_mode()` uses `config.count` in `last_n` mode, returns exactly N commits
- `lua/commit_picker/init.lua` — `M.open()` calls `get_commits_for_mode()`, passing config count to picker
- Runtime test: Saved `count=5` in `last_n` mode → `get_commits_for_mode()` returned exactly 5 commits
- Tests: 20 plenary specs all passing, including tests for count validation (rejects < 1, > 500, negative)
- No TODO/FIXME/placeholder stubs found in config or routing code

### SC-2: User can set a base commit as the review boundary to limit displayed commits

**Verdict: ✓ PASS**

**Evidence:**
- `lua/commit_picker/config.lua` — `save_config()` persists `base_commit` as full SHA string
- `lua/commit_picker/config.lua` — `validate_config()` verifies SHA format (7-40 hex chars) AND existence in git history via `git cat-file -t`
- `lua/commit_picker/settings.lua` — `_select_base_commit()` fetches last 100 commits, shows fzf-lua picker with preview (`git show --stat`), stores full SHA
- `lua/commit_picker/git.lua` — `get_commits_for_mode()` in `since_base` mode passes `base_commit..HEAD` range to `get_commit_list()`
- `lua/commit_picker/display.lua` — `show_picker()` accepts `opts.base_commit`, highlights matching commit with `★ base |` marker and yellow ANSI color
- `lua/commit_picker/init.lua` — `M.open()` receives `base_commit` return value from `get_commits_for_mode()` and passes it to display
- Runtime test: Set base SHA → `since_base` mode returned 9 commits (from base to HEAD) with correct base_commit value
- Config file format verified: clean Lua table with `base_commit = "<full-sha>"` or `base_commit = nil`

## Implementation Decision Verification

| Decision | Status | Evidence |
|----------|--------|----------|
| Config panel: Visual settings (Provider Manager pattern) | ✓ VERIFIED | `settings.lua` implements fzf-lua picker with formatted settings lines, mode selector, count input, base commit selector, save/reset/help actions |
| New config file: `~/.config/nvim/commit_picker_config.lua` | ✓ VERIFIED | `config.lua:get_config_path()` returns this path; file created on first save with valid Lua table format |
| Base commit: Persistent default | ✓ VERIFIED | `save_config()` persists full SHA; `get_config()` reads and caches by mtime; survives Neovim restarts |
| Mode presets: unpushed / last N / since base (3 modes, persists) | ✓ VERIFIED | `ALLOWED_MODES` table in config.lua, mode selector in settings.lua, routing in git.lua — all 3 modes functional with persistence |
| `:AICommitConfig` command | ✓ VERIFIED | Registered in `init.lua:setup()` as `vim.api.nvim_create_user_command`, verified via `nvim_get_commands()` |

## Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| CDRV-03 | 用户可以配置显示的 Commit 数量（从最新往前计数） | ✓ SATISFIED | Config count field, validated 1-500, used in git.lua mode routing, tested with 5 commits |
| CDRV-04 | 用户可以设置 Base Commit 作为 Review 范围边界 | ✓ SATISFIED | Config base_commit field, SHA validation + git existence check, since_base mode routing, display highlighting |

## Test Results

**20/20 tests passing** (0 failed, 0 errors):
- `get_config_path()` — returns absolute path ✓
- `get_config()` returns defaults when file missing ✓ (2 tests)
- `config_file_exists()` — false/true correctly ✓ (2 tests)
- `save_config()` — valid file read-back, persists base, rejects invalid mode/count/SHA ✓ (5 tests)
- `validate_config()` — valid/invalid mode, count bounds, SHA format/existence, nil accept, non-table reject ✓ (8 tests)
- `reset_to_defaults()` — writes known-good config ✓
- `invalidate_cache()` — clears cache, fresh reads work ✓

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `config.lua` save_config | new_config.count | User input via settings.lua | ✓ Real persisted Lua file | ✓ FLOWING |
| `config.lua` get_config | config.count, config.mode, config.base_commit | ~/.config/nvim/commit_picker_config.lua via pcall(dofile) | ✓ Real git SHA + validated values | ✓ FLOWING |
| `git.lua` get_commits_for_mode | commits array, base_commit | git log with mode-specific args | ✓ Real git history data | ✓ FLOWING |
| `display.lua` show_picker | base_commit highlight | opts.base_commit from init.lua | ✓ Real SHA matched in commit list | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Config save + read-back | save_config({count=42}) → invalidate → get_config() | count=42, mode=last_n | ✓ PASS |
| Mode routing (last_n=5) | save last_n+count=5 → get_commits_for_mode() | 5 commits returned | ✓ PASS |
| since_base mode | save base=commit[10].sha → get_commits_for_mode() | 9 commits + correct base SHA | ✓ PASS |
| Command registration | require('commit_picker').setup() → nvim_get_commands() | AICommitPicker + AICommitConfig both registered | ✓ PASS |
| Settings functions | require('commit_picker.settings') | All 8 functions exported (open, _render, _handle, etc.) | ✓ PASS |
| Config functions | require('commit_picker.config') | All 7 functions exported (get, save, validate, etc.) | ✓ PASS |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `display.lua` | 150-153 | `M.close()` is no-op stub | ℹ️ Info | Intentional — fzf-lua closes on `<Esc>` by default, stub exists for API completeness |
| `init.lua` | 13-25 | `return nil, "module"` in get_modules | ℹ️ Info | Not a stub — proper error handling for module load failures |

No TODO/FIXME/placeholder comments found. No hardcoded empty data flows to rendering.

## Threat Model Verification

| Threat | Mitigation | Status |
|--------|-----------|--------|
| T-05-01: Config file tampering | `pcall(dofile)` + field validation, no `loadstring` | ✓ Mitigated |
| T-05-03: Invalid SHA injection | SHA format (7-40 hex) + `git cat-file -t` existence check | ✓ Mitigated |
| T-05-04: Count overflow | Clamped to 1-500 in validate and merge | ✓ Mitigated |
| T-05-05: Config file corruption | `pcall(dofile)` catches parse errors, returns defaults with warning | ✓ Mitigated |
| T-05-06: Race condition on write | Atomic writes via `os.rename` + cross-device fallback | ✓ Mitigated |

## Overall Verdict

**✓ PASSED — Phase 05 goal achieved.**

Both success criteria are fully met:

1. **Commit count configuration:** Working end-to-end. Users can set count 1-500 via settings panel, it persists, and `get_commits_for_mode()` respects it in both `last_n` mode and as fallback for other modes.

2. **Base commit boundary:** Working end-to-end. Users can select a base commit from a picker with preview, it's validated (format + git existence), stored as full SHA, used in `since_base` mode for range-limited fetching, and highlighted in the display.

All 20 tests pass. No stubs or placeholders. All threat mitigations verified. The config module's atomic write pattern was correctly switched from async `vim.uv.fs_rename` to synchronous `os.rename` for headless compatibility (documented in SUMMARY.md deviations).

---

_Verified: 2026-04-26T07:30:00Z_
_Verifier: gsd-verifier_
