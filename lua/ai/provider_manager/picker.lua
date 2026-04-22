-- lua/ai/provider_manager/picker.lua
-- FZF-lua picker for Provider Manager with CRUD actions
-- Implements D-01, D-02, D-03, D-04, D-05 from CONTEXT.md
-- Two-step flow: provider → model selection

local M = {}

local Registry = require("ai.provider_manager.registry")
local Validator = require("ai.provider_manager.validator")
local Util = require("ai.util")

----------------------------------------------------------------------
-- Provider Picker (per UI-SPEC Section "Picker Layout")
----------------------------------------------------------------------
function M.open()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not installed", vim.log.levels.ERROR)
    return
  end

  -- Get provider list from registry
  local providers = Registry.list_providers()

  -- Build display items and name map (per review concern: empty state guard)
  local items = {}
  local name_map = {}
  for _, p in ipairs(providers) do
    table.insert(items, p.display)
    name_map[p.display] = p.name
  end

  -- Empty state handling — do NOT add placeholder to items (per review concern)
  -- Instead, show a message and return early
  if #items == 0 then
    vim.notify("No providers registered. Use <C-a> to add one.", vim.log.levels.WARN)
    return
  end

  -- fzf_exec API (per glm-5 review: fzf_exec not fzf_contents)
  fzf.fzf_exec(items, {
    prompt = "Providers> ",
    winopts = {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    },
    actions = {
      -- <CR> Select: proceed to model selection (Step 2)
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local display = selected[1]
        local name = name_map[display]
        if not name then return end
        M._select_model(name)
      end,

      -- <C-a> Add: open vim.ui.input for new provider name (per D-03)
      ["ctrl-a"] = function()
        M.add_provider_dialog()
      end,

      -- <C-d> Delete: confirm then delete (per D-04)
      -- FIX: capture name in closure BEFORE vim.ui.input async callback (per qwen review)
      ["ctrl-d"] = function(selected)
        if not selected or #selected == 0 then
          vim.notify("No provider selected", vim.log.levels.WARN)
          return
        end
        local display = selected[1]
        local name = name_map[display]
        if not name then
          vim.notify("Provider not found in registry", vim.log.levels.ERROR)
          return
        end
        -- Capture name for async callback
        M.delete_provider_dialog(name)
      end,

      -- <C-e> Edit: open providers.lua at provider line (per D-05)
      ["ctrl-e"] = function(selected)
        if not selected or #selected == 0 then
          vim.notify("No provider selected", vim.log.levels.WARN)
          return
        end
        local display = selected[1]
        local name = name_map[display]
        if not name then
          vim.notify("Provider not found in registry", vim.log.levels.ERROR)
          return
        end
        M.edit_provider(name)
      end,

      -- <C-?> Help: show help window (per UI-SPEC "Help Window")
      ["ctrl-/"] = function()
        M.show_help()
      end,
    },

    -- Header with action hints (per UI-SPEC)
    fzf_opts = {
      ["--header"] = "Actions: <CR>Select <C-a>Add <C-d>Delete <C-e>Edit <C-?>Help",
    },
  })
end

----------------------------------------------------------------------
-- Step 2: Model Selection Picker
----------------------------------------------------------------------
function M._select_model(provider_name)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end

  local models = Registry.list_models(provider_name)

  -- Build display items and id map
  local items = {}
  local id_map = {}
  local current_default = Registry.get_default_model(provider_name)

  -- Sort: current default first
  local sorted = {}
  for _, m in ipairs(models) do
    local model_id = type(m) == "table" and (m.id or m.model_id) or m
    if model_id == current_default then
      table.insert(sorted, 1, model_id)
    else
      table.insert(sorted, model_id)
    end
  end

  for _, model_id in ipairs(sorted) do
    local display = string.format("%s  —  unknown  —  unknown", model_id)
    -- Try to beautify if it's a table with metadata
    if type(model_id) == "table" and model_id.id then
      display = Util.beautify_model_item(model_id)
      id_map[display] = model_id.id
    else
      id_map[display] = model_id
    end
    table.insert(items, display)
  end

  -- Empty state
  if #items == 0 then
    vim.notify(string.format("No models available for %s. Check endpoint.", provider_name), vim.log.levels.WARN)
    return
  end

  fzf.fzf_exec(items, {
    prompt = string.format("Models for %s> ", provider_name),
    winopts = {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    },
    actions = {
      ["default"] = function(sel)
        if not sel or #sel == 0 then return end
        local label = sel[1]
        local model = id_map[label]
        if not model then return end

        -- Update default model via registry
        Registry.set_default_model(provider_name, model)
      end,

      -- <C-e> Edit static models (no extra keymap on provider picker)
      ["ctrl-e"] = function()
        M._edit_static_models(provider_name)
      end,
    },
    fzf_opts = {
      ["--header"] = "Select model to set as default for " .. provider_name .. " | <C-e> Edit static models",
    },
  })
end

----------------------------------------------------------------------
-- Dialog Functions (per UI-SPEC "Input Dialogs")
----------------------------------------------------------------------

-- Add provider dialog (per D-03, UI-SPEC)
function M.add_provider_dialog()
  vim.ui.input({ prompt = "New provider name: " }, function(name)
    if not name or name == "" then return end

    local valid, err = Validator.validate_provider_name(name)
    if not valid then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    Registry.add_provider(name)
    vim.notify("Provider added: " .. name .. ". Please add config to providers.lua", vim.log.levels.INFO)
  end)
end

-- Delete provider dialog (per D-04, UI-SPEC)
function M.delete_provider_dialog(name)
  vim.ui.input({ prompt = "Delete provider " .. name .. "? (y/n): " }, function(answer)
    if answer == "y" then
      Registry.delete_provider(name)
    end
  end)
end

-- Edit provider: open providers.lua at register line (per D-05, D-06, D-07)
function M.edit_provider(name)
  local line = Registry.find_provider_line(name)
  local path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  vim.cmd.edit({ file = path })
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  vim.notify("Editing provider: " .. name .. " at line " .. line, vim.log.levels.INFO)
end

----------------------------------------------------------------------
-- Static Models Editor (addresses PMGR-04, review: keymap density)
-- Accessed from model picker, no extra keymap on provider picker
----------------------------------------------------------------------
function M._edit_static_models(provider_name)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end

  local current_models = Registry.list_static_models(provider_name)

  -- Build items: each model plus action entries
  local items = {}
  local action_map = {}
  local idx = 1

  -- Action entries at top
  table.insert(items, "+ Add new model")
  action_map["+ Add new model"] = { type = "add" }

  if #current_models > 0 then
    for _, m in ipairs(current_models) do
      local display = m .. "  —  [select to keep, - to remove]"
      table.insert(items, display)
      action_map[display] = { type = "keep", model_id = m }
    end
  end

  fzf.fzf_exec(items, {
    prompt = string.format("Static models for %s (%d)> ", provider_name, #current_models),
    winopts = {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    },
    actions = {
      -- <CR> on "+ Add new model" → input dialog
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local item = selected[1]
        local action = action_map[item]
        if action and action.type == "add" then
          M._add_static_model_dialog(provider_name)
        end
        -- Keep action: no-op (selecting a model does nothing, - removes)
      end,

      -- <C-a> Add new model
      ["ctrl-a"] = function()
        M._add_static_model_dialog(provider_name)
      end,

      -- <C-e> Rename selected model
      ["ctrl-e"] = function(selected)
        if not selected or #selected == 0 then return end
        local item = selected[1]
        local action = action_map[item]
        if action and action.type == "keep" then
          M._rename_static_model_dialog(provider_name, action.model_id)
        else
          vim.notify("Select a model to rename", vim.log.levels.WARN)
        end
      end,

      -- <C-d> Remove selected model
      ["ctrl-d"] = function(selected)
        if not selected or #selected == 0 then return end
        local item = selected[1]
        local action = action_map[item]
        if action and action.type == "keep" then
          Registry.remove_static_model(provider_name, action.model_id)
          -- Auto-refresh static models editor
          vim.defer_fn(function() M._edit_static_models(provider_name) end, 50)
        else
          vim.notify("Select a model to remove", vim.log.levels.WARN)
        end
      end,

      -- <C-?> Help
      ["ctrl-/"] = function()
        M._show_static_models_help(provider_name)
      end,
    },
    fzf_opts = {
      ["--header"] = "Actions: <CR>Add <C-a>Add <C-e>Rename <C-d>Remove <C-?>Help | <Esc> Back",
    },
  })
end

-- Add static model dialog
function M._add_static_model_dialog(provider_name)
  vim.ui.input({ prompt = string.format("New model for %s: ", provider_name) }, function(model_id)
    if not model_id or model_id == "" then return end
    local ok = Registry.add_static_model(provider_name, model_id)
    if ok then
      -- Auto-refresh static models editor
      vim.defer_fn(function() M._edit_static_models(provider_name) end, 50)
    end
  end)
end

-- Rename static model dialog
function M._rename_static_model_dialog(provider_name, old_model_id)
  vim.ui.input({
    prompt = string.format("Rename '%s' to: ", old_model_id),
    default = old_model_id,
  }, function(new_model_id)
    if not new_model_id or new_model_id == "" or new_model_id == old_model_id then return end
    
    -- Remove old model and add new one
    local remove_ok = Registry.remove_static_model(provider_name, old_model_id)
    if remove_ok then
      Registry.add_static_model(provider_name, new_model_id)
      -- Auto-refresh static models editor
      vim.defer_fn(function() M._edit_static_models(provider_name) end, 50)
    end
  end)
end

-- Static models help
function M._show_static_models_help(provider_name)
  local help_text = string.format([[
Static Models Editor — %s

Keymaps:
  <CR>      Add new model (on '+ Add new model' line)
  <C-a>     Add new model (any line)
  <C-e>     Rename selected model
  <C-d>     Remove selected model
  <C-?>     Show this help
  <Esc>     Back to model picker

Static models are the fallback list when
dynamic model fetch is unavailable.

Press q to close
]], provider_name)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(help_text, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "help")

  local width = 55
  local height = 16
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

----------------------------------------------------------------------
-- Help Window (per UI-SPEC "Help Window")
----------------------------------------------------------------------
function M.show_help()
  local help_text = [[
Provider Manager - Help

Keymaps:
  <CR>      Select provider → show models
  <C-a>     Add new provider
  <C-d>     Delete selected provider
  <C-e>     Edit providers.lua directly
  <C-?>     Show this help

Fields managed:
  - Provider name (kebab-case)
  - Endpoint/base_url
  - Default model
  - Static models list

Press q to close
]]

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(help_text, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "help")

  local width = 60
  local height = 15
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Press q to close
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

return M
