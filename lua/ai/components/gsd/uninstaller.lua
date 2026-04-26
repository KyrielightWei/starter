-- lua/ai/components/gsd/uninstaller.lua
-- GSD 卸载逻辑

local M = {}

--- GSD npm 包名
local GSD_PACKAGE = "get-shit-done-cc"

--- GSD 配置目录
local GSD_CONFIG_DIR = vim.fn.expand("~/.claude/gsd")

--- 卸载 GSD
---@param opts table|nil { keep_config: boolean }
---@return boolean, string
function M.uninstall(opts)
  opts = opts or {}

  local Status = require("ai.components.gsd.status")

  -- 检查是否已安装
  if not Status.is_installed() and not opts.force then
    return true, "GSD is not installed"
  end

  local deleted_count = 0
  local errors = {}

  -- 卸载 npm 包（如果全局安装）
  if Status.is_npm_installed() then
    local cmd = "npm uninstall -g " .. GSD_PACKAGE
    local result = vim.fn.system(cmd)

    if vim.v.shell_error == 0 then
      deleted_count = deleted_count + 1
    else
      table.insert(errors, "npm uninstall failed: " .. result)
    end
  end

  -- 删除配置目录（除非 keep_config）
  if not opts.keep_config then
    if vim.fn.isdirectory(GSD_CONFIG_DIR) == 1 then
      local ok = vim.fn.delete(GSD_CONFIG_DIR, "rf")
      if ok == 0 then
        deleted_count = deleted_count + 1
      else
        table.insert(errors, "Failed to delete: " .. GSD_CONFIG_DIR)
      end
    end

    -- 删除 GSD 相关的 commands/agents/hooks 目录
    local gsd_dirs = {
      vim.fn.expand("~/.claude/commands/gsd"),
      vim.fn.expand("~/.claude/agents/gsd"),
      vim.fn.expand("~/.claude/hooks/gsd"),
    }

    for _, dir in ipairs(gsd_dirs) do
      if vim.fn.isdirectory(dir) == 1 then
        vim.fn.delete(dir, "rf")
        deleted_count = deleted_count + 1
      end
    end
  end

  if #errors > 0 then
    return false, table.concat(errors, "\n")
  end

  return true, string.format("GSD uninstalled. Deleted %d items", deleted_count)
end

--- 获取将被删除的内容预览
---@return string[]
function M.get_cleanup_preview()
  local preview = {}

  local Status = require("ai.components.gsd.status")

  if Status.is_npm_installed() then
    table.insert(preview, "  npm package: " .. GSD_PACKAGE)
  end

  if vim.fn.isdirectory(GSD_CONFIG_DIR) == 1 then
    table.insert(preview, "  config dir: " .. GSD_CONFIG_DIR)
  end

  local gsd_dirs = {
    vim.fn.expand("~/.claude/commands/gsd"),
    vim.fn.expand("~/.claude/agents/gsd"),
    vim.fn.expand("~/.claude/hooks/gsd"),
  }

  for _, dir in ipairs(gsd_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      table.insert(preview, "  " .. dir)
    end
  end

  return preview
end

return M
