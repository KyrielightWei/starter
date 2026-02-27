-- lua/plugins/ai.lua
return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    config = function()
      require("ai").setup()
    end,
  },
  -- VSCode-style side-by-side diff viewer
  {
    "Niing/codediff.nvim",
    event = "VeryLazy",
    config = function()
      require("codediff").setup({
        -- Default configuration
        diff_cmd = "git diff", -- Command to get diff content
        window = {
          width = 0.8, -- Window width (percentage)
          height = 0.8, -- Window height (percentage)
          border = "rounded", -- Border style
        },
        highlights = {
          -- Two-tier highlighting: line level + character level
          add = "DiffAdd", -- Added lines
          delete = "DiffDelete", -- Deleted lines
          change = "DiffChange", -- Changed lines
          add_text = "DiffText", -- Added text (character level)
          delete_text = "DiffText", -- Deleted text (character level)
          change_text = "DiffText", -- Changed text (character level)
        },
      })
    end,
  },
}

