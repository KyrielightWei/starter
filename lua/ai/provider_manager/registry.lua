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

----------------------------------------------------------------------
-- List models for a provider (dynamic fetch with static fallback)
-- Threat T-01-08: pcall wrapper for Fetch require and fetch call
----------------------------------------------------------------------
function M.list_models(provider_name)
  local def = Providers.get(provider_name)
  if not def then
    vim.notify("Provider not found: " .. provider_name, vim.log.levels.ERROR)
    return {}
  end

  -- Try dynamic fetch first, fallback to static_models
  local ok, Fetch = pcall(require, "ai.fetch_models")
  if ok then
    local ok2, models = pcall(Fetch.fetch, provider_name)
    if ok2 and models and #models > 0 then
      return models
    end
  end

  return def.static_models or {}
end

----------------------------------------------------------------------
-- Set default model for a provider
-- Updates both Keys config and in-memory Providers table
----------------------------------------------------------------------
function M.set_default_model(provider_name, model_id)
  -- Read current keys config
  local config = Keys.read()
  if not config then
    vim.notify("Failed to read keys config", vim.log.levels.ERROR)
    return false
  end

  -- Ensure provider section exists with proper profile structure
  if not config[provider_name] then
    config[provider_name] = {}
  end
  if not config[provider_name].default then
    config[provider_name].default = {}
  end

  -- Update default model inside the default profile
  config[provider_name].default.model = model_id
  Keys.write(config)

  -- Also update Providers table in memory
  local def = Providers.get(provider_name)
  if def then
    def.model = model_id
  end

  vim.notify(string.format("Set %s default model to: %s", provider_name, model_id), vim.log.levels.INFO)
  return true
end

----------------------------------------------------------------------
-- Get current default model for a provider
-- Priority: Keys config (default profile) > Providers.model > static_models[1]
----------------------------------------------------------------------
function M.get_default_model(provider_name)
  -- Level 1: Keys config (user preference, default profile)
  local config = Keys.read()
  if config then
    local provider_config = config[provider_name]
    if provider_config then
      -- Try current profile first, then "default"
      local profile = config.profile or "default"
      local profile_config = provider_config[profile] or provider_config["default"]
      if profile_config and profile_config.model and profile_config.model ~= "" then
        return profile_config.model
      end
    end
  end

  -- Level 2: In-memory Providers table
  local def = Providers.get(provider_name)
  if not def then return nil end
  if def.model and def.model ~= "" then
    return def.model
  end

  -- Level 3: First static model
  return def.static_models and def.static_models[1] or nil
end

return M
