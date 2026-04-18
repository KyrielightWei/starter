-- lua/ai/components/discovery.lua
-- 自动发现机制：扫描目录和自动加载组件

local M = {}

--- 组件目录列表（按优先级）
local COMPONENT_DIRS = {
  vim.fn.stdpath("config") .. "/lua/ai/components", -- 项目内组件（最高优先）
  vim.fn.expand("~/.local/share/nvim/ai-components"), -- 用户自定义组件
}

--- 排除的目录/文件名（非组件）
local EXCLUDE_NAMES = {
  "init.lua",
  "interface.lua",
  "registry.lua",
  "discovery.lua",
  "version.lua",
  "switcher.lua",
  "actions.lua",
  "picker.lua",
  "previewer.lua",
  "types.lua",
  "_template.lua",
}

--- 扫描单个目录
---@param dir_path string 目录路径
---@return table[] { name, path }
local function scan_dir(dir_path)
  local result = {}

  if vim.fn.isdirectory(dir_path) ~= 1 then
    return result
  end

  local entries = vim.fn.readdir(dir_path)

  for _, entry in ipairs(entries) do
    local full_path = dir_path .. "/" .. entry

    -- 排除非组件
    local is_excluded = false
    for _, exclude in ipairs(EXCLUDE_NAMES) do
      if entry == exclude then
        is_excluded = true
        break
      end
    end

    if not is_excluded then
      -- 检查是否是目录（且有 init.lua）
      if vim.fn.isdirectory(full_path) == 1 then
        local init_path = full_path .. "/init.lua"
        if vim.fn.filereadable(init_path) == 1 then
          table.insert(result, {
            name = entry,
            path = init_path,
            module = "ai.components." .. entry,
          })
        end
      end
    end
  end

  return result
end

--- 扫描所有组件目录
---@return table[]
function M.scan_all_dirs()
  local all = {}

  for _, dir in ipairs(COMPONENT_DIRS) do
    local found = scan_dir(dir)
    vim.list_extend(all, found)
  end

  -- 去重（按 name）
  local seen = {}
  local unique = {}
  for _, item in ipairs(all) do
    if not seen[item.name] then
      seen[item.name] = true
      table.insert(unique, item)
    end
  end

  return unique
end

--- 自动加载发现的组件
---@return number, string[] loaded_count, errors
function M.auto_load()
  local Registry = require("ai.components.registry")
  local found = M.scan_all_dirs()
  local loaded = 0
  local errors = {}

  for _, item in ipairs(found) do
    -- 尝试加载模块
    local ok, component = pcall(require, item.module)

    if ok and component and type(component) == "table" then
      -- 注册到 Registry
      local reg_ok, reg_err = Registry.register(item.name, component)

      if reg_ok then
        loaded = loaded + 1
      else
        table.insert(errors, string.format("%s: %s", item.name, reg_err))
      end
    else
      -- 加载失败
      local err_msg = ok and "not a table" or tostring(component)
      table.insert(errors, string.format("%s: failed to load - %s", item.name, err_msg))
    end
  end

  if loaded > 0 then
    vim.notify(string.format("Discovered %d component(s)", loaded), vim.log.levels.INFO)
  end

  if #errors > 0 then
    vim.notify(string.format("Component discovery errors:\n%s", table.concat(errors, "\n")), vim.log.levels.WARN)
  end

  return loaded, errors
end

--- 添加额外的组件目录
---@param dir_path string 目录路径
function M.add_dir(dir_path)
  if vim.fn.isdirectory(dir_path) == 1 then
    table.insert(COMPONENT_DIRS, dir_path)
  end
end

--- 获取当前配置的组件目录列表
---@return string[]
function M.get_dirs()
  return COMPONENT_DIRS
end

--- 重新扫描（清除 Registry 后重新加载）
---@return number, string[]
function M.reload()
  local Registry = require("ai.components.registry")
  Registry.clear()

  return M.auto_load()
end

return M
