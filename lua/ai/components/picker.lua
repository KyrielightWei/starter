-- lua/ai/components/picker.lua
-- fzf-lua 选择器 UI：核心交互入口
-- Per D-32 to D-47: Multi-line card view, header redesign, disabled actions

local M = {}

-- ANSI helper table per D-42, D-37
local ANSI = {
  reset = "\27[0m",
  bold = "\27[1m",
  dim = "\27[2m",
  gray = "\27[90m",
  green = "\27[32m",
  yellow = "\27[33m",
  red = "\27[31m",
}

-- WR-01 fix: Centralized ANSI stripping helper
--- Strip all ANSI escape sequences from a string
---@param str string Input string with potential ANSI codes
---@return string Clean string without ANSI codes
local function strip_ansi(str)
  -- Match all ANSI escape sequences: ESC[ followed by digits and letters
  -- Use string.char(27) to avoid Lua escape sequence parsing issues
  local ESC = string.char(27)
  return str:gsub(ESC .. "%[[0-9;]*[a-zA-Z]", "")
end

-- WR-02 fix: Robust component name extraction helper
--- Extract component name from picker display line format
--- Format: "icon display_name [cache_status] category"
---@param clean_line string Line with ANSI codes already stripped
---@return string|nil component_name Extracted name or nil
local function extract_component_name(clean_line)
  -- Split by space and take second token (after icon, before cache status)
  local tokens = vim.split(clean_line, " ")
  if #tokens >= 2 then
    -- Token[1] is icon, token[2] is display_name
    return tokens[2]
  end
  return nil
end

--- 检查 fzf-lua 是否可用
local function has_fzf_lua()
  local ok, _ = pcall(require, "fzf-lua")
  return ok
end

--- 构建选择器条目（多行卡片视图 per D-32 to D-34）
---@return table { display_line = component_name }
function M.build_entries()
  local Registry = require("ai.components.registry")
  local Manager = require("ai.components.manager")
  local Deployments = require("ai.components.deployments")
  local Switcher = require("ai.components.switcher")

  local components = Registry.list()
  local entries = {}

  -- WR-06 fix: Pre-fetch all deployment states once to avoid inconsistency
  local all_deployment_states = {}
  for _, comp in ipairs(components) do
    all_deployment_states[comp.name] = Deployments.get_deployment_status(comp.name)
  end

  for _, comp in ipairs(components) do
    -- Get full component for supported_targets
    local comp_full = Registry.get(comp.name)
    local supported_targets = comp_full and comp_full.supported_targets or {}

    -- Use cached deployment state instead of separate queries
    local deploy_status = all_deployment_states[comp.name]

    -- Build line 1 per D-32, D-34: Cache status
    -- WR-06: Derive cache status from pre-fetched deployment state
    local cache_status = deploy_status and deploy_status.is_cached or Manager.is_cached(comp.name)
    local cache_str
    if cache_status then
      local version = deploy_status and deploy_status.cache_version or Manager.get_cache_version(comp.name) or "unknown"
      cache_str = string.format("[cached %s]", version)
    else
      cache_str = "[not cached]"
    end

    -- Line 1 format: icon + name + cache status + category
    local line1 = string.format(
      "%s%s %s %s%s %s | %s",
      ANSI.bold,
      comp.icon or "📦",
      comp.display_name or comp.name,
      ANSI.reset,
      cache_str,
      comp.category or "unknown"
    )

    -- Build line 2 per D-33: Deploy status per tool
    local deploy_parts = {}
    for _, target in ipairs(supported_targets) do
      -- WR-06: Use pre-fetched deployment state
      local deployed = deploy_status and deploy_status.deployed_to and deploy_status.deployed_to[target]
      if deployed then
        local method = deploy_status.deployed_to[target].method or "symlink"
        local version = deploy_status.cache_version or "unknown"
        table.insert(
          deploy_parts,
          string.format("%s%s %s (v%s, %s)%s", ANSI.green, "✓", comp.name, version, method, ANSI.reset)
        )
      else
        table.insert(
          deploy_parts,
          string.format("%s%s none (not deployed)%s", ANSI.gray, "○", ANSI.reset)
        )
      end
    end

    -- If no deploy parts, show "not deployed to any tool"
    if #deploy_parts == 0 then
      table.insert(deploy_parts, string.format("%s○ not deployed to any tool%s", ANSI.gray, ANSI.reset))
    end

    -- Line 2 format: join deploy parts with " | "
    local line2 = "  " .. table.concat(deploy_parts, " | ")

    -- Combine lines with literal newline per D-32
    local display_line = line1 .. "\n" .. line2

    entries[display_line] = comp.name
  end

  return entries
end

--- 构建顶部 header（显示工具分配 per D-45 to D-47）
---@return string
function M.build_header()
  local Switcher = require("ai.components.switcher")
  local Deployments = require("ai.components.deployments")

  local assignments = Switcher.get_all()

  local lines = {
    "Tool Assignments:",
  }

  for tool, comp_name in pairs(assignments) do
    local status = Deployments.get_deployment_status(comp_name)
    if status and status.deployed_to and status.deployed_to[tool] then
      -- Per D-46: tool → ✓ component (vX, method)
      local method = status.deployed_to[tool].method or "symlink"
      local version = status.cache_version or "unknown"
      table.insert(
        lines,
        string.format("  %s → %s%s %s (v%s, %s)%s", tool, ANSI.green, "✓", comp_name, version, method, ANSI.reset)
      )
    else
      -- Per D-47: tool → ○ none
      table.insert(lines, string.format("  %s → %s%s none%s", tool, ANSI.gray, "○", ANSI.reset))
    end
  end

  table.insert(lines, "")
  table.insert(
    lines,
    "Keys: [Enter] Actions | [i] Install | [u] Update | [x] Uninstall | [s] Switch | [v] Version | [r] Refresh"
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
          -- WR-01: Use centralized ANSI stripping helper
          local clean_line = strip_ansi(fzf_data[1])
          -- Extract component name from line 1
          local comp_name = entries[fzf_data[1]]
          if not comp_name then
            -- WR-02: Use robust extraction helper
            comp_name = extract_component_name(clean_line)
          end
          if not comp_name then
            vim.notify("Could not identify selected component", vim.log.levels.ERROR)
            return ""
          end
          return Previewer2.build_preview(comp_name)
        end,
      },
    },
    fzf_opts = {
      ["--header"] = M.build_header(),
      ["--ansi"] = true, -- Enable ANSI interpretation per D-42
    },
    actions = {
      -- Enter: 打开操作菜单
      ["default"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        -- WR-01: Use centralized ANSI stripping helper
        local clean_line = strip_ansi(selected[1])
        local comp_name = entries[selected[1]]
        if not comp_name then
          -- WR-02: Use robust extraction helper
          comp_name = extract_component_name(clean_line)
        end
        if not comp_name then
          vim.notify("Could not identify selected component", vim.log.levels.ERROR)
          return
        end
        M.open_actions_menu(comp_name)
      end,

      -- i: 安装
      ["ctrl-i"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        -- WR-01: Use centralized ANSI stripping helper
        local clean_line = strip_ansi(selected[1])
        local comp_name = entries[selected[1]]
        if not comp_name then
          comp_name = extract_component_name(clean_line)
        end
        Actions.install(comp_name)
        M.open() -- 重新打开以刷新状态
      end,

      -- u: 更新
      ["ctrl-u"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        -- WR-01: Use centralized ANSI stripping helper
        local clean_line = strip_ansi(selected[1])
        local comp_name = entries[selected[1]]
        if not comp_name then
          comp_name = extract_component_name(clean_line)
        end
        Actions.update(comp_name)
        M.open()
      end,

      -- x: 卸载
      ["ctrl-x"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        -- WR-01: Use centralized ANSI stripping helper
        local clean_line = strip_ansi(selected[1])
        local comp_name = entries[selected[1]]
        if not comp_name then
          comp_name = extract_component_name(clean_line)
        end
        Actions.uninstall(comp_name)
        M.open()
      end,

      -- s: 切换工具
      ["ctrl-s"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        -- WR-01: Use centralized ANSI stripping helper
        local clean_line = strip_ansi(selected[1])
        local comp_name = entries[selected[1]]
        if not comp_name then
          comp_name = extract_component_name(clean_line)
        end
        M.open_switch_menu(comp_name)
      end,

      -- v: 版本详情
      ["ctrl-v"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        -- WR-01: Use centralized ANSI stripping helper
        local clean_line = strip_ansi(selected[1])
        local comp_name = entries[selected[1]]
        if not comp_name then
          comp_name = extract_component_name(clean_line)
        end
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

--- 打开二级操作菜单（带灰色禁用项 per D-42 to D-44）
---@param component_name string 组件名
function M.open_actions_menu(component_name)
  if not has_fzf_lua() then
    vim.notify("fzf-lua not installed", vim.log.levels.ERROR)
    return
  end

  local fzf = require("fzf-lua")
  local Registry = require("ai.components.registry")
  local Manager = require("ai.components.manager")
  local Actions = require("ai.components.actions")
  local Previewer = require("ai.components.previewer")
  local comp = Registry.get(component_name)

  if not comp then
    return
  end

  -- Get cache status per D-42
  local is_cached = Manager.is_cached(component_name)

  -- Define actions with availability metadata per D-42 to D-44
  local actions = {
    { name = "Install", available = not is_cached, reason = "already cached", fn = function() Actions.install(component_name) end },
    { name = "Deploy", available = is_cached, reason = "not cached yet", fn = function() -- Deployments logic
      local Manager2 = require("ai.components.manager")
      local targets = comp.supported_targets or { "claude", "opencode" }
      vim.ui.select(targets, { prompt = "Deploy to:" }, function(target)
        if target then
          Manager2.deploy_to(component_name, target)
        end
      end)
    end },
    { name = "Update", available = is_cached, reason = "not cached", fn = function() Actions.update(component_name) end },
    { name = "Uninstall", available = is_cached, reason = "not cached", fn = function() Actions.uninstall(component_name) end },
    { name = "Switch Tool Assignment", available = true, reason = "", fn = function() M.open_switch_menu(component_name) end },
    { name = "View Version Details", available = true, reason = "", fn = function() Previewer.show_version_detail(component_name) end },
    { name = "Open Config Directory", available = true, reason = "", fn = function() Actions.open_config_dir(component_name) end },
  }

  -- Build display_lines with ANSI styling per D-42
  local display_lines = {}
  for _, action in ipairs(actions) do
    if action.available then
      -- D-44: Normal brightness
      table.insert(display_lines, action.name)
    else
      -- D-42: Grayed with ANSI dim + gray
      table.insert(display_lines, ANSI.dim .. ANSI.gray .. action.name .. ANSI.reset .. " [disabled]")
    end
  end

  fzf.fzf_exec(display_lines, {
    prompt = string.format(" Actions for %s > ", comp.display_name or component_name),
    winopts = {
      height = 0.4,
      width = 0.5,
      row = 0.3,
      border = "rounded",
      preview = {
        layout = "vertical",
        width = 0.3,
        -- Preview callback for tooltips per D-43
        fn = function(_, _, fzf_data, _preview_scroll)
          if not fzf_data or #fzf_data < 1 then
            return ""
          end
          local action_name = fzf_data[1]
          -- WR-01: Use centralized ANSI stripping helper
          local clean_name = strip_ansi(action_name):gsub(" %[disabled%]", "")
          for _, action in ipairs(actions) do
            if action.name == clean_name then
              if not action.available then
                -- D-43: Show disabled reason
                return string.format("%s: Disabled -- %s", action.name, action.reason)
              end
              -- Available action
              return string.format("%s: Available", action.name)
            end
          end
          return ""
        end,
      },
    },
    fzf_opts = {
      ["--ansi"] = true, -- Enable ANSI interpretation per D-42
    },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected < 1 then
          return
        end
        local action_name = selected[1]
        -- WR-01: Use centralized ANSI stripping helper
        local clean_name = strip_ansi(action_name):gsub(" %[disabled%]", "")
        for _, action in ipairs(actions) do
          if action.name == clean_name then
            action.fn()
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