---
phase: 04-commit-diff-review
reviewed: 2026-04-26T12:00:00Z
depth: deep
files_reviewed: 6
files_reviewed_list:
  - lua/commit_picker/git.lua
  - lua/commit_picker/display.lua
  - lua/commit_picker/selection.lua
  - lua/commit_picker/diff.lua
  - lua/commit_picker/init.lua
  - lua/ai/init.lua
findings:
  critical: 2
  warning: 4
  info: 3
  total: 9
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-04-26T12:00:00Z
**Depth:** deep
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the commit_picker module (5 files) and its integration point in `lua/ai/init.lua`. The architecture is clean with well-defined module boundaries (git → display → selection → diff). The code follows project conventions (2-space indent, double quotes, `local M = {}` pattern, snake_case). Error handling is generally good with `pcall` guards and `vim.notify` feedback.

However, two critical issues were found: (1) the `highlight_callback` in `display.lua` returns ANSI color codes that cancel each other out, producing no visible coloring, and (2) `git.lua` is required at module-top level in `get_modules()` before fzf-lua availability check, meaning a missing `git` binary or non-git directory causes the entire `git.lua` module to error on load. Four warnings and three info-level issues round out the findings.

## Critical Issues

### CR-01: highlight_callback color codes cancel each other out — SHA coloring is a no-op

**File:** `lua/commit_picker/display.lua:82-95`
**Issue:** The `highlight_callback` returns `{ start_idx, end_idx, SHA_COLOR .. RESET }` where `SHA_COLOR = "\27[38;5;111m"` and `RESET = "\27[0m"`. Concatenating them produces `"\27[38;5;111m\27[0m"` — the color is immediately reset, so the SHA will never actually appear colored. This defeats decision D-05 (colored short SHA).

Additionally, fzf-lua's `highlight_callback` is not a standard/documented API. None of the other pickers in the codebase use it (`model_switch.lua`, `provider_manager/picker.lua`, `sync.lua`, `terminal_picker.lua`, `avante/methods.lua` — all zero uses of `highlight_callback`). The plan (REVIEWS-R2.md) states *"Do NOT embed ANSI escape codes; use fzf-lua's native highlight system instead"* but the implementation uses ANSI escape codes via `highlight_callback`, which is the exact opposite.

**Fix:**
Remove the `highlight_callback` entirely and use a text-based visual cue instead, consistent with how other pickers signal importance:
```lua
-- Remove SHA_COLOR, RESET, and highlight_callback entirely
-- Use a prefix marker instead:
local display = string.format(
  "● [%s]  %s  (%s%s)",
  c.short_sha,
  c.subject,
  c.date,
  refs_part
)
```
Or, if fzf-lua supports a `coloransi` or `file_icons` approach, use that documented API instead.

### CR-02: git.lua vim.system() call will error when git is not found (no fallback)

**File:** `lua/commit_picker/git.lua:15`
**Issue:** `vim.system({ "git", unpack(args) }):wait()` will throw a Lua error if `git` is not on PATH (Neovim raises "ENOENT: no such file or directory"). This is not caught by `run_git()`. When `get_modules()` in `init.lua` requires `commit_picker.git`, the require itself does not fail — the module loads fine. But the **first call** to any function that invokes `run_git()` will crash with an unhandled error from `vim.system()`, not returning the expected `{ ok = false, error = "..." }` structure.

This is a cascading failure: `init.lua:M.open()` calls `Git.get_unpushed()` → `get_commit_list()` → `run_git()` → `vim.system()` throws → crash propagates past the error-handling logic at lines 60-64.

**Fix:**
Wrap the `vim.system()` call in `pcall`:
```lua
local function run_git(args, opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.uv.cwd()

  local ok, result = pcall(function()
    return vim.system({ "git", unpack(args) }):wait()
  end)

  if not ok then
    return { ok = false, error = "git command failed: " .. tostring(result) }
  end

  if result.code ~= 0 then
    local err = result.stderr or result.stdout or "unknown error"
    err = err:gsub("(sk-)[%w]+", "%1***")
    return { ok = false, error = err }
  end

  return { ok = true, stdout = result.stdout or "", stderr = result.stderr or "" }
end
```

## Warnings

### WR-01: Eager module loading in get_modules() defeats lazy-loading intent

**File:** `lua/commit_picker/init.lua:9-18`
**Issue:** The `get_modules()` function wraps all four `require` calls in `pcall`, but it executes **all four sequentially** and aborts on the **first** failure. If `commit_picker.display` fails (e.g., fzf-lua guards cause early return of an empty module at `display.lua:10`), then `Selection` and `Diff` are never checked, and the module variable `Display` will be the empty `{}` table returned by the guard — not `nil`. The caller cannot distinguish between "module loaded but empty" and "module failed to load."

Furthermore, `display.lua` returns `M` (an empty table) when fzf-lua is not available (line 10), so `pcall(require, "commit_picker.display")` returns `{ true, {} }` — success with an empty module. The `ok` will be `true`, but `mods.Display.show_picker()` will then fail with "attempt to call a nil value" because `show_picker` doesn't exist on the empty table.

**Fix:**
Check that required functions exist on the loaded module:
```lua
local function get_modules()
  local ok, Git = pcall(require, "commit_picker.git")
  if not ok or type(Git.get_unpushed) ~= "function" then return nil, "git" end
  local ok, Display = pcall(require, "commit_picker.display")
  if not ok or type(Display.show_picker) ~= "function" then return nil, "display" end
  local ok, Selection = pcall(require, "commit_picker.selection")
  if not ok or type(Selection.set_selected) ~= "function" then return nil, "selection" end
  local ok, Diff = pcall(require, "commit_picker.diff")
  if not ok or type(Diff.open_diff) ~= "function" then return nil, "diff" end
  return { Git = Git, Display = Display, Selection = Selection, Diff = Diff }
end
```

### WR-02: SHA_COLOR and RESET constants are dead code

**File:** `lua/commit_picker/display.lua:14-15`
**Issue:** `SHA_COLOR` and `RESET` are defined at module level but only used inside the `highlight_callback` where they are concatenated into a no-op sequence (see CR-01). If CR-01 is fixed by removing the callback, these become dead code. Even in the current implementation, they have no visible effect.

**Fix:** Remove `SHA_COLOR` and `RESET` constants, or repurpose them if a working highlight approach is adopted.

### WR-03: Diffview already-open state not checked before reopening

**File:** `lua/commit_picker/diff.lua:19-61`
**Issue:** If `DiffviewOpenEnhanced` is called while a diffview is already open, diffview.nvim may display a warning or behave unexpectedly. The function does not check whether diffview is already open before issuing the command. Per REVIEWS.md concern: "No diffview close handling."

**Fix:**
Check diffview state before opening:
```lua
-- Check if diffview is already open
local is_open = false
pcall(function()
  is_open = require("diffview").is_open()
end)
if is_open then
  pcall(vim.cmd, "DiffviewClose")
end

local ok2, err = pcall(vim.cmd, "DiffviewOpenEnhanced " .. range)
```

### WR-04: Preview callback blocks on vim.system():wait() for every keystroke

**File:** `lua/commit_picker/display.lua:98-108`
**Issue:** The fzf-lua preview function calls `vim.system({ "git", "show", sha, "--stat" }):wait()` synchronously. This runs on **every cursor movement** in the picker. On commits with many changed files (e.g., dependency lock updates, large refactors), `git show --stat` can return thousands of lines and take 1-3 seconds. This causes the picker to freeze during navigation.

Noted as a known limitation in 04-EXECUTION-SUMMARY.md (#2), but it's a real UX degradation.

**Fix:**
Use `--shortstat` for a lighter preview, or debounce with `--max-count=1` on file list:
```lua
preview = function(selected)
  if not selected or #selected == 0 then return "" end
  local line = type(selected) == "table" and selected[1] or selected
  local sha = sha_map[line]
  if sha then
    local result = vim.system({ "git", "show", "--shortstat", "--format=%s%n%b", sha }):wait()
    return result.stdout or ""
  end
  return ""
end,
```

## Info

### IN-01: Double keymap registration — static in ai/init.lua AND dynamic in commit_picker/init.lua

**File:** `lua/commit_picker/init.lua:30` and `lua/ai/init.lua:118-121`
**Issue:** `<leader>kC` is registered twice: (1) statically in `ai/init.lua` keys table (line 118), which fires during `M.setup_keys()`, and (2) dynamically in `commit_picker/init.lua:M.setup()` (line 30), which fires during `CommitPicker.setup()` at `ai/init.lua:221`. Both register the same keymap with the same mode. The second `vim.keymap.set` will overwrite the first — this is redundant, not harmful, but it creates confusion about which registration is canonical.

**Fix:** Remove the dynamic registration in `commit_picker/init.lua:M.setup()`. The static entry in `ai/init.lua` is sufficient (and provides which-key grouping). Or, remove the static entry and keep only the dynamic one.

### IN-02: `SHA_COLOR` uses ANSI escape despite plan explicitly prohibiting it

**File:** `lua/commit_picker/display.lua:14`
**Issue:** REVIEWS-R2.md (MEDIUM-3) states: *"Plan 04-01 now explicitly states 'Do NOT embed ANSI escape codes; use fzf-lua's native highlight system instead.'"* The implementation defines `SHA_COLOR = "\27[38;5;111m"` — a raw ANSI escape sequence. This contradicts the plan resolution. While the escape doesn't end up in display strings (it's in the callback), the intent of the fix was to avoid ANSI entirely.

**Fix:** Already addressed by CR-01. Remove ANSI codes entirely.

### IN-03: `vim.loop.cwd()` deprecation — should use `vim.uv.cwd()`

**File:** `lua/commit_picker/git.lua:13`
**Issue:** `vim.loop` is the deprecated alias for `vim.uv` in Neovim 0.10+. While the rest of the codebase still uses `vim.loop` (see `plugins/git.lua:269`, `plugins/lsp.lua:15`, `ai/context.lua:93`), new code should prefer `vim.uv.cwd()` for forward compatibility. This is consistent with AGENTS.md guidance: "vim.loop.cwd() — or vim.uv.cwd() in newer versions."

**Fix:**
```lua
local cwd = opts.cwd or vim.uv.cwd()
```

---

_Reviewed: 2026-04-26T12:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: deep_