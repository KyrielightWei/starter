---
phase: 01-provider-manager-core-ui
fixed_at: 2026-04-22T12:30:00Z
review_path: .planning/phases/01-provider-manager-core-ui/01-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-04-22T12:30:00Z
**Source review:** .planning/phases/01-provider-manager-core-ui/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: ShellInjection via `vim.cmd("edit ...")` with unsanitized path

**Files modified:** `lua/ai/provider_manager/registry.lua`, `lua/ai/provider_manager/picker.lua`
**Commit:** 88564e2
**Applied fix:** Replaced `vim.cmd("edit " .. path)` with `vim.cmd.edit({ file = path })` in both `registry.lua:add_provider()` (line 86) and `picker.lua:edit_provider()` (line 213). The `vim.cmd.edit()` API accepts the file path as a table argument, which Neovim handles safely without Vim command interpretation.

### WR-01: `dofile` executes arbitrary Lua code as data parser

**Files modified:** `lua/ai/provider_manager/file_util.lua`
**Commit:** 8c91f3c
**Applied fix:** Added path validation to `read_lua_table()` that resolves both the input path and the expected `ai/` config directory to absolute paths using `vim.fn.fnamemodify(path, ":p")`, then checks the input path starts with the config directory prefix. Rejects files outside the `lua/ai/` directory with a clear error message.

### WR-02: Static model rename causes data loss on duplicate

**Files modified:** `lua/ai/provider_manager/picker.lua`
**Commit:** 1aba067
**Applied fix:** Rewrote `_rename_static_model_dialog()` to use an atomic read-replace-write pattern. Instead of removing old model then adding new one (which loses data if add fails), the fix now: reads current models, checks new model doesn't already exist, builds new list with replacement in a single pass, then calls `Registry.update_static_models()` for atomic persistence.

### WR-03: `file_util.lua` atomic write fallback is not atomic

**Files modified:** `lua/ai/provider_manager/file_util.lua`
**Commit:** 151d80d
**Applied fix:** Improved the fallback chain in `safe_write_file()`. When `uv.fs_rename` fails, the code now tries `os.rename()` as a more portable OS-level rename before falling back to direct readfile/writefile copy. The tmp file cleanup is properly handled after each fallback branch.

### WR-04: `find_provider_block` regex can match wrong provider with substring names

**Files modified:** `lua/ai/provider_manager/registry.lua`
**Commit:** 4cdba1c
**Applied fix:** Anchored the regex pattern in both `find_provider_block()` (line 44) and the fallback path in `delete_provider()` (line 133) by adding `%s*,` after the closing quote. This ensures `"M%.register%(['\"]open['\"]%s*,")` matches only `"open"` and not `"openai"`.

### WR-05: Model picker sorting `table.insert(sorted, 1, ...)` is O(n²)

**Files modified:** `lua/ai/provider_manager/picker.lua`
**Commit:** 34625dc
**Applied fix:** Replaced the O(n²) `table.insert(sorted, 1, model_id)` pattern with a two-pass approach: first collects the default model and non-default models into separate tables, then concatenates them. This achieves O(n) complexity for sorting models with the current default first.

---

_Fixed: 2026-04-22T12:30:00Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
