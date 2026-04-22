-- lua/ai/provider_manager/registry.lua
-- CRUD operations for Provider Manager
-- Delegates to ai.providers for in-memory state, persists deletes to file

local Providers = require("ai.providers")
local Validator = require("ai.provider_manager.validator")
local Keys = require("ai.keys")

local M = {}

----------------------------------------------------------------------
-- List all providers with display info
-- FIX: Use Providers.list() API — NOT pairs(Providers)
-- FIX: Include endpoint and model in result table
----------------------------------------------------------------------
function M.list_providers()
  local names = Providers.list()
  local result = {}
  for _, name in ipairs(names) do
    local def = Providers.get(name)
    if def then
      local display = string.format("%s  —  %s  —  %s", name, def.endpoint, def.model or "unknown")
      table.insert(result, { name = name, display = display, endpoint = def.endpoint, model = def.model })
    end
  end
  return result
end

----------------------------------------------------------------------
-- Find the line number of a provider's M.register() call
-- FIX: Use dynamic path via vim.fn.stdpath("config") — NOT hardcoded
----------------------------------------------------------------------
function M.find_provider_line(name)
  local config_path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  if vim.fn.filereadable(config_path) == 0 then
    return 1
  end
  local lines = vim.fn.readfile(config_path)
  local pattern = 'M.register%([\'"]' .. name .. '[\'"]'
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      return i
    end
  end
  return 1
end

----------------------------------------------------------------------
-- Add a new provider entry
-- Opens providers.lua for manual config entry
----------------------------------------------------------------------
function M.add_provider(name)
  local valid, err = Validator.validate_provider_name(name)
  if not valid then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

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
-- Delete a provider from registry AND persist to file
-- FIX: File persistence — modifies providers.lua, not just memory
-- FIX: Keys cleanup — removes key entry for deleted provider
----------------------------------------------------------------------
function M.delete_provider(name)
  local def = Providers.get(name)
  if not def then
    vim.notify("Provider not found: " .. name, vim.log.levels.ERROR)
    return false
  end

  -- Remove from in-memory registry
  Providers[name] = nil

  -- Remove provider's Keys entry
  local keys_data = Keys.read()
  if keys_data and keys_data[name] then
    keys_data[name] = nil
    Keys.write(keys_data)
  end

  -- PERSIST: Remove M.register(...) block from providers.lua file
  local config_path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  if vim.fn.filereadable(config_path) == 0 then
    vim.notify("Deleted provider: " .. name .. " (in-memory only, file not found)", vim.log.levels.WARN)
    return true
  end

  local lines = vim.fn.readfile(config_path)
  local new_lines = {}
  local skip = false
  for _, line in ipairs(lines) do
    if line:match('M%.register%([\'"]' .. name .. '[\'"]') then
      skip = true
    elseif skip then
      if line:match("^%s*%}%s*%)%s*$") then
        -- End of register call: "})"
        skip = false
        -- Do NOT include this closing line
      end
      -- Skip all lines within the register block
    else
      table.insert(new_lines, line)
    end
  end

  if skip then
    vim.notify("Warning: Could not find end of register block for " .. name .. " (block may be truncated)", vim.log.levels.WARN)
  end

  vim.fn.writefile(new_lines, config_path)
  vim.notify("Deleted provider: " .. name, vim.log.levels.INFO)
  return true
end

return M
