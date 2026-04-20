-- lua/ai/components/switcher.lua
-- 工具-组件切换状态管理

local M = {}

--- 状态文件路径
local STATE_PATH = vim.fn.expand("~/.local/state/nvim/ai_component_state.lua")

--- 默认状态
local DEFAULT_STATE = {
  active = {
    opencode = "ecc",
    claude = "ecc",
  },
  last_check = nil,
  versions = {},
}

--- 状态缓存
---@type table|nil
M._state_cache = nil

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
---@return table
function M.load_state()
  -- 使用缓存
  if M._state_cache then
    return M._state_cache
  end

  -- 尝试从文件读取
  if vim.fn.filereadable(STATE_PATH) == 1 then
    local content = vim.fn.readfile(STATE_PATH)
    if #content > 0 then
      local code = table.concat(content, "\n")

      -- 尝试执行 Lua 代码
      local ok, state = pcall(function()
        return load(code)()
      end)

      if ok and type(state) == "table" then
        -- 合并默认值（确保字段完整）
        state = vim.tbl_deep_extend("keep", state, DEFAULT_STATE)
        M._state_cache = state
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

  -- 更新时间戳
  state.last_check = os.date("%Y-%m-%dT%H:%M:%S")

  -- 转换为 Lua 代码格式
  local lines = {
    "return {",
    "  active = {",
  }

  for tool, comp_name in pairs(state.active) do
    table.insert(lines, string.format('    %s = "%s",', tool, comp_name))
  end

  table.insert(lines, "  },")

  if state.last_check then
    table.insert(lines, string.format('  last_check = "%s",', state.last_check))
  end

  if state.versions then
    table.insert(lines, "  versions = {")
    for comp_name, v_info in pairs(state.versions) do
      table.insert(lines, string.format("    %s = {", comp_name))
      if v_info.current then
        table.insert(lines, string.format('      current = "%s",', v_info.current))
      end
      if v_info.latest then
        table.insert(lines, string.format('      latest = "%s",', v_info.latest))
      end
      if v_info.status then
        table.insert(lines, string.format('      status = "%s",', v_info.status))
      end
      table.insert(lines, "    },")
    end
    table.insert(lines, "  },")
  end

  table.insert(lines, "}")
  table.insert(lines, "")

  -- 写入文件
  vim.fn.writefile(lines, STATE_PATH)

  -- 更新缓存
  M._state_cache = state
end

--- 切换工具使用的组件
---@param tool string 工具名（如 "opencode", "claude"）
---@param component_name string 组件名（如 "ecc", "gsd"）
---@return boolean
function M.switch(tool, component_name)
  if not tool or not component_name then
    return false
  end

  local state = M.load_state()
  state.active[tool] = component_name

  M.save_state(state)

  vim.notify(string.format("Switched %s to use %s", tool, component_name), vim.log.levels.INFO)

  return true
end

--- 获取工具当前使用的组件
---@param tool string 工具名
---@return string|nil component_name
function M.get_active(tool)
  local state = M.load_state()
  return state.active[tool]
end

--- 获取所有工具的当前组件分配
---@return table<string, string> { tool = component }
function M.get_all()
  local state = M.load_state()
  return state.active
end

--- 获取使用指定组件的所有工具
---@param component_name string 组件名
---@return string[] tools
function M.get_tools_using(component_name)
  local state = M.load_state()
  local tools = {}

  for tool, comp in pairs(state.active) do
    if comp == component_name then
      table.insert(tools, tool)
    end
  end

  return tools
end

--- 更新组件版本信息缓存
---@param component_name string 组件名
---@param version_info VersionInfo 版本信息
function M.update_version_cache(component_name, version_info)
  local state = M.load_state()
  state.versions[component_name] = {
    current = version_info.current,
    latest = version_info.latest,
    status = version_info.status,
  }
  M.save_state(state)
end

--- 获取缓存的组件版本信息
---@param component_name string 组件名
---@return table|nil version_info
function M.get_version_cache(component_name)
  local state = M.load_state()
  return state.versions[component_name]
end

--- 清除缓存（强制重新读取）
function M.clear_cache()
  M._state_cache = nil
end

--- 重置状态到默认值
function M.reset()
  M._state_cache = nil

  if vim.fn.filereadable(STATE_PATH) == 1 then
    vim.fn.delete(STATE_PATH)
  end

  M.save_state(DEFAULT_STATE)
end

--- 异步刷新所有已注册组件的远程版本信息
--- 在后台查询，完成后更新 switcher 版本缓存
function M.refresh_versions_async()
  local Registry = require("ai.components.registry")
  local Version = require("ai.components.version")
  local components = Registry.list()

  local function refresh_one(comp_full)
    if comp_full.npm_package and vim.fn.executable("npm") == 1 then
      Version.get_latest_npm_version_async(comp_full.npm_package, function(remote_version)
        local cached = M.get_version_cache(comp_full.name) or {}
        local local_version = cached.current or "unknown"
        local status = Version.compare_versions(local_version, remote_version or local_version)

        M.update_version_cache(comp_full.name, {
          current = cached.current,
          latest = remote_version,
          status = status,
        })
      end)
    elseif comp_full.repo_url then
      Version.get_latest_git_version_async(comp_full.repo_url, function(remote_hash)
        local cached = M.get_version_cache(comp_full.name) or {}
        local local_hash = cached.current
        local status = "unknown"
        if local_hash and remote_hash then
          status = local_hash == remote_hash and "current" or "outdated"
        end

        M.update_version_cache(comp_full.name, {
          current = local_hash,
          latest = remote_hash,
          status = status,
        })
      end)
    end
  end

  for _, comp in ipairs(components) do
    local comp_full = Registry.get(comp.name)
    if comp_full then
      refresh_one(comp_full)
    end
  end

  vim.cmd("doautocmd User RemoteVersionRefreshed")
end

return M
