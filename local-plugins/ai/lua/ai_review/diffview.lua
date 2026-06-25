local Range = require("ai_review.range")
local Session = require("ai_review.session")
local Comments = require("ai_review.comments")
local Anchor = require("ai_review.anchor")
local Config = require("ai_review.config")

local M = {}

local SIGN_GROUP = "AIReview"
local SIGN_NAME = "AIReviewComment"
local SIGN_APPROVED = "AIReviewApproved"

----------------------------------------------------------------------
-- sign 定义
----------------------------------------------------------------------
local function ensure_signs()
  pcall(vim.fn.sign_define, SIGN_NAME, { text = "󰅺", texthl = "DiagnosticInfo", numhl = "DiagnosticInfo" })
  pcall(vim.fn.sign_define, SIGN_APPROVED, { text = "✓", texthl = "DiagnosticOk", numhl = "DiagnosticOk" })
end

----------------------------------------------------------------------
-- _build_exclude_args(): 构建 git pathspec 排除参数
----------------------------------------------------------------------
function M._build_exclude_args()
  local patterns = Config.get_exclude_patterns()
  if #patterns == 0 then
    return ""
  end
  local parts = {}
  for _, p in ipairs(patterns) do
    table.insert(parts, "':(exclude)" .. p .. "'")
  end
  return table.concat(parts, " ")
end

----------------------------------------------------------------------
-- open(range): 打开 diffview 并通过 git pathspec 排除无关文件
----------------------------------------------------------------------
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

  -- 使用重试机制调用后置过滤，确保文件列表加载完成
  -- 注意：git pathspec 方式无法过滤未跟踪文件，必须使用后置过滤
  vim.defer_fn(function()
    M.filter_with_retry(5, 1000) -- 最多重试 5 次，每次间隔 1 秒
  end, 500)

  return true
end

----------------------------------------------------------------------
-- filter_excluded_files(): 从 diffview 文件列表中移除匹配的文件
----------------------------------------------------------------------
function M.filter_excluded_files()
  local ok, diffview_lib = pcall(require, "diffview.lib")
  if not ok then
    vim.notify("无法加载 diffview.lib", vim.log.levels.DEBUG)
    return false
  end

  -- 获取当前 diffview 视图
  local view = diffview_lib.get_current_view()
  if not view then
    vim.notify("未找到 diffview 视图", vim.log.levels.DEBUG)
    return false
  end

  if not view.files then
    vim.notify("diffview 文件列表未加载", vim.log.levels.DEBUG)
    return false
  end

  -- 检查文件列表是否为空（可能还在加载中）
  local total_files = #(view.files.working or {}) + #(view.files.staged or {}) + #(view.files.conflicting or {})
  if total_files == 0 then
    vim.notify("diffview 文件列表为空，可能还在加载中", vim.log.levels.DEBUG)
    return false
  end

  -- 分别过滤三种类型的文件
  local filtered_working = {}
  local filtered_staged = {}
  local filtered_conflicting = {}
  local excluded_count = 0

  -- 过滤 working 文件
  for _, file in ipairs(view.files.working or {}) do
    if file and file.path and not Config.is_excluded(file.path) then
      table.insert(filtered_working, file)
    else
      excluded_count = excluded_count + 1
    end
  end

  -- 过滤 staged 文件
  for _, file in ipairs(view.files.staged or {}) do
    if file and file.path and not Config.is_excluded(file.path) then
      table.insert(filtered_staged, file)
    else
      excluded_count = excluded_count + 1
    end
  end

  -- 过滤 conflicting 文件
  for _, file in ipairs(view.files.conflicting or {}) do
    if file and file.path and not Config.is_excluded(file.path) then
      table.insert(filtered_conflicting, file)
    else
      excluded_count = excluded_count + 1
    end
  end

  -- 更新文件列表
  if excluded_count > 0 then
    view.files:set_working(filtered_working)
    view.files:set_staged(filtered_staged)
    view.files:set_conflicting(filtered_conflicting)
    view.files:update_file_trees()

    -- #2 修复: 完整刷新文件面板（包含 redraw 和 reconstrain_cursor）
    if view.panel then
      pcall(function()
        view.panel:update_components()
        view.panel:render()
        if view.panel.redraw then
          view.panel:redraw()
        end
        if view.panel.reconstrain_cursor then
          view.panel:reconstrain_cursor()
        end
      end)
    end

    vim.notify(string.format("已过滤 %d 个非代码文件", excluded_count), vim.log.levels.INFO)
    return true
  else
    vim.notify("没有需要过滤的文件", vim.log.levels.DEBUG)
    return false
  end
end

----------------------------------------------------------------------
-- filter_with_retry(): 带重试机制的过滤函数
-- 注意: 异步执行，无返回值。调用方不应依赖过滤结果做后续操作。
-- 重试仅在后台进行，确保 diffview 文件列表最终被正确过滤。
----------------------------------------------------------------------
function M.filter_with_retry(max_retries, delay_ms)
  max_retries = max_retries or 5
  delay_ms = delay_ms or 1000

  local function try_filter(retry_count)
    local success = M.filter_excluded_files()
    if not success and retry_count < max_retries then
      vim.defer_fn(function()
        try_filter(retry_count + 1)
      end, delay_ms)
    end
  end

  try_filter(0)
end

----------------------------------------------------------------------
-- install_keymaps(bufnr): diffview buffer 内专属快捷键
----------------------------------------------------------------------
function M.install_keymaps(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  -- 避免重复安装 keymap
  if vim.b[bufnr].ai_review_keymaps_installed then
    return
  end
  vim.b[bufnr].ai_review_keymaps_installed = true

  local opts = { buffer = bufnr, silent = true, noremap = true }

  vim.keymap.set("n", "<leader>a", function()
    require("ai_review.init").add_comment()
  end, vim.tbl_extend("force", opts, { desc = "Review: Add Comment" }))

  vim.keymap.set("n", "<leader>v", function()
    M.preview_under_cursor()
  end, vim.tbl_extend("force", opts, { desc = "Review: Preview Comment" }))

  vim.keymap.set("n", "<leader>y", function()
    M.toggle_approve()
  end, vim.tbl_extend("force", opts, { desc = "Review: Approve" }))

  vim.keymap.set("n", "<leader>c", function()
    M.list_file_comments()
  end, vim.tbl_extend("force", opts, { desc = "Review: File Comments" }))
end

----------------------------------------------------------------------
-- Sign ID 计数器
-- 注意: 模块级递增，在单个 Neovim session 中不会溢出。
-- 跨 session 重置，但因使用独立 SIGN_GROUP，不会与 diffview 的 sign 冲突。
----------------------------------------------------------------------
local _next_sign_id = 1
local function alloc_sign_id()
  local id = _next_sign_id
  _next_sign_id = _next_sign_id + 1
  return id
end

----------------------------------------------------------------------
-- place_sign / restore_signs
----------------------------------------------------------------------
function M.place_sign(bufnr, comment)
  ensure_signs()
  local anchor = comment.anchor or {}
  if not anchor.line then
    return nil
  end
  local id = alloc_sign_id()
  vim.fn.sign_place(id, SIGN_GROUP, SIGN_NAME, bufnr, { lnum = anchor.line, priority = 20 })
  return id
end

function M.place_approve_sign(bufnr, line)
  ensure_signs()
  if not line then
    return nil
  end
  local id = alloc_sign_id()
  vim.fn.sign_place(id, SIGN_GROUP, SIGN_APPROVED, bufnr, { lnum = line, priority = 15 })
  return id
end

function M.restore_signs(bufnr)
  ensure_signs()
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

  for _, entry in ipairs(session.approved or {}) do
    local sign_line = entry.line_start or entry.line
    if entry.level == "global" then
      -- global approve 不在每个文件都放 sign
    elseif entry.level == "dir" then
      -- 目录级别：如果当前文件在该目录下，在第一行放 sign
      if entry.path and current.file and current.file:sub(1, #entry.path) == entry.path then
        M.place_approve_sign(bufnr, 1)
      end
    elseif entry.file == current.file and sign_line then
      M.place_approve_sign(bufnr, sign_line)
    end
  end
end

----------------------------------------------------------------------
-- preview_under_cursor(): 预览当前行的 review comment
----------------------------------------------------------------------
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
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  local width = math.min(80, math.max(30, vim.o.columns - 8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.4))
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = math.max(1, height),
    style = "minimal",
    border = "rounded",
    title = " AI Review Comment ",
  })
  -- #6 修复: 使用 augroup + once，避免 autocmd 泄漏
  local preview_grp = vim.api.nvim_create_augroup("AIReviewPreview_" .. win, { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
    group = preview_grp,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      pcall(vim.api.nvim_del_augroup_by_id, preview_grp)
    end,
  })
end

----------------------------------------------------------------------
-- Git diff hunk 解析：获取文件的 hunk 行范围
----------------------------------------------------------------------
local function range_to_git_args(range)
  if range.type == "single_commit" then
    return { range.sha .. "^", range.sha }
  elseif range.type == "commit_range" then
    return { range.base, range.head }
  elseif range.type == "since_base" then
    return { range.base, range.head or "HEAD" }
  elseif range.type == "worktree" then
    return nil -- 特殊处理
  end
  return nil
end

--- #6 修复: 添加 hunk 缓存，避免重复计算
-- #7 修复: 添加大小限制，超过 500 条目时清空重建
local HUNK_CACHE_MAX = 500
local hunk_cache = {}

--- 主动失效 hunk 缓存（session 切换、approve 操作时调用）
function M.invalidate_hunk_cache()
  hunk_cache = {}
end
local function get_cache_key(file_path, session_range)
  if session_range.type == "single_commit" then
    return file_path .. ":" .. session_range.sha
  elseif session_range.type == "commit_range" then
    return file_path .. ":" .. session_range.base .. ".." .. session_range.head
  elseif session_range.type == "since_base" then
    return file_path .. ":" .. session_range.base .. ".." .. (session_range.head or "HEAD")
  elseif session_range.type == "worktree" then
    return file_path .. ":worktree"
  end
  return file_path .. ":unknown"
end

--- 获取指定文件的 diff hunk 行范围列表
--- 返回: { {line_start=N, line_end=M}, ... }
function M.get_file_hunks(file_path, session_range)
  if not session_range then
    local session = Session.get_active()
    if not session then
      return {}
    end
    session_range = session.range
  end

  -- #6 修复: 检查缓存
  local cache_key = get_cache_key(file_path, session_range)
  if hunk_cache[cache_key] then
    return hunk_cache[cache_key]
  end

  local hunks = M._compute_file_hunks(file_path, session_range)
  -- #7 修复: 超过上限时清空，防止内存无限增长
  local count = 0
  for _ in pairs(hunk_cache) do
    count = count + 1
  end
  if count >= HUNK_CACHE_MAX then
    hunk_cache = {}
  end
  hunk_cache[cache_key] = hunks
  return hunks
end

--- #10 修复: 提取公共 hunk 解析逻辑
local function parse_hunks_from_stdout(stdout)
  local hunks = {}
  local hunk_start, hunk_count = nil, nil
  for line in stdout:gmatch("[^\n]+") do
    local ls, lc = line:match("^@@ %-%d+,?%d* %+(%d+),?(%d*)")
    if ls then
      if hunk_start and hunk_count then
        table.insert(hunks, { line_start = hunk_start, line_end = hunk_start + hunk_count - 1 })
      end
      hunk_start = tonumber(ls)
      hunk_count = tonumber(lc) or 1
      if hunk_count == 0 then
        hunk_start, hunk_count = nil, nil
      elseif hunk_count == 1 then
        table.insert(hunks, { line_start = hunk_start, line_end = hunk_start })
        hunk_start, hunk_count = nil, nil
      end
    end
  end
  if hunk_start and hunk_count then
    table.insert(hunks, { line_start = hunk_start, line_end = hunk_start + hunk_count - 1 })
  end
  return hunks
end

--- #10 修复: 内部实现，被缓存包装
function M._compute_file_hunks(file_path, session_range)
  local cmd = { "git", "diff", "-U0" }

  local args = range_to_git_args(session_range)
  if args then
    vim.list_extend(cmd, args)
  elseif session_range.type == "worktree" then
    -- worktree: 同时获取 staged + unstaged
    local result = vim.system({ "git", "diff", "-U0", "--", file_path }):wait(5000)
    local result2 = vim.system({ "git", "diff", "-U0", "--cached", "--", file_path }):wait(5000)
    local hunks = {}
    if result and result.code == 0 and result.stdout then
      vim.list_extend(hunks, parse_hunks_from_stdout(result.stdout))
    end
    if result2 and result2.code == 0 and result2.stdout then
      vim.list_extend(hunks, parse_hunks_from_stdout(result2.stdout))
    end
    return hunks
  end

  table.insert(cmd, "--")
  table.insert(cmd, file_path)

  local result = vim.system(cmd):wait(5000)
  if not result or result.code ~= 0 then
    return {}
  end

  return parse_hunks_from_stdout(result.stdout)
end

--- 获取光标所在行的 hunk 范围
--- 返回: {line_start, line_end} 或 nil
function M.get_current_hunk_range()
  local anchor = Anchor.from_cursor()
  if not anchor.file or not anchor.line then
    return nil
  end

  local session = Session.get_active()
  if not session then
    return nil
  end

  local hunks = M.get_file_hunks(anchor.file, session.range)
  local target = anchor.line

  for _, hunk in ipairs(hunks) do
    if target >= hunk.line_start and target <= hunk.line_end then
      return hunk
    end
  end

  -- 光标不在任何 hunk 内（可能在 hunk 之间的未变更区域）
  -- 找最近的 hunk
  local closest, min_dist = nil, math.huge
  for _, hunk in ipairs(hunks) do
    local dist = math.min(math.abs(target - hunk.line_start), math.abs(target - hunk.line_end))
    if dist < min_dist then
      min_dist = dist
      closest = hunk
    end
  end
  return closest
end

----------------------------------------------------------------------
-- 向后兼容：迁移旧版 approve 条目（无 level 字段 -> hunk）
-- #11 修复: 使用 per-session 标记，避免跨 session 遗漏
----------------------------------------------------------------------
local function migrate_approved(session)
  if not session or not session.approved or session._migrated then
    return
  end
  local migrated = false
  for _, entry in ipairs(session.approved) do
    if not entry.level then
      entry.level = "hunk"
      if entry.line and not entry.line_start then
        entry.line_start = entry.line
        entry.line_end = entry.line
      end
      migrated = true
    end
  end
  session._migrated = true
  if migrated then
    Session.save(session)
  end
end

----------------------------------------------------------------------
-- Approve 查询函数
----------------------------------------------------------------------

--- 检查指定文件的指定行是否被某个 approve 覆盖
function M.is_line_approved(file_path, line)
  local session = Session.get_active()
  if not session then
    return false, nil
  end
  migrate_approved(session)
  for _, entry in ipairs(session.approved or {}) do
    if entry.level == "global" then
      return true, entry
    end
    if entry.level == "dir" and entry.path and file_path:sub(1, #entry.path) == entry.path then
      return true, entry
    end
    if entry.level == "file" and entry.file == file_path then
      return true, entry
    end
    if entry.level == "hunk" and entry.file == file_path and line >= entry.line_start and line <= entry.line_end then
      return true, entry
    end
  end
  return false, nil
end

--- 检查指定范围的行内是否有 comments
function M.has_comments_in_range(file_path, line_start, line_end)
  local session = Session.get_active()
  if not session then
    return false, {}
  end
  local found = {}
  for _, comment in ipairs(session.comments or {}) do
    local anchor = comment.anchor or {}
    if anchor.file == file_path and anchor.line and anchor.line >= line_start and anchor.line <= line_end then
      table.insert(found, comment)
    end
  end
  return #found > 0, found
end

--- 查找已有的 approve 条目（匹配相同范围）
local function find_approve_entry(session, level, opts)
  opts = opts or {}
  for i, entry in ipairs(session.approved or {}) do
    if entry.level == level then
      if
        level == "hunk"
        and entry.file == opts.file
        and entry.line_start == opts.line_start
        and entry.line_end == opts.line_end
      then
        return i, entry
      end
      if level == "file" and entry.file == opts.file then
        return i, entry
      end
      if level == "dir" and entry.path == opts.path then
        return i, entry
      end
      if level == "global" then
        return i, entry
      end
    end
  end
  return nil, nil
end

--- 移除 approve 条目（含 sign 清理）
local function remove_approve(session, idx)
  local entry = session.approved[idx]
  if entry._sign_id then
    vim.fn.sign_unplace(SIGN_GROUP, { id = entry._sign_id })
  end
  table.remove(session.approved, idx)
end

----------------------------------------------------------------------
-- toggle_approve(): 多级 approve 入口
----------------------------------------------------------------------
function M.toggle_approve()
  local session = Session.get_active()
  if not session then
    vim.notify("没有 active AI Review session，先运行 :AIReviewStart", vim.log.levels.WARN)
    return
  end
  migrate_approved(session)

  local anchor = Anchor.from_cursor()
  if not anchor.file then
    vim.notify("无法确定当前文件", vim.log.levels.WARN)
    return
  end

  session.approved = session.approved or {}

  -- 检查当前文件/位置是否已有 approve（提供取消选项）
  local existing_hunk_idx = nil
  local hunk = M.get_current_hunk_range()
  if hunk then
    existing_hunk_idx = find_approve_entry(
      session,
      "hunk",
      { file = anchor.file, line_start = hunk.line_start, line_end = hunk.line_end }
    )
  end
  local existing_file_idx = find_approve_entry(session, "file", { file = anchor.file })
  local dir_path = anchor.file:match("^(.+/)") or ""
  local existing_dir_idx = find_approve_entry(session, "dir", { path = dir_path })
  local existing_global_idx = find_approve_entry(session, "global")

  -- 构建选项列表
  local items = {}

  -- Hunk 级别
  if hunk then
    if existing_hunk_idx then
      table.insert(
        items,
        { label = string.format("取消 Hunk 通过 (L%d-%d)", hunk.line_start, hunk.line_end), action = "remove_hunk" }
      )
    else
      table.insert(
        items,
        { label = string.format("通过当前 Hunk (L%d-%d)", hunk.line_start, hunk.line_end), action = "add_hunk" }
      )
    end
  end

  -- 文件级别
  if existing_file_idx then
    table.insert(items, { label = "取消文件通过: " .. anchor.file, action = "remove_file" })
  else
    table.insert(items, { label = "通过整个文件: " .. anchor.file, action = "add_file" })
  end

  -- 目录级别
  if dir_path ~= "" then
    if existing_dir_idx then
      table.insert(items, { label = "取消目录通过: " .. dir_path, action = "remove_dir" })
    else
      table.insert(items, { label = "通过整个目录: " .. dir_path, action = "add_dir" })
    end
  end

  -- 全局级别
  if existing_global_idx then
    table.insert(items, { label = "取消全局通过", action = "remove_global" })
  else
    table.insert(items, { label = "通过所有文件（全局）", action = "add_global" })
  end

  vim.ui.select(
    vim.tbl_map(function(item)
      return item.label
    end, items),
    { prompt = "Approve 级别:" },
    function(choice, idx)
      if not choice then
        return
      end
      local item = items[idx]
      M._do_approve_action(item.action, anchor, hunk, dir_path)
    end
  )
end

--- 执行 approve 动作
function M._do_approve_action(action, anchor, hunk, dir_path)
  local session = Session.get_active()
  if not session then
    return
  end
  session.approved = session.approved or {}

  -- 取消操作
  if action == "remove_hunk" and hunk then
    local idx = find_approve_entry(
      session,
      "hunk",
      { file = anchor.file, line_start = hunk.line_start, line_end = hunk.line_end }
    )
    if idx then
      remove_approve(session, idx)
      Session.save(session)
      vim.notify("已取消 hunk 通过", vim.log.levels.INFO)
    end
    return
  end
  if action == "remove_file" then
    local idx = find_approve_entry(session, "file", { file = anchor.file })
    if idx then
      remove_approve(session, idx)
      Session.save(session)
      vim.notify("已取消文件通过: " .. anchor.file, vim.log.levels.INFO)
    end
    return
  end
  if action == "remove_dir" then
    local idx = find_approve_entry(session, "dir", { path = dir_path })
    if idx then
      remove_approve(session, idx)
      Session.save(session)
      vim.notify("已取消目录通过: " .. dir_path, vim.log.levels.INFO)
    end
    return
  end
  if action == "remove_global" then
    local idx = find_approve_entry(session, "global")
    if idx then
      remove_approve(session, idx)
      Session.save(session)
      vim.notify("已取消全局通过", vim.log.levels.INFO)
    end
    return
  end

  -- 添加操作（含互斥检查）
  if action == "add_hunk" and hunk then
    -- 互斥：检查 hunk 范围内是否有 comments
    local has_conflict, conflicts = M.has_comments_in_range(anchor.file, hunk.line_start, hunk.line_end)
    if has_conflict then
      vim.notify(
        string.format(
          "无法通过: hunk 内有 %d 条 comment(s) (L%d, L%d, ...)",
          #conflicts,
          conflicts[1].anchor.line,
          conflicts[1].anchor.line
        ),
        vim.log.levels.WARN
      )
      return
    end
    local sign_id = M.place_approve_sign(vim.api.nvim_get_current_buf(), hunk.line_start)
    table.insert(session.approved, {
      level = "hunk",
      file = anchor.file,
      line_start = hunk.line_start,
      line_end = hunk.line_end,
      approved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      _sign_id = sign_id,
    })
    Session.save(session)
    vim.notify(string.format("✓ Hunk 已通过 (L%d-%d)", hunk.line_start, hunk.line_end), vim.log.levels.INFO)
    return
  end

  if action == "add_file" then
    local has_conflict, conflicts = M.has_comments_in_range(anchor.file, 1, math.huge)
    if has_conflict then
      vim.notify(string.format("无法通过: 文件内有 %d 条 comment(s)", #conflicts), vim.log.levels.WARN)
      return
    end
    table.insert(session.approved, {
      level = "file",
      file = anchor.file,
      approved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    Session.save(session)
    vim.notify("✓ 文件已通过: " .. anchor.file, vim.log.levels.INFO)
    return
  end

  if action == "add_dir" then
    -- 检查目录下所有已跟踪文件的 comments
    local has_conflict = false
    local conflict_count = 0
    for _, comment in ipairs(session.comments or {}) do
      local f = comment.anchor and comment.anchor.file
      if f and f:sub(1, #dir_path) == dir_path then
        has_conflict = true
        conflict_count = conflict_count + 1
      end
    end
    if has_conflict then
      vim.notify(
        string.format("无法通过: 目录 %s 内有 %d 条 comment(s)", dir_path, conflict_count),
        vim.log.levels.WARN
      )
      return
    end
    table.insert(session.approved, {
      level = "dir",
      path = dir_path,
      approved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    Session.save(session)
    vim.notify("✓ 目录已通过: " .. dir_path, vim.log.levels.INFO)
    return
  end

  if action == "add_global" then
    local comment_count = #(session.comments or {})
    if comment_count > 0 then
      vim.notify(
        string.format("无法全局通过: 当前有 %d 条 comment(s) 未解决", comment_count),
        vim.log.levels.WARN
      )
      return
    end
    table.insert(session.approved, {
      level = "global",
      approved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    Session.save(session)
    vim.notify("✓ 全局已通过", vim.log.levels.INFO)
    return
  end
end

----------------------------------------------------------------------
-- check_approve_before_comment(): 添加 comment 前的互斥检查
-- 由 init.lua 的 add_comment 调用
----------------------------------------------------------------------
function M.check_approve_before_comment(anchor)
  if not anchor or not anchor.file or not anchor.line then
    return false
  end
  local approved, entry = M.is_line_approved(anchor.file, anchor.line)
  if not approved then
    return false
  end

  -- 告知用户被哪个级别的 approve 覆盖
  local level_names = { hunk = "hunk", file = "文件", dir = "目录", global = "全局" }
  local level = entry and entry.level or "unknown"
  vim.notify(
    string.format("此行已被 %s 级别 approve 覆盖，无法添加 comment", level_names[level] or level),
    vim.log.levels.WARN
  )
  return true
end

----------------------------------------------------------------------
-- list_file_comments(): 列出当前文件的所有 comments + approvals
----------------------------------------------------------------------
function M.list_file_comments()
  local session = Session.get_active()
  if not session then
    vim.notify("没有 active AI Review session", vim.log.levels.INFO)
    return
  end
  migrate_approved(session)

  local anchor = Anchor.from_cursor()
  local file = anchor.file
  if not file then
    vim.notify("无法确定当前文件", vim.log.levels.WARN)
    return
  end

  local lines = { "Review: " .. file, "─────────────────────", "" }

  -- 全局/目录 approve 状态
  for _, entry in ipairs(session.approved or {}) do
    if entry.level == "global" then
      table.insert(lines, "★ 全局已通过")
      table.insert(lines, "")
    elseif entry.level == "dir" and entry.path and file:sub(1, #entry.path) == entry.path then
      table.insert(lines, "★ 目录已通过: " .. entry.path)
      table.insert(lines, "")
    end
  end

  -- 文件级别 approve
  local file_approved = find_approve_entry(session, "file", { file = file })
  if file_approved then
    table.insert(lines, "★ 文件已通过")
    table.insert(lines, "")
  end

  -- Comments
  local file_comments = {}
  for _, comment in ipairs(session.comments or {}) do
    if comment.anchor and comment.anchor.file == file then
      table.insert(file_comments, comment)
    end
  end

  if #file_comments > 0 then
    table.insert(lines, "## Comments (" .. #file_comments .. ")")
    table.insert(lines, "")
    for _, comment in ipairs(file_comments) do
      local status_icon = comment.status == "resolved" and "✓" or "○"
      table.insert(
        lines,
        string.format(
          "  %s [%s] L%d: %s",
          status_icon,
          comment.severity or "note",
          comment.anchor.line or 0,
          comment.message or ""
        )
      )
    end
    table.insert(lines, "")
  else
    table.insert(lines, "  (没有 comments)")
    table.insert(lines, "")
  end

  -- Hunk-level approves
  local hunk_approved = {}
  for _, entry in ipairs(session.approved or {}) do
    if entry.level == "hunk" and entry.file == file then
      table.insert(hunk_approved, entry)
    end
  end

  if #hunk_approved > 0 then
    table.insert(lines, "## Approved Hunks (" .. #hunk_approved .. ")")
    table.insert(lines, "")
    for _, entry in ipairs(hunk_approved) do
      table.insert(lines, string.format("  ✓ L%d-%d", entry.line_start or 0, entry.line_end or 0))
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  local width = math.min(90, math.max(40, vim.o.columns - 8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.5))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " AI Review Summary ",
    title_pos = "center",
  })
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, silent = true })
end

----------------------------------------------------------------------
-- setup_buffer(bufnr): diffview hook 入口
----------------------------------------------------------------------
function M.setup_buffer(bufnr)
  M.install_keymaps(bufnr)
  M.restore_signs(bufnr)
end

----------------------------------------------------------------------
-- setup_autocmds()
----------------------------------------------------------------------
local autocmd_created = false
function M.setup_autocmds()
  if autocmd_created then
    return
  end
  autocmd_created = true

  local group = vim.api.nvim_create_augroup("AIReviewDiffview", { clear = true })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("^diffview://") then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            M.install_keymaps(bufnr)
          end
        end)
      end
    end,
  })
end

return M
