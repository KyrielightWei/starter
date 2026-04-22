-- lua/ai/provider_manager/registry.lua
-- CRUD operations for Provider Manager
-- Delegates to ai.providers for in-memory state

local M = {}

local Providers = require("ai.providers")

----------------------------------------------------------------------
-- List all providers with display info
-- Returns: array of {name, display}
----------------------------------------------------------------------
function M.list_providers()
  local names = Providers.list()
  local result = {}
  for _, name in ipairs(names) do
    local def = Providers.get(name)
    if def then
      local display = string.format("%s  —  %s  —  %s", name, def.endpoint, def.model)
      table.insert(result, { name = name, display = display })
    end
  end
  return result
end

----------------------------------------------------------------------
-- Add a new provider entry
-- Opens providers.lua for manual config entry
----------------------------------------------------------------------
function M.add_provider(name)
  -- Open providers.lua for the user to add config
  local config_path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  vim.cmd("edit " .. config_path)

  -- Jump to end of file (before `return M`)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local insert_line = #lines
  vim.api.nvim_win_set_cursor(0, { insert_line, 0 })

  vim.notify("Provider registration added. Please fill in config for: " .. name, vim.log.levels.INFO)
  return true
end

----------------------------------------------------------------------
-- Find the line number of a provider's M.register() call
-- Returns: line number (1-indexed), or 1 if not found
----------------------------------------------------------------------
function M.find_provider_line(name)
  local config_path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  if vim.fn.filereadable(config_path) == 0 then
    return 1
  end
  local lines = vim.fn.readfile(config_path)
  local pattern = "M.register%(['\"]" .. name .. "['\"]"
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      return i
    end
  end
  return 1
end

----------------------------------------------------------------------
-- Delete a provider from memory
-- Note: Does NOT modify providers.lua file — user must manually remove
-- the M.register() call. This is by design to avoid data loss.
----------------------------------------------------------------------
function M.delete_provider(name)
  local def = Providers.get(name)
  if not def then
    vim.notify("Provider not found: " .. name, vim.log.levels.WARN)
    return false
  end

  -- Remove from in-memory registry
  Providers[name] = nil

  -- Notify that file modification is still needed
  vim.notify("Deleted provider: " .. name .. ". Please remove the M.register() call from providers.lua", vim.log.levels.INFO)
  return true
end

return M
