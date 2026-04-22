-- lua/ai/provider_manager/init.lua
-- Provider Manager subsystem orchestrator
-- Implements D-08, D-09 from CONTEXT.md

local M = {}

local Picker = require("ai.provider_manager.picker")

----------------------------------------------------------------------
-- Setup: Register keymaps and commands
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}

  -- Keymap: <leader>kp opens Provider Manager (per D-08)
  vim.keymap.set("n", "<leader>kp", function()
    Picker.open()
  end, { desc = "AI Provider Manager" })

  -- User command: :AIProviderManager (per D-09)
  vim.api.nvim_create_user_command("AIProviderManager", function()
    Picker.open()
  end, { desc = "Open AI Provider Manager panel" })

  return M
end

----------------------------------------------------------------------
-- Direct access for manual invocation
----------------------------------------------------------------------
M.open = Picker.open
M.show_help = Picker.show_help

return M
