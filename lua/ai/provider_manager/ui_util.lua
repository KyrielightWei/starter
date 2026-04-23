-- lua/ai/provider_manager/ui_util.lua
-- UI utilities for Provider Manager — icons, formatting, floating input
-- Performance-optimized: all functions use simple string ops
-- FIX: Softer icons, centered floating windows, modifiable buffer

local M = {}

----------------------------------------------------------------------
-- Icons - Softer style (Unicode symbols, not large emoji)
-- More subtle and professional appearance
----------------------------------------------------------------------
local ICONS = {
  -- Provider/Model markers (smaller, cleaner)
  provider = "•",      -- Bullet point
  model = "◦",         -- White bullet
  default = "★",       -- Star for default (subtle)
  
  -- Action indicators (minimal)
  add = "[+]",
  delete = "[-]",
  edit = "[e]",
  rename = "[r]",
  help = "?",
  
  -- Status markers
  check = "✔",
  cross = "✘",
  clock = "…",
  success = "✓",
  warn = "!",
  error = "✗",
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
-- Floating Input Dialog
-- FIX: Centered position, modifiable buffer, immediate response
----------------------------------------------------------------------
function M.floating_input(prompt, default, callback)
  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- FIX: Ensure buffer is modifiable
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "input")
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")

  -- Calculate window dimensions
  local prompt_width = vim.fn.strdisplaywidth(prompt)
  local default_width = vim.fn.strdisplaywidth(default or "")
  local width = math.max(50, prompt_width + default_width + 10)
  local height = 1

  -- FIX: Center position relative to editor (not cursor)
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = prompt,
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set default text
  if default and #default > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  end

  -- FIX: Immediate keymap response (no vim.schedule delay)
  vim.keymap.set("i", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local input = lines[1] or ""
    vim.api.nvim_win_close(win, true)
    if callback then callback(input) end
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
    if callback then callback(nil) end
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
    if callback then callback(nil) end
  end, { buffer = buf, nowait = true })

  -- Start in insert mode
  vim.cmd("startinsert")
end

----------------------------------------------------------------------
-- Confirm Dialog (for delete operations, single char input)
----------------------------------------------------------------------
function M.confirm_dialog(prompt, callback)
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- FIX: Ensure buffer is modifiable
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "modifiable", true)

  local width = math.max(40, vim.fn.strdisplaywidth(prompt) + 10)
  local height = 1

  -- FIX: Center position
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = prompt,
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set placeholder text
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "y/n" })

  -- Map keys for confirm
  vim.keymap.set({ "i", "n" }, "y", function()
    vim.api.nvim_win_close(win, true)
    if callback then callback(true) end
  end, { buffer = buf, nowait = true })

  vim.keymap.set({ "i", "n" }, "n", function()
    vim.api.nvim_win_close(win, true)
    if callback then callback(false) end
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
    if callback then callback(false) end
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
    if callback then callback(false) end
  end, { buffer = buf, nowait = true })

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