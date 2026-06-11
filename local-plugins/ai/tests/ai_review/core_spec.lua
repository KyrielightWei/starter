local plugin_lua = vim.fn.getcwd() .. "/local-plugins/ai/lua"
package.path = plugin_lua .. "/?.lua;" .. plugin_lua .. "/?/init.lua;" .. package.path

local Store = require("ai_review.store")
local Range = require("ai_review.range")
local Session = require("ai_review.session")
local Comments = require("ai_review.comments")
local Anchor = require("ai_review.anchor")
local Export = require("ai_review.export")

local function rm_rf(path)
  vim.fn.delete(path, "rf")
end

describe("ai_review core modules", function()
  local root

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    Store._set_root_for_tests(root)
    Session._reset_for_tests()
  end)

  after_each(function()
    Store._set_root_for_tests(nil)
    Session._reset_for_tests()
    rm_rf(root)
  end)

  it("loads all public modules", function()
    for _, name in ipairs({
      "ai_review.init",
      "ai_review.range",
      "ai_review.session",
      "ai_review.store",
      "ai_review.comments",
      "ai_review.anchor",
      "ai_review.diffview",
      "ai_review.export",
      "ai_review.panel",
    }) do
      local ok, mod = pcall(require, name)
      assert.is_true(ok, name)
      assert.equals("table", type(mod))
    end
  end)

  it("resolves project local and state export paths", function()
    assert.equals(root .. "/.ai-review", Store.review_dir())
    assert.equals(root .. "/.ai-review/current.json", Store.current_path())
    assert.truthy(Store.state_export_dir():match("ai%-review"))
  end)

  it("writes and reads json atomically", function()
    local path = Store.join(Store.review_dir(), "sample.json")
    local ok, err = Store.write_json(path, { hello = "world", count = 2 })
    assert.is_true(ok, err)

    local data = Store.read_json(path)
    assert.equals("world", data.hello)
    assert.equals(2, data.count)
  end)

  it("backs up malformed json", function()
    local path = Store.join(Store.review_dir(), "bad.json")
    Store.ensure_dir(Store.review_dir())
    vim.fn.writefile({ "{bad" }, path)

    local data, err = Store.read_json(path, { backup_malformed = true })
    assert.is_nil(data)
    assert.truthy(err)
    assert.is_true(#vim.fn.glob(path .. ".bak-*", false, true) >= 1)
  end)

  it("constructs and validates ranges", function()
    local sha1 = string.rep("a", 40)
    local sha2 = string.rep("b", 40)

    assert.equals("single_commit", Range.single_commit(sha1).type)
    assert.equals("commit_range", Range.commit_range(sha1, sha2).type)
    assert.equals("since_base", Range.since_base(sha1).type)

    local worktree = Range.worktree()
    assert.is_true(worktree.include_staged)
    assert.is_true(worktree.include_unstaged)
    assert.is_true(worktree.include_untracked)

    assert.is_true(Range.validate(Range.commit_range(sha1, sha2)).ok)
    assert.is_false(Range.validate(Range.commit_range("bad", sha2)).ok)
  end)

  it("converts ranges to diffview args", function()
    local sha1 = string.rep("a", 40)
    local sha2 = string.rep("b", 40)

    assert.equals(sha1 .. "^.." .. sha1, Range.to_diffview_args(Range.single_commit(sha1)))
    assert.equals(sha1 .. ".." .. sha2, Range.to_diffview_args(Range.commit_range(sha1, sha2)))
    assert.equals(sha1 .. "..HEAD", Range.to_diffview_args(Range.since_base(sha1)))
    assert.equals("--untracked-files=all", Range.to_diffview_args(Range.worktree()))
  end)

  it("creates, saves, resumes and closes a session", function()
    local sha1 = string.rep("a", 40)
    local session = Session.create(Range.single_commit(sha1))
    assert.truthy(session.id)
    assert.equals("single_commit", session.range.type)
    assert.equals(0, #session.comments)

    local active = Session.get_active()
    assert.equals(session.id, active.id)

    Session.close()
    assert.is_nil(Session.get_active())

    local resumed = Session.resume(session.id)
    assert.equals(session.id, resumed.id)
  end)

  it("creates temporary session when requested", function()
    local session = Session.ensure_active()
    assert.equals("temporary", session.range.type)
    assert.is_true(session.temporary)
  end)

  it("creates and mutates comments", function()
    local session = Session.create(Range.worktree())
    local comment = Comments.create(session, {
      message = "需要重新考虑这里",
      severity = "question",
      anchor = { file = "lua/foo.lua", line = 12, line_text = "return M", side = "right" },
    })
    assert.equals("question", comment.severity)
    assert.equals("open", comment.status)

    Comments.edit(session, comment.id, { message = "更新意见", severity = "suggestion" })
    assert.equals("更新意见", session.comments[1].message)
    assert.equals("suggestion", session.comments[1].severity)

    Comments.resolve(session, comment.id)
    assert.equals("resolved", session.comments[1].status)

    assert.is_true(Comments.delete(session, comment.id))
    assert.equals(0, #session.comments)
  end)

  it("extracts anchors from normal buffers", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, root .. "/lua/foo.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "local M = {}",
      "function M.run()",
      "  return true",
      "end",
    })
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 3, 0 })

    local anchor = Anchor.from_cursor({ repo = root })
    assert.equals("lua/foo.lua", anchor.file)
    assert.equals("right", anchor.side)
    assert.equals("new", anchor.meaning)
    assert.equals(3, anchor.line)
    assert.equals("  return true", anchor.line_text)
    assert.is_false(anchor.partial)
  end)

  it("exports markdown json and prompt", function()
    local session = Session.create(Range.worktree())
    Comments.create(session, {
      message = "这里需要讨论是否应该修改",
      severity = "question",
      anchor = { file = "lua/foo.lua", line = 3, line_text = "return true", side = "right", meaning = "new" },
    })
    Session.save(session)

    local ok, paths = Export.export(session)
    assert.is_true(ok)
    assert.is_true(vim.fn.filereadable(paths.markdown) == 1)
    assert.is_true(vim.fn.filereadable(paths.json) == 1)
    assert.is_true(vim.fn.filereadable(paths.prompt) == 1)

    local prompt = table.concat(vim.fn.readfile(paths.prompt), "\n")
    assert.truthy(prompt:match("重新审视"))
    assert.truthy(prompt:match("需要进一步讨论"))
  end)
end)
