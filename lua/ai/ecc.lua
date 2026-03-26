-- lua/ai/ecc.lua
-- ECC (Everything Claude Code) 框架状态检测

local M = {}

-- ECC 安装状态文件路径
local ECC_STATE_PATH = "~/.claude/ecc/install-state.json"

--- 获取 ECC 安装状态
--- @return table|nil 安装状态信息，未安装时返回 nil
function M.get_status()
  local state_path = vim.fn.expand(ECC_STATE_PATH)
  if vim.fn.filereadable(state_path) == 0 then
    return nil
  end

  local ok, content = pcall(vim.fn.readfile, state_path)
  if not ok then
    return nil
  end

  local json_str = table.concat(content, "\n")
  local ok2, state = pcall(vim.json.decode, json_str)
  if not ok2 then
    return nil
  end

  return {
    installed_at = state.installedAt,
    modules = (state.resolution or {}).selectedModules or {},
    schema_version = state.schemaVersion,
    repo_version = (state.source or {}).repoVersion,
  }
end

--- 检测 ECC 是否已安装
--- @return boolean
function M.is_installed()
  local state_path = vim.fn.expand(ECC_STATE_PATH)
  return vim.fn.filereadable(state_path) == 1
end

--- 获取安装命令提示
--- @return string
function M.install_hint()
  return "npx -y @anthropic-ai/claude-code-ecc@latest install"
end

--- 获取 ECC 状态路径
--- @return string
function M.state_path()
  return vim.fn.expand(ECC_STATE_PATH)
end

--- 格式化 ECC 状态通知行
--- @param ecc table|nil ECC 状态（来自 get_status()）
--- @return string[] 通知行列表
function M.format_notification(ecc)
  local lines = {}

  if ecc then
    table.insert(lines, "🔧 ECC Framework:")
    if ecc.repo_version then
      table.insert(lines, "  版本: " .. ecc.repo_version)
    end
    if #ecc.modules > 0 then
      table.insert(lines, "  模块: " .. table.concat(ecc.modules, ", "))
    end
  else
    table.insert(lines, "⚠️  ECC 未安装")
    table.insert(lines, "  安装: " .. M.install_hint())
  end

  return lines
end

return M
