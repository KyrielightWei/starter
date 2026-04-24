---
phase: 01-provider-manager-core-ui
reviewed: 2026-04-22T12:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - lua/ai/provider_manager/validator.lua
  - lua/ai/provider_manager/registry.lua
  - lua/ai/provider_manager/file_util.lua
  - lua/ai/provider_manager/init.lua
  - lua/ai/provider_manager/picker.lua
  - lua/ai/init.lua
  - tests/ai/provider_manager/validator_spec.lua
  - tests/ai/provider_manager/registry_spec.lua
  - tests/ai/provider_manager/registry_static_models_spec.lua
  - tests/ai/provider_manager/picker_spec.lua
  - tests/ai/provider_manager/init_spec.lua
findings:
  critical: 1
  warning: 4
  info: 5
  total: 10
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-22T12:00:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Reviewed the Provider Manager Core UI subsystem — a 5-module Lua package (validator, registry, file_util, init, picker) plus integration changes to `lua/ai/init.lua` and 5 test files. The implementation follows project conventions well: proper module patterns, pcall guards for optional dependencies, and a clear separation of concerns.

However, there is one **Critical** security issue (`vim.cmd` shell injection via unsanitized file path), four **Warnings** involving data safety and edge-case bugs, and five **Info** items covering style consistency and test gaps.

---

## Critical Issues

### CR-01: Shell Injection via `vim.cmd("edit ...")` with unsanitized path

**File:** `lua/ai/provider_manager/registry.lua:86`
**Issue:** The `add_provider(name)` function constructs a shell command via string concatenation: `vim.cmd("edit " .. config_path)`. While `config_path` is derived from `vim.fn.stdpath("config")`, the `edit_provider(name)` function in `picker.lua:213` does the same: `vim.cmd("edit " .. path)`. If the user's `stdpath("config")` contains spaces or special characters, this will fail or behave unexpectedly. More importantly, `vim.cmd("edit ...")` interprets the argument as a Vim command, which can be exploited if the path contains pipe characters (`|`) or other Vim command separators.

**Fix:**
```lua
-- Use vim.cmd.edit() with proper escaping, or vim.api to open buffer safely
vim.cmd("edit " .. vim.fn.fnameescape(config_path))
-- Or better, use the safer Neovim API:
vim.cmd.edit({ file = config_path })
```

Apply the same fix at `picker.lua:213`:
```lua
vim.cmd.edit({ files = { path } })
```

---

## Warnings

### WR-01: `dofile` executes arbitrary Lua code as data parser

**File:** `lua/ai/provider_manager/file_util.lua:65`
**Issue:** `M.read_lua_table(path)` uses `pcall(dofile, path)` to "parse" a Lua file and return its table. `dofile` actually **executes** the file as Lua code. If a malicious or corrupted `providers.lua` is loaded, arbitrary code runs (e.g., `vim.fn.system("rm -rf /")`). This is a known anti-pattern for config file reading when the file is user-editable.

While `providers.lua` is a trusted file in this context, the function is exported as a public API (`M.read_lua_table`) and could be reused elsewhere. The UI-SPEC mentions this is not required for Phase 1, but the function exists and is callable.

**Fix:**
```lua
-- Add a clear warning in the function name or documentation
-- Or restrict to known-safe paths:
function M.read_lua_table(path)
  -- Validate path is within expected directory
  local config_dir = vim.fn.stdpath("config") .. "/lua/ai/"
  if not path:find(config_dir, 1, true) then
    return nil, "Refusing to load file outside ai/ directory"
  end
  -- ... rest of function
end
```

### WR-02: Static model rename causes data loss on duplicate

**File:** `lua/ai/provider_manager/picker.lua:326-331`
**Issue:** In `_rename_static_model_dialog`, the function first removes the old model, then adds the new one. If `add_static_model` fails (e.g., duplicate with another existing model, or file write error), the old model is already gone — data loss.

```lua
-- Current (racy):
local remove_ok = Registry.remove_static_model(provider_name, old_model_id)
if remove_ok then
  Registry.add_static_model(provider_name, new_model_id)
```

**Fix:**
```lua
-- Atomically: read all, replace, write all in one operation
local current = Registry.list_static_models(provider_name)
local new_models = {}
for _, m in ipairs(current) do
  if m == old_model_id then
    table.insert(new_models, new_model_id)
  else
    -- Check new_model_id doesn't already exist
    if m == new_model_id then
      vim.notify("Model already exists: " .. new_model_id, vim.log.levels.ERROR)
      return
    end
    table.insert(new_models, m)
  end
end

local start, end_line = Registry.find_provider_block(provider_name)
Registry.update_static_models(provider_name, new_models)
```

### WR-03: `file_util.lua` atomic write fallback is not atomic

**File:** `lua/ai/provider_manager/file_util.lua:36-39`
**Issue:** When `uv.fs_rename` fails (line 34: `result` is truthy meaning an error occurred), the fallback does `readfile(tmp) → writefile(path)`. This is a **copy**, not a rename — it's not atomic. If Neovim crashes between write and tmp deletion, the `.tmp` file is orphaned. More critically, if the user has the file open in another buffer, the copy replaces file contents without triggering proper buffer reload events.

**Fix:**
```lua
-- Try fs_rename first; only fallback to delete-then-write if rename fails
local ok_rename = pcall(uv.fs_rename, uv, tmp_path, path)
if not ok_rename then
  -- Proper fallback: write directly (acknowledge non-atomic)
  -- Or use os.rename which is more portable
  local ok_os = os.rename(tmp_path, path)
  if not ok_os then
    -- Last resort: direct write
    local lines = vim.fn.readfile(tmp_path)
    vim.fn.writefile(lines, path)
  end
  pcall(vim.fn.delete, tmp_path)
end
```

### WR-04: `find_provider_block` regex can match wrong provider with substring names

**File:** `lua/ai/provider_manager/registry.lua:44`
**Issue:** The regex `M%.register%(['\"]" .. name .. "['\"]` will match substring provider names. For example, searching for `"open"` would match `M.register("openai", {...})`. While provider names are validated to avoid this in the validator, the `find_provider_block` function is called internally without going through the validator, and could be called with arbitrary strings from other callers.

**Fix:**
```lua
-- Anchor the match to the exact string boundary
if line:match("M%.register%(['\"]" .. name .. "['\"]%s*,") then
  start_line = i
end
```

### WR-05: Model picker sorting `table.insert(sorted, 1, ...)` is O(n²) with incorrect behavior

**File:** `lua/ai/provider_manager/picker.lua:127`
**Issue:** When sorting models with the current default first, the code does `table.insert(sorted, 1, model_id)` which shifts all existing elements. This is O(n²) for n models. More importantly, this means the model list is sorted **opposite to the iteration order** — the first model in the original list that matches `current_default` ends up at position 1, but subsequent non-default models are appended after it, preserving relative order. This likely works but is confusing.

**Fix:**
```lua
-- Collect default and non-default separately, then concatenate
local default_item = nil
local others = {}
for _, m in ipairs(models) do
  local model_id = type(m) == "table" and (m.id or m.model_id) or m
  if model_id == current_default then
    default_item = model_id
  else
    table.insert(others, model_id)
  end
end
local sorted = default_item and { default_item } or {}
for _, m in ipairs(others) do table.insert(sorted, m) end
```

---

## Info

### IN-01: Inconsistent notification message between `registry.lua` and `picker.lua`

**File:** `lua/ai/provider_manager/registry.lua:93` vs `lua/ai/provider_manager/picker.lua:196`
**Issue:** `registry.lua:add_provider` says `"Provider registration added. Please fill in config for: {name}"`, but `picker.lua:add_provider_dialog` says `"Provider added: {name}. Please add config to providers.lua"`. Two different messages for the same action. UI-SPEC copywriting contract does not specify this message, but they should be consistent.

**Fix:** Choose one message and use it in both locations.

### IN-02: `_add_static_model_dialog` calls the picker API without validation

**File:** `lua/ai/provider_manager/picker.lua:308-310`
**Issue:** The `_add_static_model_dialog` does no validation on `model_id` beyond checking for empty. It could allow duplicate entries, special characters, or empty whitespace. The `Registry.add_static_model` does check for duplicates, but a blank/whitespace-only model_id would pass through.

**Fix:**
```lua
if not model_id or model_id:match("^%s*$") then return end
```

### IN-03: Test for `set_default_model` does not verify actual keys file persistence

**File:** `tests/ai/provider_manager/registry_spec.lua:95-109`
**Issue:** The `set_default_model` tests only verify in-memory state (`def.model`), not that `Keys.write()` persisted the change. The real function writes to the keys config file, but the test uses the real file system. This means every test run mutates the user's actual `ai_keys.lua` file. Tests should mock `Keys.read/write` to avoid side effects.

**Fix:** Wrap tests in mocks:
```lua
local mock_config = {}
Keys.read = function() return mock_config end
Keys.write = function(config) mock_config = config end
-- ... run test ...
-- Verify mock_config was updated correctly
```

### IN-04: Missing test for `delete_provider` file persistence path

**File:** `tests/ai/provider_manager/registry_spec.lua`
**Issue:** The `delete_provider` test only covers the "non-existent provider" case (line 60). There is no test for the happy path where a provider is actually deleted and the file is modified. Given that file modification is one of the phase's core requirements (PMGR-03), this is a gap.

**Fix:** Add test using the `/tmp/` mock pattern from `registry_static_models_spec.lua`:
```lua
it("deletes provider and persists to file", function()
  -- Set up mock providers.lua content with a test provider block
  -- Call delete_provider
  -- Assert file content no longer contains the provider block
end)
```

### IN-05: Trailing whitespace in `picker.lua:325`

**File:** `lua/ai/provider_manager/picker.lua:325`
**Issue:** Line 325 has trailing whitespace after `then`. Per project `stylua.toml` conventions, trailing whitespace should be removed. This will be auto-fixed by running `stylua lua/` but is worth noting as the project uses `conform.nvim` for format-on-save.

**Fix:** Run `stylua lua/ai/provider_manager/picker.lua` to clean up.

---

_Reviewed: 2026-04-22T12:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
