-- lua/ai/components/picker.lua
-- fzf-lua 选择器 UI：核心交互入口

local M = {}

--- 检查 fzf-lua 是否可用
local function has_fzf_lua()
  local ok, _ = pcall(require, "fzf-lua")
  return ok
end

--- 构建选择器条目（快速：不触发网络请求）
---@return table { display_line = component_name }
function M.build_entries()
  local Registry = require("ai.components.registry")
  local Switcher = require("ai.components.switcher")
  local components = Registry.list()
  local entries = {}

  for _, comp in ipairs(components) do
    local icon = comp.installed and "✓" or "○"
    -- 从缓存读取版本状态，不触发网络请求
    local cached = Switcher.get_version_cache(comp.name)
    local status_icon = ""
    if cached then
      if cached.status == "outdated" then
        status_icon = " ⚠️"
      end
    end

    local line = string.format(
      "%s %s %s │ %s │ %s",
      icon,
      comp.icon or "📦",
      comp.display_name,
      comp.category or "unknown",
      status_icon
    )

    entries[line] = comp.name
  end

  return entries
end

--- 构建顶部 header（显示工具分配）
---@return string
function M.build_header()
  local Switcher = require("ai.components.switcher")
  local assignments = Switcher.get_all()

  local lines = {
    "Tool Assignments:",
  }

  for tool, comp_name in pairs(assignments) do
    table.insert(lines, string.format("  %s → %s", tool, comp_name))
  end

  table.insert(lines, "")
  table.insert(
    lines,
    "Keys: [Enter] Actions │ [i] Install │ [u] Update │ [x] Uninstall │ [s] Switch │ [v] Version │ [r] Refresh"
  )

  return table.concat(lines, "\n")
end

--- 打开选择器（主入口）
function M.open()
  if not has_fzf_lua() then
    vim.notify("fzf-lua not installed. Install with: Lazy.nvim fzf-lua", vim.log.levels.ERROR)
    return
  end

  local fzf = require("fzf-lua")
  local Registry = require("ai.components.registry")
  local Actions = require("ai.components.actions")
  local Previewer = require("ai.components.previewer")

  local entries = M.build_entries()

  -- 后台异步刷新远程版本（不阻塞 UI）
  vim.defer_fn(function()
    local Switcher = require("ai.components.switcher")
    Switcher.refresh_versions_async()
  end, 500)

  -- 如果没有组件
  if vim.tbl_isempty(entries) then
    vim.notify("No components registered", vim.log.levels.WARN)
    return
  end

  -- 确保有条目可显示
  local display_lines = {}
  for line, _ in pairs(entries) do
    table.insert(display_lines, line)
  end
  table.sort(display_lines)

  fzf.fzf_exec(display_lines, {
    prompt = " AI Components > ",
    winopts = {
      title = " AI Component Manager ",
      title_pos = "center",
      height = 0.6,
      width = 0.8,
      row = 0.2,
      border = "rounded",
      preview = {
        layout = "right",
        width = 0.4,
        fn = function(_, preview_win, fzf_data, _preview_scroll)
          if not fzf_data or #fzf_data < 1 then
            return ""
          end
          local Previewer2 = require("ai.components.previewer")
          local comp_name = entries[fzf_data[1]]
          return Previewer2.build_preview(comp_name)
        end,
      },
    },
    fzf_opts = {
      ["--header"] = M.build_header(),
    },
    actions = {
      -- Enter: 打开操作菜单
      ["default"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local comp_name = entries[selected[1]]
        M.open_actions_menu(comp_name)
      end,

      -- i: 安装
      ["ctrl-i"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local comp_name = entries[selected[1]]
        Actions.install(comp_name)
        M.open() -- 重新打开以刷新状态
      end,

      -- u: 更新
      ["ctrl-u"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local comp_name = entries[selected[1]]
        Actions.update(comp_name)
        M.open()
      end,

      -- x: 卸载
      ["ctrl-x"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local comp_name = entries[selected[1]]
        Actions.uninstall(comp_name)
        M.open()
      end,

      -- s: 切换工具
      ["ctrl-s"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local comp_name = entries[selected[1]]
        M.open_switch_menu(comp_name)
      end,

      -- v: 版本详情
      ["ctrl-v"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local comp_name = entries[selected[1]]
        Previewer.show_version_detail(comp_name)
      end,

      -- r: 刷新
      ["ctrl-r"] = function()
        local Discovery = require("ai.components.discovery")
        Discovery.reload()
        M.open()
      end,
    },
  })
end

--- 打开二级操作菜单
---@param component_name string 组件名
function M.open_actions_menu(component_name)
  if not has_fzf_lua() then
    vim.notify("fzf-lua not installed", vim.log.levels.ERROR)
    return
  end

  local fzf = require("fzf-lua")
  local Registry = require("ai.components.registry")
  local Actions = require("ai.components.actions")
  local Previewer = require("ai.components.previewer")
  local comp = Registry.get(component_name)

  if not comp then
    return
  end

  local actions = {
    {
      "Install",
      function()
        Actions.install(component_name)
      end,
    },
    {
      "Update",
      function()
        Actions.update(component_name)
      end,
    },
    {
      "Uninstall",
      function()
        Actions.uninstall(component_name)
      end,
    },
    {
      "Switch Tool Assignment",
      function()
        M.open_switch_menu(component_name)
      end,
    },
    {
      "View Version Details",
      function()
        Previewer.show_version_detail(component_name)
      end,
    },
    {
      "Open Config Directory",
      function()
        Actions.open_config_dir(component_name)
      end,
    },
  }

  local display_lines = vim.tbl_map(function(a)
    return a[1]
  end, actions)

  fzf.fzf_exec(display_lines, {
    prompt = string.format(" Actions for %s > ", comp.display_name or component_name),
    winopts = {
      height = 0.4,
      width = 0.5,
      row = 0.3,
      border = "rounded",
    },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local action_name = selected[1]
        for _, action in ipairs(actions) do
          if action[1] == action_name then
            action[2]()
            break
          end
        end
      end,
    },
  })
end

--- 打开工具切换选择器
---@param component_name string 组件名
function M.open_switch_menu(component_name)
  if not has_fzf_lua() then
    vim.notify("fzf-lua not installed", vim.log.levels.ERROR)
    return
  end

  local fzf = require("fzf-lua")
  local Registry = require("ai.components.registry")
  local Switcher = require("ai.components.switcher")
  local comp = Registry.get(component_name)

  if not comp then
    return
  end

  local tools = comp.supported_targets or { "claude", "opencode" }
  local current = Switcher.get_all()

  local entries = {}
  for _, tool in ipairs(tools) do
    local active_for_this = current[tool] == component_name
    local icon = active_for_this and "✓" or "○"
    local line = string.format("%s %s (current: %s)", icon, tool, current[tool] or "none")
    entries[line] = tool
  end

  local display_lines = {}
  for line, _ in pairs(entries) do
    table.insert(display_lines, line)
  end
  table.sort(display_lines)

  fzf.fzf_exec(display_lines, {
    prompt = string.format(" Switch %s to tool > ", comp.display_name or component_name),
    winopts = {
      height = 0.3,
      width = 0.4,
      border = "rounded",
    },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local tool = entries[selected[1]]
        Switcher.switch(tool, component_name)
      end,
    },
  })
end

return M