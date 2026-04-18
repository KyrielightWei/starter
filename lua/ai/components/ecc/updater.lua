-- lua/ai/components/ecc/updater.lua
-- ECC 更新逻辑

local M = {}

--- ECC 仓库 URL
local ECC_REPO = "https://github.com/affaan-m/everything-claude-code.git"

--- 临时更新目录
local ECC_TEMP_DIR = "/tmp/ecc-update"

--- 更新 ECC
---@param opts table|nil { profile: string }
---@param on_progress function|nil 进度回调
---@return boolean, string success, message
function M.update(opts, on_progress)
  opts = opts or {}
  local profile = opts.profile or "developer"

  local Status = require("ai.components.ecc.status")
  local Installer = require("ai.components.ecc.installer")
  local Version = require("ai.components.version")

  -- 检查是否已安装
  if not Status.is_installed() then
    return false, "ECC 未安装，请先安装"
  end

  -- 检查版本状态
  local version_info = M.get_version_info()

  if version_info.status == "current" then
    return true, "ECC 已是最新版本"
  end

  -- 清理临时目录
  if vim.fn.isdirectory(ECC_TEMP_DIR) == 1 then
    vim.fn.delete(ECC_TEMP_DIR, "rf")
  end

  if on_progress then
    on_progress("🔄 更新 ECC...")
  end

  -- 使用 force=true 重新安装
  local ok, msg = Installer.install({
    target = "claude",
    profile = profile,
    force = true,
  }, on_progress)

  if ok then
    -- 清理临时目录
    if vim.fn.isdirectory(ECC_TEMP_DIR) == 1 then
      vim.fn.delete(ECC_TEMP_DIR, "rf")
    end

    return true, "ECC 更新成功"
  else
    return false, "更新失败: " .. msg
  end
end

--- 获取版本信息
---@return VersionInfo
function M.get_version_info()
  local Status = require("ai.components.ecc.status")
  local Version = require("ai.components.version")

  local status = Status.get_status()

  if not status then
    return {
      current = nil,
      latest = nil,
      status = "not_installed",
    }
  end

  -- 获取当前版本（git commit 或 repo_version）
  local current = status.repo_version

  -- 获取远程最新版本
  local latest = Version.get_latest_git_version(ECC_REPO)

  -- 确定状态
  local version_status = "unknown"

  if not current then
    version_status = "unknown"
  elseif not latest then
    version_status = "unknown"
  elseif current ~= latest then
    version_status = "outdated"
  else
    version_status = "current"
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
