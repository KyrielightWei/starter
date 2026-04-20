-- lua/ai/components/version.lua
-- 版本检测核心：npm/git 版本查询和比较

local M = {}

--- semver 版本解析
---@param version_str string 版本字符串（如 "1.37.1", "v22.0.0"）
---@return table|nil { major, minor, patch, prerelease }
function M.parse_semver(version_str)
  if not version_str or version_str == "" then
    return nil
  end

  -- 去除 v 前缀
  local clean = version_str:gsub("^v", "")

  -- 匹配主版本号模式
  local pattern = "^(%d+)%.(%d+)%.(%d+)(.*)$"
  local major, minor, patch, prerelease = clean:match(pattern)

  if not major then
    -- 尝试简单模式（如 "1.37"）
    pattern = "^(%d+)%.(%d+)$"
    major, minor = clean:match(pattern)
    if major then
      patch = "0"
      prerelease = ""
    else
      return nil
    end
  end

  return {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
    prerelease = prerelease or "",
  }
end

--- 比较两个版本
---@param v1 string 当前版本
---@param v2 string 比较版本
---@return string "outdated" | "current" | "newer" | "unknown"
function M.compare_versions(v1, v2)
  -- 处理 nil 或空值
  if not v1 or v1 == "" or not v2 or v2 == "" then
    return "unknown"
  end

  local p1 = M.parse_semver(v1)
  local p2 = M.parse_semver(v2)

  if not p1 or not p2 then
    return "unknown"
  end

  -- 比较主版本号
  if p1.major < p2.major then
    return "outdated"
  elseif p1.major > p2.major then
    return "newer"
  end

  -- 比较次版本号
  if p1.minor < p2.minor then
    return "outdated"
  elseif p1.minor > p2.minor then
    return "newer"
  end

  -- 比较补丁版本号
  if p1.patch < p2.patch then
    return "outdated"
  elseif p1.patch > p2.patch then
    return "newer"
  end

  -- 比较 prerelease（有 prerelease 的版本比无 prerelease 的低）
  if p1.prerelease ~= "" and p2.prerelease == "" then
    return "outdated"
  elseif p1.prerelease == "" and p2.prerelease ~= "" then
    return "newer"
  end

  return "current"
end

--- 获取已安装命令的版本
---@param cmd string 命令名（如 "npm", "git", "node"）
---@return string|nil version
function M.get_installed_version(cmd)
  if vim.fn.executable(cmd) ~= 1 then
    return nil
  end

  local result = vim.fn.system(cmd .. " --version")

  if vim.v.shell_error ~= 0 then
    return nil
  end

  -- 解析输出
  return M.parse_from_string(result)
end

--- 从字符串中提取版本号
---@param str string 包含版本号的字符串
---@return string|nil version
function M.parse_from_string(str)
  if not str then
    return nil
  end

  -- 匹配常见的版本输出格式
  -- git version 2.43.0
  -- npm v10.2.0
  -- node v22.0.0
  -- 1.37.1

  local patterns = {
    "version (%d+%.%d+%.%d+)", -- git version X.Y.Z
    "v(%d+%.%d+%.%d+)", -- vX.Y.Z
    "^(%d+%.%d+%.%d+)", -- X.Y.Z at start
    "(%d+%.%d+%.%d+)", -- any X.Y.Z
  }

  for _, pattern in ipairs(patterns) do
    local match = str:match(pattern)
    if match then
      return match
    end
  end

  return nil
end

--- 同步获取 npm 包最新版本
---@param package_name string npm 包名
---@param timeout number|nil 超时时间（毫秒），默认 30000
---@return string|nil latest_version
function M.get_latest_npm_version(package_name, timeout)
  timeout = timeout or 30000

  if not package_name or package_name == "" then
    return nil
  end

  if vim.fn.executable("npm") ~= 1 then
    return nil
  end

  local cmd = string.format("npm view %s version --json", package_name)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return nil
  end

  local version = result:gsub('"', ""):gsub("\n", "")
  return version ~= "" and version or nil
end

--- 异步获取 npm 包最新版本
--- via jobstart + callback
---@param package_name string npm 包名
---@param callback fun(version: string|nil)
function M.get_latest_npm_version_async(package_name, callback)
  if not package_name or package_name == "" then
    callback(nil)
    return
  end

  if vim.fn.executable("npm") ~= 1 then
    callback(nil)
    return
  end

  local cmd = string.format("npm view %s version --json", package_name)
  local stdout = {}

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stdout, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 or #stdout == 0 then
        callback(nil)
        return
      end
      local version = table.concat(stdout):gsub('"', ""):gsub("\n", "")
      callback(version ~= "" and version or nil)
    end,
  })
end

--- 同步获取 git 仓库最新版本（阻塞）
---@param repo_url string 仓库 URL
---@return string|nil latest_commit_hash
function M.get_latest_git_version(repo_url)
  if not repo_url or repo_url == "" then
    return nil
  end

  if vim.fn.executable("git") ~= 1 then
    return nil
  end

  local cmd = string.format("git ls-remote %s HEAD", repo_url)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return nil
  end

  local hash = result:match("^([a-f0-9]+)")
  return hash
end

--- 异步获取 git 仓库最新版本
--- via jobstart + callback
---@param repo_url string 仓库 URL
---@param callback fun(hash: string|nil)
function M.get_latest_git_version_async(repo_url, callback)
  if not repo_url or repo_url == "" then
    callback(nil)
    return
  end

  if vim.fn.executable("git") ~= 1 then
    callback(nil)
    return
  end

  local cmd = string.format("git ls-remote %s HEAD", repo_url)
  local stdout = {}

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stdout, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 or #stdout == 0 then
        callback(nil)
        return
      end
      local hash = table.concat(stdout):match("^([a-f0-9]+)")
      callback(hash)
    end,
  })
end

--- 同步获取本地已克隆仓库的版本
---@param repo_path string 本地仓库路径
---@return string|nil commit_hash, number|nil commits_behind
function M.get_local_git_version(repo_path)
  if vim.fn.isdirectory(repo_path) ~= 1 then
    return nil, nil
  end

  local current_hash = vim.fn.system(string.format("git -C %s rev-parse HEAD", repo_path))

  if vim.v.shell_error ~= 0 then
    return nil, nil
  end

  current_hash = current_hash:gsub("\n", "")

  local fetch_result = vim.fn.system(string.format("git -C %s fetch --dry-run 2>&1", repo_path))
  local needs_fetch = fetch_result:match("would fetch") or fetch_result:match("new commits")

  return current_hash, needs_fetch and -1 or 0
end

--- 综合版本状态查询（npm 包）
---@param cmd string 命令名（用于获取本地版本）
---@param package_name string npm 包名
---@return VersionInfo
function M.get_version_status_npm(cmd, package_name)
  local current = nil
  local latest = nil

  -- 尝试获取本地版本
  if cmd and vim.fn.executable(cmd) == 1 then
    current = M.get_installed_version(cmd)
  end

  -- 尝试获取 npm 最新版本
  if package_name then
    latest = M.get_latest_npm_version(package_name)
  end

  -- 确定状态
  local status = "unknown"

  if not current then
    status = "not_installed"
  elseif not latest then
    status = "unknown" -- 无法获取最新版本
  else
    status = M.compare_versions(current, latest)
  end

  return {
    current = current,
    latest = latest,
    status = status,
  }
end

--- 综合版本状态查询（git 仓库）
---@param repo_url string 仓库 URL
---@param local_path string|nil 本地克隆路径
---@return VersionInfo
function M.get_version_status_git(repo_url, local_path)
  local current = nil
  local latest = nil

  -- 获取本地版本
  if local_path and vim.fn.isdirectory(local_path) == 1 then
    current = M.get_local_git_version(local_path)
  end

  -- 获取远程最新版本
  if repo_url then
    latest = M.get_latest_git_version(repo_url)
  end

  -- 确定状态
  local status = "unknown"

  if not current then
    status = "not_installed"
  elseif not latest then
    status = "unknown"
  elseif current ~= latest then
    status = "outdated"
  else
    status = "current"
  end

  return {
    current = current,
    latest = latest,
    status = status,
  }
end

return M
