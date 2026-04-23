-- lua/ai/provider_manager/ui_util.lua
-- UI utilities for Provider Manager — icons, formatting, floating input
-- Performance-optimized: all functions use simple string ops

local M = {}

----------------------------------------------------------------------
-- Icons - Softer style (Unicode symbols, not large emoji)
----------------------------------------------------------------------
local ICONS = {
  provider = "•",
  model = "◦",
  default = "★",
  add = "[+]",
  delete = "[-]",
  edit = "[e]",
  rename = "[r]",
  help = "?",
  check = "✔",
  cross = "✘",
  clock = "…",
  success = "✓",
  warn = "!",
  error = "✗",
}

----------------------------------------------------------------------
-- Get Icons (public accessor)
----------------------------------------------------------------------
function M.get_icons()
  return ICONS
end

----------------------------------------------------------------------
-- Format Provider Display
----------------------------------------------------------------------
function M.format_provider_display(name, def)
  def = def or {}
  local model = def.model or "unknown"
  local endpoint = def.endpoint or "unknown"
  if #endpoint > 40 then
    endpoint = endpoint:sub(1, 37) .. "..."
  end
  return string.format("%s %s  %s  %s", ICONS.provider, name, endpoint, model)
end

----------------------------------------------------------------------
-- Format Model Display
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
-- Notify with icon
----------------------------------------------------------------------
function M.notify_with_icon(message, level, icon_key)
  icon_key = icon_key or "success"
  local icon = ICONS[icon_key] or ""
  vim.notify(icon .. " " .. message, level)
end

----------------------------------------------------------------------
-- Reliable Floating Input Dialog
-- Creates a proper floating window with guaranteed modifiable + insert mode
----------------------------------------------------------------------
function M.floating_input(opts, callback)
  opts = opts or {}
  local prompt = opts.prompt or "Input: "
  local default = opts.default or ""

  -- Create buffer FIRST, set all options BEFORE opening window
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- CRITICAL: Set modifiable BEFORE any operations
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  
  -- Set initial content AFTER modifiable is set
  -- Add left padding for better visual appearance
  local padding = "  "  -- Two spaces for left margin
  if default and #default > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { padding .. default })
  else
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { padding })
  end

  -- Calculate dimensions - top-center position, larger width
  local width = math.max(60, #prompt + #default + 20)
  local height = 1
  local row = math.floor(vim.o.lines * 0.15)  -- Near top (15% from top)
  local col = math.floor((vim.o.columns - width) / 2)  -- Center horizontally

  -- Open floating window
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = prompt,
    title_pos = "center",
    focusable = true,
  }
  
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- Set window options for better input experience
  vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal")
  vim.api.nvim_win_set_option(win, "cursorline", false)

  -- Define keymaps AFTER window is open
  -- Enter: confirm input (strip leading padding)
  vim.keymap.set("i", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local input = lines[1] or ""
    -- Strip leading padding (2 spaces)
    input = input:gsub("^%s*", "")
    vim.api.nvim_win_close(win, true)
    if callback then callback(input) end
  end, { buffer = buf, nowait = true, silent = true })

  -- Esc: cancel
  vim.keymap.set({ "i", "n" }, "<Esc>", function()
    vim.api.nvim_win_close(win, true)
    if callback then callback(nil) end
  end, { buffer = buf, nowait = true, silent = true })

  -- q in normal: cancel
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
    if callback then callback(nil) end
  end, { buffer = buf, nowait = true, silent = true })

  -- CRITICAL: Enter insert mode IMMEDIATELY using feedkeys
  -- Move cursor to end of content (after padding + default text)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>A", true, false, true), "n", false)
end

return M