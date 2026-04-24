-- lua/ai/provider_manager/results.lua
-- Floating window display for detection results

local M = {}

M._win = nil
M._buf = nil

local STATUS_SYMBOLS = {
  available   = "✓",
  unavailable = "✗",
  timeout     = "⏱",
  warning     = "⚠",
}

local MAX_COL_WIDTH = 16

----------------------------------------------------------------------
-- Private: Truncate string to max width (UTF-8 safe)
-- Fix WR-08: Use vim.fn.strcharpart to properly cut at character
-- boundaries instead of byte boundaries, preventing garbled output
-- for multi-byte characters (Chinese provider names, unicode symbols)
---------------------------------------------------------------------
local function truncate(str, max_len)
  max_len = max_len or MAX_COL_WIDTH
  local chars = vim.fn.strchars(str)
  if chars > max_len then
    return vim.fn.strcharpart(str, 0, max_len - 1) .. "…"
  end
  return str
end

----------------------------------------------------------------------
-- Private: Truncate string to max width
-- Fix WR-09: Use UTF-8 aware string.len() (str:ln()) instead of #str
-- which counts bytes. This prevents garbled Unicode characters.
----------------------------------------------------------------------
local function truncate(str)
  -- str:ln() is Neovim's UTF-8 aware string length in characters
  if str:ln() > MAX_COL_WIDTH then
    return vim.fn.strcharpart(str, 0, MAX_COL_WIDTH - 1) .. "…"
  end
  return str
end

----------------------------------------------------------------------
-- Private: Create floating window
----------------------------------------------------------------------
local function create_window(title, width, height, buf)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)
  return win
end

----------------------------------------------------------------------
-- Private: Close existing window/buffer
----------------------------------------------------------------------
local function close_existing()
  if M._win and vim.api.nvim_win_is_valid(M._win) then
    vim.api.nvim_win_close(M._win, true)
    M._win = nil
  end
  if M._buf and vim.api.nvim_buf_is_valid(M._buf) then
    vim.api.nvim_buf_delete(M._buf, { force = true })
    M._buf = nil
  end
end

----------------------------------------------------------------------
-- show_results(results, title) — batch table display
----------------------------------------------------------------------
function M.show_results(results, title)
  close_existing()

  title = title or "Detection Results"

  -- Build table lines
  local lines = {}

  -- Header (no truncation needed for fixed column names)
  local header = string.format("%-16s %-16s %-10s %-10s %s",
    "Provider", "Model", "Status",
    "Time(ms)", "Error"
  )
  table.insert(lines, header)
  table.insert(lines, string.rep("─", #header))

  -- Data rows
  for _, r in ipairs(results) do
    local sym = status_symbol(r.status)
    local provider = truncate(r.provider or "unknown")
    local model = truncate(r.model or "unknown")
    local status = sym .. " " .. truncate(r.status or "unknown", MAX_COL_WIDTH - 2)
    local time_ms = tostring(r.response_time or 0)
    local error_msg = r.error_msg and r.error_msg ~= "" and truncate(r.error_msg) or ""

    local line = string.format("%-16s %-16s %-10s %-10s %s",
      provider, model, status, time_ms, error_msg
    )
    table.insert(lines, line)
  end

  -- Determine window size
  local num_rows = #lines
  local max_line_len = 0
  for _, line in ipairs(lines) do
    if #line > max_line_len then
      max_line_len = #line
    end
  end

  local width = math.min(max_line_len + 2, math.floor(vim.o.columns * 0.8))
  local height = math.min(num_rows + 2, math.floor(vim.o.lines * 0.8))

  -- Create buffer and window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- For > 15 rows, make buffer scrollable (don't truncate, just set full content)
  -- Window height is limited but buffer has all content

  local win = create_window(title, width, height, buf)

  M._win = win
  M._buf = buf

  -- Keymap: q closes window
  vim.keymap.set("n", "q", function()
    close_existing()
  end, { buffer = buf, nowait = true, silent = true })

  -- Read-only, no wrap
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
end

----------------------------------------------------------------------
-- show_single_result(result, title) — compact single result
----------------------------------------------------------------------
function M.show_single_result(result, title)
  close_existing()

  title = title or "Detection Result"

  local sym = status_symbol(result.status)
  local lines = {
    string.format("  Provider :  %s", result.provider or "unknown"),
    string.format("  Model    :  %s", result.model or "unknown"),
    string.format("  Status   :  %s %s", sym, result.status or "unknown"),
    string.format("  Time     :  %d ms", result.response_time or 0),
  }

  if result.error_msg and result.error_msg ~= "" then
    table.insert(lines, "")
    table.insert(lines, string.format("  Error    :  %s", result.error_msg))
  end

  -- Determine window size
  local num_rows = #lines + 4
  local max_line_len = 0
  for _, line in ipairs(lines) do
    if #line > max_line_len then
      max_line_len = #line
    end
  end

  local width = math.min(max_line_len + 4, 60)
  local height = math.min(num_rows, 12)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = create_window(title, width, height, buf)

  M._win = win
  M._buf = buf

  vim.keymap.set("n", "q", function()
    close_existing()
  end, { buffer = buf, nowait = true, silent = true })

  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
end

----------------------------------------------------------------------
-- close_results() — close window and delete buffer
----------------------------------------------------------------------
function M.close_results()
  close_existing()
end

return M
