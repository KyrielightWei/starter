-- lua/ai/components/progress_window.lua
-- Progress Window: Floating window for real-time install/deploy/update logs
-- Per D-36 to D-41

local M = {}

-- Module state
local state = {
  buf = nil,
  win = nil,
  steps = {},
  start_time = nil,
  component_name = nil,
  action = nil,
}

-- ANSI helper constants per D-42, D-37
local ANSI = {
  reset = "\27[0m",
  bold = "\27[1m",
  dim = "\27[2m",
  gray = "\27[90m",
  green = "\27[32m",
  yellow = "\27[33m",
  red = "\27[31m",
}

-- Spinner characters per D-37
local SPINNER_CHARS = { "⏳", "⟳", "◐" }
local spinner_idx = 0

-- Advance spinner for animation
local function advance_spinner()
  spinner_idx = (spinner_idx % #SPINNER_CHARS) + 1
  return SPINNER_CHARS[spinner_idx]
end

-- WR-03 fix: Remove spinner using plain string replacement (not pattern)
-- Lua patterns don't handle Unicode multi-byte characters properly
local function remove_spinner(line)
  for _, char in ipairs(SPINNER_CHARS) do
    -- Remove spinner character (plain replacement, not pattern)
    line = line:gsub(char, "", 1)
  end
  return line:gsub("%s+$", "") -- Trim trailing whitespace
end

-- Create floating progress window per D-40, D-41
local function create_progress_win(component_name, action)
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "progress")

  local title = string.format(" Progress: %s → %s ", component_name, action)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })

  vim.api.nvim_win_set_option(win, "wrap", false)
  vim.api.nvim_win_set_option(win, "cursorline", true)

  return buf, win
end

-- Open progress window and return on_progress callback per D-36
---@param component_name string Component name
---@param action string Action name (install, update, deploy, etc.)
---@return function on_progress callback to stream progress messages
function M.open(component_name, action)
  -- Close any existing window
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  -- Create new window
  state.buf, state.win = create_progress_win(component_name, action)
  state.component_name = component_name
  state.action = action
  state.steps = {}
  state.start_time = os.time()

  -- Set initial buffer content per D-36
  local initial_lines = {
    string.format("Component: %s", component_name),
    string.format("Action: %s", action),
    "",
    "Steps:",
  }
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, initial_lines)

  -- Set up "q" keymap for manual close
  vim.api.nvim_buf_set_keymap(state.buf, "n", "q", "", {
    callback = M.close,
    noremap = true,
    desc = "Close progress window",
  })

  -- Return on_progress callback
  return function(msg)
    M.update_step(msg)
  end
end

-- Update step progress per D-38
---@param msg string Progress message
function M.update_step(msg)
  -- Check window validity
  if not state.buf or not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end

  -- Filter verbose npm output per D-38
  local filtered_msg = msg
  filtered_msg = filtered_msg:gsub("npm WARN.*", "")
  filtered_msg = filtered_msg:gsub("npm info.*", "")
  filtered_msg = filtered_msg:gsub("npm http request.*", "")
  filtered_msg = filtered_msg:gsub("npm http response.*", "")

  -- Skip empty lines after filtering
  if filtered_msg:match("^%s*$") then
    return
  end

  -- Get current line count
  local line_count = vim.api.nvim_buf_line_count(state.buf)

  -- Auto-detect step start patterns
  local step_num = #state.steps + 1
  local spinner = advance_spinner()
  local formatted_msg = string.format("%d. %s %s", step_num, filtered_msg, spinner)

  -- Track step
  state.steps[step_num] = {
    msg = filtered_msg,
    line_idx = line_count,
    start_time = os.time(),
  }

  -- Append to buffer
  vim.api.nvim_buf_set_lines(state.buf, line_count, line_count, false, { formatted_msg })

  -- Auto-scroll to bottom
  vim.api.nvim_win_set_cursor(state.win, { line_count + 1, 0 })
end

-- Mark step complete with timing per D-37
---@param step_num number Step number
---@param duration number Duration in seconds (optional)
function M.mark_step_complete(step_num, duration)
  -- Check window validity
  if not state.buf or not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end

  local step = state.steps[step_num]
  -- WR-04: Guard against nil step or start_time
  if not step or not step.start_time then
    return
  end

  -- Calculate duration if not provided
  if not duration then
    duration = os.time() - step.start_time
  end

  -- WR-04: Use appropriate format for integer seconds
  local duration_str = duration == math.floor(duration)
    and string.format("%ds", duration)
    or string.format("%.1fs", duration)

  -- Get current line
  local lines = vim.api.nvim_buf_get_lines(state.buf, step.line_idx, step.line_idx + 1, false)
  if not lines or not lines[1] then
    return
  end

  -- Replace spinner with checkmark + timing per D-37
  -- Example: "1. Cloning repo... ⏳" → "1. Cloning repo ✓ (3.2s)"
  local old_line = lines[1]
  -- WR-03: Use helper for Unicode-safe spinner removal
  local msg_part = remove_spinner(old_line)
  msg_part = msg_part:gsub("^%d+%.", ""):gsub("^%s*", "")
  local new_line = string.format("%d. %s %s%s (%s)", step_num, msg_part, ANSI.green, "✓", ANSI.reset, duration_str)

  -- Update line in buffer
  vim.api.nvim_buf_set_lines(state.buf, step.line_idx, step.line_idx + 1, false, { new_line })
end

-- Handle completion per D-39
---@param success boolean Whether operation succeeded
---@param error_msg string|nil Error message if failed
function M.handle_complete(success, error_msg)
  -- Check window validity
  if not state.buf or not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(state.buf)

  if success then
    -- Show completion message
    local complete_line = ANSI.green .. "✓ Complete" .. ANSI.reset
    vim.api.nvim_buf_set_lines(state.buf, line_count, line_count, false, { "", complete_line })

    -- Auto-scroll to bottom
    vim.api.nvim_win_set_cursor(state.win, { line_count + 2, 0 })

    -- Auto-close after 2000ms per D-39
    vim.defer_fn(M.close, 2000)
  else
    -- Show error line per D-39
    local error_line = ANSI.red .. "❌ Error: " .. (error_msg or "Unknown error") .. ANSI.reset
    vim.api.nvim_buf_set_lines(state.buf, line_count, line_count, false, { "", error_line })

    -- Auto-scroll to bottom
    vim.api.nvim_win_set_cursor(state.win, { line_count + 2, 0 })

    -- Do NOT auto-close on failure - manual close only per D-39
  end
end

-- Abort/cancel progress window (user cancellation)
function M.abort()
  if state.buf and state.win and vim.api.nvim_win_is_valid(state.win) then
    local line_count = vim.api.nvim_buf_line_count(state.buf)
    local abort_line = ANSI.yellow .. "⚠ Aborted by user" .. ANSI.reset
    vim.api.nvim_buf_set_lines(state.buf, line_count, line_count, false, { "", abort_line })

    -- Close after 1000ms
    vim.defer_fn(M.close, 1000)
  end
end

-- Close progress window and reset state per D-36
function M.close()
  -- Close window if valid
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  -- Reset state
  state.buf = nil
  state.win = nil
  state.steps = {}
  state.start_time = nil
  state.component_name = nil
  state.action = nil
end

-- Check if progress window is open
---@return boolean
function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- Get current progress window state
---@return table|nil
function M.get_state()
  if M.is_open() then
    return {
      buf = state.buf,
      win = state.win,
      component_name = state.component_name,
      action = state.action,
      step_count = #state.steps,
      start_time = state.start_time,
    }
  end
  return nil
end

return M