-- lua/ai/components/ecc/init.lua
-- ECC 组件入口：实现完整接口

local M = {}

-- ============================================
-- Metadata Fields
-- ============================================

M.name = "ecc"
M.display_name = "Everything Claude Code"
M.version = "1.0.0"
M.category = "framework"
M.description = "AI development framework with rules, commands, agents, and skills"
M.repo_url = "https://github.com/affaan-m/everything-claude-code.git"
M.npm_package = nil -- ECC 不使用 npm，直接 git clone
M.dependencies = { "git", "npm", "node" }
M.icon = "🔧"
M.supported_targets = { "claude", "opencode" }

-- ============================================
-- Sub-module Imports
-- ============================================

local Status = require("ai.components.ecc.status")
local Installer = require("ai.components.ecc.installer")
local Uninstaller = require("ai.components.ecc.uninstaller")
local Updater = require("ai.components.ecc.updater")
local Version = require("ai.components.version")

-- ============================================
-- Interface Methods
-- ============================================

--- 初始化组件
---@param opts table|nil
---@return boolean
function M.setup(opts)
  opts = opts or {}
  return true
end

--- 检查是否已安装
---@return boolean
function M.is_installed()
  return Status.is_installed()
end

--- 获取状态信息
---@return table|nil
function M.get_status()
  return Status.get_status()
end

--- 获取版本信息
---@return VersionInfo
function M.get_version_info()
  return Updater.get_version_info()
end

--- 检查依赖状态
---@return DependencyStatus[]
function M.check_dependencies()
  local deps = {}

  for _, dep_name in ipairs(M.dependencies) do
    local installed = vim.fn.executable(dep_name) == 1
    local version = nil

    if installed then
      version = Version.get_installed_version(dep_name)
    end

    table.insert(deps, {
      name = dep_name,
      installed = installed,
      required = true,
      version = version,
      install_hint = M.get_install_hint(dep_name),
    })
  end

  return deps
end

--- 安装组件
---@param opts table|nil
---@param callback function|nil
---@return boolean, string
function M.install(opts, callback)
  return Installer.install(opts, callback)
end

--- 卸载组件
---@param opts table|nil
---@return boolean, string
function M.uninstall(opts)
  return Uninstaller.uninstall(opts)
end

--- 更新组件
---@param opts table|nil
---@return boolean, string
function M.update(opts)
  return Updater.update(opts)
end

--- 健康检查
---@return HealthStatus
function M.health_check()
  local installed = M.is_installed()
  local deps = M.check_dependencies()
  local missing = vim.tbl_filter(function(d)
    return d.required and not d.installed
  end, deps)

  if not installed then
    return {
      status = "warn",
      message = "Not installed. Run :AIComponents to install",
    }
  end

  if #missing > 0 then
    return {
      status = "warn",
      message = "Missing dependencies: " .. table.concat(
        vim.tbl_map(function(d)
          return d.name
        end, missing),
        ", "
      ),
    }
  end

  return {
    status = "ok",
    message = "Installed and healthy",
  }
end

--- 获取配置目录路径
---@return string
function M.get_config_dir()
  return Status.install_dir()
end

-- ============================================
-- Helper Methods
-- ============================================

--- 获取依赖安装提示
---@param dep_name string
---@return string
function M.get_install_hint(dep_name)
  local hints = {
    npm = "Ubuntu: apt install nodejs npm\nmacOS: brew install node npm\nArch: pacman -S nodejs npm",
    node = "Ubuntu: apt install nodejs\nmacOS: brew install node\nArch: pacman -S nodejs",
    git = "Ubuntu: apt install git\nmacOS: brew install git\nArch: pacman -S git",
  }
  return hints[dep_name] or "Please install " .. dep_name
end

--- 获取安装命令提示（向后兼容）
---@return string
function M.install_hint()
  return Installer.install_hint()
end

--- 显示状态（向后兼容）
function M.show_status()
  local status = M.get_status()
  local lines = Status.format_notification(status)

  if status then
    local counts = Status.get_module_counts()
    table.insert(lines, "")
    table.insert(lines, "安装目录:")
    for name, count in pairs(counts) do
      table.insert(lines, string.format("  %s: %d items", name, count))
    end
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
