-- lua/ai/skill_studio/init.lua
-- Skill/MCP Authoring Studio for Claude Code and OpenCode

local M = {}

local Backup = require("ai.skill_studio.backup")
local Validator = require("ai.skill_studio.validator")
local Converter = require("ai.skill_studio.converter")
local StudioUI = require("ai.skill_studio.ui")
local Reviewer = require("ai.skill_studio.reviewer")

local _setup_done = false

----------------------------------------------------------------------
-- Configuration
----------------------------------------------------------------------
local config = {
  -- Backup directory for storing created skills/MCPs
  backup_dir = vim.fn.stdpath("data") .. "/skill_studio/backups",

  -- Target directories
  targets = {
    claude_global = vim.fn.expand("~/.claude/plugins/skill_studio"),
    claude_project = function()
      return vim.fn.getcwd() .. "/.claude/plugins/skill_studio"
    end,
    opencode_global = vim.fn.expand("~/.config/opencode"),
    opencode_project = function()
      return vim.fn.getcwd() .. "/.opencode"
    end,
  },

  -- Templates for new skills
  templates = {
    skill = {
      claude = {
        frontmatter = {
          name = "skill-name",
          description = "When this skill should be used",
          version = "1.0.0",
        },
        body = [[
# Skill Name

Brief description of what this skill does.

## When This Skill Applies

This skill activates when:
- User mentions "keyword1" or "keyword2"
- Task involves specific domain

## Instructions

1. Step 1
2. Step 2
3. Step 3

## Examples

**Example 1:**
Input: ...
Output: ...
]],
      },
    },
    command = {
      claude = {
        frontmatter = {
          description = "Command description",
          argument_hint = "<required> [optional]",
          allowed_tools = { "Read", "Write", "Bash" },
        },
        body = [[
# Command Name

## Arguments

$ARGUMENTS

## Instructions

1. Parse the arguments
2. Perform the action
3. Report results
]],
      },
    },
    mcp = {
      claude = {
        stdio = {
          server_name = {
            type = "stdio",
            command = "npx",
            args = { "-y", "@modelcontextprotocol/server-example" },
            env = {
              API_KEY = "${YOUR_API_KEY}",
            },
          },
        },
        http = {
          server_name = {
            type = "http",
            url = "https://mcp.example.com/api",
            headers = {
              Authorization = "Bearer ${YOUR_TOKEN}",
            },
          },
        },
      },
    },
  },
}

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------
function M.setup(opts)
  if _setup_done then
    return M
  end
  _setup_done = true

  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)

  Backup.setup(config.backup_dir)
  StudioUI.setup(config)
  M.register_commands()

  return M
end

----------------------------------------------------------------------
-- Create New Skill/Command/MCP
----------------------------------------------------------------------
function M.create(opts)
  opts = opts or {}
  local item_type = opts.type or "skill" -- skill, command, mcp
  local target = opts.target or "claude" -- claude, opencode
  local level = opts.level or "project" -- project, global

  -- Show creation UI
  StudioUI.open_creator({
    type = item_type,
    target = target,
    level = level,
    templates = config.templates,
    on_save = function(data)
      -- Validate
      local validation = Validator.validate(data)
      if not validation.valid then
        vim.notify("Validation failed:\n" .. table.concat(validation.errors, "\n"), vim.log.levels.ERROR)
        return false
      end

      -- Save to backup
      local backup_id = Backup.save(data)

      -- Deploy to target
      local target_path = M.get_target_path(target, level)
      M.deploy(data, target_path, target)

      vim.notify(string.format("✅ Created %s (backup: %s)", item_type, backup_id), vim.log.levels.INFO)
      return true
    end,
  })
end

----------------------------------------------------------------------
-- Edit Existing Item
----------------------------------------------------------------------
function M.edit(backup_id)
  local item = Backup.load(backup_id)
  if not item then
    vim.notify("Backup not found: " .. backup_id, vim.log.levels.ERROR)
    return
  end

  StudioUI.open_editor({
    item = item,
    on_save = function(data)
      -- Validate
      local validation = Validator.validate(data)
      if not validation.valid then
        vim.notify("Validation failed:\n" .. table.concat(validation.errors, "\n"), vim.log.levels.ERROR)
        return false
      end

      -- Update backup
      Backup.update(backup_id, data)

      -- Re-deploy
      local target_path = M.get_target_path(item.target, item.level)
      M.deploy(data, target_path, item.target)

      vim.notify("✅ Updated: " .. backup_id, vim.log.levels.INFO)
      return true
    end,
  })
end

----------------------------------------------------------------------
-- List Backups
----------------------------------------------------------------------
function M.list_backups()
  local backups = Backup.list()
  StudioUI.show_backup_list(backups, {
    on_select = function(backup_id)
      M.edit(backup_id)
    end,
    on_delete = function(backup_id)
      Backup.delete(backup_id)
      vim.notify("Deleted: " .. backup_id, vim.log.levels.INFO)
    end,
    on_convert = function(backup_id, new_target)
      local item = Backup.load(backup_id)
      if not item then
        return
      end
      local converted = Converter.convert(item, new_target)
      if converted then
        M.create({
          type = item.type,
          target = new_target,
          level = item.level,
        })
      end
    end,
    on_change_level = function(backup_id, new_level)
      local item = Backup.load(backup_id)
      if not item then
        return
      end
      item.level = new_level
      Backup.update(backup_id, item)
      local target_path = M.get_target_path(item.target, new_level)
      M.deploy(item, target_path, item.target)
      vim.notify(string.format("Changed to %s level: %s", new_level, backup_id), vim.log.levels.INFO)
    end,
  })
end

----------------------------------------------------------------------
-- Review Item
----------------------------------------------------------------------
function M.review(backup_id)
  local item = Backup.load(backup_id)
  if not item then
    vim.notify("Backup not found: " .. backup_id, vim.log.levels.ERROR)
    return
  end

  local review_result = Reviewer.review(item)
  StudioUI.show_review(review_result)
end

----------------------------------------------------------------------
-- Convert Format
----------------------------------------------------------------------
function M.convert(backup_id, new_target)
  local item = Backup.load(backup_id)
  if not item then
    vim.notify("Backup not found: " .. backup_id, vim.log.levels.ERROR)
    return
  end

  local converted = Converter.convert(item, new_target)
  if converted then
    -- Save as new backup
    converted.target = new_target
    local new_id = Backup.save(converted)

    vim.notify(string.format("Converted to %s format: %s", new_target, new_id), vim.log.levels.INFO)
    return new_id
  end
end

----------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------
function M.get_target_path(target, level)
  local path_key = target .. "_" .. level
  local path = config.targets[path_key]
  if type(path) == "function" then
    return path()
  end
  return path
end

function M.deploy(data, target_path, target)
  -- Ensure directory exists
  vim.fn.mkdir(target_path, "p")

  if data.type == "skill" then
    if target == "claude" then
      local skill_dir = target_path .. "/skills/" .. data.frontmatter.name
      vim.fn.mkdir(skill_dir, "p")
      local content = M.format_skill_md(data)
      vim.fn.writefile(vim.split(content, "\n"), skill_dir .. "/SKILL.md")
    elseif target == "opencode" then
      -- OpenCode uses agents in JSON config
      local config_path = target_path .. "/oh-my-opencode.json"
      M.update_opencode_agent(config_path, data)
    end
  elseif data.type == "command" then
    if target == "claude" then
      local cmd_dir = target_path .. "/commands"
      vim.fn.mkdir(cmd_dir, "p")
      local content = M.format_command_md(data)
      vim.fn.writefile(vim.split(content, "\n"), cmd_dir .. "/" .. data.name .. ".md")
    end
  elseif data.type == "mcp" then
    if target == "claude" then
      local content = vim.json.encode(data.config)
      vim.fn.writefile(vim.split(content, "\n"), target_path .. "/.mcp.json")
    elseif target == "opencode" then
      -- OpenCode doesn't have MCP directly, but we can create provider config
      local config_path = target_path .. "/opencode.json"
      M.update_opencode_provider(config_path, data)
    end
  end
end

function M.format_skill_md(data)
  local lines = { "---" }
  for key, value in pairs(data.frontmatter) do
    if type(value) == "table" then
      lines[#lines + 1] = key .. ":"
      for _, v in ipairs(value) do
        lines[#lines + 1] = "  - " .. v
      end
    else
      lines[#lines + 1] = string.format("%s: %s", key, value)
    end
  end
  lines[#lines + 1] = "---"
  lines[#lines + 1] = ""
  lines[#lines + 1] = data.body
  return table.concat(lines, "\n")
end

function M.format_command_md(data)
  local lines = { "---" }
  for key, value in pairs(data.frontmatter) do
    if key == "allowed_tools" then
      lines[#lines + 1] = "allowed-tools: [" .. table.concat(value, ", ") .. "]"
    elseif key == "argument_hint" then
      lines[#lines + 1] = "argument-hint: " .. value
    else
      lines[#lines + 1] = string.format("%s: %s", key, value)
    end
  end
  lines[#lines + 1] = "---"
  lines[#lines + 1] = ""
  lines[#lines + 1] = data.body
  return table.concat(lines, "\n")
end

function M.update_opencode_agent(config_path, data)
  -- Read existing config or create new
  local config = {}
  if vim.fn.filereadable(config_path) == 1 then
    local content = table.concat(vim.fn.readfile(config_path), "\n")
    config = vim.json.decode(content) or {}
  end

  -- Add/update agent
  config.agents = config.agents or {}
  config.agents[data.frontmatter.name] = {
    model = data.model or "default",
    prompt = data.body,
  }

  -- Write back
  local content = vim.json.encode(config)
  vim.fn.writefile(vim.split(content, "\n"), config_path)
end

function M.update_opencode_provider(config_path, data)
  -- Similar to agent update but for provider configuration
  local config = {}
  if vim.fn.filereadable(config_path) == 1 then
    local content = table.concat(vim.fn.readfile(config_path), "\n")
    config = vim.json.decode(content) or {}
  end

  -- Add/update provider
  config.provider = config.provider or {}
  for name, conf in pairs(data.config) do
    config.provider[name] = conf
  end

  local content = vim.json.encode(config)
  vim.fn.writefile(vim.split(content, "\n"), config_path)
end

----------------------------------------------------------------------
-- Commands Registration
----------------------------------------------------------------------
function M.register_commands()
  vim.api.nvim_create_user_command("SkillNew", function(opts)
    local args = vim.split(opts.args or "", " ")
    local item_type = args[1] or "skill"
    local target = args[2] or "claude"
    local level = args[3] or "project"
    M.create({ type = item_type, target = target, level = level })
  end, {
    desc = "Create new skill/command/mcp: SkillNew [skill|command|mcp] [claude|opencode] [project|global]",
    nargs = "*",
    complete = function()
      return {
        "skill claude project", "skill claude global", "skill opencode project", "skill opencode global",
        "command claude project", "command claude global",
        "mcp claude project", "mcp claude global", "mcp opencode project", "mcp opencode global",
      }
    end,
  })

  vim.api.nvim_create_user_command("SkillList", function()
    M.list_backups()
  end, { desc = "List all saved items" })

  vim.api.nvim_create_user_command("SkillEdit", function(opts)
    M.edit(opts.args)
  end, {
    desc = "Edit saved item",
    nargs = 1,
    complete = function()
      return vim.tbl_map(function(b) return b.id end, Backup.list())
    end,
  })

  vim.api.nvim_create_user_command("SkillDel", function(opts)
    Backup.delete(opts.args)
    vim.notify("Deleted: " .. opts.args, vim.log.levels.INFO)
  end, {
    desc = "Delete saved item",
    nargs = 1,
    complete = function()
      return vim.tbl_map(function(b) return b.id end, Backup.list())
    end,
  })

  vim.api.nvim_create_user_command("SkillReview", function(opts)
    M.review(opts.args)
  end, {
    desc = "Review saved item",
    nargs = 1,
    complete = function()
      return vim.tbl_map(function(b) return b.id end, Backup.list())
    end,
  })

  vim.api.nvim_create_user_command("SkillConvert", function(opts)
    local args = vim.split(opts.args or "", " ")
    if #args >= 2 then
      M.convert(args[1], args[2])
    else
      vim.notify("Usage: SkillConvert <id> <claude|opencode>", vim.log.levels.WARN)
    end
  end, {
    desc = "Convert item format: SkillConvert <id> <target>",
    nargs = "+",
    complete = function()
      local items = vim.tbl_map(function(b) return b.id end, Backup.list())
      vim.list_extend(items, { "claude", "opencode" })
      return items
    end,
  })
end

return M