-- lua/ai/components/ecc/installer.lua
-- ECC 安装逻辑 (Cache-based per D-28, D-19)
--
-- Key changes from old implementation:
-- - ECC_TEMP_DIR removed → use Manager.get_cache_path("ecc") or opts.cache_path
-- - scripts/install-apply.js NOT run during cache phase (D-19)
-- - Deployment handled by manager.deploy_to() in separate phase

local M = {}

--- ECC 源仓库
local ECC_REPO = "https://github.com/affaan-m/everything-claude-code.git"

--- Manager 模块（提供缓存路径）
local Manager = require("ai.components.manager")

--- 验证缓存路径是否在预期范围内 (CR-01, CR-02 安全修复)
---@param path string 待验证路径
---@return boolean, string valid, normalized_path_or_error
local function validate_cache_path(path)
  local expected_base = vim.fn.expand("~/.local/share/nvim/ai_components/cache")
  local normalized = vim.fs.normalize(path)
  -- 检查路径遍历
  if normalized:match("..") then
    return false, "Path traversal detected"
  end
  -- 检查是否在缓存目录范围内
  if not normalized:match("^" .. vim.pesc(expected_base)) then
    return false, "Path must be within cache directory"
  end
  return true, normalized
end

--- 同步执行命令
---@param cmd string 命令
---@return boolean, string success, output
local function run_cmd_sync(cmd)
  local result = vim.fn.systemlist(cmd)
  local exit_code = vim.v.shell_error

  return exit_code == 0, table.concat(result, "\n")
end

--- 克隆 ECC 仓库到缓存目录
--- Security: Uses shellescape for path safety (CR-02 pattern from Phase 2)
---@param cache_path string 缓存目录路径
---@param force boolean 是否强制重新克隆
---@param on_progress function|nil 进度回调
---@return boolean, string success, message
local function clone_repo(cache_path, force, on_progress)
  if on_progress then
    on_progress("克隆 ECC 仓库到缓存...")
  end

  -- 清理现有缓存（如果强制）
  if force and vim.fn.isdirectory(cache_path) == 1 then
    -- CR-01: 验证路径后才执行删除
    local valid, err = validate_cache_path(cache_path)
    if valid then
      vim.fn.delete(cache_path, "rf")
    else
      return false, "Refusing to delete: " .. err
    end
  end

  -- 如果缓存已存在，跳过克隆
  if vim.fn.isdirectory(cache_path) == 1 then
    return true, "缓存目录已存在，跳过克隆"
  end

  -- Security: Use shellescape to prevent command injection (T-03-01 mitigation)
  local safe_path = vim.fn.shellescape(cache_path)
  local cmd = string.format("git clone %s %s --depth=1", ECC_REPO, safe_path)
  local ok, output = run_cmd_sync(cmd)

  if not ok then
    return false, "克隆失败: " .. output
  end

  return true, "克隆成功"
end

--- 安装 npm 依赖
--- Security: Uses npm --prefix with shellescape instead of chdir (EXT-CR-01 fix)
---@param cache_path string 缓存目录路径
---@param on_progress function|nil 进度回调
---@return boolean, string
local function install_deps(cache_path, on_progress)
  if on_progress then
    on_progress("安装依赖...")
  end

  -- EXT-CR-01: Use npm --prefix with shellescape instead of chdir
  -- This prevents command injection via cache_path shell metacharacters
  local safe_path = vim.fn.shellescape(cache_path)
  local cmd = string.format("npm --prefix %s install --no-audit --no-fund --loglevel=error", safe_path)
  local ok, output = run_cmd_sync(cmd)

  if not ok then
    return false, "依赖安装失败: " .. output
  end

  return true, "依赖安装成功"
end

--- 安装 ECC 到缓存目录 (per D-19, D-28)
--- 流程: git clone → npm install → 完成（不运行 install-apply.js）
---@param opts table|nil { cache_path: string, force: boolean }
---@param on_progress function|nil 进度回调 (message: string) -> void
---@return boolean, string success, message
function M.install(opts, on_progress)
  opts = opts or {}
  local force = opts.force or false

  -- 获取缓存路径（优先使用 opts.cache_path，否则使用 Manager.get_cache_path）
  local cache_path = opts.cache_path or Manager.get_cache_path("ecc")

  -- CR-02: 验证缓存路径
  local valid, validated_path_or_err = validate_cache_path(cache_path)
  if not valid then
    return false, "Invalid cache_path: " .. validated_path_or_err
  end
  cache_path = validated_path_or_err

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

  -- 确保缓存基础目录存在
  Manager.ensure_cache_dir()

  -- 使用 xpcall 确保错误恢复
  local ok, result = xpcall(function()
    -- 克隆仓库到缓存
    local ok2, msg = clone_repo(cache_path, force, on_progress)
    if not ok2 then
      error(msg)
    end

    -- 安装依赖（在缓存目录中）
    ok2, msg = install_deps(cache_path, on_progress)
    if not ok2 then
      error(msg)
    end

    -- D-19: 不运行 scripts/install-apply.js
    -- 部署阶段由 manager.deploy_to() 处理

    return "ECC 已缓存到: " .. cache_path
  end, function(err)
    return tostring(err)
  end)

  if ok then
    return true, result
  else
    return false, result
  end
end

--- 获取安装命令提示 (缓存模式)
---@return string
function M.install_hint()
  local cache_path = Manager.get_cache_path("ecc")
  return "git clone "
    .. ECC_REPO
    .. " "
    .. cache_path
    .. " --depth=1 && cd "
    .. cache_path
    .. " && npm install"
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