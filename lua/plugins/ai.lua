-- lua/plugins/ai.lua
-- AI Integration Plugin Configuration
-- 
-- This file provides lazy-loading trigger for AI module.
-- Main AI tools: OpenCode, Claude Code (via Components system)

return {
  {
    "nvim-lua/plenary.nvim",  -- Common utility library (used by many AI submodules)
    lazy = true,
    config = function()
      -- Initialize AI module when plenary loads
      require("ai").setup()
    end,
  },
}
