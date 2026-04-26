-- lua/ai/components/ecc/uninstaller.lua
-- ECC 卸载逻辑

local M = {}

--- 需要删除的目录列表
--- 仅删除 ECC 特定的子目录，保留用户自己的 commands/agents/skills/hooks
local CLEANUP_DIRS = {
  vim.fn.expand("~/.claude/ecc"),
  vim.fn.expand("~/.claude/commands/ecc"),
  vim.fn.expand("~/.claude/agents/ecc"),
  vim.fn.expand("~/.claude/skills/ecc"),
  vim.fn.expand("~/.claude/hooks/ecc"),
}

--- 需要删除的文件列表
local CLEANUP_FILES = {
  vim.fn.expand("~/.claude/ecc/install-state.json"),
}

--- 卸载 ECC
---@param opts table|nil 选项 { force: boolean, keep_config: boolean }
---@return boolean, string success, message
function M.uninstall(opts)
  opts = opts or {}

  local Status = require("ai.components.ecc.status")

  -- 检查是否已安装
  if not Status.is_installed() and not opts.force then
    return true, "ECC is not installed"
  end

  -- 如果 keep_config 为 true，只删除 ecc 目录，保留其他模块
  if opts.keep_config then
    local ecc_dir = Status.install_dir()
    if vim.fn.isdirectory(ecc_dir) == 1 then
      vim.fn.delete(ecc_dir, "rf")
    end

    return true, "ECC state removed (config files preserved)"
  end

  -- 完整卸载
  local deleted_dirs = 0
  local deleted_files = 0
  local errors = {}

  -- 删除目录
  for _, dir in ipairs(CLEANUP_DIRS) do
    if vim.fn.isdirectory(dir) == 1 then
      local ok = vim.fn.delete(dir, "rf")
      if ok == 0 then
        deleted_dirs = deleted_dirs + 1
      else
        table.insert(errors, string.format("Failed to delete: %s", dir))
      end
    end
  end

  -- 删除文件
  for _, file in ipairs(CLEANUP_FILES) do
    if vim.fn.filereadable(file) == 1 then
      local ok = vim.fn.delete(file)
      if ok == 0 then
        deleted_files = deleted_files + 1
      else
        table.insert(errors, string.format("Failed to delete: %s", file))
      end
    end
  end

  -- 清理空目录（如果父目录为空）
  M.cleanup_empty_parents()

  -- 返回结果
  if #errors > 0 then
    return false, table.concat(errors, "\n")
  end

  return true, string.format("ECC uninstalled. Deleted %d directories, %d files", deleted_dirs, deleted_files)
end

--- 清理空的父目录
local function cleanup_empty_parents()
  local parent_dirs = {
    vim.fn.expand("~/.claude"),
  }

  for _, dir in ipairs(parent_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.readdir(dir)
      -- 如果只有空目录或没有文件，考虑清理
      -- 但 ~/.claude 可能还有其他用途，所以不删除
    end
  end
end

--- 获取将被删除的目录列表（预览）
---@return string[]
function M.get_cleanup_preview()
  local preview = {}

  for _, dir in ipairs(CLEANUP_DIRS) do
    if vim.fn.isdirectory(dir) == 1 then
      local count = #vim.fn.readdir(dir)
      table.insert(preview, string.format("  %s (%d items)", dir, count))
    end
  end

  for _, file in ipairs(CLEANUP_FILES) do
    if vim.fn.filereadable(file) == 1 then
      table.insert(preview, string.format("  %s (file)", file))
    end
  end

  return preview
end

return M
