-- lua/ai/gsd.lua
-- GSD (Get Shit Done) tool detection

local M = {}

--- 检测 GSD 是否可用 (通过 npx)
---@return boolean
function M.is_installed()
  return vim.fn.executable("npx") == 1
end

--- 获取 GSD 状态
---@return table
function M.get_status()
  return {
    available = M.is_installed(),
    command = "npx -y get-shit-done-cc@latest",
  }
end

--- 获取使用提示
---@return string
function M.install_hint()
  return "npx -y get-shit-done-cc@latest"
end

--- 显示 GSD 状态
function M.show_status()
  if M.is_installed() then
    vim.notify("GSD available via npx", vim.log.levels.INFO)
  else
    vim.notify("GSD requires npx (Node.js)", vim.log.levels.WARN)
  end
end

return M
