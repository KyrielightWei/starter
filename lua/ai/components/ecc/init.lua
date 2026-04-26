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
-- Cache for Performance (avoid blocking network requests)
-- ============================================

local _version_cache = nil
local _deps_cache = nil
local _cache_time = nil
local CACHE_DURATION = 300 -- 5 minutes

--- Clear cache (call after install/update/uninstall)
function M.clear_cache()
  _version_cache = nil
  _deps_cache = nil
  _cache_time = nil
end

--- Check if cache is valid
---@return boolean
local function cache_valid()
  return _cache_time and (os.time() - _cache_time < CACHE_DURATION)
end

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

--- 获取版本信息（带缓存）
---@return VersionInfo
function M.get_version_info()
  -- 返回缓存
  if cache_valid() and _version_cache then
    return _version_cache
  end

  -- 获取新版本信息（可能涉及网络请求）
  local info = Updater.get_version_info()
  _version_cache = info
  _cache_time = os.time()
  return info
end

--- 强制刷新版本信息（用于用户手动刷新）
---@return VersionInfo
function M.refresh_version_info()
  M.clear_cache()
  return M.get_version_info()
end

--- 检查依赖状态（带缓存）
---@return DependencyStatus[]
function M.check_dependencies()
  -- 返回缓存
  if cache_valid() and _deps_cache then
    return _deps_cache
  end

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

  _deps_cache = deps
  _cache_time = os.time()
  return deps
end

--- 安装组件
---@param opts table|nil
---@param callback function|nil
---@return boolean, string
function M.install(opts, callback)
  M.clear_cache() -- 清除缓存
  return Installer.install(opts, callback)
end

--- 卸载组件
---@param opts table|nil
---@return boolean, string
function M.uninstall(opts)
  M.clear_cache() -- 清除缓存
  return Uninstaller.uninstall(opts)
end

--- 更新组件
---@param opts table|nil
---@return boolean, string
function M.update(opts)
  M.clear_cache() -- 清除缓存
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

  -- WR-06: 统一检查顺序和状态（先检查 missing deps，使用 "error" 状态）
  if #missing > 0 then
    return {
      status = "error",
      message = "Missing dependencies: " .. table.concat(
        vim.tbl_map(function(d)
          return d.name
        end, missing),
        ", "
      ),
    }
  end

  if not installed then
    return {
      status = "warn",
      message = "Not installed. Run :AIComponents to install",
    }
  end

  -- IN-08: 统一 OK 消息格式
  return {
    status = "ok",
    message = "ECC ready (cached)",
  }
end

--- 获取配置目录路径
---@return string
function M.get_config_dir()
  return Status.install_dir()
end

-- ============================================
-- Cache Methods (per D-24, D-25, D-30)
-- ============================================

--- 检查是否已缓存
---@return boolean
function M.is_cached()
  local Manager = require("ai.components.manager")
  return Manager.is_cached("ecc")
end

--- 获取缓存版本 (per D-20: git rev-parse HEAD)
---@return string|nil
function M.get_cache_version()
  local Manager = require("ai.components.manager")
  return Manager.get_cache_version("ecc")
end

--- 部署前钩子 (per D-31)
--- ECC 无特殊部署前处理，此为空操作
---@param target string 目标工具
---@return boolean, string|nil
function M.pre_deploy(target)
  -- ECC 无特殊部署前处理
  -- 未来可扩展：如验证缓存完整性等
  return true, nil
end

--- 部署后钩子 (per D-31)
--- ECC 无特殊部署后处理，此为空操作
---@param target string 目标工具
---@return boolean, string|nil
function M.post_deploy(target)
  -- ECC 无特殊部署后处理
  -- 未来可扩展：如发送通知、记录日志等
  return true, nil
end

--- 获取部署路径映射 (per D-24, D-25)
---@param target string 目标工具 ("claude" | "opencode")
---@return table[] 路径映射数组 { source, target }
function M.get_deploy_paths(target)
  -- WR-05: 使用 Manager.get_cache_path 替代硬编码路径
  local Manager = require("ai.components.manager")
  local cache_base = Manager.get_cache_path("ecc")

  if target == "claude" then
    -- D-24: ECC → Claude Code full mapping
    return {
      { source = cache_base .. "/rules",      target = vim.fn.expand("~/.claude/rules") },
      { source = cache_base .. "/agents",     target = vim.fn.expand("~/.claude/agents") },
      { source = cache_base .. "/skills",     target = vim.fn.expand("~/.claude/skills") },
      { source = cache_base .. "/commands",   target = vim.fn.expand("~/.claude/commands/ecc") },
      { source = cache_base .. "/hooks",      target = vim.fn.expand("~/.claude/hooks") },
    }
  elseif target == "opencode" then
    -- D-25: ECC → OpenCode subset mapping
    return {
      { source = cache_base .. "/agents",     target = vim.fn.expand("~/.config/opencode/agents") },
      { source = cache_base .. "/skills",     target = vim.fn.expand("~/.config/opencode/skills/ecc") },
      { source = cache_base .. "/commands",   target = vim.fn.expand("~/.config/opencode/command/ecc") },
    }
  end

  return {}
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