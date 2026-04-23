-- lua/ai/provider_manager/ui_util.lua
-- UI utilities for Provider Manager — icons, formatting, floating input
-- Performance-optimized: all functions use simple string ops

local M = {}

----------------------------------------------------------------------
-- Icons and Colors (performance: pre-defined constants)
-- FIX: Provide ASCII fallback for terminals without emoji support
----------------------------------------------------------------------
local USE_EMOJI = vim.fn.has("nvim-0.9") == 1 and vim.env.TERM ~= nil and not vim.env.TERM:match("dumb")

local ICONS = USE_EMOJI and {
  provider = "📦",
  model = "🤖",
  add = "➕",
  delete = "🗑️",
  edit = "✏️",
  rename = "📝",
  help = "❓",
  check = "✓",
  cross = "✗",
  clock = "⏱",
  default = "⭐",
  success = "✅",
  warn = "⚠️",
  error = "❌",
} or {
  provider = "[P]",
  model = "[M]",
  add = "[+]",
  delete = "[-]",
  edit = "[E]",
  rename = "[R]",
  help = "[?]",
  check = "[OK]",
  cross = "[X]",
  clock = "[...]",
  default = "[*]",
  success = "[OK]",
  warn = "[WARN]",
  error = "[ERR]",
}

-- Simple ANSI colors (works in most terminals)
local COLORS = {
  highlight = "\x1b[1m", -- bold
  reset = "\x1b[0m",
  green = "\x1b[32m",
  yellow = "\x1b[33m",
  red = "\x1b[31m",
  cyan = "\x1b[36m",
}

----------------------------------------------------------------------
-- Get Icons (public accessor for external use)
----------------------------------------------------------------------
function M.get_icons()
  return ICONS
end

----------------------------------------------------------------------
-- Format Provider Display (performance: single string.format call)
----------------------------------------------------------------------
function M.format_provider_display(name, def)
  def = def or {}
  local model = def.model or "unknown"
  local endpoint = def.endpoint or "unknown"

  -- Truncate long endpoints for readability
  if #endpoint > 40 then
    endpoint = endpoint:sub(1, 37) .. "..."
  end

  return string.format("%s %s  %s  %s", ICONS.provider, name, endpoint, model)
end

----------------------------------------------------------------------
-- Format Model Display (performance: single string.format call)
----------------------------------------------------------------------
function M.format_model_display(model_id, is_default, metadata)
  metadata = metadata or {}
  local icon = is_default and ICONS.default or ICONS.model
  local context = metadata.context_length or ""

  if context and #context > 0 then
    context = string.format("[%s]", context)
  else
    context = ""
  end

  return string.format("%s %s %s", icon, model_id, context)
end

----------------------------------------------------------------------
-- Floating Input Dialog (performance: minimal buffer operations)
----------------------------------------------------------------------
function M.floating_input(prompt, default, callback)
  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "input")

  -- FIX: Calculate window dimensions using display width (not byte length)
  local prompt_width = vim.fn.strdisplaywidth(prompt)
  local default_width = vim.fn.strdisplaywidth(default or "")
  local width = math.max(60, prompt_width + default_width + 20)
  local height = 1

  -- Open floating window
  -- FIX: Check Neovim version for title support (requires 0.8+)
  local opts = {
    relative = "cursor",
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
  }

  -- Add title only if Neovim >= 0.8
  if vim.fn.has("nvim-0.8") == 1 then
    opts.title = prompt
    opts.title_pos = "center"
  end

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set default text
  if default and #default > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  end

  -- Map keys
  vim.keymap.set("i", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local input = lines[1] or ""
    vim.api.nvim_win_close(win, true)
    if callback then
      callback(input)
    end
  end, { buffer = buf })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
    if callback then
      callback(nil)
    end
  end, { buffer = buf })

  -- FIX: Also allow 'q' to close (common Neovim pattern)
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
    if callback then
      callback(nil)
    end
  end, { buffer = buf })

  -- Start in insert mode
  vim.cmd("startinsert")
end

----------------------------------------------------------------------
-- Confirm Dialog (for delete operations, single char input)
----------------------------------------------------------------------
function M.confirm_dialog(prompt, callback)
  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local width = math.max(40, vim.fn.strdisplaywidth(prompt) + 10)
  local height = 1

  local opts = {
    relative = "cursor",
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
  }

  if vim.fn.has("nvim-0.8") == 1 then
    opts.title = prompt
    opts.title_pos = "center"
  end

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set placeholder text
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "y/n" })

  -- Map keys for confirm
  vim.keymap.set({ "i", "n" }, "y", function()
    vim.api.nvim_win_close(win, true)
    if callback then
      callback(true)
    end
  end, { buffer = buf })

  vim.keymap.set({ "i", "n" }, "n", function()
    vim.api.nvim_win_close(win, true)
    if callback then
      callback(false)
    end
  end, { buffer = buf })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
    if callback then
      callback(false)
    end
  end, { buffer = buf })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
    if callback then
      callback(false)
    end
  end, { buffer = buf })

  -- Start in insert mode
  vim.cmd("startinsert")
end

----------------------------------------------------------------------
-- Notify with icon
----------------------------------------------------------------------
function M.notify_with_icon(message, level, icon_key)
  icon_key = icon_key or "success"
  local icon = ICONS[icon_key] or ""
  vim.notify(icon .. " " .. message, level)
end

return M