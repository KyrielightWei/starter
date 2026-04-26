-- lua/ai/components/deployments.lua
-- 部署状态文件管理

local M = {}

--- 状态文件路径 (per D-01, D-13)
local STATE_PATH = vim.fn.expand("~/.local/share/nvim/ai_components/deployments.json")

--- 默认状态
local DEFAULT_STATE = {
  version = 1,
  deployments = {},
}

--- 状态缓存
---@type table|nil
M._state_cache = nil

--- 上次文件修改时间 (WR-02: cache invalidation)
---@type number|nil
local last_mtime = nil

--- 获取状态文件路径
---@return string
function M.state_path()
  return STATE_PATH
end

--- 确保状态目录存在
local function ensure_state_dir()
  local dir = vim.fn.fnamemodify(STATE_PATH, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

--- 加载状态
--- 使用缓存，处理损坏文件备份和恢复 (per T-02-03)
---@return table
function M.load_state()
  -- WR-02: Check file modification time for cache invalidation
  local current_mtime = vim.fn.getftime(STATE_PATH)
  if M._state_cache and last_mtime and current_mtime == last_mtime then
    return M._state_cache
  end

  -- 尝试从文件读取
  if vim.fn.filereadable(STATE_PATH) == 1 then
    local content = vim.fn.readfile(STATE_PATH)
    if #content > 0 then
      local json_str = table.concat(content, "\n")

      -- 尝试解析 JSON
      local ok, state = pcall(vim.json.decode, json_str)

      if not ok then
        -- 备份损坏文件
        vim.fn.rename(STATE_PATH, STATE_PATH .. ".corrupted")
        vim.notify("deployments.json 已损坏，已备份并重建", vim.log.levels.WARN)
        M._state_cache = DEFAULT_STATE
        return DEFAULT_STATE
      end

      if type(state) == "table" then
        -- 合并默认值（确保字段完整）
        state = vim.tbl_deep_extend("keep", state, DEFAULT_STATE)
        M._state_cache = state
        -- WR-02: Update last_mtime after successful load
        last_mtime = current_mtime
        return state
      end
    end
  end

  -- 返回默认状态
  M._state_cache = DEFAULT_STATE
  return DEFAULT_STATE
end

--- 保存状态
---@param state table|nil 状态（nil 时保存缓存）
function M.save_state(state)
  state = state or M._state_cache or DEFAULT_STATE

  ensure_state_dir()

  -- 编码 JSON
  local json_str = vim.json.encode(state)

  -- 写入文件
  vim.fn.writefile({ json_str }, STATE_PATH)

  -- 更新缓存
  M._state_cache = state
end

--- 记录部署
---@param component_name string 组件名
---@param target string 目标工具
---@param method string 部署方式 ("symlink" | "copy")
---@return boolean
function M.record_deployment(component_name, target, method)
  if not component_name or not target or not method then
    return false
  end

  local state = M.load_state()

  -- 确保组件条目存在
  state.deployments[component_name] = state.deployments[component_name] or {}
  state.deployments[component_name].deployed_to = state.deployments[component_name].deployed_to or {}

  -- 记录部署信息
  state.deployments[component_name].deployed_to[target] = {
    deployed_at = os.date("%Y-%m-%dT%H:%M:%SZ"),
    method = method,
  }

  M.save_state(state)

  return true
end

--- 记录缓存状态 (per M-06: 设置 last_cache_update)
---@param component_name string 组件名
---@param cache_version string 缓存版本
---@return boolean
function M.record_cache(component_name, cache_version)
  if not component_name then
    return false
  end

  local state = M.load_state()

  -- 确保组件条目存在
  state.deployments[component_name] = state.deployments[component_name] or {}

  -- 记录缓存信息
  state.deployments[component_name].cached_at = os.date("%Y-%m-%dT%H:%M:%SZ")
  state.deployments[component_name].cache_version = cache_version
  -- M-06: 设置 last_cache_update 时间戳
  state.deployments[component_name].last_cache_update = os.date("%Y-%m-%dT%H:%M:%SZ")

  M.save_state(state)

  return true
end

--- 清除部署记录
---@param component_name string 组件名
---@param target string 目标工具
---@return boolean
function M.clear_deployment(component_name, target)
  if not component_name or not target then
    return false
  end

  local state = M.load_state()

  -- 如果存在部署记录，则清除
  if
    state.deployments[component_name]
    and state.deployments[component_name].deployed_to
    and state.deployments[component_name].deployed_to[target]
  then
    state.deployments[component_name].deployed_to[target] = nil
    M.save_state(state)
  end

  return true
end

--- 获取组件部署状态
---@param component_name string 组件名
---@return table|nil
function M.get_deployment_status(component_name)
  local state = M.load_state()
  return state.deployments[component_name] or nil
end

--- 检查组件是否部署到指定目标
---@param component_name string 组件名
---@param target string 目标工具
---@return boolean
function M.is_deployed_to(component_name, target)
  local state = M.load_state()

  if
    state.deployments[component_name]
    and state.deployments[component_name].deployed_to
    and state.deployments[component_name].deployed_to[target]
  then
    return true
  end

  return false
end

--- 检查缓存是否过期 (per M-06)
--- 比较 last_cache_update 与 deployed_at，判断缓存是否在部署后更新
---@param component_name string 组件名
---@return boolean
function M.is_cache_stale(component_name)
  local state = M.load_state()

  local comp_record = state.deployments[component_name]
  if not comp_record then
    return false
  end

  local last_cache_update = comp_record.last_cache_update
  local deployed_to = comp_record.deployed_to

  -- 如果没有缓存更新记录或没有部署，则不算过期
  if not last_cache_update or not deployed_to then
    return false
  end

  -- 检查每个部署目标
  for target, info in pairs(deployed_to) do
    local deployed_at = info.deployed_at
    if deployed_at then
      -- 比较 ISO 8601 时间戳字符串
      -- 字符串比较适用于相同格式的时间戳
      if last_cache_update > deployed_at then
        return true
      end
    end
  end

  return false
end

--- 清除缓存（强制重新读取）
function M.clear_cache()
  M._state_cache = nil
  -- WR-02: Reset last_mtime when clearing cache
  last_mtime = nil
end

return M