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
---@return VersionInfo
function M.get_version_info()
  local Status = require("ai.components.gsd.status")
  local Version = require("ai.components.version")

  local current = Status.get_npm_version()
  local latest = Version.get_latest_npm_version(GSD_PACKAGE)

  local version_status = "unknown"

  if not current then
    -- npx 模式，无本地版本
    version_status = "on_demand" -- 使用 npx 按需运行
  elseif not latest then
    version_status = "unknown"
  else
    version_status = Version.compare_versions(current, latest)
  end

  return {
    current = current,
    latest = latest,
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
