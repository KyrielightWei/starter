-- lua/ai/components/gsd/init.lua
-- GSD 组件入口：实现完整接口

local M = {}

-- ============================================
-- Metadata Fields
-- ============================================

M.name = "gsd"
M.display_name = "Get Shit Done"
M.version = "1.37.1"
M.category = "framework"
M.description = "Spec-driven development system for AI coding agents"
M.repo_url = "https://github.com/gsd-build/get-shit-done.git"
M.npm_package = "get-shit-done-cc"
M.dependencies = { "npx", "node" }
M.icon = "🚀"
M.supported_targets = { "claude", "opencode", "gemini", "cursor", "codex", "windsurf" }

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

local Status = require("ai.components.gsd.status")
local Installer = require("ai.components.gsd.installer")
local Uninstaller = require("ai.components.gsd.uninstaller")
local Updater = require("ai.components.gsd.updater")
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

  return {
    status = "ok",
    -- IN-08: 统一 OK 消息格式
    message = "GSD ready (cached)",
  }
end

--- 获取配置目录路径
---@return string
function M.get_config_dir()
  return Status.get_config_dir()
end

-- ============================================
-- Cache Methods (per D-26, D-27, D-30)
-- ============================================

--- 检查是否已缓存
---@return boolean
function M.is_cached()
  local Manager = require("ai.components.manager")
  return Manager.is_cached("gsd")
end

--- 获取缓存版本 (per D-23: package.json version)
---@return string|nil
function M.get_cache_version()
  local Manager = require("ai.components.manager")
  -- Try package.json version first (D-23)
  local cache_path = Manager.get_cache_path("gsd")
  local pkg_path = cache_path .. "/package.json"
  if vim.fn.filereadable(pkg_path) == 1 then
    local content = vim.fn.readfile(pkg_path)
    local ok, pkg = pcall(vim.json.decode, table.concat(content, "\n"))
    if ok and pkg and pkg.version then
      return pkg.version
    end
  end
  -- Fallback to manager's git hash
  return Manager.get_cache_version("gsd")
end

--- 获取部署路径映射 (per D-26, D-27)
---@param target string 目标工具 ("opencode" | "claude")
---@return table[] 路径映射数组 { source, target }
function M.get_deploy_paths(target)
  local Manager = require("ai.components.manager")
  local cache_base = Manager.get_cache_path("gsd")

  if target == "opencode" then
    -- D-26: GSD → OpenCode full mapping
    return {
      { source = cache_base .. "/commands/gsd", target = vim.fn.expand("~/.config/opencode/command/gsd") },
      { source = cache_base .. "/agents",       target = vim.fn.expand("~/.opencode/agents") },
      { source = cache_base .. "/skills/gsd",   target = vim.fn.expand("~/.opencode/skills/gsd") },
      { source = cache_base .. "/hooks",        target = vim.fn.expand("~/.opencode/hooks") },
      { source = cache_base .. "/bin",          target = vim.fn.expand("~/.local/bin") },
    }
  elseif target == "claude" then
    -- D-27: GSD → Claude Code subset mapping
    return {
      { source = cache_base .. "/agents/gsd",   target = vim.fn.expand("~/.claude/agents/gsd") },
      { source = cache_base .. "/skills/gsd",   target = vim.fn.expand("~/.claude/skills/gsd") },
      { source = cache_base .. "/commands/gsd", target = vim.fn.expand("~/.claude/commands/gsd") },
    }
  end

  return {}
end

-- ============================================
-- Deploy Hooks (per D-31)
-- ============================================

--- 部署前钩子 (per D-31)
--- GSD 无特殊部署前处理，此为空操作
---@param target string 目标工具
---@return boolean, string|nil CR-03: 返回两个值以符合接口规范
function M.pre_deploy(target)
  -- GSD 无特殊部署前处理
  -- 所有准备工作（包括 build:hooks）已在 install_to_cache 完成
  return true, nil
end

--- 部署后钩子 (per D-31)
--- GSD 的 build:hooks 已在缓存阶段完成（D-22），此为空操作
---@param target string 目标工具
---@return boolean, string|nil CR-03: 返回两个值以符合接口规范
function M.post_deploy(target)
  -- GSD 无特殊部署后处理
  -- build:hooks 已在 install_to_cache 中执行（D-22）
  -- 未来可扩展：如发送通知、记录日志等
  return true, nil
end

-- ============================================
-- Helper Methods
-- ============================================

--- 获取依赖安装提示
---@param dep_name string
---@return string
function M.get_install_hint(dep_name)
  local hints = {
    npx = "随 Node.js 一起安装\nUbuntu: apt install nodejs npm\nmacOS: brew install node npm",
    node = "Ubuntu: apt install nodejs\nmacOS: brew install node\nArch: pacman -S nodejs",
    npm = "Ubuntu: apt install nodejs npm\nmacOS: brew install node npm\nArch: pacman -S nodejs npm",
  }
  return hints[dep_name] or "Please install " .. dep_name
end

--- 获取安装命令提示
---@return string
function M.install_hint()
  return Installer.install_hint()
end

--- 显示状态
function M.show_status()
  local status = M.get_status()
  local version = M.get_version_info()

  local lines = {
    "🚀 GSD (Get Shit Done)",
    "",
    "Status: " .. (status and "installed" or "not installed"),
    "Version: " .. (version.current or "npx latest"),
    "Latest: " .. (version.latest or "N/A"),
    "State: " .. (version.status or "unknown"),
    "",
    "Dependencies:",
  }

  local deps = M.check_dependencies()
  for _, dep in ipairs(deps) do
    local icon = dep.installed and "✓" or "✗"
    table.insert(lines, string.format("  %s %s", icon, dep.name))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M