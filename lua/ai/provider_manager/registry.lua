-- lua/ai/provider_manager/registry.lua
-- CRUD operations for Provider Manager
-- Delegates to ai.providers for in-memory state, persists deletes to file

local Providers = require("ai.providers")
local Validator = require("ai.provider_manager.validator")
local Keys = require("ai.keys")
local FileUtil = require("ai.provider_manager.file_util")

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
-- Find the provider block (start_line, end_line, content_lines)
-- Addresses review: block-aware parser for reliable editing
----------------------------------------------------------------------
function M.find_provider_block(name)
  local config_path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  if vim.fn.filereadable(config_path) == 0 then
    return nil, nil, nil
  end
  local lines = vim.fn.readfile(config_path)
  local start_line = nil
  local end_line = nil

  for i, line in ipairs(lines) do
    if line:match("M%.register%(['\"]" .. name .. "['\"]%s*,") then
      start_line = i
    end
    if start_line and line:match("^%s*%}%s*%)%s*$") and i > start_line then
      end_line = i
      break
    end
  end

  if start_line and end_line then
    local content = {}
    for i = start_line, end_line do
      table.insert(content, lines[i])
    end
    return start_line, end_line, content
  end

  return nil, nil, nil
end

----------------------------------------------------------------------
-- Find the line number of a provider's M.register() call
-- FIX: Use dynamic path via vim.fn.stdpath("config") — NOT hardcoded
----------------------------------------------------------------------
function M.find_provider_line(name)
  local start, _, _ = M.find_provider_block(name)
  return start or 1
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
  vim.cmd.edit({ file = config_path })

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

  local start_line, end_line, _ = M.find_provider_block(name)
  if not start_line then
    -- Fallback: line-by-line removal
    local lines = vim.fn.readfile(config_path)
    local new_lines = {}
    local skip = false
    for _, line in ipairs(lines) do
      if line:match('M%.register%([\'"]' .. name .. '[\'"]%s*,') then
        skip = true
      elseif skip then
        if line:match("^%s*%}%s*%)%s*$") then
          skip = false
        end
      else
        table.insert(new_lines, line)
      end
    end
    local content = table.concat(new_lines, "\n")
    local ok, err = FileUtil.safe_write_file(config_path, content)
    if not ok then
      vim.notify("Warning: Could not persist deletion for " .. name, vim.log.levels.WARN)
    end
    vim.notify("Deleted provider: " .. name, vim.log.levels.INFO)
    return true
  end

  -- Block-aware removal
  local lines = vim.fn.readfile(config_path)
  local new_lines = {}
  for i, line in ipairs(lines) do
    if i < start_line or i > end_line then
      table.insert(new_lines, line)
    end
  end

  local content = table.concat(new_lines, "\n")
  local ok, err = FileUtil.safe_write_file(config_path, content)
  if not ok then
    vim.notify("Warning: Could not persist deletion for " .. name, vim.log.levels.WARN)
  end

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

----------------------------------------------------------------------
-- Static Models CRUD (addresses review: safe file write, block parser)
----------------------------------------------------------------------

-- Parse static_models array from provider block content
local function parse_static_models_from_block(content_lines)
  local in_static_models = false
  local models = {}
  local buffer = ""

  for _, line in ipairs(content_lines) do
    if line:match("static_models%s*=") then
      in_static_models = true
      buffer = line
    elseif in_static_models then
      buffer = buffer .. line
    end

    if in_static_models and line:match("}") then
      -- Extract model IDs from the buffer
      local str = buffer
      -- Match all string literals inside {}
      for model_id in str:gmatch('"([^"]*)"') do
        table.insert(models, model_id)
      end
      in_static_models = false
      buffer = ""
    end
  end

  return models
end

-- Build replacement line for static_models
local function build_static_models_line(models, indent)
  if #models == 0 then
    return indent .. "static_models = {},"
  end
  local items = {}
  for _, m in ipairs(models) do
    table.insert(items, '"' .. m .. '"')
  end
  return indent .. "static_models = { " .. table.concat(items, ", ") .. " },"
end

function M.list_static_models(provider_name)
  local _, _, content = M.find_provider_block(provider_name)
  if not content then
    local def = Providers.get(provider_name)
    return def and def.static_models and vim.deepcopy(def.static_models) or {}
  end
  return parse_static_models_from_block(content)
end

function M.add_static_model(provider_name, model_id)
  local start, end_line, _ = M.find_provider_block(provider_name)
  if not start then
    vim.notify("Provider block not found in file", vim.log.levels.ERROR)
    return false
  end

  -- Get current static models
  local current = M.list_static_models(provider_name)

  -- Skip if duplicate
  for _, m in ipairs(current) do
    if m == model_id then
      vim.notify("Model already exists: " .. model_id, vim.log.levels.WARN)
      return false
    end
  end

  table.insert(current, model_id)

  -- Persist new list
  return M._update_static_models_in_file(provider_name, start, end_line, current)
end

function M.remove_static_model(provider_name, model_id)
  local start, end_line, _ = M.find_provider_block(provider_name)
  if not start then return false end

  local current = M.list_static_models(provider_name)
  local filtered = {}
  local found = false
  for _, m in ipairs(current) do
    if m == model_id then
      found = true
    else
      table.insert(filtered, m)
    end
  end

  if not found then
    vim.notify("Model not found: " .. model_id, vim.log.levels.WARN)
    return false
  end

  return M._update_static_models_in_file(provider_name, start, end_line, filtered)
end

function M.update_static_models(provider_name, new_models)
  local start, end_line, _ = M.find_provider_block(provider_name)
  if not start then return false end
  return M._update_static_models_in_file(provider_name, start, end_line, new_models)
end

-- Internal: update static_models in providers.lua
function M._update_static_models_in_file(provider_name, start, end_line, new_models)
  local path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  local lines = vim.fn.readfile(path)

  -- Determine indent from first line of provider block
  local indent = lines[start]:match("^(%s*)") or "  "

  -- Check if static_models line exists in block
  local static_line_idx = nil
  for i = start, end_line do
    if lines[i]:match("static_models%s*=") then
      static_line_idx = i
      break
    end
  end

  local new_content = build_static_models_line(new_models, indent)

  if static_line_idx then
    -- Replace existing line
    lines[static_line_idx] = new_content
  else
    -- Insert before closing "})"
    local insert_idx = end_line - 1
    table.insert(lines, insert_idx, new_content)
    -- Update end_line since we inserted
    end_line = end_line + 1
  end

  -- Write atomically
  local content = table.concat(lines, "\n")
  local ok, err = FileUtil.safe_write_file(path, content)
  if not ok then
    vim.notify("Failed to save static models: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  -- Update in-memory Providers table
  local def = Providers.get(provider_name)
  if def then
    def.static_models = new_models
  end

  vim.notify("Static models updated for " .. provider_name, vim.log.levels.INFO)
  return true
end

return M
