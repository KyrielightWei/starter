local Range = require("ai_review.range")
local Session = require("ai_review.session")
local Comments = require("ai_review.comments")
local Anchor = require("ai_review.anchor")

local M = {}

local SIGN_GROUP = "AIReview"
local SIGN_NAME = "AIReviewComment"

local function ensure_sign()
  pcall(vim.fn.sign_define, SIGN_NAME, { text = "󰅺", texthl = "DiagnosticInfo", numhl = "DiagnosticInfo" })
end

function M.open(range)
  local ok = pcall(require, "diffview")
  if not ok then
    vim.notify("AI Review 需要 diffview.nvim", vim.log.levels.ERROR)
    return false
  end
  local args = Range.to_diffview_args(range)
  local ok_cmd, err = pcall(vim.cmd, "DiffviewOpenEnhanced " .. args)
  if not ok_cmd then
    vim.notify("打开 review diff 失败: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.install_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, noremap = true }
  vim.keymap.set("n", "<leader>kra", function()
    require("ai_review.init").add_comment()
  end, vim.tbl_extend("force", opts, { desc = "AI Review Add Comment" }))
  vim.keymap.set("n", "<leader>krv", function()
    require("ai_review.diffview").preview_under_cursor()
  end, vim.tbl_extend("force", opts, { desc = "AI Review Preview Comment" }))
  vim.keymap.set("n", "<leader>krl", function()
    require("ai_review.panel").open()
  end, vim.tbl_extend("force", opts, { desc = "AI Review Panel" }))
  vim.keymap.set("n", "<leader>krx", function()
    require("ai_review.init").export()
  end, vim.tbl_extend("force", opts, { desc = "AI Review Export" }))
end

function M.place_sign(bufnr, comment)
  ensure_sign()
  local anchor = comment.anchor or {}
  if not anchor.line then
    return
  end
  vim.fn.sign_place(0, SIGN_GROUP, SIGN_NAME, bufnr, { lnum = anchor.line, priority = 20 })
end

function M.restore_signs(bufnr)
  ensure_sign()
  vim.fn.sign_unplace(SIGN_GROUP, { buffer = bufnr })
  local session = Session.get_active()
  if not session then
    return
  end
  local current = Anchor.from_cursor({ bufnr = bufnr })
  for _, comment in ipairs(session.comments or {}) do
    local anchor = comment.anchor or {}
    if anchor.file == current.file and anchor.line then
      M.place_sign(bufnr, comment)
    end
  end
end

function M.preview_under_cursor()
  local session = Session.get_active()
  if not session then
    vim.notify("没有 active AI Review session", vim.log.levels.INFO)
    return
  end
  local anchor = Anchor.from_cursor()
  local comments = Comments.for_anchor(session, anchor)
  if #comments == 0 then
    vim.notify("当前行没有 review comment", vim.log.levels.INFO)
    return
  end
  local lines = {}
  for _, comment in ipairs(comments) do
    table.insert(lines, string.format("[%s] %s", comment.severity or "note", comment.id or ""))
    table.insert(lines, comment.message or "")
    table.insert(lines, "")
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  local width = math.min(80, math.max(30, vim.o.columns - 8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.4))
  vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = math.max(1, height),
    style = "minimal",
    border = "rounded",
    title = " AI Review Comment ",
  })
end

function M.setup_buffer(bufnr)
  M.install_keymaps(bufnr)
  M.restore_signs(bufnr)
end

return M
