-- lua/ai/components/gsd/installer.lua
-- GSD 安装逻辑（cache model per D-22, D-29）

local M = {}

--- GSD 仓库 URL
local GSD_REPO = "https://github.com/gsd-build/get-shit-done.git"

--- Module dependencies
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
---@param cmd string
---@return boolean, string
local function run_cmd_sync(cmd)
  local result = vim.fn.systemlist(cmd)
  local exit_code = vim.v.shell_error

  return exit_code == 0, table.concat(result, "\n")
end

--- 克隆 GSD 仓库到缓存目录
---@param cache_path string 缓存路径
---@param on_progress function|nil
---@return boolean, string
local function clone_repo(cache_path, on_progress)
  if on_progress then
    on_progress("📥 克隆 GSD 仓库...")
  end

  -- Security: Use shellescape (CR-02 pattern)
  local safe_path = vim.fn.shellescape(cache_path)
  local cmd = string.format("git clone %s %s", GSD_REPO, safe_path)
  local ok, output = run_cmd_sync(cmd)

  if not ok then
    return false, "克隆失败: " .. output
  end

  return true, "克隆成功"
end

--- 安装 npm 依赖
--- Security: Uses npm --prefix with shellescape instead of chdir (EXT-CR-03 fix)
---@param cache_path string 缓存路径
---@param on_progress function|nil
---@return boolean, string
local function install_deps(cache_path, on_progress)
  if on_progress then
    on_progress("📦 安装依赖...")
  end

  -- EXT-CR-03: Use npm --prefix with shellescape instead of chdir
  local safe_path = vim.fn.shellescape(cache_path)
  local cmd = string.format("npm --prefix %s install --no-audit --no-fund --loglevel=error", safe_path)
  local ok, output = run_cmd_sync(cmd)

  if not ok then
    return false, "依赖安装失败: " .. output
  end

  return true, "依赖安装成功"
end

--- 构建 hooks（D-22 关键步骤）
--- Security: Uses npm --prefix with shellescape instead of chdir (EXT-CR-03 fix)
---@param cache_path string 缓存路径
---@param on_progress function|nil
---@return boolean, string
local function build_hooks(cache_path, on_progress)
  if on_progress then
    on_progress("🔧 构建 hooks...")
  end

  -- EXT-CR-03: Use npm --prefix with shellescape instead of chdir
  local safe_path = vim.fn.shellescape(cache_path)
  local cmd = string.format("npm --prefix %s run build:hooks", safe_path)
  local ok, output = run_cmd_sync(cmd)

  if not ok then
    return false, "build:hooks 失败: " .. output
  end

  return true, "hooks 构建成功"
end

--- 安装 GSD 到缓存 (per D-22, D-29)
---@param opts table|nil { force: boolean, cache_path: string }
---@param on_progress function|nil
---@return boolean, string
function M.install(opts, on_progress)
  opts = opts or {}

  -- Get cache path from manager (D-29)
  local cache_path = opts.cache_path or Manager.get_cache_path("gsd")

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

  -- 清理现有缓存（force 模式）
  if opts.force and vim.fn.isdirectory(cache_path) == 1 then
    -- CR-01: 验证路径后才执行删除
    local valid, err = validate_cache_path(cache_path)
    if valid then
      vim.fn.delete(cache_path, "rf")
    else
      return false, "Refusing to delete: " .. err
    end
  end

  -- WR-07: 使用 xpcall 确保错误恢复
  local ok, result = xpcall(function()
    -- D-22 Step 1: git clone
    local ok2, msg = clone_repo(cache_path, on_progress)
    if not ok2 then
      error(msg)
    end

    -- D-22 Step 2: npm install
    ok2, msg = install_deps(cache_path, on_progress)
    if not ok2 then
      error(msg)
    end

    -- D-22 Step 3: npm run build:hooks（关键：离线部署能力）
    ok2, msg = build_hooks(cache_path, on_progress)
    if not ok2 then
      error(msg)
    end

    return "GSD 缓存成功: " .. cache_path
  end, function(err)
    return tostring(err)
  end)

  if ok then
    return true, result
  else
    return false, result
  end
end

--- 获取安装命令提示
---@return string
function M.install_hint()
  return "git clone " .. GSD_REPO .. " ~/.local/share/nvim/ai_components/cache/gsd && npm install && npm run build:hooks"
end

--- 获取支持的安装目标 (IN-05: 接口一致性)
---@return string[]
function M.get_targets()
  return { "claude", "opencode", "gemini", "cursor", "codex", "windsurf" }
end

--- 获取支持的安装 profile (IN-05: 接口一致性)
---@return string[]
function M.get_profiles()
  return { "core", "developer", "full" }
end

return M