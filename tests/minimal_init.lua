-- tests/minimal_init.lua
-- Minimal Neovim configuration for running tests
-- Used by plenary.nvim test harness

-- Set minimal runtimepath
vim.cmd([[set runtimepath=$VIMRUNTIME]])

-- Add project root to runtimepath
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:append(project_root)

-- Add plenary.nvim to runtimepath (if available)
vim.opt.runtimepath:append(project_root .. "/.tests/plenary.nvim")

-- Disable swap files
vim.opt.swapfile = false

-- Disable plugin loading (we'll load manually)
vim.opt.loadplugins = false

-- Set up basic variables
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Minimal initialization complete
print("Minimal test config loaded")
