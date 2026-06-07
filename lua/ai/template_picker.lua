-- lua/ai/template_picker.lua
-- Template Version Picker UI - FZF-lua integration

local M = {}

----------------------------------------------------------------------
-- Private: Get FZF-lua module with error handling
----------------------------------------------------------------------
local function get_fzf()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not found. Please install fzf-lua plugin.", vim.log.levels.ERROR)
    return nil
  end
  return fzf
end

----------------------------------------------------------------------
-- open(tool, opts): 打开模版版本选择器
-- @param tool string: 工具名称 (opencode, claude_code)
-- @param opts table|nil: 可选配置 { on_select = function }
----------------------------------------------------------------------
function M.open(tool, opts)
  opts = opts or {}
  local fzf = get_fzf()
  if not fzf then
    return
  end

  local TV = require("ai.template_version")
  local State = require("ai.state")

  -- Check if migration needed
  if TV.check_migration_needed(tool) then
    local ok, result = TV.migrate_legacy(tool)
    if ok then
      vim.notify("Legacy template migrated: " .. result, vim.log.levels.INFO)
    end
  end

  local versions = TV.list(tool)

  if #versions == 0 then
    vim.notify(
      "No templates found for " .. tool .. ". Create one with :AITemplateCreate " .. tool .. " <name>",
      vim.log.levels.WARN
    )
    return
  end

  local current = State.get_template_version(tool)

  fzf.fzf_exec(function(cb)
    for _, v in ipairs(versions) do
      local prefix = v == current and "* " or "  "
      cb(prefix .. v)
    end
    cb()
  end, {
    prompt = tool .. " templates> ",
    preview = function(selected)
      if not selected then
        return
      end
      local version = selected:gsub("^%*? ", "")
      local path = TV.get_template_path(tool, version)
      if vim.fn.filereadable(path) == 1 then
        return vim.fn.readfile(path)
      end
      return { "Template not found: " .. path }
    end,
    actions = {
      -- Enter: Select version
      ["default"] = function(selected)
        if not selected then
          return
        end
        local version = selected[1]:gsub("^%*? ", "")
        State.set_template_version(tool, version)
        vim.notify("Selected template: " .. version, vim.log.levels.INFO)
        if opts.on_select then
          opts.on_select(version)
        end
      end,
      -- Ctrl-E: Edit template
      ["ctrl-e"] = function(selected)
        if not selected then
          return
        end
        local version = selected[1]:gsub("^%*? ", "")
        local path = TV.get_template_path(tool, version)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
      end,
      -- Ctrl-D: Delete version
      ["ctrl-d"] = function(selected)
        if not selected then
          return
        end
        local version = selected[1]:gsub("^%*? ", "")
        if version == "default" then
          vim.notify("Cannot delete default template", vim.log.levels.ERROR)
          return
        end
        local confirm = vim.fn.confirm("Delete template '" .. version .. "'?", "&Yes\n&No", 2)
        if confirm == 1 then
          local ok, result = TV.delete(tool, version)
          if ok then
            vim.notify(result, vim.log.levels.INFO)
            -- Refresh picker
            M.open(tool, opts)
          else
            vim.notify(result, vim.log.levels.ERROR)
          end
        end
      end,
      -- Ctrl-N: Create new version
      ["ctrl-n"] = function()
        local name = vim.fn.input("New template name: ")
        if name and name ~= "" then
          local ok, result = TV.create(tool, name)
          if ok then
            vim.notify("Created template: " .. name, vim.log.levels.INFO)
            -- Refresh picker
            M.open(tool, opts)
          else
            vim.notify(result, vim.log.levels.ERROR)
          end
        end
      end,
      -- Ctrl-Y: Copy version
      ["ctrl-y"] = function(selected)
        if not selected then
          return
        end
        local source = selected[1]:gsub("^%*? ", "")
        local target = vim.fn.input("Copy '" .. source .. "' to: ")
        if target and target ~= "" then
          local ok, result = TV.copy(tool, source, target)
          if ok then
            vim.notify("Copied to: " .. target, vim.log.levels.INFO)
            -- Refresh picker
            M.open(tool, opts)
          else
            vim.notify(result, vim.log.levels.ERROR)
          end
        end
      end,
    },
  })
end

----------------------------------------------------------------------
-- quick_select(tool): 快速选择并生成配置
-- @param tool string: 工具名称
----------------------------------------------------------------------
function M.quick_select(tool)
  M.open(tool, {
    on_select = function(version)
      if tool == "opencode" then
        local OpenCode = require("ai.opencode")
        OpenCode.write_config(version)
      elseif tool == "claude_code" then
        local ClaudeCode = require("ai.claude_code")
        ClaudeCode.write_config(version)
      end
    end,
  })
end

return M
