local Range = require("ai_review.range")
local Session = require("ai_review.session")
local Comments = require("ai_review.comments")
local Anchor = require("ai_review.anchor")
local Diffview = require("ai_review.diffview")
local Export = require("ai_review.export")
local Panel = require("ai_review.panel")

local M = {}

-- 确保全局 autocmd 已注册（覆盖 diffview hooks 遗漏的场景）
Diffview.setup_autocmds()

local function choose_range(callback)
  local choices = {
    "Worktree changes",
    "Last cached range",
    "Select commit range",
    "Base..HEAD",
  }
  vim.ui.select(choices, { prompt = "AI Review range" }, function(choice)
    if not choice then
      return
    end
    if choice == "Worktree changes" then
      callback(Range.worktree())
      return
    end
    if choice == "Last cached range" then
      local ok, Cache = pcall(require, "ai_review.range_cache")
      if ok then
        local range, err = Cache.load_last({ validate_repo = true })
        if range then
          callback(range)
          return
        end
        if err then
          vim.notify("Cached review range 不可用: " .. tostring(err), vim.log.levels.WARN)
          return
        end
      end
      vim.notify("没有可用的 cached review range", vim.log.levels.WARN)
      return
    end
    if choice == "Select commit range" then
      local ok, Picker = pcall(require, "commit_picker.init")
      if not ok then
        vim.notify("Commit Picker 加载失败", vim.log.levels.ERROR)
        return
      end
      Picker.open({
        review_mode = true,
        on_range_selected = callback,
      })
      return
    end
    vim.ui.input({ prompt = "Base commit SHA: " }, function(base)
      if base and base ~= "" then
        callback(Range.since_base(base))
      end
    end)
  end)
end

function M.start(opts)
  opts = opts or {}
  local function start_with_range(range)
    local valid = Range.validate(range)
    if not valid.ok then
      vim.notify("无效 review range: " .. tostring(valid.error), vim.log.levels.ERROR)
      return
    end
    if not Diffview.open(range) then
      return
    end
    local session = Session.create(range)
    vim.notify("AI Review session started: " .. session.id, vim.log.levels.INFO)
  end

  if opts.range then
    start_with_range(opts.range)
    return
  end
  choose_range(start_with_range)
end

function M.add_comment(opts)
  opts = opts or {}
  local function finish(message, severity)
    if not message or message == "" then
      return
    end
    local session = Session.ensure_active()
    local anchor = opts.anchor or Anchor.from_cursor()

    -- 互斥检查：如果该行已被 approve 覆盖，则拒绝添加 comment
    if Diffview.check_approve_before_comment(anchor) then
      return
    end

    local comment = Comments.create(session, {
      message = message,
      severity = severity or opts.severity or "note",
      anchor = anchor,
    })
    local ok, err = Session.save(session)
    if not ok then
      vim.notify("保存 review comment 失败: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
    Diffview.place_sign(vim.api.nvim_get_current_buf(), comment)
    vim.notify("AI Review comment added: " .. comment.id, vim.log.levels.INFO)
  end

  if opts.message then
    finish(opts.message, opts.severity)
    return
  end

  vim.ui.select({ "note", "must-fix", "suggestion", "question" }, { prompt = "Severity" }, function(severity)
    if not severity then
      severity = "note"
    end
    vim.ui.input({ prompt = "Review comment: " }, function(message)
      finish(message, severity)
    end)
  end)
end

function M.panel()
  Panel.open()
end

function M.export(opts)
  local session = Session.get_active()
  if not session then
    vim.notify("没有 active AI Review session", vim.log.levels.WARN)
    return
  end
  local ok, result = Export.export(session, opts)
  if ok then
    vim.notify("AI Review 已导出: " .. result.markdown, vim.log.levels.INFO)
  else
    vim.notify("AI Review 导出失败: " .. tostring(result), vim.log.levels.ERROR)
  end
end

function M.status()
  local status = Session.status()
  if not status.active then
    vim.notify("AI Review: no active session", vim.log.levels.INFO)
    return status
  end
  vim.notify(
    table.concat({
      "AI Review Session:",
      "  ID: " .. status.id,
      "  Comments: " .. tostring(status.comments),
      "  Path: " .. status.path,
    }, "\n"),
    vim.log.levels.INFO
  )
  return status
end

function M.close()
  Session.close()
  vim.notify("AI Review session closed", vim.log.levels.INFO)
end

function M.approve()
  Diffview.toggle_approve()
end

function M.list_comments()
  Diffview.list_file_comments()
end

function M.filter_files()
  -- 文件过滤现在在打开 diffview 时通过 git pathspec 自动完成
  -- 如果需要重新过滤，请关闭当前 diffview 并重新启动 review
  vim.notify("文件过滤在 :AIReviewStart 时自动执行，无需手动触发", vim.log.levels.INFO)
end

return M
