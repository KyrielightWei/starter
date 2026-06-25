local Session = require("ai_review.session")
local Anchor = require("ai_review.anchor")
local Comments = require("ai_review.comments")
local Export = require("ai_review.export")

local M = {}

--- 构建统一的显示列表（comments + approvals 混合，按行号排序）
local function build_items(session)
  local items = {}

  -- Comments
  for _, comment in ipairs(session.comments or {}) do
    local anchor = comment.anchor or {}
    table.insert(items, {
      kind = "comment",
      line = anchor.line or 0,
      file = anchor.file or "",
      data = comment,
    })
  end

  -- Approvals
  for _, entry in ipairs(session.approved or {}) do
    local level = entry.level or "hunk"
    local display_line = entry.line_start or entry.line or 0
    table.insert(items, {
      kind = "approve",
      line = display_line,
      file = entry.file or entry.path or "",
      data = entry,
      level = level,
    })
  end

  -- 按行号排序，同行号按文件名二级排序
  table.sort(items, function(a, b)
    if a.line ~= b.line then
      return a.line < b.line
    end
    return a.file < b.file
  end)

  return items
end

--- 查找 approve 条目索引（与 diffview 中的逻辑一致）
local function find_approve_entry(session, entry)
  for i, a in ipairs(session.approved or {}) do
    if a.level == entry.level then
      if
        a.level == "hunk"
        and a.file == entry.file
        and a.line_start == entry.line_start
        and a.line_end == entry.line_end
      then
        return i, a
      end
      if a.level == "file" and a.file == entry.file then
        return i, a
      end
      if a.level == "dir" and a.path == entry.path then
        return i, a
      end
      if a.level == "global" then
        return i, a
      end
    end
  end
  return nil, nil
end

function M.render(session)
  local lines = {
    "AI Review Panel",
    "────────────────────────────",
  }
  if not session then
    table.insert(lines, "No active session")
    return lines, {}
  end
  table.insert(lines, "Session: " .. session.id)
  table.insert(lines, "Comments: " .. tostring(#(session.comments or {})))
  local approved = session.approved or {}
  table.insert(lines, "Approved: " .. tostring(#approved))
  table.insert(lines, "")

  -- 全局/目录级别的 approve 置顶显示
  for _, entry in ipairs(approved) do
    if entry.level == "global" then
      table.insert(lines, "★ 全局已通过")
    elseif entry.level == "dir" then
      table.insert(lines, "★ 目录已通过: " .. (entry.path or "?"))
    end
  end

  local has_global_or_dir = false
  for _, entry in ipairs(approved) do
    if entry.level == "global" or entry.level == "dir" then
      has_global_or_dir = true
      break
    end
  end
  if has_global_or_dir then
    table.insert(lines, "")
  end

  -- 构建统一列表（comments + hunk/file approvals，按行号排序）
  local items = build_items(session)

  if #items == 0 then
    table.insert(lines, "  (无 comments 或 approvals)")
    return lines, items
  end

  for i, item in ipairs(items) do
    if item.kind == "comment" then
      local comment = item.data
      local status_icon = comment.status == "resolved" and "✓" or "○"
      table.insert(
        lines,
        string.format("[%d] %s [%s] %s:%s", i, status_icon, comment.severity or "note", item.file, item.line)
      )
      table.insert(lines, "    " .. (comment.message or ""))
    else
      local entry = item.data
      local level = item.level
      if level == "file" then
        table.insert(lines, string.format("[%d] ★ [文件通过] %s", i, item.file))
      else
        -- hunk
        table.insert(
          lines,
          string.format("[%d] ✓ [Hunk通过] %s:L%d-%d", i, item.file, entry.line_start or 0, entry.line_end or 0)
        )
      end
    end
    table.insert(lines, "")
  end

  return lines, items
end

function M.open()
  local session = Session.get_active()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

  local lines, items = M.render(session)

  local function refresh()
    local new_lines, new_items = M.render(session)
    items = new_items
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(90, vim.o.columns - 4)
  local height = math.min(math.max(8, #lines), vim.o.lines - 4)
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

  --- 获取当前光标所在的 item
  local function current_item()
    local line = vim.api.nvim_get_current_line()
    local idx = tonumber(line:match("^%[(%d+)%]"))
    if idx and items[idx] then
      return items[idx]
    end
    return nil
  end

  --- 获取当前 item 的 comment（如果是 comment 类型）
  local function current_comment()
    local item = current_item()
    if item and item.kind == "comment" then
      return item.data
    end
    return nil
  end

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, silent = true })

  -- <CR>: 跳转到 comment/approve 对应位置
  vim.keymap.set("n", "<CR>", function()
    local item = current_item()
    if not item then
      return
    end
    if item.kind == "comment" then
      M.jump(item.data and item.data.anchor)
    elseif item.kind == "approve" and item.data and item.data.file then
      vim.cmd("edit " .. vim.fn.fnameescape(item.data.file))
      local target_line = item.data.line_start or item.data.line or 1
      vim.api.nvim_win_set_cursor(0, { target_line, 0 })
    end
  end, { buffer = buf, silent = true, desc = "Jump to item" })

  -- x: 导出
  vim.keymap.set("n", "x", function()
    if session then
      local ok, err = Export.export(session)
      vim.notify(
        ok and "AI Review 已导出" or ("AI Review 导出失败: " .. tostring(err)),
        ok and vim.log.levels.INFO or vim.log.levels.ERROR
      )
    end
  end, { buffer = buf, silent = true })

  -- d: 删除 comment 或 approve（需确认）
  vim.keymap.set("n", "d", function()
    local item = current_item()
    if not item or not session then
      return
    end

    if item.kind == "comment" then
      local comment = item.data
      vim.ui.select(
        { "确认删除", "取消" },
        { prompt = string.format("删除 comment [%s]?", comment.id or "?") },
        function(choice, idx)
          if idx == 1 then
            Comments.delete(session, comment.id)
            Session.save(session)
            -- 重建 items
            local _, new_items = M.render(session)
            items = new_items
            refresh()
          end
        end
      )
    elseif item.kind == "approve" then
      local entry = item.data
      local level_names = { hunk = "Hunk", file = "文件", dir = "目录", global = "全局" }
      local label = level_names[entry.level or "hunk"] or "Hunk"
      vim.ui.select(
        { "确认移除", "取消" },
        { prompt = string.format("移除 %s 级别的 approve?", label) },
        function(choice, idx)
          if idx == 1 then
            local found_idx, found_entry = find_approve_entry(session, entry)
            if found_idx and found_entry then
              if found_entry._sign_id then
                vim.fn.sign_unplace("AIReview", { id = found_entry._sign_id })
              end
              table.remove(session.approved, found_idx)
            end
            Session.save(session)
            local _, new_items = M.render(session)
            items = new_items
            refresh()
          end
        end
      )
    end
  end, { buffer = buf, silent = true, desc = "Delete comment or approve" })

  -- e: 编辑 comment
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

  -- r: resolve comment
  vim.keymap.set("n", "r", function()
    local comment = current_comment()
    if session and comment then
      Comments.resolve(session, comment.id)
      Session.save(session)
      refresh()
    end
  end, { buffer = buf, silent = true, desc = "Resolve review comment" })

  refresh()
end

function M.jump(anchor)
  anchor = anchor or Anchor.from_cursor()
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
