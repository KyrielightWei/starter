return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Ensure mason installs the server
        clangd = {
          autostart = false,
          keys = {
            { "<leader>ch", "<cmd>ClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C/C++)" },
          },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern(
              "Makefile",
              "configure.ac",
              "configure.in",
              "config.h.in",
              "meson.build",
              "meson_options.txt",
              "build.ninja"
            )(fname) or require("lspconfig.util").root_pattern("compile_commands.json", "compile_flags.txt")(
           fname
            ) or require("lspconfig.util").find_git_ancestor(fname)
          end,
          capabilities = {
            offsetEncoding = { "utf-16" },
          },
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
          },
          init_options = {
            usePlaceholders = true,
            completeUnimported = true,
            clangdFileStatus = true,
          },
        },

        ccls = {
          autostart = false,
          cmd = { "ccls" },
          filetypes = { "c", "cpp", "ipp", "cuda", "ic", "objc", "objcpp" },
          root_markers = { "compile_commands.json", ".ccls", ".git", ".svn" },
          -- on_attach = function(client, bufnr)
          --     local map_opts = { noremap = true, silent = true }
          --     vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>k', '<cmd>lua vim.lsp.buf.signature_help()<CR>',
          --         map_opts)
          --     vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', map_opts)
          --
          --     vim.api.nvim_buf_create_user_command(0, 'LspSwitchSourceHeader', function()
          --       switch_source_header(client, 0)
          --     end, { desc = 'Switch between source/header' })
          --
          --     vim.api.nvim_buf_create_user_command(0, 'LspShowSymbolInfo', function()
          --       symbol_info()
          --     end, { desc = 'Show symbol info' })
          --
          --     vim.g.navic_silence = true
          --     if client.server_capabilities.documentSymbolProvider then
          --         require("nvim-navic").attach(client, bufnr)
          --     end
          -- end,
          init_options = {
            compilationDatabaseCommand = "",
            compilationDatabaseDirectory = "",
            cache = {
              directory = ".ccls-cache",
              format = "json",
              hierarchicalPath = false,
              retainInMemory = 2,
            },
            capabilities = {
              documentOnTypeFormattingProvider = {
                firstTriggerCharacter = "}",
                moreTriggerCharacter = {},
              },
              foldingRangeProvider = true,
              workspace = {
                workspaceFolders = {
                  supported = true,
                  changeNotifications = true,
                },
              },
            },
            clang = {
              excludeArgs = {},
              extraArgs = {},
              pathMappings = {},
              resourceDir = "",
            },
            client = {
              diagnosticsRelatedInformation = true,
              hierarchicalDocumentSymbolSupport = true,
              linkSupport = true,
              snippetSupport = true,
            },
            codeLens = {
              localVariables = true,
            },
            completion = {
              caseSensitivity = 2,
              detailedLabel = true,
              dropOldRequests = true,
              duplicateOptional = true,
              filterAndSort = true,
              include = {
                blacklist = {},
                maxPathSize = 30,
                suffixWhitelist = {
                  ".h",
                  ".hpp",
                  ".hh",
                  ".inc",
                },
                whitelist = {},
              },
              maxNum = 100,
              placeholder = true,
            },
            diagnostics = {
              blacklist = {},
              onChange = 1000,
              onOpen = 0,
              onSave = 0,
              spellChecking = true,
              whitelist = {},
            },
            highlight = {
              largeFileSize = 2097152,
              lsRanges = false,
              blacklist = {},
              whitelist = {},
            },
            index = {
              blacklist = {},
              comments = 2,
              initialNoLinkage = false,
              initialBlacklist = {},
              initialWhitelist = {},
              maxInitializerLines = 5,
              multiVersion = 0,
              multiVersionBlacklist = {},
              multiVersionWhitelist = {},
              name = {
                suppressUnwrittenScope = false,
              },
              onChange = false,
              parametersInDeclarations = true,
              threads = 8,
              trackDependency = 2,
              whitelist = {},
            },
            request = {
              timeout = 5000,
            },
            session = {
              maxNum = 10,
            },
            workspaceSymbol = {
              caseSensitivity = 1,
              maxNum = 1000,
              sort = true,
            },
            xref = {
              maxNum = 2000,
            },
          },
        },
      },
      setup = {
        ccls = function (_, opts)
          return false; 
        end, 
        clangd = function(_, opts)
          local clangd_ext_opts = LazyVim.opts("clangd_extensions.nvim")
          require("clangd_extensions").setup(vim.tbl_deep_extend("force", clangd_ext_opts or {}, { server = opts }))
          return false
        end,
      },
    },
  },
}
