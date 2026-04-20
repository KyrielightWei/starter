-- lua/ai/components/previewer.lua
-- 预览器模块：组件详情显示和浮动窗口

local M = {}

--- 构建组件预览内容
---@param component_name string 组件名
---@return string preview_content
function M.build_preview(component_name)
  local Registry = require("ai.components.registry")
  local comp = Registry.get(component_name)

  if not comp then
    return "Component not found"
  end

  local status = comp.get_status() or {}
  local version = comp.get_version_info() or {}
  local deps = comp.check_dependencies() or {}

  local lines = {
    string.format("Name: %s", comp.display_name or component_name),
    string.format("Category: %s", comp.category or "unknown"),
    string.format("Description: %s", comp.description or ""),
    "",
    "Version:",
    string.format("  Current: %s", version.current or "N/A"),
    string.format("  Latest:  %s", version.latest or "N/A"),
    string.format("  Status:  %s", version.status or "unknown"),
    "",
    "Dependencies:",
  }

  for _, dep in ipairs(deps) do
    local icon = dep.installed and "✓" or "✗"
    local version_str = dep.version or ""
    table.insert(
      lines,
      string.format("  %s %s: %s %s", icon, dep.name, version_str, dep.installed and "" or "(MISSING)")
    )
  end

  if #deps == 0 then
    table.insert(lines, "  (none)")
  end

  table.insert(lines, "")
  table.insert(lines, "Supported Tools:")

  if comp.supported_targets then
    for _, target in ipairs(comp.supported_targets) do
      table.insert(lines, string.format("  • %s", target))
    end
  else
    table.insert(lines, "  (all)")
  end

  return table.concat(lines, "\n")
end

--- 构建版本详情内容
---@param component_name string 组件名
---@return string[] lines
function M.build_version_detail_lines(component_name)
  local Registry = require("ai.components.registry")
  local comp = Registry.get(component_name)

  if not comp then
    return { "Component not found" }
  end

  local version = comp.get_version_info() or {}
  local lines = {
    string.format("Component: %s", comp.display_name or component_name),
    "",
    "Version Information:",
    string.format("  Current version: %s", version.current or "N/A"),
    string.format("  Latest version:  %s", version.latest or "N/A"),
    string.format("  Status:          %s", version.status or "unknown"),
    "",
  }

  if version.status == "outdated" then
    table.insert(lines, "⚠️  This component is outdated. Press 'u' to update.")
  elseif version.status == "current" then
    table.insert(lines, "✓  This component is up to date.")
  elseif version.status == "not_installed" then
    table.insert(lines, "○  This component is not installed. Press 'i' to install.")
  end

  return lines
end

--- 显示版本详情浮动窗口
---@param component_name string 组件名
function M.show_version_detail(component_name)
  local lines = M.build_version_detail_lines(component_name)

  -- 创建浮动窗口
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = 50
  local height = #lines + 2
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Version Details ",
    title_pos = "center",
  })

  -- 按 q 或 Esc 关闭
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<cr>", { silent = true })
end

--- 创建 fzf-lua 预览配置（写入 winopts.preview）
---@param entries table 选择器条目映射
---@return table preview_config
function M.create_fzf_previewer(entries)
  return {
    title = " Component Details ",
    fn = function(_, preview_win, fzf_data, _preview_scroll)
      if not fzf_data or #fzf_data < 1 then
        return ""
      end
      local comp_name = entries[fzf_data[1]]
      return M.build_preview(comp_name)
    end,
  }
end

return M
