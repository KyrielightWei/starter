# Phase 01: Provider Manager Core UI - Research

**Phase:** 01 - Provider Manager Core UI
**Researched:** 2026-04-22
**Confidence:** HIGH

---

## Executive Summary

Phase 01 extends the existing `model_switch.lua` FZF-lua picker pattern to add CRUD operations for Provider/Model configurations. Research confirms this is a **well-documented pattern** with multiple reference implementations (`skill_studio/picker.lua`, `terminal_picker.lua`). No new dependencies required.

Key approach: Create `lua/ai/provider_manager/` subsystem directory following the Skill Studio pattern, with a `picker.lua` that extends the existing two-step picker flow with Ctrl-key CRUD actions.

---

## Technical Approach

### Stack (Verified Against Codebase)

| Component | Technology | Source | Confidence |
|-----------|------------|--------|------------|
| Picker UI | FZF-lua | `lua/ai/model_switch.lua` | HIGH (existing pattern) |
| Input dialogs | `vim.ui.input` | Neovim core | HIGH (standard API) |
| Config CRUD | `dofile()` + `vim.fn.writefile()` | `lua/ai/keys.lua` | HIGH (existing pattern) |
| Provider registry | `providers.lua` delegation | `lua/ai/providers.lua` | HIGH (existing API) |
| Keymaps | `<leader>kp` via `vim.keymap.set` | Lazy.nvim pattern | HIGH (standard) |

### Architecture Pattern

Follow the **Skill Studio subsystem pattern** (reference: `lua/ai/skill_studio/`):

```lua
-- Directory structure: lua/ai/provider_manager/
-- init.lua         — Orchestrator, command/keymap registration
-- picker.lua       — FZF-lua picker with CRUD actions
-- registry.lua     — CRUD operations, delegates to providers.lua/keys.lua
-- validator.lua    — Input validation (provider name format)
```

**Integration point:** Load in `lua/ai/init.lua` via `pcall(require, "ai.provider_manager")`

---

## Implementation Details

### 1. Picker Extension Pattern

**Reference:** `lua/ai/model_switch.lua` lines 20-80

The existing two-step picker flow:
```
Step 1: Select Provider → fzf_exec with providers list
Step 2: Select Model → fzf_exec with models for selected provider
```

**Extension for Phase 01:** Add Ctrl-key actions at Step 1 (Provider picker):

| Key | Action | Implementation |
|-----|--------|----------------|
| `Ctrl-A` | Add provider | `vim.ui.input` → validate → open `providers.lua` |
| `Ctrl-D` | Delete provider | `vim.ui.input` confirmation → call `registry.delete()` |
| `Ctrl-E` | Edit provider | `vim.cmd("edit lua/ai/providers.lua")` → jump to line |
| `Ctrl-/` | Help | Floating buffer with keybinding help |

**FZF-lua actions pattern (from skill_studio/picker.lua):**
```lua
local actions = require("fzf-lua.actions")
local fzf = require("fzf-lua")

fzf.fzf_exec(contents, {
  actions = {
    ["ctrl-a"] = function(selected)
      -- Add provider logic
    end,
    ["ctrl-d"] = function(selected)
      -- Delete provider logic
    end,
    ["ctrl-e"] = function(selected)
      -- Edit provider logic
    end,
  },
  -- Header hint for actions
  fzf_opts = {
    ["--header"] = "Actions: <CR>Select <C-a>Add <C-d>Delete <C-e>Edit",
  },
})
```

### 2. Registry CRUD Operations

**Reference:** `lua/ai/providers.lua` `register()`, `list()`, `get()`

**Registry.lua responsibilities:**
- `list_providers()` — delegate to `Providers.list()`, format for picker display
- `add_provider(name, config)` — call `Providers.register(name, config)`, notify user
- `delete_provider(name)` — remove from providers table, update state, notify
- `edit_provider(name)` — open `providers.lua` at provider's `M.register()` line

**Provider display format (from UI-SPEC):**
```lua
local display = string.format("%s  —  %s  —  %s", name, endpoint, default_model)
```

### 3. Input Validation

**Reference:** `lua/ai/keys.lua` validation patterns

**Validator.lua rules:**
- Provider name: `^[a-z][a-z0-9_-]*$` (kebab/snake case, lowercase)
- Empty check: name must not be empty
- Duplicate check: name must not exist in registry

```lua
local M = {}

function M.validate_provider_name(name)
  if not name or name == "" then
    return false, "Provider name cannot be empty"
  end
  if not name:match("^[a-z][a-z0-9_-]*$") then
    return false, "Provider name must be lowercase with dashes/underscores"
  end
  local Providers = require("ai.providers")
  if Providers.get(name) then
    return false, "Provider already exists: " .. name
  end
  return true, nil
end

return M
```

### 4. Keymap & Command Registration

**Reference:** `lua/ai/init.lua` setup_keys(), setup_commands()

**init.lua:**
```lua
local M = {}

function M.setup()
  -- Keymap
  vim.keymap.set("n", "<leader>kp", function()
    require("ai.provider_manager.picker").open()
  end, { desc = "AI Provider Manager" })

  -- User command
  vim.api.nvim_create_user_command("AIProviderManager", function()
    require("ai.provider_manager.picker").open()
  end, { desc = "Open AI Provider Manager panel" })
end

return M
```

### 5. Help Window Implementation

**Reference:** `lua/ai/skill_studio/picker.lua` help window pattern

Floating buffer with keybinding help:
```lua
local function show_help()
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    "Provider Manager - Help",
    "",
    "Keymaps:",
    "  <CR>      Select provider → show models",
    "  <C-a>     Add new provider",
    "  <C-d>     Delete selected provider",
    "  <C-e>     Edit providers.lua directly",
    "  <C-?>     Show this help",
    "",
    "Fields managed:",
    "  - Provider name (kebab-case)",
    "  - Endpoint/base_url",
    "  - Default model",
    "  - Static models list",
    "",
    "Press q to close",
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- Float window config...
end
```

---

## Critical Pitfalls

### Pitfall #1: State Subscription Memory Leak

**Risk:** If picker subscribes to state changes without cleanup, callbacks persist after picker closes.

**Prevention:** Add `BufWipeout` autocmd in picker setup:
```lua
local picker_buf = ...
vim.api.nvim_create_autocmd("BufWipeout", {
  buffer = picker_buf,
  callback = function()
    -- Cleanup subscriptions
  end,
})
```

### Pitfall #2: FZF Actions Timing

**Risk:** Ctrl-key actions execute before selection is confirmed. Need to handle empty selection.

**Prevention:** Check `selected` is not nil/empty before processing:
```lua
["ctrl-d"] = function(selected)
  if not selected or #selected == 0 then
    vim.notify("No provider selected", vim.log.levels.WARN)
    return
  end
  local name = selected[1]:match("^(%S+)")  -- Extract name from display
  -- Proceed with delete...
end,
```

### Pitfall #3: Provider Lua File Parsing

**Risk:** Jumping to provider's `M.register()` line requires parsing `providers.lua`.

**Prevention:** Use simple grep approach:
```lua
local function find_register_line(provider_name)
  local lines = vim.fn.readfile("lua/ai/providers.lua")
  for i, line in ipairs(lines) do
    if line:match("M.register%(['\"]" .. provider_name) then
      return i
    end
  end
  return 1  -- Default to top of file
end
```

---

## Codebase Integration Points

### Files to Create

| File | Purpose |
|------|---------|
| `lua/ai/provider_manager/init.lua` | Orchestrator, keymap/command registration |
| `lua/ai/provider_manager/picker.lua` | FZF-lua picker with CRUD actions |
| `lua/ai/provider_manager/registry.lua` | CRUD operations delegation |
| `lua/ai/provider_manager/validator.lua` | Input validation |

### Files to Modify

| File | Modification |
|------|--------------|
| `lua/ai/init.lua` | Add `pcall(require, "ai.provider_manager")` in setup() |

### Files to Reference (No Modification)

| File | Reference Purpose |
|------|-------------------|
| `lua/ai/providers.lua` | Provider registry API (list, get, register) |
| `lua/ai/keys.lua` | Config CRUD pattern reference |
| `lua/ai/model_switch.lua` | FZF-lua picker pattern reference |
| `lua/ai/skill_studio/picker.lua` | Custom actions and help window reference |

---

## Validation Architecture

### Testing Approach

**Unit tests:** `tests/ai/provider_manager/`
- `registry_spec.lua` — CRUD operations, delegation to providers.lua
- `validator_spec.lua` — Name validation rules
- `picker_spec.lua` — FZF actions behavior (mock fzf-lua)

**Integration tests:**
- Manual: Open picker via `<leader>kp`, verify provider list
- Manual: Ctrl-A → add provider → verify in providers.lua
- Manual: Ctrl-D → delete provider → verify removal
- Manual: Ctrl-E → edit provider → verify file opens at correct line

### Acceptance Criteria Verification

| Requirement | Verification Method |
|-------------|---------------------|
| PMGR-01 | Manual: Open picker, verify all providers displayed |
| PMGR-02 | Manual: Ctrl-A, enter name, verify provider added |
| PMGR-03 | Manual: Ctrl-D on provider, verify deleted |
| PMGR-04 | Manual: Ctrl-E, verify file opens, edit and verify saved |

---

## Decision Coverage

| Decision ID | Research Coverage |
|-------------|-------------------|
| D-01 | ✓ FZF-lua picker extension pattern documented |
| D-02 | ✓ Two-step flow preserved in picker.lua design |
| D-03 | ✓ Ctrl-A → vim.ui.input implementation shown |
| D-04 | ✓ Ctrl-D → confirmation dialog pattern documented |
| D-05 | ✓ Ctrl-E → open providers.lua at line approach |
| D-06 | ✓ Registry.lua manages all provider fields |
| D-07 | ✓ Rename via file edit (Ctrl-E approach) |
| D-08 | ✓ Keymap `<leader>kp` registration shown |
| D-09 | ✓ Command `:AIProviderManager` registration shown |

---

## Summary

Phase 01 is **straightforward implementation** with well-documented patterns:
- FZF-lua picker extension (reference: `model_switch.lua`, `skill_studio/picker.lua`)
- CRUD operations (reference: `keys.lua`, `providers.lua`)
- Subsystem directory structure (reference: `skill_studio/`)

**No blockers identified.** Proceed to planning with standard TDD approach for registry.lua and validator.lua.

---

*Research completed: 2026-04-22*
*Ready for planning: yes*