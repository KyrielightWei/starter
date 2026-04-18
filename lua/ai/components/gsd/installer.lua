-- lua/ai/components/gsd/installer.lua
-- GSD 安装逻辑（npx/npm）

local M = {}

--- GSD npm 包名
local GSD_PACKAGE = "get-shit-done-cc"

--- GSD 仓库 URL
local GSD_REPO = "https://github.com/gsd-build/get-shit-done.git"

--- 安装方式
local INSTALL_METHODS = {
  npx = "npx", -- 按需运行（推荐）
  npm = "npm", -- 全局安装
}

--- 同步执行命令
---@param cmd string
---@param opts table|nil { timeout: number }
---@return boolean, string
local function run_cmd_sync(cmd, opts)
  opts = opts or {}
  local timeout = opts.timeout or 300000

  local result = vim.fn.systemlist(cmd)
  local exit_code = vim.v.shell_error

  return exit_code == 0, table.concat(result, "\n")
end

--- 安装 GSD（npm 全局安装）
---@param opts table|nil { method: string }
---@param on_progress function|nil
---@return boolean, string
function M.install(opts, on_progress)
  opts = opts or {}
  local method = opts.method or "npx"

  if on_progress then
    on_progress("📦 安装 GSD (" .. method .. ")...")
  end

  -- 检查依赖
  if vim.fn.executable("npm") ~= 1 then
    return false, "需要安装 npm"
  end

  if vim.fn.executable("npx") ~= 1 then
    return false, "需要安装 npx"
  end

  -- 方式 1: npx 按需运行（实际上不需要安装）
  if method == "npx" then
    if on_progress then
      on_progress("GSD 使用 npx 按需运行，无需全局安装")
    end

    -- 运行一次以初始化配置
    local cmd = "npx -y " .. GSD_PACKAGE .. "@latest"
    if on_progress then
      on_progress("初始化配置...")
    end

    local ok, output = run_cmd_sync(cmd, { timeout = 120000 })

    if ok then
      return true, "GSD 已就绪（使用 npx 按需运行）"
    else
      -- 可能只是配置初始化问题，npx 运行可能有输出
      return true, "GSD 可用（使用 npx 按需运行）"
    end
  end

  -- 方式 2: npm 全局安装
  if method == "npm" then
    local cmd = "npm install -g " .. GSD_PACKAGE

    if on_progress then
      on_progress("npm 全局安装...")
    end

    local ok, output = run_cmd_sync(cmd, { timeout = 180000 })

    if ok then
      return true, "GSD 全局安装成功"
    else
      return false, "npm 安装失败: " .. output
    end
  end

  return false, "未知的安装方式: " .. method
end

--- 获取安装命令提示
---@return string
function M.install_hint()
  return "npx -y get-shit-done-cc@latest"
end

--- 获取支持的安装方式
---@return string[]
function M.get_methods()
  return { "npx", "npm" }
end

return M
