-- AI 补全配置（avante.nvim 内嵌补全）

return {
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        default = {
          "lsp",
          "path",
          "snippets",
          "buffer",
        },

        priority = {
          lsp = 100,
          snippets = 90,
          path = 80,
          buffer = 70,
        },
      },

      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
      },
    },
  },
}

