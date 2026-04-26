-- lua/ai/ecc.lua
-- ECC shim: 向后兼容层，重定向到 components/ecc
--
-- 此文件保留向后兼容性，所有原有调用方式继续工作。
-- 实际实现已迁移到 lua/ai/components/ecc/

local M = {}

--- 获取 ECC 组件实例
---@return AIComponent
local function get_component()
  local ok, comp = pcall(require, "ai.components.ecc")
  if ok and comp then
    return comp
  end
  -- 如果组件系统未加载，返回空实现
  return nil
end

--- 检测 ECC 是否已安装
---@return boolean
function M.is_installed()
  local comp = get_component()
  if comp then
    return comp.is_installed()
  end
  -- 简单检测
  local state_path = vim.fn.expand("~/.claude/ecc/install-state.json")
  return vim.fn.filereadable(state_path) == 1
end

--- 获取 ECC 安装状态
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
  return "git clone https://github.com/affaan-m/everything-claude-code.git /tmp/ecc --depth=1 && cd /tmp/ecc && npm install && node scripts/install-apply.js --profile developer"
end

--- 安装 ECC
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

--- 显示 ECC 状态
function M.show_status()
  local comp = get_component()
  if comp then
    comp.show_status()
  else
    local status = M.get_status()
    if status then
      vim.notify("ECC installed: " .. tostring(status.installed_at), vim.log.levels.INFO)
    else
      vim.notify("ECC not installed", vim.log.levels.WARN)
    end
  end
end

--- 格式化 ECC 状态通知行
---@param ecc table|nil
---@return string[]
function M.format_notification(ecc)
  local comp = get_component()
  if comp then
    local Status = require("ai.components.ecc.status")
    return Status.format_notification(ecc)
  end

  local lines = {}
  if ecc then
    table.insert(lines, "🔧 ECC Framework:")
    if ecc.repo_version then
      table.insert(lines, "  版本: " .. ecc.repo_version)
    end
  else
    table.insert(lines, "⚠️  ECC 未安装")
    table.insert(lines, "  安装: " .. M.install_hint())
  end
  return lines
end

--- 获取 ECC 状态路径
---@return string
function M.state_path()
  local state_path = vim.fn.expand("~/.claude/ecc/install-state.json")
  return state_path
end

--- 打开安装 UI
function M.open_installer()
  -- 重定向到组件选择器
  local ok, Picker = pcall(require, "ai.components.picker")
  if ok then
    Picker.open()
  else
    vim.notify("Run :AIComponents to open the component manager", vim.log.levels.INFO)
  end
end

return M
