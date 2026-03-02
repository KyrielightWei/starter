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
  --             { "filename", path = 1, symbols = { modified = "  ", readonly = "", unnamed = "" } },
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
  --               return " " .. os.date("%R")
  --             end,
  --           },
  --         },
  --       }
  --     end,
  --   },
  -- },
  --
    -- VSCode-style diff viewer with two-tier highlighting
    {
      "esmuellert/codediff.nvim",
      cmd = "CodeDiff",
      opts = {
        highlights = {
          line_insert = "DiffAdd",
          line_delete = "DiffDelete",
          char_brightness = nil, -- auto-detect based on colorscheme
        },
        diff = {
          disable_inlay_hints = true,
          max_computation_time_ms = 5000,
          ignore_trim_whitespace = false,
          original_position = "left",
          jump_to_first_change = true,
        },
        keymaps = {
          view = {
            quit = "q",
            next_hunk = "]c",
            prev_hunk = "[c",
            next_file = "]f",
            prev_file = "[f",
            diff_get = "do",
            diff_put = "dp",
            show_help = "g?",
          },
        },
      },
    },
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
  -- 终端配置
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        -- 通用配置
        open_mapping = [[<c-\>]], -- 默认快捷键
        direction = "float",
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        persist_mode = true,
        auto_scroll = true,
        close_on_exit = true,
        shell = vim.o.shell,
        autochdir = false,
        -- 浮动终端配置
        float_opts = {
          border = "curved",
          winblend = 0,
          highlights = {
            border = "Normal",
            background = "Normal",
          },
        },
        -- 窗口配置
        winbar = {
          enabled = true,
          name_formatter = function(term)
            return string.format(" #%d - %s ", term.id, term:_display_name())
          end,
        },
      })

      -- 自定义终端类型
      local Terminal = require("toggleterm.terminal").Terminal

      -- 浮动终端
      local float_term = Terminal:new({
        direction = "float",
        float_opts = {
          border = "curved",
          winblend = 0,
        },
        on_open = function(term)
          vim.cmd("startinsert!")
        end,
      })

      -- 水平终端
      local horizontal_term = Terminal:new({
        direction = "horizontal",
        shade_terminals = true,
        on_open = function(term)
          vim.cmd("startinsert!")
        end,
      })

      -- 垂直终端
      local vertical_term = Terminal:new({
        direction = "vertical",
        on_open = function(term)
          vim.cmd("startinsert!")
        end,
      })

      -- 终端管理表
      _G.terminals = {
        float = float_term,
        horizontal = horizontal_term,
        vertical = vertical_term,
        list = {},
      }

      -- 快捷键函数
      _G.toggle_float_term = function()
        float_term:toggle()
      end

      _G.toggle_horizontal_term = function()
        horizontal_term:toggle()
      end

      _G.toggle_vertical_term = function()
        vertical_term:toggle()
      end

      -- 创建新终端
      _G.new_terminal = function()
        local term = Terminal:new({
          direction = "float",
          float_opts = {
            border = "curved",
          },
          on_open = function(t)
            vim.cmd("startinsert!")
            table.insert(_G.terminals.list, t)
          end,
        })
        term:toggle()
      end

      -- 终端列表选择
      _G.select_terminal = function()
        local terms = require("toggleterm.terminal").get_all()
        if #terms == 0 then
          vim.notify("No terminals open", vim.log.levels.INFO)
          return
        end

        local ok, fzf = pcall(require, "fzf-lua")
        if ok then
          local items = {}
          for _, term in ipairs(terms) do
            local name = term:_display_name() or "terminal"
            local dir = term.dir or vim.loop.cwd()
            table.insert(items, string.format("#%d: %s (%s)", term.id, name, vim.fn.fnamemodify(dir, ":t")))
          end
          fzf.fzf_exec(items, {
            prompt = "Terminals> ",
            actions = {
              ["default"] = function(selected)
                local id = tonumber(selected[1]:match("#(%d+)"))
                local term = require("toggleterm.terminal").get(id)
                if term then
                  term:toggle()
                end
              end,
              ["ctrl-d"] = function(selected)
                local id = tonumber(selected[1]:match("#(%d+)"))
                local term = require("toggleterm.terminal").get(id)
                if term then
                  term:shutdown()
                end
              end,
            },
          })
        else
          -- 回退到 vim.ui.select
          local items = {}
          for _, term in ipairs(terms) do
            local name = term:_display_name() or "terminal"
            table.insert(items, string.format("#%d: %s", term.id, name))
          end
          vim.ui.select(items, { prompt = "Select Terminal" }, function(choice, idx)
            if choice then
              terms[idx]:toggle()
            end
          end)
        end
      end

      -- 发送当前行到终端
      _G.send_line_to_term = function()
        local line = vim.api.nvim_get_current_line()
        local terms = require("toggleterm.terminal").get_all()
        if #terms == 0 then
          vim.notify("No terminals open", vim.log.levels.WARN)
          return
        end
        -- 发送到第一个终端
        terms[1]:send(line)
      end

      -- 发送选中内容到终端
      _G.send_selection_to_term = function()
        -- 获取选中的文本
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
        local terms = require("toggleterm.terminal").get_all()
        if #terms == 0 then
          vim.notify("No terminals open", vim.log.levels.WARN)
          return
        end
        for _, line in ipairs(lines) do
          terms[1]:send(line)
        end
      end

      -- 在项目根目录打开终端
      _G.toggle_term_root = function()
        local root = require("lazyvim.util").root()
        local term = Terminal:new({
          direction = "float",
          float_opts = {
            border = "curved",
          },
          dir = root,
          on_open = function(t)
            vim.cmd("startinsert!")
          end,
        })
        term:toggle()
      end
    end,
    keys = {
      -- 终端切换（t 前缀）
      { "<leader>tt", "<cmd>lua toggle_float_term()<CR>", desc = "Float Terminal" },
      { "<leader>th", "<cmd>lua toggle_horizontal_term()<CR>", desc = "Horizontal Terminal" },
      { "<leader>tv", "<cmd>lua toggle_vertical_term()<CR>", desc = "Vertical Terminal" },
      { "<leader>tn", "<cmd>lua new_terminal()<CR>", desc = "New Terminal" },
      { "<leader>ts", "<cmd>lua select_terminal()<CR>", desc = "Select Terminal" },
      { "<leader>tr", "<cmd>lua toggle_term_root()<CR>", desc = "Terminal (Root Dir)" },
      -- 发送代码到终端
      { "<leader>tl", "<cmd>lua send_line_to_term()<CR>", desc = "Send Line to Terminal" },
      { "<leader>tL", "<cmd>lua send_selection_to_term()<CR>", mode = "v", desc = "Send Selection to Terminal" },
      -- 终端内快捷键（兼容性更好的快捷键）
      { "<C-q>", [[<C-\><C-n>]], mode = "t", desc = "Terminal Normal Mode" },
      { "<C-h>", [[<C-\><C-n><C-w>h]], mode = "t", desc = "Terminal: Go Left" },
      { "<C-j>", [[<C-\><C-n><C-w>j]], mode = "t", desc = "Terminal: Go Down" },
      { "<C-k>", [[<C-\><C-n><C-w>k]], mode = "t", desc = "Terminal: Go Up" },
      { "<C-l>", [[<C-\><C-n><C-w>l]], mode = "t", desc = "Terminal: Go Right" },
      -- 备用快捷键（某些终端可能不支持 Ctrl+方向键）
      { "<Esc>", [[<C-\><C-n>]], mode = "t", desc = "Terminal Normal Mode (Esc)" },
      { "<C-[>", [[<C-\><C-n>]], mode = "t", desc = "Terminal Normal Mode (Alt)" },
      -- 方向键备用方案
      { "<C-Up>", [[<C-\><C-n><C-w>k]], mode = "t", desc = "Terminal: Go Up (Ctrl+Up)" },
      { "<C-Down>", [[<C-\><C-n><C-w>j]], mode = "t", desc = "Terminal: Go Down (Ctrl+Down)" },
      { "<C-Left>", [[<C-\><C-n><C-w>h]], mode = "t", desc = "Terminal: Go Left (Ctrl+Left)" },
      { "<C-Right>", [[<C-\><C-n><C-w>l]], mode = "t", desc = "Terminal: Go Right (Ctrl+Right)" },
      -- 终端编号切换
      { "<M-1>", [[<cmd>1ToggleTerm<CR>]], mode = { "n", "t" }, desc = "Toggle Terminal 1" },
      { "<M-2>", [[<cmd>2ToggleTerm<CR>]], mode = { "n", "t" }, desc = "Toggle Terminal 2" },
      { "<M-3>", [[<cmd>3ToggleTerm<CR>]], mode = { "n", "t" }, desc = "Toggle Terminal 3" },
      { "<M-4>", [[<cmd>4ToggleTerm<CR>]], mode = { "n", "t" }, desc = "Toggle Terminal 4" },
      { "<M-5>", [[<cmd>5ToggleTerm<CR>]], mode = { "n", "t" }, desc = "Toggle Terminal 5" },
    },
  },
}
