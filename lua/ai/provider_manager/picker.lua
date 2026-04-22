-- lua/ai/provider_manager/picker.lua
-- FZF-lua picker for Provider Manager with CRUD actions
-- Implements D-01, D-02, D-03, D-04, D-05 from CONTEXT.md

local M = {}

local Registry = require("ai.provider_manager.registry")
local Validator = require("ai.provider_manager.validator")

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
      -- <CR> Select: proceed to model selection (Step 2 deferred to Phase 3)
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local display = selected[1]
        local name = name_map[display]
        if not name then return end
        -- TODO: Step 2 model selection — deferred to Phase 3 (auto-detection)
        -- For now, just select the provider
        vim.notify("Selected provider: " .. name, vim.log.levels.INFO)
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
  vim.cmd("edit " .. path)
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  vim.notify("Editing provider: " .. name .. " at line " .. line, vim.log.levels.INFO)
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
