-- lua/ai/skill_studio/init.lua
-- Simplified Skill Studio for Claude Code skill management

local M = {}

local Converter = require("ai.skill_studio.converter")

----------------------------------------------------------------------
-- Paths
----------------------------------------------------------------------
local PATHS = {
  project = function()
    return vim.fn.getcwd() .. "/.claude/skills"
  end,
  global = function()
    return vim.fn.expand("~/.claude/skills")
  end,
}

----------------------------------------------------------------------
-- List Skills
----------------------------------------------------------------------
function M.list_all()
  local skills = {}
  for scope, path_fn in pairs(PATHS) do
    local path = path_fn()
    if vim.fn.isdirectory(path) == 1 then
      local dirs = vim.fn.readdir(path)
      for _, dir in ipairs(dirs) do
        if vim.fn.isdirectory(path .. "/" .. dir) == 1 then
          local skill_file = path .. "/" .. dir .. "/SKILL.md"
          if vim.fn.filereadable(skill_file) == 1 then
            skills[dir] = {
              path = skill_file,
              scope = scope,
            }
          end
        end
      end
    end
  end
  return skills
end

----------------------------------------------------------------------
-- Generate Template
----------------------------------------------------------------------
function M.generate_template(name, desc)
  return string.format(
    [[---
name: %s
description: %s
version: "1.0.0"
---

# %s

## When This Skill Applies

Describe when this skill should be triggered.

## Instructions

1. Step 1
2. Step 2
3. Step 3

## Examples

**Example 1:**
Input: ...
Output: ...
]],
    name,
    desc or "Skill description",
    name
  )
end

----------------------------------------------------------------------
-- Create Skill
----------------------------------------------------------------------
function M.new(opts)
  opts = opts or {}
  local scope = opts.scope or "project"

  vim.ui.input({ prompt = "Skill name (kebab-case): " }, function(name)
    if not name or name == "" then
      return
    end

    -- Validate name
    if not name:match("^[a-z][a-z0-9-]*$") then
      vim.notify("Invalid name: must be lowercase alphanumeric with hyphens", vim.log.levels.ERROR)
      return
    end

    -- Check if exists
    local skills = M.list_all()
    if skills[name] then
      vim.notify("Skill already exists: " .. name, vim.log.levels.WARN)
      return
    end

    vim.ui.input({ prompt = "Description: " }, function(desc)
      local content = M.generate_template(name, desc or "")
      local dir = PATHS[scope]() .. "/" .. name
      vim.fn.mkdir(dir, "p")
      vim.fn.writefile(vim.split(content, "\n"), dir .. "/SKILL.md")
      vim.notify("Created skill: " .. name, vim.log.levels.INFO)
      vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/SKILL.md"))
    end)
  end)
end

----------------------------------------------------------------------
-- Edit Skill
----------------------------------------------------------------------
function M.edit(name)
  if not name then
    vim.notify("Skill name required", vim.log.levels.ERROR)
    return
  end

  local skills = M.list_all()
  local info = skills[name]
  if not info then
    vim.notify("Skill not found: " .. name, vim.log.levels.ERROR)
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(info.path))
end

----------------------------------------------------------------------
-- Delete Skill
----------------------------------------------------------------------
function M.delete(name)
  if not name then
    vim.notify("Skill name required", vim.log.levels.ERROR)
    return
  end

  local skills = M.list_all()
  local info = skills[name]
  if not info then
    vim.notify("Skill not found: " .. name, vim.log.levels.ERROR)
    return
  end

  vim.ui.select({ "Yes", "No" }, { prompt = "Delete skill " .. name .. "?" }, function(choice)
    if choice == "Yes" then
      local dir = vim.fn.fnamemodify(info.path, ":h")
      vim.fn.delete(dir, "rf")
      vim.notify("Deleted skill: " .. name, vim.log.levels.INFO)
    end
  end)
end

----------------------------------------------------------------------
-- Copy Skill (scope transfer)
----------------------------------------------------------------------
function M.copy(name, target_scope)
  if not name then
    vim.notify("Skill name required", vim.log.levels.ERROR)
    return
  end

  local skills = M.list_all()
  local info = skills[name]
  if not info then
    vim.notify("Skill not found: " .. name, vim.log.levels.ERROR)
    return
  end

  if info.scope == target_scope then
    vim.notify("Skill already in " .. target_scope .. " scope", vim.log.levels.WARN)
    return
  end

  local dst_dir = PATHS[target_scope]() .. "/" .. name
  if vim.fn.isdirectory(dst_dir) == 1 then
    vim.notify("Skill already exists in " .. target_scope .. " scope", vim.log.levels.WARN)
    return
  end

  vim.fn.mkdir(dst_dir, "p")
  vim.fn.system(string.format("cp %s %s", vim.fn.shellescape(info.path), vim.fn.shellescape(dst_dir .. "/SKILL.md")))
  vim.notify("Copied " .. name .. " to " .. target_scope .. " scope", vim.log.levels.INFO)
end

----------------------------------------------------------------------
-- Validate Skill
----------------------------------------------------------------------
function M.validate(name)
  if not name then
    return { valid = false, errors = { "Skill name required" } }
  end

  local skills = M.list_all()
  local info = skills[name]
  if not info then
    return { valid = false, errors = { "Skill not found: " .. name } }
  end

  local content = table.concat(vim.fn.readfile(info.path), "\n")
  local errors = {}

  -- Check frontmatter
  if not content:match("^%-%-%-") then
    table.insert(errors, "Missing frontmatter (---)")
  end

  -- Check required fields
  if not content:find("name:", 1, true) then
    table.insert(errors, "Missing 'name' in frontmatter")
  end
  if not content:find("description:", 1, true) then
    table.insert(errors, "Missing 'description' in frontmatter")
  end

  -- Check required sections
  if not content:find("## Instructions", 1, true) and not content:find("## 指令", 1, true) then
    table.insert(errors, "Missing '## Instructions' section")
  end

  return {
    valid = #errors == 0,
    errors = errors,
    path = info.path,
    scope = info.scope,
  }
end

----------------------------------------------------------------------
-- Convert Skill
----------------------------------------------------------------------
function M.convert(name, target)
  if not name then
    vim.notify("Skill name required", vim.log.levels.ERROR)
    return
  end

  local skills = M.list_all()
  local info = skills[name]
  if not info then
    vim.notify("Skill not found: " .. name, vim.log.levels.ERROR)
    return
  end

  local content = table.concat(vim.fn.readfile(info.path), "\n")

  if target == "opencode" then
    local ok, err = Converter.to_opencode(name, content)
    if ok then
      vim.notify("Converted " .. name .. " to OpenCode agents format", vim.log.levels.INFO)
    else
      vim.notify("Conversion failed: " .. err, vim.log.levels.ERROR)
    end
  elseif target == "qoder" then
    local ok, err = Converter.to_qoder(name, content)
    if ok then
      vim.notify("Converted " .. name .. " to QoderCLI format", vim.log.levels.INFO)
    else
      vim.notify("Conversion failed: " .. err, vim.log.levels.ERROR)
    end
  else
    vim.notify("Unknown target: " .. target, vim.log.levels.ERROR)
  end
end

----------------------------------------------------------------------
-- Skill Picker (fzf-lua)
----------------------------------------------------------------------
function M.list()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua required for picker", vim.log.levels.ERROR)
    return
  end

  local skills = M.list_all()
  if vim.tbl_isempty(skills) then
    vim.notify("No skills found", vim.log.levels.INFO)
    return
  end

  local items = {}
  for name, info in pairs(skills) do
    local scope_icon = info.scope == "global" and "G" or "P"
    items[string.format("[%s] %s", scope_icon, name)] = { name = name, info = info }
  end

  local display_list = {}
  for display, _ in pairs(items) do
    table.insert(display_list, display)
  end
  table.sort(display_list)

  fzf.fzf_contents("Skills", function(cb)
    for _, display in ipairs(display_list) do
      cb(display)
    end
    cb()
  end, {
    fzf_opts = {
      ["--header"] = "<CR> edit  <C-d> delete  <C-c> copy  <C-v> convert  <C-x> validate",
    },
    actions = {
      ["default"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        vim.cmd("edit " .. vim.fn.fnameescape(item.info.path))
      end,
      ["ctrl-d"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        M.delete(item.name)
      end,
      ["ctrl-c"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        local target = item.info.scope == "project" and "global" or "project"
        M.copy(item.name, target)
      end,
      ["ctrl-v"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        vim.ui.select({ "opencode", "qoder" }, { prompt = "Convert to:" }, function(target)
          if target then
            M.convert(item.name, target)
          end
        end)
      end,
      ["ctrl-x"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        local result = M.validate(item.name)
        if result.valid then
          vim.notify("✅ " .. item.name .. " is valid", vim.log.levels.INFO)
        else
          vim.notify("❌ " .. item.name .. " validation failed:\n" .. table.concat(result.errors, "\n"), vim.log.levels.ERROR)
        end
      end,
    },
  })
end

----------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------
local function setup_commands()
  vim.api.nvim_create_user_command("SkillNew", function(opts)
    local args = vim.split(opts.args or "", " ")
    local name = args[1]
    local scope = args[2] or "project"
    if name then
      vim.ui.input({ prompt = "Description: ", default = "" }, function(desc)
        local content = M.generate_template(name, desc or "")
        local dir = PATHS[scope]() .. "/" .. name
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile(vim.split(content, "\n"), dir .. "/SKILL.md")
        vim.notify("Created skill: " .. name, vim.log.levels.INFO)
        vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/SKILL.md"))
      end)
    else
      M.new({ scope = scope })
    end
  end, {
    desc = "Create new skill: SkillNew [name] [project|global]",
    nargs = "*",
    complete = function()
      return { "project", "global" }
    end,
  })

  vim.api.nvim_create_user_command("SkillList", function()
    M.list()
  end, { desc = "List all skills with fzf-lua picker" })

  vim.api.nvim_create_user_command("SkillEdit", function(opts)
    M.edit(opts.args)
  end, {
    desc = "Edit skill: SkillEdit <name>",
    nargs = 1,
    complete = function()
      local skills = M.list_all()
      local names = {}
      for name, _ in pairs(skills) do
        table.insert(names, name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("SkillDelete", function(opts)
    M.delete(opts.args)
  end, {
    desc = "Delete skill: SkillDelete <name>",
    nargs = 1,
    complete = function()
      local skills = M.list_all()
      local names = {}
      for name, _ in pairs(skills) do
        table.insert(names, name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("SkillCopy", function(opts)
    local args = vim.split(opts.args or "", " ")
    local name = args[1]
    local target = args[2]
    if name and target then
      M.copy(name, target)
    else
      vim.notify("Usage: SkillCopy <name> <project|global>", vim.log.levels.WARN)
    end
  end, {
    desc = "Copy skill to other scope: SkillCopy <name> <project|global>",
    nargs = "+",
    complete = function()
      local skills = M.list_all()
      local names = {}
      for name, _ in pairs(skills) do
        table.insert(names, name)
        table.insert(names, "project")
        table.insert(names, "global")
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("SkillValidate", function(opts)
    local name = opts.args
    if name then
      local result = M.validate(name)
      if result.valid then
        vim.notify("✅ " .. name .. " is valid", vim.log.levels.INFO)
      else
        vim.notify("❌ " .. name .. " validation failed:\n" .. table.concat(result.errors, "\n"), vim.log.levels.ERROR)
      end
    else
      vim.notify("Usage: SkillValidate <name>", vim.log.levels.WARN)
    end
  end, {
    desc = "Validate skill format: SkillValidate <name>",
    nargs = 1,
    complete = function()
      local skills = M.list_all()
      local names = {}
      for name, _ in pairs(skills) do
        table.insert(names, name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("SkillConvert", function(opts)
    local args = vim.split(opts.args or "", " ")
    local name = args[1]
    local target = args[2]
    if name and target then
      M.convert(name, target)
    else
      vim.notify("Usage: SkillConvert <name> <opencode|qoder>", vim.log.levels.WARN)
    end
  end, {
    desc = "Convert skill format: SkillConvert <name> <opencode|qoder>",
    nargs = "+",
    complete = function()
      local skills = M.list_all()
      local items = {}
      for name, _ in pairs(skills) do
        table.insert(items, name)
      end
      table.insert(items, "opencode")
      table.insert(items, "qoder")
      return items
    end,
  })
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------
function M.setup()
  setup_commands()
  return M
end

return M
