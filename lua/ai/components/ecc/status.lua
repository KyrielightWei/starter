-- lua/ai/components/ecc/status.lua
-- ECC 状态检查模块

local M = {}

--- ECC 安装状态文件路径
local ECC_STATE_PATH = vim.fn.expand("~/.claude/ecc/install-state.json")

--- ECC 源仓库
local ECC_REPO = "https://github.com/affaan-m/everything-claude-code.git"

--- ECC 安装目录
local ECC_INSTALL_DIR = vim.fn.expand("~/.claude/ecc")

--- 检测 ECC 是否已安装
---@return boolean
function M.is_installed()
  local state_path = ECC_STATE_PATH
  return vim.fn.filereadable(state_path) == 1
end

--- 获取 ECC 安装状态
---@return table|nil { installed_at, modules, schema_version, repo_version }
function M.get_status()
  if not M.is_installed() then
    return nil
  end

  local ok, content = pcall(vim.fn.readfile, ECC_STATE_PATH)
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
    state_path = ECC_STATE_PATH,
    install_dir = ECC_INSTALL_DIR,
  }
end

--- 获取 ECC 目录下的模块数量
---@return table { commands, agents, skills, rules, hooks }
function M.get_module_counts()
  local counts = {
    commands = 0,
    agents = 0,
    skills = 0,
    rules = 0,
    hooks = 0,
  }

  local dirs = {
    commands = vim.fn.expand("~/.claude/commands"),
    agents = vim.fn.expand("~/.claude/agents"),
    skills = vim.fn.expand("~/.claude/skills"),
    rules = vim.fn.expand("~/.claude/rules"),
    hooks = vim.fn.expand("~/.claude/hooks"),
  }

  for name, dir in pairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.readdir(dir)
      counts[name] = #files
    end
  end

  return counts
end

--- 格式化 ECC 状态通知行
---@param ecc table|nil ECC 状态（来自 get_status()）
---@return string[] lines
function M.format_notification(ecc)
  local lines = {}

  if ecc then
    table.insert(lines, "🔧 ECC Framework:")
    if ecc.repo_version then
      table.insert(lines, "  版本: " .. ecc.repo_version)
    end
    if ecc.installed_at then
      table.insert(lines, "  安装时间: " .. ecc.installed_at)
    end
    if #ecc.modules > 0 then
      table.insert(lines, "  模块: " .. table.concat(ecc.modules, ", "))
    end
  else
    table.insert(lines, "⚠️  ECC 未安装")
    table.insert(lines, "  安装: :AIComponents 然后选择 ECC 安装")
  end

  return lines
end

--- 检查 ECC 安装目录是否存在
---@return boolean
function M.install_dir_exists()
  return vim.fn.isdirectory(ECC_INSTALL_DIR) == 1
end

--- 获取状态文件路径
---@return string
function M.state_path()
  return ECC_STATE_PATH
end

--- 获取安装目录路径
---@return string
function M.install_dir()
  return ECC_INSTALL_DIR
end

--- 获取仓库 URL
---@return string
function M.repo_url()
  return ECC_REPO
end

return M
