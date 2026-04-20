-- lua/ai/components/gsd/updater.lua
-- GSD 更新逻辑

local M = {}

--- GSD npm 包名
local GSD_PACKAGE = "get-shit-done-cc"

--- 更新 GSD
---@param opts table|nil
---@param on_progress function|nil
---@return boolean, string
function M.update(opts, on_progress)
  opts = opts or {}

  local Status = require("ai.components.gsd.status")
  local Version = require("ai.components.version")

  -- 检查是否已安装
  if not Status.is_installed() then
    return false, "GSD 未安装，请先安装"
  end

  -- 检查版本状态
  local version_info = M.get_version_info()

  if version_info.status == "current" then
    return true, "GSD 已是最新版本"
  end

  -- npx 自动使用 latest，无需手动更新
  if not Status.is_npm_installed() then
    if on_progress then
      on_progress("GSD 使用 npx 按需运行，自动使用最新版本")
    end
    return true, "npx 自动使用 latest，无需更新"
  end

  -- npm 全局安装的更新
  if on_progress then
    on_progress("更新 GSD...")
  end

  local cmd = "npm update -g " .. GSD_PACKAGE
  local result = vim.fn.system(cmd)

  if vim.v.shell_error == 0 then
    return true, "GSD 更新成功"
  else
    return false, "npm update 失败: " .. result
  end
end

--- 获取版本信息
--- GSD 通过 npx 按需运行，没有本地版本概念
---@return VersionInfo
function M.get_version_info()
  local Version = require("ai.components.version")

  -- npx 模式：本地版本即为 npx available，远程版本为 latest
  local current = nil
  local latest = Version.get_latest_npm_version(GSD_PACKAGE)
  local version_status = "unknown"

  -- 检查 npm 全局安装版本（如果有的话）
  if is_npm_installed_from_status() then
    current = get_npm_global_version()
    if latest then
      version_status = Version.compare_versions(current, latest)
    end
  else
    -- npx 模式：无本地版本，自动使用 latest
    current = "npx latest"
    version_status = "on_demand"
  end

  return {
    current = current or "npx latest",
    latest = latest,
    status = version_status,
  }
end

--- 检查 npm 全局安装状态
local function is_npm_installed_from_status()
  if vim.fn.executable("npm") ~= 1 then
    return false
  end
  local result = vim.fn.system("npm list -g " .. GSD_PACKAGE .. " --depth=0 2>&1")
  return result:match(GSD_PACKAGE) ~= nil and not result:match("empty")
end

--- 获取 npm 全局安装版本
local function get_npm_global_version()
  local result = vim.fn.system("npm list -g " .. GSD_PACKAGE .. " --depth=0 --json 2>&1")
  if vim.v.shell_error == 0 then
    local ok, data = pcall(vim.json.decode, result)
    if ok and data and data.dependencies and data.dependencies[GSD_PACKAGE] then
      return data.dependencies[GSD_PACKAGE].version
    end
  end
  return nil
end

--- 检查是否需要更新
---@return boolean
function M.needs_update()
  local version_info = M.get_version_info()
  return version_info.status == "outdated"
end

return M
