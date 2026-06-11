local Store = require("ai_review.store")

local M = {}

local function context_lines(bufnr, lnum, before, after)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local before_start = math.max(1, lnum - before)
  local before_lines = vim.api.nvim_buf_get_lines(bufnr, before_start - 1, lnum - 1, false)
  local after_lines = vim.api.nvim_buf_get_lines(bufnr, lnum, math.min(total, lnum + after), false)
  return before_lines, after_lines
end

local function parse_diffview_name(name)
  local rest = name:match("^diffview://(.+)$")
  if not rest then
    return nil
  end

  local root = Store.repo_root()
  if root and rest:sub(1, #root + 1) == root .. "/" then
    local remainder = rest:sub(#root + 2)
    local rev, path = remainder:match("^([^/]+)/(.+)$")
    if rev and path and path ~= "null" then
      return root, rev, path
    end
  end

  local rev, path = rest:match("^([^/]+)/(.+)$")
  if not rev or path == "null" then
    return nil
  end
  return nil, rev, path
end

function M.from_cursor(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local winid = opts.winid or 0
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local lnum = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)
  local line_text = lines[1] or ""
  local name = vim.api.nvim_buf_get_name(bufnr)
  local repo = opts.repo or Store.repo_root()
  local file = nil
  local side = opts.side or "right"
  local meaning = opts.meaning or "new"
  local commit = opts.commit
  local partial = false

  local dv_repo, dv_rev, dv_path = parse_diffview_name(name)
  if dv_path then
    repo = dv_repo or repo
    file = dv_path
    commit = commit or dv_rev
    if dv_rev and (dv_rev:match("^:") or dv_rev == "[custom]") then
      side = "right"
      meaning = "new"
    elseif opts.side then
      meaning = side == "left" and "old" or "new"
    end
  elseif name and name ~= "" then
    file = vim.fn.fnamemodify(name, ":p")
    local rel = vim.fn.fnamemodify(file, ":.")
    if opts.repo then
      rel = file:gsub("^" .. vim.pesc(opts.repo) .. "/?", "")
    end
    file = rel
  else
    file = "unknown"
    partial = true
  end

  if file == name and repo then
    file = file:gsub("^" .. vim.pesc(repo) .. "/?", "")
  end

  local before_lines, after_lines = context_lines(bufnr, lnum, opts.context_before or 3, opts.context_after or 3)

  return {
    file = file,
    side = side,
    meaning = meaning,
    line = lnum,
    line_text = line_text,
    context_before = before_lines,
    context_after = after_lines,
    hunk = opts.hunk,
    commit = commit,
    partial = partial,
  }
end

return M
