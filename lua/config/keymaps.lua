-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function toggleterm_with_dir(dir)
  local ok, _ = pcall(require, "toggleterm")
  if not ok then
    vim.notify("toggleterm.nvim is not available", vim.log.levels.WARN)
    return
  end

  local escaped = vim.fn.fnameescape(dir)
  vim.cmd("ToggleTerm dir=" .. escaped)
end

vim.keymap.set("n", "<leader>ft", function()
  local root = require("lazyvim.util").root()
  toggleterm_with_dir(root)
end, { desc = "ToggleTerm (Root Dir)" })

vim.keymap.set("n", "<leader>fT", function()
  toggleterm_with_dir(vim.loop.cwd())
end, { desc = "ToggleTerm (cwd)" })

vim.keymap.set("t", "<M-q>", [[<C-\><C-n>]], { desc = "Terminal Normal Mode" })
