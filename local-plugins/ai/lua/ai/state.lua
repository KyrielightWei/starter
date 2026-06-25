-- lua/ai/state.lua
-- State Manager Module
--
-- 提供统一的状态管理接口，支持订阅模式

local M = {}

-- 私有状态
local state = {
  provider = nil,
  model = nil,
  template_versions = {}, -- 模版版本选择：{ tool: version }
}

-- 订阅者列表（使用表存储，支持删除后重新分配）
local subscribers = {}
local next_id = 1

----------------------------------------------------------------------
-- get(): 获取当前状态
-- 返回浅拷贝：provider/model 是字符串（不可变），template_versions 是 deepcopy。
-- 修改返回值不会影响全局状态。
-- @return table: { provider: string|nil, model: string|nil, template_versions: table }
----------------------------------------------------------------------
function M.get()
  return {
    provider = state.provider,
    model = state.model,
    -- #15 修复: 使用 deepcopy 避免外部修改影响全局状态
    template_versions = vim.deepcopy(state.template_versions),
  }
end

----------------------------------------------------------------------
-- set(provider, model): 更新状态并通知订阅者
-- @param provider string: Provider name
-- @param model string: Model name
----------------------------------------------------------------------
function M.set(provider, model)
  state.provider = provider
  state.model = model

  -- 通知所有订阅者
  for _, callback in pairs(subscribers) do
    local ok, err = pcall(callback, M.get())
    if not ok then
      vim.notify(string.format("State subscriber error: %s", err), vim.log.levels.WARN)
    end
  end
end

----------------------------------------------------------------------
-- subscribe(callback): 注册状态变更监听器
-- @param callback function: 回调函数，接收新状态作为参数
-- @return number: 订阅者 ID（可用于取消订阅）
----------------------------------------------------------------------
function M.subscribe(callback)
  if type(callback) ~= "function" then
    error("subscribe() requires a function argument")
  end

  local id = next_id
  subscribers[id] = callback
  next_id = next_id + 1
  return id
end

----------------------------------------------------------------------
-- unsubscribe(id): 取消订阅
-- @param id number: subscribe() 返回的 ID
----------------------------------------------------------------------
function M.unsubscribe(id)
  if subscribers[id] then
    subscribers[id] = nil
    return true
  end
  return false
end

----------------------------------------------------------------------
-- clear(): 清空数据状态（不重置订阅者，避免 setup 时注册的回调丢失）
----------------------------------------------------------------------
function M.clear()
  state.provider = nil
  state.model = nil
  state.template_versions = {}
  -- H-01 修复：不清空 subscribers 和 next_id，保留已注册的回调
end

----------------------------------------------------------------------
-- _reset_for_tests(): 完全重置（包括订阅者，仅测试用）
----------------------------------------------------------------------
function M._reset_for_tests()
  state.provider = nil
  state.model = nil
  state.template_versions = {}
  subscribers = {}
  next_id = 1
end

----------------------------------------------------------------------
-- get_template_version(tool): 获取工具的模版版本
-- @param tool string: 工具名称 (opencode, claude_code, pi)
-- @return string: 当前版本，默认 "default"
----------------------------------------------------------------------
function M.get_template_version(tool)
  if not state.template_versions then
    return "default"
  end
  return state.template_versions[tool] or "default"
end

----------------------------------------------------------------------
-- set_template_version(tool, version): 设置工具的模版版本
-- @param tool string: 工具名称
-- @param version string: 版本名称
----------------------------------------------------------------------
function M.set_template_version(tool, version)
  state.template_versions = state.template_versions or {}
  state.template_versions[tool] = version

  -- 通知订阅者
  for _, callback in pairs(subscribers) do
    local ok, err = pcall(callback, M.get())
    if not ok then
      vim.notify(string.format("State subscriber error: %s", err), vim.log.levels.WARN)
    end
  end
end

return M
