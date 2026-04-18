-- lua/ai/gsd.lua
-- GSD shim: 向后兼容层，重定向到 components/gsd

local M = {}

--- 获取 GSD 组件实例
---@return AIComponent|nil
local function get_component()
  local ok, comp = pcall(require, "ai.components.gsd")
  if ok and comp then
    return comp
  end
  return nil
end

--- 检测 GSD 是否已安装
---@return boolean
function M.is_installed()
  local comp = get_component()
  if comp then
    return comp.is_installed()
  end
  -- 简单检测
  return vim.fn.executable("npx") == 1
end

--- 获取 GSD 安装状态
---@return table|nil
function M.get_status()
  local comp = get_component()
  if comp then
    return comp.get_status()
  end
  return nil
end

--- 获取安装命令提示
---@return string
function M.install_hint()
  local comp = get_component()
  if comp then
    return comp.install_hint()
  end
  return "npx -y get-shit-done-cc@latest"
end

--- 安装 GSD
---@param opts table|nil
---@param on_progress function|nil
---@return boolean, string
function M.install(opts, on_progress)
  local comp = get_component()
  if comp then
    return comp.install(opts, on_progress)
  end
  return false, "Component system not loaded"
end

--- 显示 GSD 状态
function M.show_status()
  local comp = get_component()
  if comp then
    comp.show_status()
  else
    local status = M.is_installed()
    if status then
      vim.notify("GSD available (npx)", vim.log.levels.INFO)
    else
      vim.notify("GSD requires npx", vim.log.levels.WARN)
    end
  end
end

return M
