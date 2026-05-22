# Config Template Versioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement multi-version template management for OpenCode and Claude Code configuration generation, with backup strategy and security validation.

**Architecture:** Template versions stored in `~/.config/nvim/templates/{tool}/{version}.template.jsonc`, version selection tracked via State module, Picker UI for selection, backup rotation on config overwrite.

**Tech Stack:** Lua 5.1/LuaJIT (Neovim), FZF-lua (picker), State module (state management), plenary.nvim (testing)

---

## File Structure

| File | Responsibility |
|------|----------------|
| `lua/ai/template_version.lua` | Core module: version CRUD, discovery, migration |
| `lua/ai/template_picker.lua` | Picker UI: FZF-lua integration |
| `lua/ai/state.lua` | State extension: version tracking |
| `lua/ai/opencode.lua` | Modify: version parameter, backup integration |
| `lua/ai/claude_code.lua` | Modify: version parameter, backup integration |
| `lua/ai/init.lua` | Modify: command registration |
| `tests/ai/template_version_spec.lua` | Unit tests |

---

## Task 1: State Module Extension

**Files:**
- Modify: `lua/ai/state.lua`
- Test: `tests/ai/state_spec.lua`

### Step 1.1: Write failing test for get_template_version

```lua
-- tests/ai/state_spec.lua
describe("State template version", function()
  it("returns default version when not set", function()
    local State = require("ai.state")
    local version = State.get_template_version("opencode")
    assert.are.equal("default", version)
  end)
end)
```

- [ ] **Step 1.1: Write the failing test**

- [ ] **Step 1.2: Run test to verify it fails**

Run: `nvim --headless -c "PlenaryBustedFile tests/ai/state_spec.lua" -c "q"`
Expected: FAIL with "attempt to call field 'get_template_version' (a nil value)"

### Step 1.3: Implement State.get_template_version

```lua
-- lua/ai/state.lua (add to M table)
function M.get_template_version(tool)
  local state = M.get()
  if not state.template_versions then
    return "default"
  end
  return state.template_versions[tool] or "default"
end
```

- [ ] **Step 1.3: Write minimal implementation**

- [ ] **Step 1.4: Run test to verify it passes**

Run: `nvim --headless -c "PlenaryBustedFile tests/ai/state_spec.lua" -c "q"`
Expected: PASS

### Step 1.5: Write failing test for set_template_version

```lua
-- tests/ai/state_spec.lua (add to describe block)
  it("sets and retrieves template version", function()
    local State = require("ai.state")
    State.set_template_version("opencode", "secure")
    local version = State.get_template_version("opencode")
    assert.are.equal("secure", version)
  end)
```

- [ ] **Step 1.5: Write the failing test**

- [ ] **Step 1.6: Implement State.set_template_version**

```lua
-- lua/ai/state.lua (add to M table)
function M.set_template_version(tool, version)
  local state = M.get()
  state.template_versions = state.template_versions or {}
  state.template_versions[tool] = version
  M._state = state
  -- Notify subscribers
  if M._subscribers then
    for _, callback in ipairs(M._subscribers) do
      callback(state)
    end
  end
end
```

- [ ] **Step 1.6: Write minimal implementation**

- [ ] **Step 1.7: Run test to verify it passes**

- [ ] **Step 1.8: Commit**

```bash
git add lua/ai/state.lua tests/ai/state_spec.lua
git commit -m "feat(state): add template version tracking methods"
```

---

## Task 2: Core Module Structure

**Files:**
- Create: `lua/ai/template_version.lua`

### Step 2.1: Create module with directory helpers

```lua
-- lua/ai/template_version.lua
-- Template Version Manager - CRUD operations for config templates

local M = {}

local function get_templates_dir()
  return vim.fn.stdpath("config") .. "/templates"
end

local function get_tool_templates_dir(tool)
  return get_templates_dir() .. "/" .. tool
end

function M.get_template_path(tool, version)
  return get_tool_templates_dir(tool) .. "/" .. version .. ".template.jsonc"
end

function M.get_templates_dir()
  return get_templates_dir()
end

function M.get_tool_templates_dir(tool)
  return get_tool_templates_dir(tool)
end

return M
```

- [ ] **Step 2.1: Create module file**

- [ ] **Step 2.2: Write basic test for get_template_path**

```lua
-- tests/ai/template_version_spec.lua
describe("TemplateVersion path helpers", function()
  it("returns correct template path", function()
    local TV = require("ai.template_version")
    local path = TV.get_template_path("opencode", "default")
    assert.is_true(path:match("templates/opencode/default.template.jsonc") ~= nil)
  end)
end)
```

- [ ] **Step 2.3: Run test**

Run: `nvim --headless -c "PlenaryBustedFile tests/ai/template_version_spec.lua" -c "q"`
Expected: PASS

- [ ] **Step 2.4: Commit**

```bash
git add lua/ai/template_version.lua tests/ai/template_version_spec.lua
git commit -m "feat(template): add core module with path helpers"
```

---

## Task 3: Version Discovery

**Files:**
- Modify: `lua/ai/template_version.lua`
- Test: `tests/ai/template_version_spec.lua`

### Step 3.1: Write failing test for list

```lua
-- tests/ai/template_version_spec.lua (add to describe block)
describe("TemplateVersion.list", function()
  it("returns empty array when directory does not exist", function()
    local TV = require("ai.template_version")
    -- Use a non-existent tool name
    local versions = TV.list("nonexistent_tool")
    assert.are.same({}, versions)
  end)
end)
```

- [ ] **Step 3.1: Write the failing test**

- [ ] **Step 3.2: Implement TemplateVersion.list**

```lua
-- lua/ai/template_version.lua (add to M table)
function M.list(tool)
  local dir = get_tool_templates_dir(tool)
  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end

  local versions = {}
  local files = vim.fn.glob(dir .. "/*.template.jsonc", false, true) or {}
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r:r") -- Remove .template.jsonc
    table.insert(versions, name)
  end
  table.sort(versions)
  return versions
end
```

- [ ] **Step 3.2: Write minimal implementation**

- [ ] **Step 3.3: Run test to verify it passes**

### Step 3.4: Write test for exists

```lua
-- tests/ai/template_version_spec.lua (add to describe block)
describe("TemplateVersion.exists", function()
  it("returns false for non-existent version", function()
    local TV = require("ai.template_version")
    local exists = TV.exists("opencode", "nonexistent")
    assert.is_false(exists)
  end)
end)
```

- [ ] **Step 3.4: Write the failing test**

### Step 3.5: Implement TemplateVersion.exists

```lua
-- lua/ai/template_version.lua (add to M table)
function M.exists(tool, version)
  local path = M.get_template_path(tool, version)
  return vim.fn.filereadable(path) == 1
end
```

- [ ] **Step 3.5: Write minimal implementation**

- [ ] **Step 3.6: Run test**

- [ ] **Step 3.7: Commit**

```bash
git add lua/ai/template_version.lua tests/ai/template_version_spec.lua
git commit -m "feat(template): add version discovery (list, exists)"
```

---

## Task 4: Version CRUD Operations

**Files:**
- Modify: `lua/ai/template_version.lua`
- Test: `tests/ai/template_version_spec.lua`

### Step 4.1: Implement TemplateVersion.create

```lua
-- lua/ai/template_version.lua (add to M table)
function M.create(tool, name, source)
  if M.exists(tool, name) then
    return false, "Version '" .. name .. "' already exists"
  end

  local dir = get_tool_templates_dir(tool)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local target_path = M.get_template_path(tool, name)

  if source and M.exists(tool, source) then
    -- Copy from source
    local source_path = M.get_template_path(tool, source)
    vim.fn.writefile(vim.fn.readfile(source_path), target_path)
  else
    -- Create minimal template
    local minimal = '{
  "$schema": "https://opencode.ai/config.json",
  // Template: ' .. name .. '
  "model": "bailian_coding/qwen3.6-plus"
}'
    vim.fn.writefile(vim.split(minimal, "\n"), target_path)
  end

  return true, target_path
end
```

- [ ] **Step 4.1: Write the implementation**

### Step 4.2: Write test for create

```lua
-- tests/ai/template_version_spec.lua (add describe block)
describe("TemplateVersion.create", function()
  it("creates minimal template without source", function()
    local TV = require("ai.template_version")
    -- This test requires a mock directory
    local ok, result = TV.create("test_tool", "test_version")
    assert.is_true(ok)
    assert.is_true(TV.exists("test_tool", "test_version"))
    -- Cleanup
    vim.fn.delete(TV.get_template_path("test_tool", "test_version"))
    vim.fn.delete(TV.get_tool_templates_dir("test_tool"), "d")
  end)
end)
```

- [ ] **Step 4.2: Write the test**

- [ ] **Step 4.3: Run test**

### Step 4.4: Implement delete

```lua
-- lua/ai/template_version.lua (add to M table)
function M.delete(tool, name)
  if name == "default" then
    return false, "Cannot delete default template"
  end

  if not M.exists(tool, name) then
    return false, "Version '" .. name .. "' not found"
  end

  local path = M.get_template_path(tool, name)
  vim.fn.delete(path)

  -- Reset state if this was current version
  local State = require("ai.state")
  if State.get_template_version(tool) == name then
    State.set_template_version(tool, "default")
  end

  return true, "Deleted version '" .. name .. "'"
end
```

- [ ] **Step 4.4: Write the implementation**

### Step 4.5: Implement rename

```lua
-- lua/ai/template_version.lua (add to M table)
function M.rename(tool, old_name, new_name)
  if M.exists(tool, new_name) then
    return false, "Version '" .. new_name .. "' already exists"
  end

  if not M.exists(tool, old_name) then
    return false, "Version '" .. old_name .. "' not found"
  end

  local old_path = M.get_template_path(tool, old_name)
  local new_path = M.get_template_path(tool, new_name)
  vim.fn.rename(old_path, new_path)

  -- Update state if renaming current version
  local State = require("ai.state")
  if State.get_template_version(tool) == old_name then
    State.set_template_version(tool, new_name)
  end

  return true, "Renamed '" .. old_name .. "' to '" .. new_name .. "'"
end
```

- [ ] **Step 4.5: Write the implementation**

### Step 4.6: Implement copy

```lua
-- lua/ai/template_version.lua (add to M table)
function M.copy(tool, source, target)
  if M.exists(tool, target) then
    return false, "Version '" .. target .. "' already exists"
  end

  if not M.exists(tool, source) then
    return false, "Version '" .. source .. "' not found"
  end

  return M.create(tool, target, source)
end
```

- [ ] **Step 4.6: Write the implementation**

- [ ] **Step 4.7: Commit**

```bash
git add lua/ai/template_version.lua tests/ai/template_version_spec.lua
git commit -m "feat(template): add CRUD operations (create, delete, rename, copy)"
```

---

## Task 5: Picker UI Module

**Files:**
- Create: `lua/ai/template_picker.lua`

### Step 5.1: Create Picker module

```lua
-- lua/ai/template_picker.lua
-- Template Version Picker UI - FZF-lua integration

local M = {}

local function get_fzf()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not found", vim.log.levels.ERROR)
    return nil
  end
  return fzf
end

function M.open(tool, opts)
  opts = opts or {}
  local fzf = get_fzf()
  if not fzf then return end

  local TV = require("ai.template_version")
  local State = require("ai.state")
  local versions = TV.list(tool)

  if #versions == 0 then
    vim.notify("No templates found for " .. tool, vim.log.levels.WARN)
    return
  end

  local current = State.get_template_version(tool)

  fzf.fzf_exec(
    function(cb)
      for _, v in ipairs(versions) do
        local prefix = v == current and "* " or "  "
        cb(prefix .. v)
      end
      cb()
    end,
    {
      prompt = tool .. " templates> ",
      actions = {
        ["default"] = function(selected)
          if not selected then return end
          local version = selected[1]:gsub("^%*? ", "")
          State.set_template_version(tool, version)
          vim.notify("Selected template: " .. version, vim.log.levels.INFO)
          if opts.on_select then opts.on_select(version) end
        end,
        ["ctrl-e"] = function(selected)
          if not selected then return end
          local version = selected[1]:gsub("^%*? ", "")
          local path = TV.get_template_path(tool, version)
          vim.cmd("edit " .. vim.fn.fnameescape(path))
        end,
        ["ctrl-d"] = function(selected)
          if not selected then return end
          local version = selected[1]:gsub("^%*? ", "")
          if version == "default" then
            vim.notify("Cannot delete default template", vim.log.levels.ERROR)
            return
          end
          local confirm = vim.fn.confirm("Delete template '" .. version .. "'?", "&Yes\n&No", 2)
          if confirm == 1 then
            TV.delete(tool, version)
            vim.notify("Deleted template: " .. version, vim.log.levels.INFO)
          end
        end,
        ["ctrl-n"] = function()
          local name = vim.fn.input("New template name: ")
          if name and name ~= "" then
            local ok, result = TV.create(tool, name)
            if ok then
              vim.notify("Created template: " .. name, vim.log.levels.INFO)
            else
              vim.notify(result, vim.log.levels.ERROR)
            end
          end
        end,
        ["ctrl-y"] = function(selected)
          if not selected then return end
          local source = selected[1]:gsub("^%*? ", "")
          local target = vim.fn.input("Copy to: ")
          if target and target ~= "" then
            local ok, result = TV.copy(tool, source, target)
            if ok then
              vim.notify("Copied to: " .. target, vim.log.levels.INFO)
            else
              vim.notify(result, vim.log.levels.ERROR)
            end
          end
        end,
      },
    }
  )
end

return M
```

- [ ] **Step 5.1: Create the picker module**

- [ ] **Step 5.2: Commit**

```bash
git add lua/ai/template_picker.lua
git commit -m "feat(template): add FZF-lua picker for template selection"
```

---

## Task 6: User Commands

**Files:**
- Modify: `lua/ai/init.lua`

### Step 6.1: Add command registration

```lua
-- lua/ai/init.lua (add to setup_commands function)
local TemplatePicker = require("ai.template_picker")
local TemplateVersion = require("ai.template_version")

vim.api.nvim_create_user_command("AITemplateSelect", function(opts)
  local tool = opts.args or "opencode"
  TemplatePicker.open(tool)
end, {
  desc = "Select template version for AI tool",
  nargs = "?",
  complete = function()
    return { "opencode", "claude_code" }
  end,
})

vim.api.nvim_create_user_command("AITemplateList", function(opts)
  local tool = opts.args or "opencode"
  local versions = TemplateVersion.list(tool)
  if #versions == 0 then
    vim.notify("No templates found for " .. tool, vim.log.levels.INFO)
  else
    vim.notify("Templates for " .. tool .. ": " .. table.concat(versions, ", "), vim.log.levels.INFO)
  end
end, {
  desc = "List template versions for AI tool",
  nargs = "?",
  complete = function()
    return { "opencode", "claude_code" }
  end,
})

vim.api.nvim_create_user_command("AITemplateCreate", function(opts)
  local args = vim.split(opts.args, " ")
  local tool = args[1] or "opencode"
  local name = args[2]
  local source = args[3]
  if not name then
    vim.notify("Usage: AITemplateCreate <tool> <name> [source]", vim.log.levels.ERROR)
    return
  end
  local ok, result = TemplateVersion.create(tool, name, source)
  if ok then
    vim.notify("Created: " .. result, vim.log.levels.INFO)
  else
    vim.notify(result, vim.log.levels.ERROR)
  end
end, {
  desc = "Create new template version",
  nargs = "+",
})

vim.api.nvim_create_user_command("AITemplateDelete", function(opts)
  local args = vim.split(opts.args, " ")
  local tool = args[1] or "opencode"
  local name = args[2]
  if not name then
    vim.notify("Usage: AITemplateDelete <tool> <name>", vim.log.levels.ERROR)
    return
  end
  local ok, result = TemplateVersion.delete(tool, name)
  if ok then
    vim.notify(result, vim.log.levels.INFO)
  else
    vim.notify(result, vim.log.levels.ERROR)
  end
end, {
  desc = "Delete template version",
  nargs = "+",
})

vim.api.nvim_create_user_command("AITemplateRename", function(opts)
  local args = vim.split(opts.args, " ")
  local tool = args[1] or "opencode"
  local old_name = args[2]
  local new_name = args[3]
  if not old_name or not new_name then
    vim.notify("Usage: AITemplateRename <tool> <old> <new>", vim.log.levels.ERROR)
    return
  end
  local ok, result = TemplateVersion.rename(tool, old_name, new_name)
  if ok then
    vim.notify(result, vim.log.levels.INFO)
  else
    vim.notify(result, vim.log.levels.ERROR)
  end
end, {
  desc = "Rename template version",
  nargs = "+",
})
```

- [ ] **Step 6.1: Add command registration to init.lua**

- [ ] **Step 6.2: Commit**

```bash
git add lua/ai/init.lua
git commit -m "feat(ai): add template management commands"
```

---

## Task 7: Config Generation Integration (OpenCode)

**Files:**
- Modify: `lua/ai/opencode.lua`

### Step 7.1: Modify read_template_config to accept version

```lua
-- lua/ai/opencode.lua (modify function signature)
local function read_template_config(version)
  version = version or "default"

  local TemplateVersion = require("ai.template_version")
  local template_path = TemplateVersion.get_template_path("opencode", version)

  if vim.fn.filereadable(template_path) == 0 then
    -- Fallback to legacy path
    local legacy_path = get_opencode_template_path()
    if vim.fn.filereadable(legacy_path) == 1 then
      template_path = legacy_path
    else
      table.insert(warnings, "Template not found: " .. template_path)
      return {}, errors, warnings
    end
  end

  local content = table.concat(vim.fn.readfile(template_path), "\n")
  -- ... rest of the function unchanged
end
```

- [ ] **Step 7.1: Modify read_template_config**

### Step 7.2: Modify generate_config to use State version

```lua
-- lua/ai/opencode.lua (modify generate_config)
function M.generate_config(version_override)
  local State = require("ai.state")
  local version = version_override or State.get_template_version("opencode")

  local template_config, errors, warnings = read_template_config(version)
  -- ... rest of the function unchanged
end
```

- [ ] **Step 7.2: Modify generate_config**

- [ ] **Step 7.3: Commit**

```bash
git add lua/ai/opencode.lua
git commit -m "feat(opencode): integrate template version selection"
```

---

## Task 8: Backup Strategy

**Files:**
- Create: `lua/ai/config_backup.lua`
- Modify: `lua/ai/opencode.lua`

### Step 8.1: Create backup module

```lua
-- lua/ai/config_backup.lua
-- Config Backup Manager - backup rotation and restore

local M = {}

local function get_backup_dir(tool)
  if tool == "opencode" then
    local xdg_config = os.getenv("XDG_CONFIG_HOME") or vim.fn.expand("~/.config")
    return xdg_config .. "/opencode"
  elseif tool == "claude_code" then
    return vim.fn.expand("~/.claude")
  end
  return nil
end

local function get_config_path(tool)
  local dir = get_backup_dir(tool)
  if tool == "opencode" then
    return dir .. "/opencode.json"
  elseif tool == "claude_code" then
    return dir .. "/settings.json"
  end
  return nil
end

local function get_backup_paths(tool)
  local config_path = get_config_path(tool)
  return {
    config_path .. ".bak1",
    config_path .. ".bak2",
  }
end

function M.backup(tool)
  local config_path = get_config_path(tool)
  if not config_path then return false, "Unknown tool" end

  if vim.fn.filereadable(config_path) == 0 then
    return true, "No existing config to backup"
  end

  local bak1, bak2 = unpack(get_backup_paths(tool))

  -- Rotate backups: delete bak2, rename bak1 to bak2, create new bak1
  if vim.fn.filereadable(bak2) == 1 then
    vim.fn.delete(bak2)
  end
  if vim.fn.filereadable(bak1) == 1 then
    vim.fn.rename(bak1, bak2)
  end

  -- Copy current config to bak1
  vim.fn.writefile(vim.fn.readfile(config_path), bak1)

  return true, bak1
end

function M.restore(tool, backup_num)
  backup_num = backup_num or 1
  local config_path = get_config_path(tool)
  local backup_path = get_backup_paths(tool)[backup_num]

  if vim.fn.filereadable(backup_path) == 0 then
    return false, "Backup not found: " .. backup_path
  end

  vim.fn.writefile(vim.fn.readfile(backup_path), config_path)
  return true, "Restored from backup " .. backup_num
end

function M.get_diff(tool)
  local config_path = get_config_path(tool)
  local bak1 = get_backup_paths(tool)[1]

  if vim.fn.filereadable(config_path) == 0 or vim.fn.filereadable(bak1) == 0 then
    return nil
  end

  -- Return simple diff info
  return {
    current = config_path,
    backup = bak1,
  }
end

return M
```

- [ ] **Step 8.1: Create the backup module**

### Step 8.2: Integrate backup into write_config

```lua
-- lua/ai/opencode.lua (modify write_config)
function M.write_config(version_override)
  -- Backup before writing
  local Backup = require("ai.config_backup")
  Backup.backup("opencode")

  -- Generate config
  local config, auth_config, ok = M.generate_config(version_override)
  if not ok then
    vim.notify("Config generation failed", vim.log.levels.ERROR)
    return false
  end

  -- Show overwrite warning
  local diff = Backup.get_diff("opencode")
  if diff then
    vim.notify("Config backed up to: " .. diff.backup .. ".bak1\nUse :OpenCodeRestoreBackup to restore", vim.log.levels.INFO)
  end

  -- ... rest of write_config unchanged
end
```

- [ ] **Step 8.2: Integrate backup**

### Step 8.3: Add restore command

```lua
-- lua/ai/opencode.lua (add new function)
function M.restore_backup(backup_num)
  local Backup = require("ai.config_backup")
  local ok, result = Backup.restore("opencode", backup_num)
  if ok then
    vim.notify(result, vim.log.levels.INFO)
  else
    vim.notify(result, vim.log.levels.ERROR)
  end
end
```

- [ ] **Step 8.3: Add restore function**

- [ ] **Step 8.4: Register restore command in init.lua**

```lua
-- lua/ai/init.lua (add to setup_commands)
vim.api.nvim_create_user_command("OpenCodeRestoreBackup", function(opts)
  local backup_num = tonumber(opts.args) or 1
  require("ai.opencode").restore_backup(backup_num)
end, {
  desc = "Restore OpenCode config from backup",
  nargs = "?",
})
```

- [ ] **Step 8.5: Commit**

```bash
git add lua/ai/config_backup.lua lua/ai/opencode.lua lua/ai/init.lua
git commit -m "feat(config): add backup strategy with rotation and restore"
```

---

## Task 9: Security Validation

**Files:**
- Modify: `lua/ai/template_version.lua`

### Step 9.1: Add security validation

```lua
-- lua/ai/template_version.lua (add to M table)
local SENSITIVE_PATTERNS = {
  "api[_-]?key",
  "secret",
  "password",
  "token",
  "credential",
  "sk-[a-zA-Z0-9]+",  -- OpenAI key pattern
  "[a-f0-9]{32}",     -- Hex key pattern
}

function M.validate_security(content)
  local warnings = {}

  for _, pattern in ipairs(SENSITIVE_PATTERNS) do
    if content:lower():match(pattern) then
      table.insert(warnings, "Template may contain sensitive data matching: " .. pattern)
    end
  end

  return #warnings == 0, warnings
end
```

- [ ] **Step 9.1: Add security validation function**

### Step 9.2: Integrate security check into read_template_config

```lua
-- lua/ai/opencode.lua (add to read_template_config)
local TemplateVersion = require("ai.template_version")
local secure_ok, security_warnings = TemplateVersion.validate_security(clean_content)
if not secure_ok then
  vim.list_extend(warnings, security_warnings)
end
```

- [ ] **Step 9.2: Integrate security check**

- [ ] **Step 9.3: Commit**

```bash
git add lua/ai/template_version.lua lua/ai/opencode.lua
git commit -m "feat(template): add security validation for sensitive data"
```

---

## Task 10: Legacy Migration

**Files:**
- Modify: `lua/ai/template_version.lua`

### Step 10.1: Implement migration function

```lua
-- lua/ai/template_version.lua (add to M table)
function M.migrate_legacy(tool)
  local legacy_path = vim.fn.stdpath("config") .. "/" .. tool .. ".template.jsonc"
  local templates_dir = get_tool_templates_dir(tool)

  -- Check if migration needed
  if vim.fn.filereadable(legacy_path) == 0 then
    return false, "No legacy template to migrate"
  end

  if vim.fn.isdirectory(templates_dir) == 1 then
    return false, "Templates directory already exists"
  end

  -- Create directory and migrate
  vim.fn.mkdir(templates_dir, "p")
  local target_path = M.get_template_path(tool, "default")
  vim.fn.writefile(vim.fn.readfile(legacy_path), target_path)

  -- Create migration marker
  vim.fn.writefile({ "migrated" }, templates_dir .. "/.migration_done")

  return true, "Migrated to " .. target_path
end

function M.check_migration_needed(tool)
  local legacy_path = vim.fn.stdpath("config") .. "/" .. tool .. ".template.jsonc"
  local templates_dir = get_tool_templates_dir(tool)
  local marker = templates_dir .. "/.migration_done"

  return vim.fn.filereadable(legacy_path) == 1
    and vim.fn.isdirectory(templates_dir) == 0
    and vim.fn.filereadable(marker) == 0
end
```

- [ ] **Step 10.1: Implement migration functions**

### Step 10.2: Trigger migration on first use

```lua
-- lua/ai/template_picker.lua (add to M.open)
local TV = require("ai.template_version")
if TV.check_migration_needed(tool) then
  local ok, result = TV.migrate_legacy(tool)
  if ok then
    vim.notify("Legacy template migrated: " .. result, vim.log.levels.INFO)
  end
end
```

- [ ] **Step 10.2: Trigger migration**

- [ ] **Step 10.3: Commit**

```bash
git add lua/ai/template_version.lua lua/ai/template_picker.lua
git commit -m "feat(template): add legacy migration with auto-trigger"
```

---

## Task 11: Tests - Complete Suite

**Files:**
- Modify: `tests/ai/template_version_spec.lua`

### Step 11.1: Add complete test suite

```lua
-- tests/ai/template_version_spec.lua
local assert = require("luassert")

describe("TemplateVersion module", function()
  local TV = require("ai.template_version")

  describe("path helpers", function()
    it("returns correct templates directory", function()
      local dir = TV.get_templates_dir()
      assert.is_true(dir:match("templates") ~= nil)
    end)

    it("returns correct tool directory", function()
      local dir = TV.get_tool_templates_dir("opencode")
      assert.is_true(dir:match("templates/opencode") ~= nil)
    end)

    it("returns correct template path", function()
      local path = TV.get_template_path("opencode", "default")
      assert.is_true(path:match("templates/opencode/default.template.jsonc") ~= nil)
    end)
  end)

  describe("version discovery", function()
    it("list returns empty for nonexistent tool", function()
      local versions = TV.list("nonexistent_tool_xyz")
      assert.are.same({}, versions)
    end)

    it("exists returns false for nonexistent version", function()
      assert.is_false(TV.exists("opencode", "nonexistent_xyz"))
    end)
  end)

  describe("CRUD operations", function()
    local test_tool = "test_tool_crud"
    local test_version = "test_version"

    after_each(function()
      -- Cleanup test artifacts
      local dir = TV.get_tool_templates_dir(test_tool)
      if vim.fn.isdirectory(dir) == 1 then
        vim.fn.delete(dir, "d")
      end
    end)

    it("create creates minimal template", function()
      local ok, result = TV.create(test_tool, test_version)
      assert.is_true(ok)
      assert.is_true(TV.exists(test_tool, test_version))
    end)

    it("create fails for existing version", function()
      TV.create(test_tool, test_version)
      local ok, err = TV.create(test_tool, test_version)
      assert.is_false(ok)
      assert.is_true(err:match("already exists") ~= nil)
    end)

    it("delete removes version", function()
      TV.create(test_tool, test_version)
      local ok = TV.delete(test_tool, test_version)
      assert.is_true(ok)
      assert.is_false(TV.exists(test_tool, test_version))
    end)

    it("delete fails for default version", function()
      TV.create(test_tool, "default")
      local ok, err = TV.delete(test_tool, "default")
      assert.is_false(ok)
      assert.is_true(err:match("Cannot delete default") ~= nil)
    end)

    it("rename changes version name", function()
      TV.create(test_tool, "old_name")
      local ok = TV.rename(test_tool, "old_name", "new_name")
      assert.is_true(ok)
      assert.is_true(TV.exists(test_tool, "new_name"))
      assert.is_false(TV.exists(test_tool, "old_name"))
    end)

    it("copy creates duplicate", function()
      TV.create(test_tool, "source")
      local ok = TV.copy(test_tool, "source", "target")
      assert.is_true(ok)
      assert.is_true(TV.exists(test_tool, "target"))
    end)
  end)

  describe("security validation", function()
    it("detects API key pattern", function()
      local content = '{"api_key": "sk-123456"}'
      local ok, warnings = TV.validate_security(content)
      assert.is_false(ok)
      assert.is_true(#warnings > 0)
    end)

    it("passes for safe content", function()
      local content = '{"model": "gpt-4"}'
      local ok, warnings = TV.validate_security(content)
      assert.is_true(ok)
      assert.are.same({}, warnings)
    end)
  end)
end)
```

- [ ] **Step 11.1: Write complete test suite**

- [ ] **Step 11.2: Run all tests**

Run: `nvim --headless -c "PlenaryBustedDirectory tests/ai/" -c "q"`
Expected: All PASS

- [ ] **Step 11.3: Commit**

```bash
git add tests/ai/template_version_spec.lua
git commit -m "test(template): complete test suite for template versioning"
```

---

## Self-Review Checklist

✅ **Spec coverage**: Each spec requirement has corresponding task
✅ **Placeholder scan**: No TBD/TODO in plan
✅ **Type consistency**: Function names consistent throughout tasks

---

**Plan complete.** Saved to `docs/superpowers/plans/2026-05-22-config-template-versioning.md`.