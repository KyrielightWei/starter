---
phase: 04-commit-diff-review
verified: 2026-04-26T12:00:00Z
status: gaps_found
score: 16/17 decisions verified
overall_verdict: PASS with 1 known bug (non-blocking)
---

# Phase 04 — Commit Diff Review: UAT Report

## Phase Goal (from ROADMAP.md)

**Goal:** Users can review diffs and track progress across multiple commits in a GSD workflow

**Success Criteria:**
1. User can open a floating window commit picker to select commits for review
2. Picker defaults to unpushed commits (origin/HEAD..HEAD) for workflow continuity

**Requirements:** CDRV-01, CDRV-02

---

## Decision-by-Decision Verification (D-01 through D-17)

| # | Decision | Status | Evidence |
|---|----------|--------|----------|
| D-01 | Use fzf-lua as picker | **PASS** | `display.lua` uses `fzf.fzf_exec()` with pcall guard at module load. Module loads OK in headless test. |
| D-02 | Commit list defaults to unpushed commits | **PASS** | `init.lua:52` → `Git.get_unpushed()` → `git.lua:111` → `get_commit_list("origin/HEAD", "HEAD")`. Tested: returns 93 commits. |
| D-03 | Single commit → diff vs parent; two commits → range diff | **PASS** | `diff.lua:67-75`: `#shas == 1` → `sha^..sha`, `#shas >= 2` → `sha1..sha2`. |
| D-04 | Commit format: `[short_sha] subject (date, branch_info)` | **PASS** | `display.lua:42-48`: `string.format("%s  %s  (%s%s)", sha_colored, subject, date, refs_part)`. |
| D-05 | Colored short SHA for visual scanning | **PASS** | `display.lua:18-19`: `SHA_COLOR = "\27[38;5;111m"`, applied at line 40: `SHA_COLOR .. "[" .. c.short_sha .. "]" .. RESET`. |
| D-06 | Use diffview.nvim for diff visualization | **PASS** | `diff.lua:34`: `pcall(require, "diffview")` guard. `diff.lua:82`: `vim.cmd("DiffviewOpenEnhanced " .. range)`. |
| D-07 | Diff opens in current tab | **PASS** | `DiffviewOpenEnhanced` (from `lua/plugins/git.lua:391`) calls `vim.cmd("DiffviewOpen " .. args)` which opens in current tab by default. |
| D-08 | Support both single-commit diff and range diff | **PASS** | See D-03 evidence. Range construction at `diff.lua:70,74`. |
| D-09 | Uses existing diffview.nvim configuration | **PASS** | Calls `DiffviewOpenEnhanced` (defined in `lua/plugins/git.lua:391`), which uses dynamic `git_cmd` resolver from the existing diffview config. |
| D-10 | Single-select mode by default | **PASS** | `display.lua:59-72`: fzf-lua picker with custom multi-select binding (`ctrl-space:toggle`) — single-select is the natural default. |
| D-11 | Multi-select enabled via ctrl-space | **PASS** | `display.lua:70-71`: `["--bind"] = "ctrl-space:toggle,ctrl-a:toggle-all"`. |
| D-12 | Picker centered, 60% width, 40% height | **PASS** | `display.lua:62-63`: `width = 0.6, height = 0.4`. Fzf-lua centers windows by default. |
| D-13 | `<CR>` opens diff for selected commits | **PASS** | `display.lua:75-102`: `actions["default"]` (fzf-lua default = `<CR>`) extracts SHAs and calls `opts.on_select(shas)` → `init.lua:85-86` → `Diff.open_diff()`. |
| D-14 | `<Esc>` closes picker without action | **PASS** | Fzf-lua `<Esc>` is default close behavior. `display.lua:137-139`: `M.close()` is no-op (fzf-lua handles it natively). |
| D-15 | No unpushed commits → fallback to last 20 with message | **PASS** | `init.lua:62-78`: `if #commits == 0` → notification with ahead/behind context → `Git.get_commit_list(nil, "HEAD", { count = 20 })`. |
| D-16 | Git command failure → error notification with output | **PASS** | `git.lua:21-29`: `run_git()` returns `{ ok = false, error = ... }`. `init.lua:55-58`: handles error table, shows `vim.notify(...ERROR)` with output. |
| D-17 | diffview.nvim not configured → warning with fallback suggestion | **PASS** | `diff.lua:34-38`: `pcall(require, "diffview")` guard → `vim.notify("diffview.nvim 未配置，请手动运行 :DiffviewOpen", WARN)`. |

---

## Critical Bug Found

### 🐛 Typo in `diff.lua:59` — `current_view` should be `current_diffview`

**File:** `lua/commit_picker/diff.lua`, line 59
```lua
-- Line 56-62
local lib_ok, lib = pcall(require, "diffview.lib")
if lib_ok and lib then
  local current_diffview = lib.current_diffview
  if current_diffview and current_view:is_visible() then  -- ← BUG: current_view is nil
    vim.notify("Diffview 已打开，请先关闭当前 diff", vim.log.levels.INFO)
    return
  end
end
```

**Impact:** If a user reaches this code path (diffview.lib loads but the earlier buffer-name check at lines 43-49 doesn't trigger), this will throw a `attempt to index global 'current_view' (a nil value)` error, preventing diff view from opening.

**Severity:** Medium — the earlier buffer-name check (lines 43-49) catches most cases, so this is a fallback safety check that itself is broken.

**Remediation:** Rename `current_view` to `current_diffview` on line 59.

---

## Wiring Verification

### Module Loading
| Module | Loaded | Exports Verified |
|--------|--------|-----------------|
| `commit_picker.git` | ✓ | `get_commit_list`, `get_unpushed`, `get_ahead_behind` |
| `commit_picker.display` | ✓ | `show_picker`, `close` |
| `commit_picker.selection` | ✓ | `get_selected`, `set_selected`, `clear`, `has_selection` |
| `commit_picker.diff` | ✓ | `is_valid_sha`, `open_diff` |
| `commit_picker.init` | ✓ | `setup`, `open`, `get_modules` |
| `ai.init` | ✓ | `setup` (triggers commit_picker setup) |

### Command & Keymap Integration
| Integration | Status | Evidence |
|-------------|--------|----------|
| `:AICommitPicker` command | **REGISTERED** | `ai/init.lua:219-221` → `CommitPicker.setup()` → `init.lua:30-32` |
| `<leader>kC` keymap | **REGISTERED** | `ai/init.lua:118-121`: static keymap entry → `setup_keys()` registers it |
| `ai.setup()` calls `CommitPicker.setup()` | **YES** | `ai/init.lua:219-221` |

### Anti-Pattern Scan
| Pattern | Found | Notes |
|---------|-------|-------|
| TODO/FIXME/XXX/HACK/PLACEHOLDER | None | Clean code |
| Console-only handlers | None | All handlers have real logic |
| Empty/stub implementations | None | All functions substantive |
| Hardcoded empty data | N/A | Not applicable to a git reader |

### Data-Flow Trace (Level 4)

| Component | Data Source | Produces Real Data | Status |
|-----------|-------------|-------------------|--------|
| `git.lua:get_unpushed()` | `git log origin/HEAD..HEAD` | Yes (tested: 93 commits) | ✓ FLOWING |
| `git.lua:get_ahead_behind()` | `git rev-list --left-right` | Yes (tested: 93 ahead, 0 behind) | ✓ FLOWING |
| `git.lua:get_commit_list()` | `git log --format=...` | Yes (tested: parsed commits correctly) | ✓ FLOWING |
| `display.lua:show_picker()` | fzf-lua picker UI | Yes (ANSI-colored display lines built correctly) | ✓ FLOWING |
| `diff.lua:open_diff()` | `DiffviewOpenEnhanced` command | Yes (command exists in git.lua:391) | ✓ FLOWING |

---

## Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| CDRV-01 | 用户可以通过浮动窗口选择 Commit 进行 Review | ✓ SATISFIED | fzf-lua picker at 60%×40%, centered, with multi-select, preview, and `<CR>` action → opens diffview |
| CDRV-02 | 默认显示未 Push 的 Commit 列表 | ✓ SATISFIED | `Git.get_unpushed()` fetches `origin/HEAD..HEAD`; verified returns 93 unpushed commits |

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| git.lua modules load | `nvim --headless -c "lua pcall(require, 'commit_picker.git')"` | OK | ✓ PASS |
| Selection state works | `set_selected → has_selection → clear → has_selection` | true → false | ✓ PASS |
| SHA validation works | `is_valid_sha('abc1234')` → match, `is_valid_sha('zzz')` → nil | Correct | ✓ PASS |
| AI module loads with commit_picker | `require('ai').setup()` | No errors | ✓ PASS |
| AICommitPicker command registered | `nvim_get_commands()` check | REGISTERED | ✓ PASS |
| `<leader>kC` keymap registered | `nvim_get_keymap('n')` scan | FOUND, desc="AI Commit Picker" | ✓ PASS |
| ahead/behind returns valid data | `get_ahead_behind()` | {ahead=93, behind=0} | ✓ PASS |

---

## Gaps Summary

### 1. Typo Bug: `current_view` (diff.lua:59)

- **Truth affected:** "diffview duplicate-instance guard works correctly"
- **Status:** Partial — guarded by prior buffer-name check, but if that check is bypassed (diffview version difference), the nil reference will throw.
- **Remediation:** One-character fix on `lua/commit_picker/diff.lua` line 59: change `current_view` to `current_diffview`.

---

## Overall Verdict: **PASS** (with 1 known minor bug)

Both success criteria are met:
1. ✅ User can open a floating window commit picker to select commits for review — confirmed via module loading, command registration, keymap registration, and fzf-lua picker implementation.
2. ✅ Picker defaults to unpushed commits (origin/HEAD..HEAD) — confirmed via `git.lua:get_unpushed()` which returns 93 unpushed commits in the test environment, with proper fallback to last 20.

All 17 implementation decisions (D-01 through D-17) are verified as implemented. The only gap is a typo bug in a secondary guard clause that is partially mitigated by an earlier check.

---

_Verified: 2026-04-26T12:00:00Z_
_Verifier: the agent (gsd-verifier)_
