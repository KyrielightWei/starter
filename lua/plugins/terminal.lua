-- lua/plugins/terminal.lua
-- 统一终端插件配置：替代 ui.lua 中的 toggleterm 部分和 opencode.lua 中的终端快捷键

-- 用户命令
vim.api.nvim_create_user_command("TermSelect", function()
  require("ai.terminal_picker").open()
end, { desc = "Open terminal selector" })

vim.api.nvim_create_user_command("TermNew", function(args)
  local direction = args.args ~= "" and args.args or "float"
  require("ai.terminal").create_free({ direction = direction })
end, { nargs = "?", desc = "Create new terminal (float|horizontal|vertical)" })

vim.api.nvim_create_user_command("TermKillAll", function()
  require("ai.terminal").kill_all()
  vim.notify("All terminals closed", vim.log.levels.INFO)
end, { desc = "Kill all managed terminals" })

-- 独立注册快捷键，不触发 toggleterm lazy-load
vim.keymap.set("n", "<leader>tt", "<cmd>TermSelect<CR>", { desc = "Terminal Selector" })
vim.keymap.set("n", "<leader>ta", function()
  require("ai.terminal").toggle_all()
end, { desc = "Toggle All Terminals" })

return {
  -- 覆盖 lualine 在终端 buffer 中的显示
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      -- 自定义 toggleterm extension（替代 lualine 内置的 "TERMINAL" 显示）
      -- extension 会完全接管 toggleterm filetype 的状态栏渲染
      local term_extension = {
        sections = {
          lualine_a = {
            -- 显示 vim 模式（TERMINAL / NORMAL）
            "mode",
          },
          lualine_b = {
            function()
              -- 当前终端名称 + 标签列表
              local label = vim.b.managed_term_label
              local idx = vim.b.managed_term_index
              local total = vim.b.managed_term_total
              if not label then
                return "Terminal"
              end
              -- 多终端时显示标签列表
              local ok, Terminal = pcall(require, "ai.terminal")
              if ok then
                local entries = Terminal.get_all()
                if #entries > 1 then
                  local current_id = vim.b.managed_term_id
                  local parts = {}
                  for _, entry in ipairs(entries) do
                    local short = entry.label:sub(1, 10)
                    if entry.id == current_id then
                      table.insert(parts, "[" .. short .. "]")
                    else
                      table.insert(parts, short)
                    end
                  end
                  return table.concat(parts, " │ ")
                end
              end
              return string.format("[%d/%d] %s", idx or 0, total or 0, label)
            end,
          },
          lualine_z = {
            function()
              local mode = vim.api.nvim_get_mode().mode
              if mode == "t" then
                return "C-q:Normal  C-\\C-q:关闭"
              else
                return "i:Terminal  <leader>tt:选择器  <leader>ta:全部隐藏"
              end
            end,
          },
        },
        filetypes = { "toggleterm" },
      }

      -- 移除已有的 toggleterm extension（如果有）
      opts.extensions = opts.extensions or {}
      local new_ext = {}
      for _, ext in ipairs(opts.extensions) do
        if ext ~= "toggleterm" then
          table.insert(new_ext, ext)
        end
      end
      table.insert(new_ext, term_extension)
      opts.extensions = new_ext
    end,
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        direction = "float",
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = false,
        terminal_mappings = false,
        persist_size = true,
        persist_mode = true,
        auto_scroll = true,
        close_on_exit = false, -- 改为 false，进程退出后保留终端以便查看输出
        shell = vim.o.shell,
        autochdir = false,
        float_opts = {
          border = "curved",
          winblend = 0,
          highlights = {
            border = "Normal",
            background = "Normal",
          },
        },
        winbar = {
          enabled = true,
          name_formatter = function(term)
            return string.format(" #%d - %s ", term.id, term:_display_name())
          end,
        },
      })
    end,
    keys = {
      -- 发送代码到终端（需要 toggleterm 已加载）
      {
        "<leader>tl",
        function()
          local line = vim.api.nvim_get_current_line()
          local terms = require("toggleterm.terminal").get_all()
          if #terms == 0 then
            vim.notify("No terminals open", vim.log.levels.WARN)
            return
          end
          terms[1]:send(line)
        end,
        desc = "Send Line to Terminal",
      },
      {
        "<leader>tL",
        function()
          local start_pos = vim.fn.getpos("'<")
          local end_pos = vim.fn.getpos("'>")
          local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
          local terms = require("toggleterm.terminal").get_all()
          if #terms == 0 then
            vim.notify("No terminals open", vim.log.levels.WARN)
            return
          end
          for _, l in ipairs(lines) do
            terms[1]:send(l)
          end
        end,
        mode = "v",
        desc = "Send Selection to Terminal",
      },
      -- 终端内快捷键（窗口导航）
      { "<C-h>", [[<C-\><C-n><C-w>h]], mode = "t", desc = "Terminal: Go Left" },
      { "<C-j>", [[<C-\><C-n><C-w>j]], mode = "t", desc = "Terminal: Go Down" },
      { "<C-k>", [[<C-\><C-n><C-w>k]], mode = "t", desc = "Terminal: Go Up" },
      { "<C-l>", [[<C-\><C-n><C-w>l]], mode = "t", desc = "Terminal: Go Right" },
    },
  },
}
