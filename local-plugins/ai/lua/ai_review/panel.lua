local Session = require("ai_review.session")
local Anchor = require("ai_review.anchor")
local Comments = require("ai_review.comments")
local Export = require("ai_review.export")

local M = {}

function M.render(session)
  local lines = {
    "AI Review Panel",
    "────────────────────────────",
  }
  if not session then
    table.insert(lines, "No active session")
    return lines
  end
  table.insert(lines, "Session: " .. session.id)
  table.insert(lines, "Comments: " .. tostring(#(session.comments or {})))
  table.insert(lines, "")
  for i, comment in ipairs(session.comments or {}) do
    local anchor = comment.anchor or {}
    table.insert(
      lines,
      string.format("[%d] %s %s:%s", i, comment.severity or "note", anchor.file or "unknown", anchor.line or "?")
    )
    table.insert(lines, "    " .. (comment.message or ""))
    table.insert(lines, "")
  end
  return lines
end

function M.open()
  local session = Session.get_active()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.render(session))
  local width = math.min(90, vim.o.columns - 4)
  local height = math.min(math.max(8, #(session and session.comments or {}) * 3 + 5), vim.o.lines - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " AI Review Panel ",
  })
  local function current_comment()
    local line = vim.api.nvim_get_current_line()
    local idx = tonumber(line:match("^%[(%d+)%]"))
    if session and idx then
      return session.comments[idx]
    end
  end

  local function refresh()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.render(session))
  end

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", function()
    M.jump(current_comment())
  end, { buffer = buf, silent = true, desc = "Jump to review comment" })
  vim.keymap.set("n", "x", function()
    if session then
      local ok, err = Export.export(session)
      vim.notify(
        ok and "AI Review 已导出" or ("AI Review 导出失败: " .. tostring(err)),
        ok and vim.log.levels.INFO or vim.log.levels.ERROR
      )
    end
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "d", function()
    local comment = current_comment()
    if session and comment then
      Comments.delete(session, comment.id)
      Session.save(session)
      refresh()
    end
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "e", function()
    local comment = current_comment()
    if not comment then
      return
    end
    vim.ui.input({ prompt = "Edit review comment: ", default = comment.message or "" }, function(message)
      if message and message ~= "" then
        Comments.edit(session, comment.id, { message = message })
        Session.save(session)
        refresh()
      end
    end)
  end, { buffer = buf, silent = true, desc = "Edit review comment" })
  vim.keymap.set("n", "r", function()
    local comment = current_comment()
    if session and comment then
      Comments.resolve(session, comment.id)
      Session.save(session)
      refresh()
    end
  end, { buffer = buf, silent = true, desc = "Resolve review comment" })
end

function M.jump(comment)
  local anchor = comment and comment.anchor or Anchor.from_cursor()
  if not anchor or not anchor.file then
    return false
  end
  vim.cmd("edit " .. vim.fn.fnameescape(anchor.file))
  if anchor.line then
    vim.api.nvim_win_set_cursor(0, { anchor.line, 0 })
  end
  return true
end

return M
