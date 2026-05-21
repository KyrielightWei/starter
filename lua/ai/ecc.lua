-- lua/ai/ecc.lua
-- ECC (Everything Claude Code) tool detection and installation

local M = {}

--- 检测 ECC 是否已安装
---@return boolean
function M.is_installed()
  local state_path = vim.fn.expand("~/.claude/ecc/install-state.json")
  return vim.fn.filereadable(state_path) == 1
end

--- 获取 ECC 安装状态
---@return table|nil
function M.get_status()
  local state_path = vim.fn.expand("~/.claude/ecc/install-state.json")
  if vim.fn.filereadable(state_path) ~= 1 then
    return nil
  end

  local ok, content = pcall(vim.fn.readfile, state_path)
  if not ok or #content == 0 then
    return nil
  end

  local json_str = table.concat(content, "\n")
  local ok2, data = pcall(vim.json.decode, json_str)
  if not ok2 then
    return nil
  end

  return data
end

--- 获取安装命令提示
---@return string
function M.install_hint()
  return "git clone https://github.com/affaan-m/everything-claude-code.git /tmp/ecc --depth=1 && cd /tmp/ecc && npm install && node scripts/install-apply.js --profile developer"
end

--- 安装 ECC
---@param opts table|nil
---@param on_progress function|nil
---@return boolean, string
function M.install(opts, on_progress)
  opts = opts or {}

  local notify = function(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO)
    if on_progress then
      on_progress(msg)
    end
  end

  notify("Installing ECC Framework...")


  local cmd = M.install_hint()
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false, "Installation failed: " .. output
  end

  notify("ECC installed successfully")
  return true, "Installation complete"
end

--- 显示 ECC 状态
function M.show_status()
  local status = M.get_status()
  if status then
    vim.notify("ECC installed: " .. tostring(status.installed_at or "unknown"), vim.log.levels.INFO)
  else
    vim.notify("ECC not installed. Run :ECCInstall to install", vim.log.levels.WARN)
  end
end

--- 打开安装器
function M.open_installer()
  if M.is_installed() then
    vim.notify("ECC already installed", vim.log.levels.INFO)
    return
  end

  vim.ui.select({"Yes", "No"}, {
    prompt = "Install ECC Framework?",
  }, function(choice)
    if choice == "Yes" then
      M.install({}, function(msg)
        vim.notify(msg, vim.log.levels.INFO)
      end)
    end
  end)
end

--- 格式化 ECC 状态通知行
---@param ecc table|nil
---@return string[]
function M.format_notification(ecc)
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
