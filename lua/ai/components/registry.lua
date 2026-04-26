-- lua/ai/components/registry.lua
-- 组件注册表（类似 providers.lua 的注册模式）

local M = {}

--- Module dependencies
local Deployments = require("ai.components.deployments")

--- 内部注册表
---@type table<string, AIComponent>
M._registry = {}

--- 注册组件
---@param name string 组件名称
---@param component AIComponent 组件实例
---@return boolean, string|nil success, error_message
function M.register(name, component)
  if not name or name == "" then
    return false, "Component name cannot be empty"
  end

  -- GLM5-CR-03: Validate component name against all shell-dangerous characters
  if name:match("[;|&<>'`$()%s]") then
    return false, "Component name contains invalid characters (shell-dangerous or whitespace)"
  end

  -- Validate name is alphanumeric with hyphens and underscores only
  if not name:match("^[%w_-]+$") then
    return false, "Component name must be alphanumeric with hyphens/underscores only"
  end

  -- 验证组件接口
  local Interface = require("ai.components.interface")
  local valid, err = Interface.validate_component(component)

  if not valid then
    return false, string.format("Invalid component '%s': %s", name, err)
  end

  -- 检查已注册
  if M._registry[name] then
    vim.notify(string.format("Component '%s' already registered, overwriting", name), vim.log.levels.WARN)
  end

  -- 注册
  M._registry[name] = component
  M._registry[name]._registered_at = os.time()

  return true, nil
end

--- 批量注册组件
---@param components table<string, AIComponent> 组件列表 { name = component }
---@return number, string[] registered_count, errors
function M.register_batch(components)
  local count = 0
  local errors = {}

  for name, component in pairs(components) do
    local ok, err = M.register(name, component)
    if ok then
      count = count + 1
    else
      table.insert(errors, err)
    end
  end

  return count, errors
end

--- 获取组件
---@param name string 组件名称
---@return AIComponent|nil
function M.get(name)
  return M._registry[name]
end

--- 检查组件是否已注册
---@param name string 组件名称
---@return boolean
function M.is_registered(name)
  return M._registry[name] ~= nil
end

--- 获取所有已注册组件的列表（快速：无网络请求）
---@return table[] { name, category, description, installed, icon }
function M.list()
  local result = {}

  for name, comp in pairs(M._registry) do
    if type(comp) == "table" and comp.name then
      table.insert(result, {
        name = name,
        display_name = comp.display_name or name,
        category = comp.category or "unknown",
        description = comp.description or "",
        installed = comp.is_installed(),
        icon = comp.icon or "📦",
        -- get_version_info 延迟到预览时调用，避免阻塞列表加载
      })
    end
  end

  -- 按 name 排序
  table.sort(result, function(a, b)
    return a.name < b.name
  end)

  return result
end

--- 获取已安装的组件列表
---@return table[]
function M.list_installed()
  local all = M.list()
  return vim.tbl_filter(function(c)
    return c.installed
  end, all)
end

--- 获取未安装的组件列表
---@return table[]
function M.list_uninstalled()
  local all = M.list()
  return vim.tbl_filter(function(c)
    return not c.installed
  end, all)
end

--- 获取需要更新的组件列表
---@return AIComponent[]
function M.list_outdated()
  local installed = M.list_installed()
  local ok, Switcher = pcall(require, "ai.components.switcher")
  if not ok then
    return {}
  end
  return vim.tbl_filter(function(c)
    local version_info = Switcher.get_version_cache(c.name)
    return version_info and version_info.status == "outdated"
  end, installed)
end

--- 获取组件数量
---@return number
function M.count()
  return vim.tbl_count(M._registry)
end

--- 清空注册表（用于测试）
function M.clear()
  M._registry = {}
end

--- 获取注册时间
---@param name string 组件名称
---@return number|nil timestamp
function M.get_registered_at(name)
  local comp = M.get(name)
  if comp and comp._registered_at then
    return comp._registered_at
  end
  return nil
end

--- Check if component is cached (per D-11)
--- Checks: 1) Component is_cached method, 2) Deployments state, 3) Cache directory
---@param name string Component name
---@return boolean
function M.is_cached(name)
  local comp = M.get(name)
  if not comp then
    return false
  end

  -- Check if component implements is_cached
  if comp.is_cached and type(comp.is_cached) == "function" then
    return comp.is_cached()
  end

  -- Fallback: check deployments state
  local status = Deployments.get_deployment_status(name)
  if status and status.cached_at then
    return true
  end

  -- Fallback: check cache directory
  local Manager = require("ai.components.manager")
  return vim.fn.isdirectory(Manager.get_cache_path(name)) == 1
end

--- Get cached component version (per D-11)
---@param name string Component name
---@return string|nil
function M.get_cache_version(name)
  local comp = M.get(name)
  if not comp then
    return nil
  end

  -- Check if component implements get_cache_version
  if comp.get_cache_version and type(comp.get_cache_version) == "function" then
    return comp.get_cache_version()
  end

  -- Fallback: check deployments state
  local status = Deployments.get_deployment_status(name)
  return status and status.cache_version
end

--- Check if component is deployed to a specific target
---@param name string Component name
---@param target string Target tool name
---@return boolean
function M.is_deployed_to(name, target)
  return Deployments.is_deployed_to(name, target)
end

--- Get list of cached components
---@return table[]
function M.list_cached()
  local all = M.list()
  return vim.tbl_filter(function(c)
    return M.is_cached(c.name)
  end, all)
end

--- Validate consistency between switcher and deployments state (per D-14)
--- Cross-references switcher state with deployments records
---@return table { consistent: boolean, issues: string[] }
function M.validate_state_consistency()
  local ok, Switcher = pcall(require, "ai.components.switcher")
  if not ok then
    return {
      consistent = false,
      issues = { "Failed to load switcher module" },
    }
  end

  local issues = {}

  local tool_assignments = Switcher.load_state() -- { tools = { claude = "ecc", ... } }
  local deployment_records = Deployments.load_state() -- { deployments = { ecc = { deployed_to = {...} } } }

  -- Check: if switcher says tool uses component, component must be deployed to that tool
  for tool, component in pairs(tool_assignments.active or {}) do
    if not Deployments.is_deployed_to(component, tool) then
      table.insert(
        issues,
        string.format("状态不一致：%s 分配给 %s 但 %s 未部署到 %s", tool, component, component, tool)
      )
    end
  end

  -- Check: if component is deployed to a tool, but switcher assigns different component
  for component_name, record in pairs(deployment_records.deployments or {}) do
    for target, _ in pairs(record.deployed_to or {}) do
      local assigned = tool_assignments.active and tool_assignments.active[target]
      if assigned and assigned ~= component_name then
        table.insert(
          issues,
          string.format("状态不一致：%s 已部署到 %s，但 switcher 分配了 %s", component_name, target, assigned)
        )
      end
    end
  end

  return {
    consistent = #issues == 0,
    issues = issues,
  }
end

return M
