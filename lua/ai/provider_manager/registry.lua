-- lua/ai/provider_manager/registry.lua
-- CRUD operations for Provider Manager
-- Delegates to ai.providers for in-memory state, persists deletes to file

local Providers = require("ai.providers")
local Validator = require("ai.provider_manager.validator")
local Keys = require("ai.keys")
local FileUtil = require("ai.provider_manager.file_util")

local M = {}

----------------------------------------------------------------------
-- Helper: Get providers.lua path
-- FIX: Use project directory when running from project, not stdpath("config")
-- Priority: project root > user config directory
----------------------------------------------------------------------
local function _get_providers_path()
  -- Try project root first (when running as a standalone project)
  local cwd = vim.fn.getcwd()
  local project_path = cwd .. "/lua/ai/providers.lua"
  if vim.fn.filereadable(project_path) == 1 then
    return project_path
  end

  -- Fallback to user config directory (when installed as plugin)
  local config_path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  if vim.fn.filereadable(config_path) == 1 then
    return config_path
  end

  -- Last resort: return project path even if doesn't exist (for creating new file)
  return project_path
end

----------------------------------------------------------------------
-- Helper: Escape Lua pattern special characters
-- FIX: Prevent regex injection when provider names contain magic chars
----------------------------------------------------------------------
local function escape_pattern(s)
  return s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

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
      local display = string.format("%s  —  %s  —  %s", name, def.endpoint or "unknown", def.model or "unknown")
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
  local config_path = _get_providers_path()
  if vim.fn.filereadable(config_path) == 0 then
    return nil, nil, nil
  end
  local lines = vim.fn.readfile(config_path)
  local start_line = nil
  local end_line = nil

  -- FIX: Escape pattern special chars to prevent regex injection
  local escaped_name = escape_pattern(name)

  for i, line in ipairs(lines) do
    if line:match("M%.register%(['\"]" .. escaped_name .. "['\"]%s*,") then
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
  local config_path = _get_providers_path()
  vim.cmd("edit " .. vim.fn.fnameescape(config_path))

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
  local config_path = _get_providers_path()
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
      local escaped_name = escape_pattern(name)
      if line:match('M%.register%([\'"]' .. escaped_name .. '[\'"]%s*,') then
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

  -- Trigger config sync to Claude Code / OpenCode
  -- Keys.write() directly writes file (no BufWritePost event)
  -- so we must manually trigger sync
  vim.schedule(function()
    local ok, Sync = pcall(require, "ai.sync")
    if ok then
      Sync.sync_all({ silent = true })
    end
  end)

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
-- FIX: Only capture strings inside static_models = { ... }, not other fields
-- FIX: Track brace depth to correctly identify end of array
local function parse_static_models_from_block(content_lines)
  local models = {}
  local in_static_models = false
  local brace_depth = 0
  local collecting = false

  for _, line in ipairs(content_lines) do
    -- Start collecting when we hit static_models =
    if line:match("static_models%s*=%s*{") then
      in_static_models = true
      collecting = true
      brace_depth = 1
    end

    if collecting then
      -- Count opening braces
      for _ in line:gmatch("{") do
        brace_depth = brace_depth + 1
      end
      
      -- Count closing braces
      for _ in line:gmatch("}") do
        brace_depth = brace_depth - 1
      end

      -- Extract model IDs from current line
      -- Only capture quoted strings that are array items (not keys)
      for model_id in line:gmatch('"([^"]+)"') do
        -- FIX: Escape model_id for pattern matching (regex injection prevention)
        local escaped_model = escape_pattern(model_id)
        -- Skip if it appears to be a key (followed by =)
        if not line:match('"' .. escaped_model .. '"%s*=') then
          table.insert(models, model_id)
        end
      end

      -- Stop when we close the static_models array
      if brace_depth == 0 then
        collecting = false
        break
      end
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
-- FIX: Handle multi-line static_models blocks correctly, preserve closing braces
function M._update_static_models_in_file(provider_name, start, end_line, new_models)
  local path = _get_providers_path()
  local lines = vim.fn.readfile(path)

  -- Determine indent from first line of provider block
  local indent = lines[start]:match("^(%s*)") or "  "

  -- Find static_models block and identify closing brace type
  local static_start = nil
  local static_end = nil
  local brace_depth = 0
  local close_type = "inline" -- "inline", "separate_comma", "separate_close"

  for i = start, end_line do
    local line = lines[i]
    
    if line:match("static_models%s*=%s*{") then
      static_start = i
      -- FIX: Count braces on this line to get accurate depth
      -- Count opening braces (excluding the one in static_models = {)
      local open_count = 0
      for _ in line:gmatch("{") do
        open_count = open_count + 1
      end
      -- Count closing braces on same line (for inline case)
      local close_count = 0
      for _ in line:gmatch("}") do
        close_count = close_count + 1
      end
      brace_depth = open_count - close_count
      
      -- If inline (same line has `},` or `})`), set static_end immediately
      if close_count > 0 and brace_depth == 0 then
        static_end = i
        if line:match("^%s*}%s*,%s*$") then
          close_type = "separate_comma"
        elseif line:match("%)") then
          close_type = "inline" -- has `}` followed by `)`
        end
      end
    end
    
    -- Only count braces on subsequent lines (after static_start)
    if static_start and not static_end and i > static_start then
      -- Count braces to find end of static_models array
      for _ in line:gmatch("{") do
        brace_depth = brace_depth + 1
      end
      
      for _ in line:gmatch("}") do
        brace_depth = brace_depth - 1
        if brace_depth == 0 then
          static_end = i
          -- Determine close type from the line content
          if line:match("^%s*}%s*,%s*$") then
            close_type = "separate_comma" -- `  },`
          elseif line:match("^%s*}%s*%)%s*$") then
            close_type = "separate_close" -- `})`
          end
          break
        end
      end
    end
  end

  local new_content = build_static_models_line(new_models, indent)

  if static_start and static_end then
    -- Handle multi-line vs single-line differently
    if static_start == static_end then
      -- Single line: just replace the line
      lines[static_start] = new_content
    else
      -- Multi-line: replace entire block with single line
      -- Strategy: remove all lines between static_start and static_end, 
      -- then insert new_content at static_start
      
      -- First, check if static_end line is `})` (closes M.register)
      -- If so, we need to keep it and add `},` before it
      local static_end_line = lines[static_end]
      
      if static_end_line:match("^%s*}%s*%)%s*$") then
        -- static_end is `})` — we need to preserve it and add `},`
        -- Remove lines from static_end-1 down to static_start
        for i = static_end - 1, static_start, -1 do
          table.remove(lines, i)
        end
        -- Now insert new_content at static_start, and `},` at static_start+1
        table.insert(lines, static_start, new_content)
        table.insert(lines, static_start + 1, indent .. "},")
      elseif static_end_line:match("^%s*}%s*,%s*$") then
        -- static_end is `},` — good, we can just replace
        -- Remove lines from static_end down to static_start
        for i = static_end, static_start, -1 do
          table.remove(lines, i)
        end
        -- Insert new_content at static_start
        table.insert(lines, static_start, new_content)
      else
        -- Other case: the `}` is part of a larger line
        -- Just replace static_start, keep other lines as-is
        lines[static_start] = new_content
        -- Remove middle lines (static_start+1 to static_end-1)
        for i = static_end - 1, static_start + 1, -1 do
          table.remove(lines, i)
        end
      end
    end
  elseif static_start then
    -- Only found start, no end (malformed?) - just replace
    lines[static_start] = new_content
  else
    -- No static_models line exists - insert before closing "})"
    local insert_idx = end_line - 1
    table.insert(lines, insert_idx, new_content)
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
