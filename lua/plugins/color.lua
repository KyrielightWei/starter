return {
  -- {
  --   "glepnir/zephyr-nvim",
  --   dependencies = { "nvim-treesitter/nvim-treesitter" },
  -- },
  -- {
  --   "rebelot/kanagawa.nvim",
  -- },
  -- {
  --   "dracula/vim",
  -- },
  {
    "github-main-user/lytmode.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("lytmode").setup()
    end,
  },
  -- {
  --   "sainnhe/sonokai",
  -- },
  -- {
  --   "ray-x/aurora",
  --   init = function()
  --     vim.g.aurora_italic = 1
  --     vim.g.aurora_transparent = 1
  --     vim.g.aurora_bold = 1
  --   end,
  --   config = function()
  --     -- vim.cmd.colorscheme("aurora")
  --     -- override defaults
  --     vim.api.nvim_set_hl(0, "@number", { fg = "#e933e3" })
  --   end,
  -- },
  -- {
  --   "xero/miasma.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     -- vim.cmd("colorscheme miasma")
  --   end,
  -- },
  {
    "everviolet/nvim",
    name = "evergarden",
    priority = 1000, -- Colorscheme plugin is loaded first before any other plugins
    opts = {
      theme = {
        variant = "fall", -- 'winter'|'fall'|'spring'|'summer'
        accent = "green",
      },
      editor = {
        transparent_background = false,
        sign = { color = "none" },
        float = {
          color = "mantle",
          solid_border = false,
        },
        completion = {
          color = "surface0",
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "lytmode",
    },
  },
}
