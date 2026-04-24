-- lua/ai/provider_manager/init.lua
-- Provider Manager subsystem orchestrator
-- Implements D-08, D-09 from CONTEXT.md

local M = {}

local Picker = require("ai.provider_manager.picker")
local Detector = require("ai.provider_manager.detector")
local Results = require("ai.provider_manager.results")
local Cache = require("ai.provider_manager.cache")
local Registry = require("ai.provider_manager.registry")
local State = require("ai.state")

----------------------------------------------------------------------
-- Helper: Check if provider exists in registry
----------------------------------------------------------------------
local function provider_exists(name)
  for _, p in ipairs(Registry.list_providers()) do
    if p.name == name then return true end
  end
  return false
end

----------------------------------------------------------------------
-- Helper: Command callback — check single provider/model
----------------------------------------------------------------------
local function cmd_check_provider(opts)
  local args = opts.fargs
  local provider, model

  if #args == 0 then
    -- No args: use current provider from state
    local current = State.get()
    provider = current.provider
    model = current.model
    if not provider then
      vim.notify("No current provider set. Use :AICheckProvider <name>", vim.log.levels.WARN)
      return
    end
  elseif #args == 1 then
    -- One arg: provider name, resolve default model
    provider = args[1]
  else
    -- Two args: provider + specific model
    provider = args[1]
    model = args[2]
  end

  -- Validate provider exists
  if not provider_exists(provider) then
    vim.notify("Provider not found: " .. provider, vim.log.levels.ERROR)
    return
  end

  -- Resolve model if not specified
  if not model or model == "" then
    model = Registry.get_default_model(provider)
    if not model then
      local def = require("ai.providers").get(provider)
      model = def and def.model or "unknown"
    end
  end

  -- Run sync check
  local result = Detector.check_single(provider, model)
  if result then
    Results.show_single_result(result, "Detection Result: " .. provider .. "/" .. model)
  else
    vim.notify("Detection timed out for " .. provider, vim.log.levels.WARN)
  end
end

----------------------------------------------------------------------
-- Helper: Command callback — check all providers
----------------------------------------------------------------------
local function cmd_check_all()
  Detector.check_all_providers(function(results)
    if not results or #results == 0 then
      vim.notify("No providers found to check", vim.log.levels.WARN)
      return
    end
    Results.show_results(results, "All Providers Detection")
  end)
end

----------------------------------------------------------------------
-- Helper: Command callback — clear detection cache
----------------------------------------------------------------------
local function cmd_clear_cache()
  Cache.clear()
  vim.notify("Detection cache cleared", vim.log.levels.INFO)
end

----------------------------------------------------------------------
-- Provider completion for :AICheckProvider
----------------------------------------------------------------------
local function provider_complet(arglead)
  local completions = {}
  for _, p in ipairs(Registry.list_providers()) do
    if p.name:find(arglead, 1, true) == 1 then
      table.insert(completions, p.name)
    end
  end
  return completions
end

----------------------------------------------------------------------
-- Setup: Register keymaps and commands
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}

  -- Phase 1: Provider Manager picker
  vim.keymap.set("n", "<leader>kp", function()
    Picker.open()
  end, { desc = "AI Provider Manager" })

  vim.api.nvim_create_user_command("AIProviderManager", function()
    Picker.open()
  end, { desc = "Open AI Provider Manager panel" })

  -- Phase 2: Detection keymaps
  vim.keymap.set("n", "<leader>kP", function()
    cmd_check_provider({ fargs = {} })
  end, { desc = "Check current provider/model" })

  vim.keymap.set("n", "<leader>kA", function()
    cmd_check_all()
  end, { desc = "Check all providers" })

  -- Phase 2: Detection commands
  vim.api.nvim_create_user_command("AICheckProvider", cmd_check_provider, {
    desc = "Check provider/model availability",
    nargs = "*",
    complete = provider_complet,
  })

  vim.api.nvim_create_user_command("AICheckAllProviders", cmd_check_all, {
    desc = "Check all configured providers",
    nargs = 0,
  })

  vim.api.nvim_create_user_command("AIClearDetectionCache", cmd_clear_cache, {
    desc = "Clear all cached detection results",
    nargs = 0,
  })

  return M
end

----------------------------------------------------------------------
-- Direct access for manual invocation
----------------------------------------------------------------------
M.open = Picker.open
M.show_help = Picker.show_help

-- Phase 2: Detection exports
M.check_provider = function(provider_name, callback)
  Detector.check_provider(provider_name, function(r)
    Results.show_single_result(r, "Detection Result: " .. provider_name)
    if callback then callback(r) end
  end)
end

M.check_all = function(callback)
  Detector.check_all_providers(function(results)
    Results.show_results(results, "All Providers Detection")
    if callback then callback(results) end
  end)
end

return M
