return {
  -- {
  --   "nvim-lualine/lualine.nvim",
  --   opts = {
  --     function()
  --       local function fg(name)
  --         return function()
  --           ---@type {foreground?:number}?
  --           local hl = vim.api.nvim_get_hl(0, { name = name })
  --           return hl and hl.foreground and { fg = string.format("#%06x", hl.foreground) }
  --         end
  --       end
  --
  --       return {
  --         options = {
  --           theme = "auto",
  --           globalstatus = true,
  --           disabled_filetypes = { statusline = { "dashboard", "lazy", "alpha" } },
  --         },
  --         sections = {
  --           lualine_a = { "mode" },
  --           lualine_b = { "branch" },
  --           lualine_c = {
  --             {
  --               "diagnostics",
  --             },
  --             { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
  --             { "filename", path = 1, symbols = { modified = "  ", readonly = "", unnamed = "" } },
  --           },
  --           lualine_x = {
  --             {
  --               "lsp_status",
  --             },
  --             {
  --               require("lazy.status").updates,
  --               cond = require("lazy.status").has_updates,
  --               color = fg("Special"),
  --             },
  --             {
  --               "diff",
  --             },
  --           },
  --           lualine_y = {
  --             { "progress", separator = "", padding = { left = 1, right = 0 } },
  --             { "location", padding = { left = 0, right = 1 } },
  --           },
  --           lualine_z = {
  --             function()
  --               return " " .. os.date("%R")
  --             end,
  --           },
  --         },
  --         -- winbar = {
  --         --   lualine_a = {
  --         --     {
  --         --       "filename",
  --         --       path = 1,
  --         --     },
  --         --   },
  --         --   lualine_b = {
  --         --     {
  --         --       function()
  --         --         return require("nvim-navic").get_location()
  --         --       end,
  --         --       cond = function()
  --         --         return package.loaded["nvim-navic"] and require("nvim-navic").is_available()
  --         --       end,
  --         --     },
  --         --   },
  --         --   lualine_c = {},
  --         --   lualine_x = {},
  --         --   lualine_y = {},
  --         --   lualine_z = {},
  --         -- },
  --         -- inactive_winbar = {
  --         --   lualine_a = {},
  --         --   lualine_b = {},
  --         --   lualine_c = { "filename" },
  --         --   lualine_x = {},
  --         --   lualine_y = {},
  --         --   lualine_z = {},
  --         -- },
  --         -- extensions = { "neo-tree" },
  --       }
  --     end,
  --   },
  -- },
  --
  {
    "akinsho/bufferline.nvim",
    keys = {
      { "<leader>bp", "<Cmd>BufferLinePick<CR>", desc = "Buffer Pick" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
      { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
      { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
      { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
    },
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      open_mapping = [[<leader>t]],
      direction = 'float',
    },
  },
}
