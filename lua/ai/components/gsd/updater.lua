-- lua/ai/components/gsd/updater.lua
-- GSD 更新逻辑（cache model per D-07, D-08, D-22, D-23）

local M = {}

--- GSD 仓库 URL
local GSD_REPO = "https://github.com/gsd-build/get-shit-done.git"

--- Module dependencies
local Manager = require("ai.components.manager")
local Deployments = require("ai.components.deployments")

--- 验证缓存路径是否在预期范围内 (CR-02 安全修复)
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

--- 更新 GSD 缓存 (per D-07, D-08, D-22)
--- Security: Uses npm --prefix with shellescape instead of chdir (EXT-CR-04 fix)
--- WR-05: Dynamic branch detection instead of hardcoded "main"
---@param opts table|nil { force: boolean, cache_path: string }
---@param on_progress function|nil
---@return boolean, string
function M.update(opts, on_progress)
  opts = opts or {}

  -- Get cache path (D-07)
  local cache_path = opts.cache_path or Manager.get_cache_path("gsd")

  -- CR-02: 验证缓存路径
  local valid, validated_path_or_err = validate_cache_path(cache_path)
  if not valid then
    return false, "Invalid cache_path: " .. validated_path_or_err
  end
  cache_path = validated_path_or_err

  -- Check if cached
  if not Manager.is_cached("gsd") then
    return false, "GSD 未缓存，请先运行 install_to_cache"
  end

  if on_progress then
    on_progress("更新 GSD 缓存...")
  end

  -- D-07: Only update cache, NOT deployed targets
  -- WR-05: Detect current branch dynamically instead of hardcoded "main"
  local safe_path = vim.fn.shellescape(cache_path)
  local branch_cmd = string.format("git -C %s rev-parse --abbrev-ref HEAD", safe_path)
  local branch_result = vim.fn.system(branch_cmd)
  local branch = vim.v.shell_error == 0 and vim.trim(branch_result) or "main"

  -- Step 1: Git pull in cache directory
  local cmd = string.format("git -C %s pull origin %s", safe_path, vim.fn.shellescape(branch))
  local ok, output = run_cmd_sync(cmd)

  if not ok then
    return false, "git pull 失败: " .. output
  end

  -- Step 2: npm install (update dependencies)
  -- EXT-CR-04: Use npm --prefix with shellescape instead of chdir
  if on_progress then
    on_progress("更新依赖...")
  end

  cmd = string.format("npm --prefix %s install --no-audit --no-fund --loglevel=error", safe_path)
  ok, output = run_cmd_sync(cmd)

  if not ok then
    return false, "npm install 失败: " .. output
  end

  -- D-22: Rebuild hooks after update (critical for offline deploy)
  -- EXT-CR-04: Use npm --prefix with shellescape instead of chdir
  if on_progress then
    on_progress("重新构建 hooks...")
  end

  cmd = string.format("npm --prefix %s run build:hooks", safe_path)
  ok, output = run_cmd_sync(cmd)

  if not ok then
    return false, "build:hooks 失败: " .. output
  end

  -- D-08: Prompt user for redeploy AFTER update
  local status = Deployments.get_deployment_status("gsd")
  if status and status.deployed_to and #vim.tbl_keys(status.deployed_to) > 0 then
    vim.notify(
      string.format(
        "GSD 缓存已更新。之前部署到: %s。是否重新部署？",
        table.concat(vim.tbl_keys(status.deployed_to), ", ")
      ),
      vim.log.levels.WARN
    )
  end

  return true, "GSD 缓存已更新: " .. cache_path
end

--- 获取版本信息 (per D-23: package.json version)
---@return VersionInfo
function M.get_version_info()
  local cache_path = Manager.get_cache_path("gsd")

  -- Check if cached
  if not Manager.is_cached("gsd") then
    return {
      current = nil,
      latest = nil,
      status = "not_installed",
    }
  end

  -- D-23: Get current version from package.json
  local current = nil
  local pkg_path = cache_path .. "/package.json"
  if vim.fn.filereadable(pkg_path) == 1 then
    local content = vim.fn.readfile(pkg_path)
    local ok, pkg = pcall(vim.json.decode, table.concat(content, "\n"))
    if ok and pkg and pkg.version then
      current = pkg.version
    end
  end

  -- Fallback to git hash if package.json missing
  if not current then
    current = Manager.get_cache_version("gsd")
  end

  -- Get remote latest version (git ls-remote)
  local cmd = "git ls-remote " .. GSD_REPO .. " HEAD"
  local result = vim.fn.system(cmd)
  local latest_hash = nil
  if vim.v.shell_error == 0 then
    -- IN-02: nil guard before vim.trim
    local match_result = result:match("^([a-f0-9]+)")
    if match_result then
      latest_hash = vim.trim(match_result)
    end
  end

  -- Determine status
  local version_status = "unknown"
  if current and latest_hash then
    -- For GSD, compare by package version if available
    -- Otherwise compare git hashes
    local current_hash = Manager.get_cache_version("gsd")
    if current_hash and latest_hash then
      if current_hash == latest_hash then
        version_status = "current"
      else
        version_status = "outdated"
      end
    end
  end

  return {
    current = current,
    latest = latest_hash,
    status = version_status,
  }
end

--- 检查是否需要更新
---@return boolean
function M.needs_update()
  local version_info = M.get_version_info()
  return version_info.status == "outdated"
end

return M