-- lua/ai/components/actions.lua
-- 操作执行器：install/update/uninstall 执行逻辑

local M = {}

--- 执行安装操作
---@param component_name string 组件名
---@param opts table|nil 选项
---@return boolean, string success, message
function M.install(component_name, opts)
  opts = opts or {}

  local Registry = require("ai.components.registry")
  local comp = Registry.get(component_name)

  if not comp then
    return false, string.format("Component '%s' not found", component_name)
  end

  -- 检查依赖
  local missing = M.check_missing_dependencies(comp)

  if #missing > 0 then
    -- 显示依赖缺失对话框
    M.show_dependency_dialog(missing, component_name)
    return false,
      string.format(
        "Missing dependencies: %s",
        table.concat(
          vim.tbl_map(function(d)
            return d.name
          end, missing),
          ", "
        )
      )
  end

  -- 已安装检查
  if comp.is_installed() and not opts.force then
    return true, string.format("Component '%s' is already installed", component_name)
  end

  -- 执行安装
  local progress_msg = "Installing " .. component_name .. "..."

  vim.notify(progress_msg, vim.log.levels.INFO)

  local ok, msg = comp.install(opts, function(progress)
    vim.notify(progress, vim.log.levels.INFO)
  end)

  if ok then
    vim.notify(string.format("✅ %s installed successfully", component_name), vim.log.levels.INFO)

    -- 更新版本缓存
    local Switcher = require("ai.components.switcher")
    local version_info = comp.get_version_info()
    Switcher.update_version_cache(component_name, version_info)
  else
    vim.notify(string.format("❌ %s installation failed: %s", component_name, msg), vim.log.levels.ERROR)
  end

  return ok, msg
end

--- 执行更新操作
---@param component_name string 组件名
---@param opts table|nil 选项
---@return boolean, string success, message
function M.update(component_name, opts)
  opts = opts or {}

  local Registry = require("ai.components.registry")
  local comp = Registry.get(component_name)

  if not comp then
    return false, string.format("Component '%s' not found", component_name)
  end

  -- 检查是否已安装
  if not comp.is_installed() then
    return false, string.format("Component '%s' is not installed. Run install first.", component_name)
  end

  -- 检查版本状态
  local version_info = comp.get_version_info()

  if version_info.status == "current" then
    return true, string.format("Component '%s' is already up to date", component_name)
  end

  -- 检查依赖
  local missing = M.check_missing_dependencies(comp)

  if #missing > 0 then
    M.show_dependency_dialog(missing, component_name)
    return false, "Missing dependencies"
  end

  -- 执行更新
  vim.notify("Updating " .. component_name .. "...", vim.log.levels.INFO)

  local ok, msg = comp.update(opts)

  if ok then
    vim.notify(string.format("✅ %s updated successfully", component_name), vim.log.levels.INFO)

    -- 更新版本缓存
    local Switcher = require("ai.components.switcher")
    local new_version_info = comp.get_version_info()
    Switcher.update_version_cache(component_name, new_version_info)
  else
    vim.notify(string.format("❌ %s update failed: %s", component_name, msg), vim.log.levels.ERROR)
  end

  return ok, msg
end

--- 执行卸载操作
---@param component_name string 组件名
---@param opts table|nil 选项
---@return boolean, string success, message
function M.uninstall(component_name, opts)
  opts = opts or {}

  local Registry = require("ai.components.registry")
  local comp = Registry.get(component_name)

  if not comp then
    return false, string.format("Component '%s' not found", component_name)
  end

  -- 检查是否已安装
  if not comp.is_installed() then
    return true, string.format("Component '%s' is not installed", component_name)
  end

  -- 确认对话框
  if not opts.force then
    local choice = vim.fn.confirm(string.format("Uninstall %s?", component_name), "&Yes\n&No", 2)

    if choice ~= 1 then
      return false, "Cancelled by user"
    end
  end

  -- 执行卸载
  vim.notify("Uninstalling " .. component_name .. "...", vim.log.levels.INFO)

  local ok, msg = comp.uninstall(opts)

  if ok then
    vim.notify(string.format("✅ %s uninstalled successfully", component_name), vim.log.levels.INFO)

    -- 清除版本缓存
    local Switcher = require("ai.components.switcher")
    Switcher.update_version_cache(component_name, {
      current = nil,
      latest = nil,
      status = "not_installed",
    })
  else
    vim.notify(string.format("❌ %s uninstall failed: %s", component_name, msg), vim.log.levels.ERROR)
  end

  return ok, msg
end

--- 检查缺失的必需依赖
---@param comp AIComponent 组件
---@return DependencyStatus[] missing_required
function M.check_missing_dependencies(comp)
  local deps = comp.check_dependencies()

  return vim.tbl_filter(function(d)
    return d.required and not d.installed
  end, deps)
end

--- 显示依赖缺失对话框
---@param missing DependencyStatus[] 缺失的依赖
---@param component_name string 组件名
function M.show_dependency_dialog(missing, component_name)
  local lines = {
    string.format("⚠️  Missing Dependencies for %s", component_name),
    "",
    "Required dependencies not installed:",
  }

  for _, dep in ipairs(missing) do
    table.insert(lines, string.format("  • %s", dep.name))
  end

  table.insert(lines, "")
  table.insert(lines, "Install commands:")

  -- 尝试提取安装提示
  for _, dep in ipairs(missing) do
    if dep.install_hint then
      local hints = vim.split(dep.install_hint, "\n")
      for _, hint in ipairs(hints) do
        table.insert(lines, string.format("    %s: %s", dep.name, hint))
      end
    end
  end

  -- 创建浮动窗口
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = 60
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
    title = " Dependency Missing ",
    title_pos = "center",
  })

  -- 按 q 或 Esc 关闭
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<cr>", { silent = true })

  -- 5 秒后自动关闭
  vim.defer_fn(function()
    pcall(vim.api.nvim_win_close, win, true)
  end, 5000)
end

--- 批量更新所有过期的组件
---@return number, string[] updated_count, errors
function M.update_all()
  local Registry = require("ai.components.registry")
  local outdated = Registry.list_outdated()

  local updated = 0
  local errors = {}

  for _, comp_info in ipairs(outdated) do
    local ok, msg = M.update(comp_info.name)
    if ok then
      updated = updated + 1
    else
      table.insert(errors, string.format("%s: %s", comp_info.name, msg))
    end
  end

  if updated > 0 then
    vim.notify(string.format("Updated %d component(s)", updated), vim.log.levels.INFO)
  end

  if #errors > 0 then
    vim.notify(string.format("Update errors:\n%s", table.concat(errors, "\n")), vim.log.levels.WARN)
  end

  return updated, errors
end

--- 打开组件配置目录
---@param component_name string 组件名
function M.open_config_dir(component_name)
  local Registry = require("ai.components.registry")
  local comp = Registry.get(component_name)

  if not comp then
    vim.notify(string.format("Component '%s' not found", component_name), vim.log.levels.ERROR)
    return
  end

  local config_dir = comp.get_config_dir()

  if not config_dir or vim.fn.isdirectory(config_dir) ~= 1 then
    vim.notify(string.format("Component '%s' has no config directory", component_name), vim.log.levels.WARN)
    return
  end

  vim.cmd("edit " .. config_dir)
end

return M
