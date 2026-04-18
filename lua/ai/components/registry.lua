-- lua/ai/components/registry.lua
-- 组件注册表（类似 providers.lua 的注册模式）

local M = {}

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

--- 获取所有已注册组件的列表
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
        version_info = comp.get_version_info(),
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
---@return table[]
function M.list_outdated()
  local installed = M.list_installed()
  return vim.tbl_filter(function(c)
    return c.version_info and c.version_info.status == "outdated"
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

return M
