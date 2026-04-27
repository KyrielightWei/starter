-- lua/ai/components/gsd/status.lua
-- GSD 状态检查模块

local M = {}

--- GSD npm 包名
local GSD_PACKAGE = "get-shit-done-cc"

--- GSD 配置目录
local GSD_CONFIG_DIR = vim.fn.expand("~/.claude/gsd")

--- GSD 状态文件路径（尝试多个可能位置）
local GSD_STATE_PATHS = {
  vim.fn.expand("~/.claude/gsd/install-state.json"),
  vim.fn.expand("~/.config/gsd/state.json"),
}

--- 检测 GSD 是否已安装
--- GSD 通过 npx 按需运行，不需要本地安装
---@return boolean
function M.is_installed()
  -- 核心检查: npx 可用即可运行 GSD
  if vim.fn.executable("npx") == 1 then
    return true
  end

  -- 方式 1: 检查 npm 全局安装
  if M.is_npm_installed() then
    return true
  end

  -- 方式 2: 检查配置目录
  if vim.fn.isdirectory(GSD_CONFIG_DIR) == 1 then
    return true
  end

  -- 方式 3: 检查状态文件
  for _, path in ipairs(GSD_STATE_PATHS) do
    if vim.fn.filereadable(path) == 1 then
      return true
    end
  end

  return false
end

--- 检查 npm 全局安装状态
---@return boolean
function M.is_npm_installed()
  if vim.fn.executable("npm") ~= 1 then
    return false
  end

  local result = vim.fn.system("npm list -g " .. vim.fn.shellescape(GSD_PACKAGE) .. " --depth=0 2>&1")

  -- 检查输出是否包含包名
  return result:match(GSD_PACKAGE) ~= nil and not result:match("empty")
end

--- 获取 npm 安装版本
---@return string|nil
function M.get_npm_version()
  if not M.is_npm_installed() then
    return nil
  end

  local result = vim.fn.system("npm list -g " .. GSD_PACKAGE .. " --depth=0 --json 2>&1")

  if vim.v.shell_error == 0 then
    local ok, data = pcall(vim.json.decode, result)
    if ok and data and data.dependencies and data.dependencies[GSD_PACKAGE] then
      return data.dependencies[GSD_PACKAGE].version
    end
  end

  return nil
end

--- 获取 GSD 安装状态
---@return table|nil
function M.get_status()
  if not M.is_installed() then
    return nil
  end

  local npm_version = M.get_npm_version()

  return {
    installed = true,
    npm_installed = M.is_npm_installed(),
    npm_version = npm_version,
    config_dir = GSD_CONFIG_DIR,
    package_name = GSD_PACKAGE,
  }
end

--- 获取配置目录
---@return string
function M.get_config_dir()
  return GSD_CONFIG_DIR
end

--- 获取包名
---@return string
function M.get_package_name()
  return GSD_PACKAGE
end

--- 获取 GSD 目录下的模块数量
---@return table
function M.get_module_counts()
  local counts = {
    commands = 0,
    agents = 0,
    hooks = 0,
  }

  local dirs = {
    commands = vim.fn.expand("~/.claude/commands/gsd"),
    agents = vim.fn.expand("~/.claude/agents/gsd"),
    hooks = vim.fn.expand("~/.claude/hooks/gsd"),
  }

  for name, dir in pairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.readdir(dir)
      counts[name] = #files
    end
  end

  return counts
end

return M
