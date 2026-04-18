-- lua/ai/components/ecc/installer.lua
-- ECC 安装逻辑

local M = {}

--- ECC 源仓库
local ECC_REPO = "https://github.com/affaan-m/everything-claude-code.git"

--- 临时克隆目录
local ECC_TEMP_DIR = "/tmp/ecc-install"

--- 有效的安装目标和 profile
local VALID_TARGETS = { claude = true, opencode = true }
local VALID_PROFILES = { core = true, developer = true, security = true, research = true, full = true }

--- 同步执行命令
---@param cmd string 命令
---@param opts table|nil 选项 { timeout: number }
---@return boolean, string success, output
local function run_cmd_sync(cmd, opts)
  opts = opts or {}
  local timeout = opts.timeout or 300000

  local result = vim.fn.systemlist(cmd)
  local exit_code = vim.v.shell_error

  return exit_code == 0, table.concat(result, "\n")
end

--- 克隆 ECC 仓库
---@param on_progress function|nil 进度回调
---@return boolean, string success, message
local function clone_repo(on_progress)
  if on_progress then
    on_progress("📥 克隆 ECC 仓库...")
  end

  -- 清理旧的临时目录
  if vim.fn.isdirectory(ECC_TEMP_DIR) == 1 then
    vim.fn.delete(ECC_TEMP_DIR, "rf")
  end

  local cmd = string.format("git clone %s %s --depth=1", ECC_REPO, ECC_TEMP_DIR)
  local ok, output = run_cmd_sync(cmd, { timeout = 120000 })

  if not ok then
    return false, "克隆失败: " .. output
  end

  return true, "克隆成功"
end

--- 安装 npm 依赖
---@param on_progress function|nil 进度回调
---@return boolean, string
local function install_deps(on_progress)
  if on_progress then
    on_progress("📦 安装依赖...")
  end

  local cmd = "npm install --no-audit --no-fund --loglevel=error"
  local ok, output = run_cmd_sync(cmd, { timeout = 180000 })

  if not ok then
    return false, "依赖安装失败: " .. output
  end

  return true, "依赖安装成功"
end

--- 运行 ECC 安装脚本
---@param target string "claude" 或 "opencode"
---@param profile string 安装 profile
---@param on_progress function|nil 进度回调
---@return boolean, string
local function run_install(target, profile, on_progress)
  -- 参数验证（防止注入）
  if not VALID_TARGETS[target] then
    return false, "无效的安装目标: " .. tostring(target)
  end
  if not VALID_PROFILES[profile] then
    return false, "无效的安装 profile: " .. tostring(profile)
  end

  if on_progress then
    on_progress(string.format("🔧 安装 ECC 到 %s (profile: %s)...", target, profile))
  end

  local cmd = string.format("node scripts/install-apply.js --target %s --profile %s", target, profile)
  local ok, output = run_cmd_sync(cmd, { timeout = 120000 })

  if not ok then
    return false, "安装失败: " .. output
  end

  return true, "安装成功"
end

--- 安装 ECC
---@param opts table|nil { target: string, profile: string, force: boolean }
---@param on_progress function|nil 进度回调 (message: string) -> void
---@return boolean, string success, message
function M.install(opts, on_progress)
  opts = opts or {}
  local target = opts.target or "claude"
  local profile = opts.profile or "developer"
  local force = opts.force or false

  local Status = require("ai.components.ecc.status")

  -- 检查是否已安装
  if not force and Status.is_installed() then
    return true, "ECC 已安装"
  end

  -- 检查必要工具
  if vim.fn.executable("git") ~= 1 then
    return false, "需要安装 git"
  end
  if vim.fn.executable("node") ~= 1 then
    return false, "需要安装 Node.js"
  end
  if vim.fn.executable("npm") ~= 1 then
    return false, "需要安装 npm"
  end

  -- 清理函数
  local function cleanup()
    if vim.fn.isdirectory(ECC_TEMP_DIR) == 1 then
      vim.fn.delete(ECC_TEMP_DIR, "rf")
    end
  end

  -- 使用 xpcall 确保错误恢复
  local ok, result = xpcall(function()
    -- 切换到临时目录
    local original_dir = vim.fn.getcwd()

    -- 克隆仓库
    local ok2, msg = clone_repo(on_progress)
    if not ok2 then
      error(msg)
    end

    -- 切换到临时目录
    vim.fn.chdir(ECC_TEMP_DIR)

    -- 安装依赖
    ok2, msg = install_deps(on_progress)
    if not ok2 then
      error(msg)
    end

    -- 运行安装脚本
    ok2, msg = run_install(target, profile, on_progress)
    if not ok2 then
      error(msg)
    end

    -- 恢复目录
    vim.fn.chdir(original_dir)

    return "✅ ECC 安装成功！"
  end, function(err)
    return tostring(err)
  end)

  -- 确保清理
  cleanup()

  if ok then
    return true, result
  else
    return false, result
  end
end

--- 获取安装命令提示
---@return string
function M.install_hint()
  return "git clone "
    .. ECC_REPO
    .. " /tmp/ecc --depth=1 && cd /tmp/ecc && npm install && node scripts/install-apply.js --profile developer"
end

--- 获取支持的安装目标
---@return string[]
function M.get_targets()
  return { "claude", "opencode" }
end

--- 获取支持的安装 profile
---@return string[]
function M.get_profiles()
  return { "core", "developer", "security", "research", "full" }
end

return M
