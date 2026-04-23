-- lua/ai/provider_manager/picker.lua
-- FZF-lua picker for Provider Manager with CRUD actions
-- Implements D-01, D-02, D-03, D-04, D-05 from CONTEXT.md
-- Two-step flow: provider → model selection

local M = {}

local Registry = require("ai.provider_manager.registry")
local Validator = require("ai.provider_manager.validator")
local Util = require("ai.util")
local UIUtil = require("ai.provider_manager.ui_util")

----------------------------------------------------------------------
-- Provider Picker (per UI-SPEC Section "Picker Layout")
-- Beautified: icons, better formatting, clearer header
----------------------------------------------------------------------
function M.open()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not installed", vim.log.levels.ERROR)
    return
  end

  -- Get provider list from registry
  local providers = Registry.list_providers()

  -- Build display items and name map with beautified format
  local items = {}
  local name_map = {}
  local icons = UIUtil.get_icons()

  for _, p in ipairs(providers) do
    local display = UIUtil.format_provider_display(p.name, {
      endpoint = p.endpoint,
      model = p.model,
    })
    table.insert(items, display)
    name_map[display] = p.name
  end

  -- Empty state handling — show friendly message with icon
  if #items == 0 then
    vim.notify(icons.provider .. " No providers registered. Use <C-a> to add one.", vim.log.levels.WARN)
    return
  end

  -- fzf_exec API with beautified prompt and header
  fzf.fzf_exec(items, {
    prompt = icons.provider .. " Select Provider > ",
    winopts = {
      width = 0.7,
      height = 0.5,
      border = "rounded",
      title = " Provider Manager ",
      title_pos = "center",
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

      -- <C-a> Add: open floating input for new provider name (per D-03)
      ["ctrl-a"] = function()
        M.add_provider_dialog()
      end,

      -- <C-d> Delete: confirm then delete (per D-04)
      -- FIX: capture name in closure BEFORE async callback
      ["ctrl-d"] = function(selected)
        if not selected or #selected == 0 then
          vim.notify("Select a provider to delete", vim.log.levels.WARN)
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
          vim.notify("Select a provider to edit", vim.log.levels.WARN)
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

    -- Header with icons and clearer action descriptions
    fzf_opts = {
      ["--header"] = string.format(
        "%s <C-a> Add  %s <C-d> Delete  %s <C-e> Edit  %s <C-?> Help",
        icons.add, icons.delete, icons.edit, icons.help
      ),
    },
  })
end

----------------------------------------------------------------------
-- Step 2: Model Selection Picker
-- Beautified: icons, default marked with ⭐, clearer header
----------------------------------------------------------------------
function M._select_model(provider_name)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end

  local models = Registry.list_models(provider_name)
  local icons = UIUtil.get_icons()

  -- Build display items and id map
  local items = {}
  local id_map = {}
  local current_default = Registry.get_default_model(provider_name)

  -- Sort: current default first (O(n) instead of O(n²) table.insert at position 1)
  local default_item = nil
  local others = {}
  for _, m in ipairs(models) do
    local model_id = type(m) == "table" and (m.id or m.model_id) or m
    if model_id == current_default then
      default_item = model_id
    else
      table.insert(others, model_id)
    end
  end
  local sorted = default_item and { default_item } or {}
  for _, m in ipairs(others) do
    table.insert(sorted, m)
  end

  for _, model_id in ipairs(sorted) do
    local is_default = model_id == current_default
    local display = UIUtil.format_model_display(model_id, is_default, nil)
    id_map[display] = model_id
    table.insert(items, display)
  end

  -- Empty state with icon
  if #items == 0 then
    vim.notify(string.format("%s No models available for %s. Check endpoint.", icons.model, provider_name), vim.log.levels.WARN)
    return
  end

  fzf.fzf_exec(items, {
    prompt = string.format("%s Select Model for %s > ", icons.model, provider_name),
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
        UIUtil.notify_with_icon(string.format("Set %s default: %s", provider_name, model), vim.log.levels.INFO, "default")
      end,

      -- <C-e> Edit static models (no extra keymap on provider picker)
      ["ctrl-e"] = function()
        M._edit_static_models(provider_name)
      end,

      -- <C-?> Help
      ["ctrl-/"] = function()
        M._show_model_picker_help(provider_name)
      end,
    },
    fzf_opts = {
      ["--header"] = string.format("%s <CR> Set Default  %s <C-e> Edit Static Models  %s <C-?> Help", icons.default, icons.edit, icons.help),
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
  local Registry2 = require("ai.provider_manager.registry")
  -- Use the same path helper from registry
  local path
  local cwd = vim.fn.getcwd()
  local project_path = cwd .. "/lua/ai/providers.lua"
  if vim.fn.filereadable(project_path) == 1 then
    path = project_path
  else
    path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"
  end
  vim.cmd.edit({ file = path })
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  vim.notify("Editing provider: " .. name .. " at line " .. line, vim.log.levels.INFO)
end

----------------------------------------------------------------------
-- Static Models Editor (addresses PMGR-04, review: keymap density)
-- Beautified: icons, floating input dialogs, clearer help
----------------------------------------------------------------------
function M._edit_static_models(provider_name)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end

  local current_models = Registry.list_static_models(provider_name)
  local icons = UIUtil.get_icons()

  -- Build items: each model plus action entries with icons
  local items = {}
  local action_map = {}
  local idx = 1

  -- Action entries at top with icon
  table.insert(items, icons.add .. " Add new model")
  action_map[icons.add .. " Add new model"] = { type = "add" }

  if #current_models > 0 then
    for _, m in ipairs(current_models) do
      local display = string.format("%s %s  %s <C-d> Remove", icons.model, m, icons.delete)
      table.insert(items, display)
      action_map[display] = { type = "keep", model_id = m }
    end
  end

  fzf.fzf_exec(items, {
    prompt = string.format("%s Static models for %s (%d)> ", icons.model, provider_name, #current_models),
    winopts = {
      width = 0.6,
      height = 0.4,
      border = "rounded",
    },
    actions = {
      -- <CR> on "+ Add new model" → floating input dialog
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local item = selected[1]
        local action = action_map[item]
        if action and action.type == "add" then
          M._add_static_model_dialog(provider_name)
        end
        -- Keep action: no-op (selecting a model does nothing, - removes)
      end,

      -- <C-a> Add new model via floating input
      ["ctrl-a"] = function()
        M._add_static_model_dialog(provider_name)
      end,

      -- <C-e> Rename selected model via floating input
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
      ["--header"] = string.format(
        "%s <C-a> Add  %s <C-e> Rename  %s <C-d> Remove  %s <C-?> Help | <CR>on '%s Add' line",
        icons.add, icons.edit, icons.delete, icons.help, icons.add
      ),
    },
  })
end

-- Add static model dialog
-- FIX: Direct call (no vim.schedule delay), floating_input is immediate now
function M._add_static_model_dialog(provider_name)
  local icons = UIUtil.get_icons()
  
  UIUtil.floating_input(
    string.format("%s New model for %s:", icons.add, provider_name),
    "",
    function(model_id)
      if not model_id or model_id == "" then return end
      local ok = Registry.add_static_model(provider_name, model_id)
      if ok then
        -- Auto-refresh static models editor
        vim.defer_fn(function() M._edit_static_models(provider_name) end, 50)
      end
    end
  )
end

-- Rename static model dialog
-- FIX: Direct call (no vim.schedule delay)
function M._rename_static_model_dialog(provider_name, old_model_id)
  local icons = UIUtil.get_icons()
  
  UIUtil.floating_input(
    string.format("%s Rename '%s' to:", icons.edit, old_model_id),
    old_model_id,
    function(new_model_id)
      if not new_model_id or new_model_id == "" or new_model_id == old_model_id then return end

      -- Atomically replace: read all, swap, write all (prevents data loss if add fails)
      local current = Registry.list_static_models(provider_name)
      local found_old = false
      for _, m in ipairs(current) do
        if m == new_model_id then
          UIUtil.notify_with_icon("Model already exists: " .. new_model_id, vim.log.levels.ERROR, "error")
          return
        end
        if m == old_model_id then
          found_old = true
        end
      end
      if not found_old then
        UIUtil.notify_with_icon("Model not found: " .. old_model_id, vim.log.levels.ERROR, "error")
        return
      end

      -- Build new list with replacement
      local new_models = {}
      for _, m in ipairs(current) do
        if m == old_model_id then
          table.insert(new_models, new_model_id)
        else
          table.insert(new_models, m)
        end
      end

      local ok = Registry.update_static_models(provider_name, new_models)
      if ok then
        -- Auto-refresh static models editor
        vim.defer_fn(function() M._edit_static_models(provider_name) end, 50)
      end
    end
  )
end

-- Static models help (with softer icons)
function M._show_static_models_help(provider_name)
  local icons = UIUtil.get_icons()
  
  local help_text = string.format([[
%s Static Models Editor — %s

Keymaps:
  %s <CR>      Add new model (on '%s Add' line)
  %s <C-a>     Add new model
  %s <C-e>     Rename selected model
  %s <C-d>     Remove selected model
  %s <C-?>     Show this help
  <Esc>        Back to model picker

Tips:
  %s Default models marked with ★
  %s Changes persist to providers.lua

Press q to close
]], icons.model, provider_name, icons.add, icons.add, icons.add, icons.edit, icons.delete, icons.help, icons.check, icons.clock)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(help_text, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "help")

  local width = 50
  local height = 16
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Static Models Help ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

----------------------------------------------------------------------
-- Help Window
----------------------------------------------------------------------
function M.show_help()
  local icons = UIUtil.get_icons()
  
  local help_text = string.format([[
%s Provider Manager - Help

Keymaps:
  <CR>        Select provider → show models
  %s <C-a>    Add new provider
  %s <C-d>    Delete selected provider
  %s <C-e>    Edit providers.lua directly
  %s <C-?>    Show this help

Fields managed:
  Provider name (kebab-case)
  Endpoint/base_url
  Default model
  Static models list

Press q to close
]], icons.provider, icons.add, icons.delete, icons.edit, icons.help)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(help_text, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "help")

  local width = 45
  local height = 15
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Provider Manager Help ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Press q to close
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

----------------------------------------------------------------------
-- Model Picker Help Window
----------------------------------------------------------------------
function M._show_model_picker_help(provider_name)
  local icons = UIUtil.get_icons()
  
  local help_text = string.format([[
%s Model Picker — %s

Keymaps:
  <CR>        Set selected model as default
  %s <C-e>    Open Static Models Editor
  %s <C-?>    Show this help
  <Esc>       Back to provider picker

Tips:
  Default model marked with ★
  Setting default updates ai_keys.lua

Press q to close
]], icons.model, provider_name, icons.edit, icons.help)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(help_text, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "help")

  local width = 40
  local height = 12
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Model Picker Help ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

return M
