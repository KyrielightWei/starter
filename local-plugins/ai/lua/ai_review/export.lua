local Store = require("ai_review.store")
local Range = require("ai_review.range")

local M = {}

local function line(s)
  return s or ""
end

local function fmt_anchor(anchor)
  anchor = anchor or {}
  local parts = {}
  table.insert(parts, string.format("- File: `%s`", anchor.file or "unknown"))
  table.insert(parts, string.format("- Side: `%s`", anchor.side or "unknown"))
  if anchor.line then
    table.insert(parts, string.format("- Line: `%s`", anchor.line))
  end
  if anchor.line_text then
    table.insert(parts, "- Line text:")
    table.insert(parts, "")
    table.insert(parts, "```text")
    table.insert(parts, anchor.line_text)
    table.insert(parts, "```")
  end
  if anchor.context_before and #anchor.context_before > 0 then
    table.insert(parts, "- Context before:")
    table.insert(parts, "")
    table.insert(parts, "```text")
    vim.list_extend(parts, anchor.context_before)
    table.insert(parts, "```")
  end
  if anchor.context_after and #anchor.context_after > 0 then
    table.insert(parts, "- Context after:")
    table.insert(parts, "")
    table.insert(parts, "```text")
    vim.list_extend(parts, anchor.context_after)
    table.insert(parts, "```")
  end
  if anchor.hunk then
    table.insert(parts, "- Hunk:")
    table.insert(parts, "")
    table.insert(parts, "```diff")
    table.insert(parts, anchor.hunk)
    table.insert(parts, "```")
  end
  return parts
end

function M.render_markdown(session)
  local lines = {
    "# AI Review Notes",
    "",
    "## Summary",
    "",
    "- Session: `" .. line(session.id) .. "`",
    "- Repository: `" .. line(session.repo) .. "`",
    "- Range: `" .. Range.describe(session.range) .. "`",
    "- Created: `" .. line(session.created_at) .. "`",
    "- Updated: `" .. line(session.updated_at) .. "`",
    "- Comments: `" .. tostring(#(session.comments or {})) .. "`",
    "- Approved: `" .. tostring(#(session.approved or {})) .. "`",
    "",
    "## Comments",
    "",
  }

  for i, comment in ipairs(session.comments or {}) do
    table.insert(lines, string.format("### %d. %s `%s`", i, comment.severity or "note", comment.id or ""))
    table.insert(lines, "")
    table.insert(lines, "- Status: `" .. (comment.status or "open") .. "`")
    table.insert(lines, "- Created: `" .. line(comment.created_at) .. "`")
    table.insert(lines, "")
    table.insert(lines, "**Comment:**")
    table.insert(lines, "")
    table.insert(lines, comment.message or "")
    table.insert(lines, "")
    table.insert(lines, "**Anchor:**")
    table.insert(lines, "")
    vim.list_extend(lines, fmt_anchor(comment.anchor))
    table.insert(lines, "")
  end

  -- 已通过的条目（多级）
  local approved = session.approved or {}
  if #approved > 0 then
    table.insert(lines, "## Approved")
    table.insert(lines, "")
    for i, entry in ipairs(approved) do
      local level = entry.level or "hunk"
      local level_label = ({ hunk = "Hunk", file = "文件", dir = "目录", global = "全局" })[level] or level
      local location
      if level == "global" then
        location = "(所有文件)"
      elseif level == "dir" then
        location = entry.path or "?"
      elseif level == "file" then
        location = entry.file or "?"
      else
        location = string.format("%s:L%d-%d", entry.file or "?", entry.line_start or 0, entry.line_end or 0)
      end
      table.insert(lines, string.format("### %d. ✓ [%s] %s", i, level_label, location))
      table.insert(lines, "")
      if entry.line_text and entry.line_text ~= "" then
        table.insert(lines, "```text")
        table.insert(lines, entry.line_text)
        table.insert(lines, "```")
        table.insert(lines, "")
      end
      table.insert(lines, "- Approved at: `" .. line(entry.approved_at) .. "`")
      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

function M.render_prompt(session)
  local approved = session.approved or {}
  local approved_section = ""
  if #approved > 0 then
    local parts = { "", "## Approved (已通过，无需修改)", "" }
    for _, entry in ipairs(approved) do
      local level = entry.level or "hunk"
      local level_label = ({ hunk = "Hunk", file = "文件", dir = "目录", global = "全局" })[level] or level
      local location
      if level == "global" then
        location = "(所有文件)"
      elseif level == "dir" then
        location = entry.path or "?"
      elseif level == "file" then
        location = entry.file or "?"
      else
        location = string.format("%s:L%d-%d", entry.file or "?", entry.line_start or 0, entry.line_end or 0)
      end
      table.insert(parts, string.format("- ✓ [%s] %s", level_label, location))
    end
    table.insert(parts, "")
    approved_section = table.concat(parts, "\n")
  end

  local lines = {
    "# AI Review Follow-up Prompt",
    "",
    "请基于以下 code review comments 重新审视本次代码变更。",
    "",
    "你需要对每条 comment 做出处理判断：",
    "",
    "- accept：采纳并修改",
    "- discuss：需要进一步讨论或提出方案",
    "- reject：不采纳，并说明原因",
    "- clarify：信息不足，需要补充上下文",
    "",
    "要求：",
    "1. must-fix 优先处理，但仍需说明修改方案。",
    "2. suggestion 需要评估是否采纳。",
    "3. question 先回答问题，不要直接假设需要修改。",
    "4. 修改应尽量限制在 review 范围相关代码内。",
    "5. 如修改影响行为，请补充或更新测试。",
    "6. 最终输出每条 comment 的处理状态。",
    "7. 已标记为 Approved 的 hunk 表示已通过，不需要修改。",
    "",
    "## Review Range",
    "",
    "`" .. Range.describe(session.range) .. "`",
    "",
  }
  if approved_section ~= "" then
    table.insert(lines, approved_section)
    table.insert(lines, "")
  end
  table.insert(lines, "## Review Comments")
  table.insert(lines, "")
  table.insert(lines, M.render_markdown(session))
  return table.concat(lines, "\n")
end

local function write_text(path, content)
  local ok, result = pcall(vim.fn.writefile, vim.split(content, "\n", { plain = true }), path)
  if not ok then
    return false, tostring(result)
  end
  if result ~= 0 then
    return false, "writefile failed: " .. path
  end
  return true
end

function M.export(session, opts)
  opts = opts or {}
  if not session or not session.id then
    return false, "invalid session"
  end
  local dir = opts.destination == "state" and Store.join(Store.state_export_dir(), session.id)
    or Store.session_dir(session.id)
  Store.ensure_dir(dir)
  local paths = {
    markdown = Store.join(dir, "notes.md"),
    json = Store.join(dir, "notes.json"),
    prompt = Store.join(dir, "fix-prompt.md"),
  }

  local ok_md, err_md = write_text(paths.markdown, M.render_markdown(session))
  if not ok_md then
    return false, err_md
  end
  local ok_json, err_json = Store.write_json(paths.json, session)
  if not ok_json then
    return false, err_json
  end
  local ok_prompt, err_prompt = write_text(paths.prompt, M.render_prompt(session))
  if not ok_prompt then
    return false, err_prompt
  end

  return true, paths
end

return M
