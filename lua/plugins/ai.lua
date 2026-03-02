-- lua/plugins/ai.lua
return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    config = function()
      require("ai").setup()
    end,
  },
}

