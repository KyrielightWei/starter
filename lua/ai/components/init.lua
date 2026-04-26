-- lua/ai/components/init.lua
-- 组件管理器入口：整合所有模块，提供统一 API

local M = {}

--- 模块版本
M.version = "1.0.0"

--- 是否已初始化
M._initialized = false

--- 初始化组件管理器
---@param opts table|nil 选项
---@return boolean
function M.setup(opts)
  opts = opts or {}

  if M._initialized then
    return true
  end

  -- 加载子模块
  local Interface = require("ai.components.interface")
  local Registry = require("ai.components.registry")
  local Discovery = require("ai.components.discovery")
  local Switcher = require("ai.components.switcher")
  local Actions = require("ai.components.actions")
  local Picker = require("ai.components.picker")
  local Version = require("ai.components.version")

  -- 自动发现并注册组件
  if opts.auto_discover ~= false then
    Discovery.auto_load()
  end

  -- 注册命令
  M.register_commands()

  -- 注册 keymap
  if opts.keymap ~= false then
    M.register_keymap(opts.keymap_opts or {})
  end

  M._initialized = true

  vim.notify(
    string.format("AI Component Manager initialized. %d components registered.", Registry.count()),
    vim.log.levels.INFO
  )

  return true
end

--- 注册命令
function M.register_commands()
  -- 主命令：打开选择器
  vim.api.nvim_create_user_command("AIComponents", function()
    local Picker = require("ai.components.picker")
    Picker.open()
  end, {
    desc = "Open AI Component Manager (fzf-lua picker)",
  })

  -- 快捷命令（可选）
  vim.api.nvim_create_user_command("AIComponentList", function()
    local Registry = require("ai.components.registry")
    local list = Registry.list()

    local lines = { "Registered Components:" }
    for _, comp in ipairs(list) do
      local icon = comp.installed and "✓" or "○"
      table.insert(lines, string.format("%s %s (%s) - %s", icon, comp.display_name, comp.category, comp.description))
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "List all registered AI components",
  })

  vim.api.nvim_create_user_command("AIComponentInstall", function(args)
    local Actions = require("ai.components.actions")
    local component_name = args.args

    if component_name == "" then
      vim.notify("Usage: :AIComponentInstall <component_name>", vim.log.levels.WARN)
      return
    end

    Actions.install(component_name)
  end, {
    desc = "Install an AI component",
    nargs = 1,
  })

  vim.api.nvim_create_user_command("AIComponentUpdate", function(args)
    local Actions = require("ai.components.actions")
    local component_name = args.args

    if component_name == "" then
      Actions.update_all()
    else
      Actions.update(component_name)
    end
  end, {
    desc = "Update AI component(s)",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("AIComponentSwitch", function(args)
    local parts = vim.split(args.args, " ")
    local Switcher = require("ai.components.switcher")

    if #parts < 2 then
      vim.notify("Usage: :AIComponentSwitch <tool> <component>", vim.log.levels.WARN)
      return
    end

    local tool = parts[1]
    local component = parts[2]

    Switcher.switch(tool, component)
  end, {
    desc = "Switch tool to use a different component",
    nargs = "+",
  })

  vim.api.nvim_create_user_command("AIComponentRefresh", function()
    local Discovery = require("ai.components.discovery")
    Discovery.reload()
    vim.notify("Components refreshed", vim.log.levels.INFO)
  end, {
    desc = "Refresh component discovery and reload",
  })
end

--- 注册 keymap
---@param opts table|nil keymap 选项
function M.register_keymap(opts)
  opts = opts or {}

  local keymap = opts.keymap or "<leader>kc"
  local mode = opts.mode or "n"

  vim.keymap.set(mode, keymap, function()
    local Picker = require("ai.components.picker")
    Picker.open()
  end, {
    desc = "Open AI Component Manager",
    noremap = true,
    silent = true,
  })
end

--- ============================================
--- 代理 API（直接调用子模块）
--- ============================================

--- 注册组件
---@param name string
---@param component table
---@return boolean, string|nil
function M.register(name, component)
  local Registry = require("ai.components.registry")
  return Registry.register(name, component)
end

--- 获取组件列表
---@return table[]
function M.list()
  local Registry = require("ai.components.registry")
  return Registry.list()
end

--- 获取组件
---@param name string
---@return table|nil
function M.get(name)
  local Registry = require("ai.components.registry")
  return Registry.get(name)
end

--- 安装组件
---@param name string
---@param opts table|nil
---@return boolean, string
function M.install(name, opts)
  local Actions = require("ai.components.actions")
  return Actions.install(name, opts)
end

--- 更新组件
---@param name string
---@param opts table|nil
---@return boolean, string
function M.update(name, opts)
  local Actions = require("ai.components.actions")
  return Actions.update(name, opts)
end

--- 卸载组件
---@param name string
---@param opts table|nil
---@return boolean, string
function M.uninstall(name, opts)
  local Actions = require("ai.components.actions")
  return Actions.uninstall(name, opts)
end

--- 切换工具组件
---@param tool string
---@param component_name string
---@return boolean
function M.switch(tool, component_name)
  local Switcher = require("ai.components.switcher")
  return Switcher.switch(tool, component_name)
end

--- 打开选择器
function M.open_picker()
  local Picker = require("ai.components.picker")
  Picker.open()
end

--- 刷新组件
function M.refresh()
  local Discovery = require("ai.components.discovery")
  return Discovery.reload()
end

--- 验证组件接口
---@param component table
---@return boolean, string|nil
function M.validate(component)
  local Interface = require("ai.components.interface")
  return Interface.validate_component(component)
end

--- 获取接口规范摘要
---@return string[]
function M.interface_summary()
  local Interface = require("ai.components.interface")
  return Interface.get_interface_summary()
end

--- 健康检查（用于 :checkhealth）
---@return table[]
function M.health_check()
  local Registry = require("ai.components.registry")
  local list = Registry.list()
  local results = {}

  for _, comp_info in ipairs(list) do
    local comp = Registry.get(comp_info.name)
    if comp and comp.health_check then
      local health = comp.health_check()
      table.insert(results, {
        name = comp_info.name,
        display_name = comp_info.display_name,
        status = health.status,
        message = health.message,
      })
    end
  end

  return results
end

return M
