local plugin_lua = vim.fn.getcwd() .. "/local-plugins/ai/lua"
package.path = plugin_lua .. "/?.lua;" .. plugin_lua .. "/?/init.lua;" .. package.path

local Store = require("ai_review.store")
local Range = require("ai_review.range")
local Session = require("ai_review.session")
local Comments = require("ai_review.comments")
local Anchor = require("ai_review.anchor")
local ReviewDiffview = require("ai_review.diffview")
local Panel = require("ai_review.panel")
local Cache = require("ai_review.range_cache")
local Init = require("ai_review.init")

local function rm_rf(path)
  vim.fn.delete(path, "rf")
end

local function reset_command(name)
  if vim.fn.exists(":" .. name) == 2 then
    pcall(vim.api.nvim_del_user_command, name)
  end
end

describe("ai_review integration behavior", function()
  local root
  local notify_messages
  local original_notify

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    Store._set_root_for_tests(root)
    Session._reset_for_tests()
    package.loaded.diffview = nil
    reset_command("DiffviewOpenEnhanced")
    notify_messages = {}
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notify_messages, { msg = tostring(msg), level = level })
    end
  end)

  after_each(function()
    vim.notify = original_notify
    Store._set_root_for_tests(nil)
    Session._reset_for_tests()
    package.loaded.diffview = nil
    reset_command("DiffviewOpenEnhanced")
    rm_rf(root)
  end)

  it("extracts anchors from diffview buffer names", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "diffview://" .. root .. "/abcdef12345/lua/foo.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local M = {}", "return M" })
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    local anchor = Anchor.from_cursor({ bufnr = buf })
    assert.equals("lua/foo.lua", anchor.file)
    assert.equals("abcdef12345", anchor.commit)
    assert.equals("right", anchor.side)
    assert.equals("new", anchor.meaning)
    assert.equals("return M", anchor.line_text)
  end)

  it("saves and loads cached review ranges", function()
    local range = Range.commit_range(string.rep("a", 40), string.rep("b", 40))
    local ok, item = Cache.save(range)
    assert.is_true(ok)
    assert.equals("commit_range", item.type)
    assert.is_true(vim.fn.filereadable(Cache.last_path()) == 1)
    assert.is_true(vim.fn.filereadable(Cache.history_path()) == 1)

    local loaded = Cache.load_last()
    assert.equals("commit_range", loaded.type)
    assert.equals(string.rep("a", 40), loaded.base)
  end)

  it("rejects invalid cached ranges", function()
    Store.write_json(Cache.last_path(), { type = "commit_range", base = "bad", head = string.rep("b", 40) })
    local loaded, err = Cache.load_last()
    assert.is_nil(loaded)
    assert.truthy(err)
  end)

  it("opens diffview with generated range args", function()
    package.loaded.diffview = {}
    local captured
    vim.api.nvim_create_user_command("DiffviewOpenEnhanced", function(opts)
      captured = opts.args
    end, { nargs = "*" })

    local range = Range.commit_range(string.rep("a", 40), string.rep("b", 40))
    assert.is_true(ReviewDiffview.open(range))
    assert.equals(string.rep("a", 40) .. ".." .. string.rep("b", 40), captured)
  end)

  it("fails gracefully when diffview is unavailable", function()
    assert.is_false(ReviewDiffview.open(Range.worktree()))
    assert.truthy(notify_messages[#notify_messages].msg:match("diffview"))
  end)

  it("places and restores signs for active session comments", function()
    local session = Session.create(Range.worktree())
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, root .. "/lua/foo.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local M = {}", "return M" })
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })

    Comments.create(session, {
      message = "comment",
      anchor = { file = "lua/foo.lua", line = 2, side = "right" },
    })
    Session.save(session)

    ReviewDiffview.restore_signs(buf)
    local signs = vim.fn.sign_getplaced(buf, { group = "AIReview" })[1].signs
    assert.equals(1, #signs)
    assert.equals(2, signs[1].lnum)
  end)

  it("installs diff buffer keymaps", function()
    local buf = vim.api.nvim_create_buf(false, true)
    ReviewDiffview.install_keymaps(buf)
    local maps = vim.api.nvim_buf_get_keymap(buf, "n")
    local function has_suffix(suffix)
      for _, map in ipairs(maps) do
        if map.lhs:sub(-#suffix) == suffix then
          return true
        end
      end
      return false
    end
    assert.is_true(has_suffix("kra"))
    assert.is_true(has_suffix("krv"))
    assert.is_true(has_suffix("krl"))
    assert.is_true(has_suffix("krx"))
  end)

  it("renders panel with comments", function()
    local session = Session.create(Range.worktree())
    Comments.create(session, {
      message = "需要讨论",
      severity = "question",
      anchor = { file = "lua/foo.lua", line = 7, partial = true },
    })
    local lines = table.concat(Panel.render(session), "\n")
    assert.truthy(lines:match("AI Review Panel"))
    assert.truthy(lines:match("lua/foo.lua:7"))
    assert.truthy(lines:match("需要讨论"))
  end)

  it("start with explicit range creates active session and opens diff", function()
    package.loaded.diffview = {}
    local opened
    vim.api.nvim_create_user_command("DiffviewOpenEnhanced", function(opts)
      opened = opts.args
    end, { nargs = "*" })

    local range = Range.single_commit(string.rep("a", 40))
    Init.start({ range = range })
    local session = Session.get_active()
    assert.truthy(session)
    assert.equals("single_commit", session.range.type)
    assert.equals(string.rep("a", 40) .. "^.." .. string.rep("a", 40), opened)
  end)

  it("add_comment creates temporary session when none exists", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, root .. "/lua/foo.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "return true" })
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    Init.add_comment({ message = "临时意见", severity = "suggestion" })
    local session = Session.get_active()
    assert.truthy(session)
    assert.is_true(session.temporary)
    assert.equals(1, #session.comments)
    assert.equals("suggestion", session.comments[1].severity)
  end)

  it("exports active session from init module", function()
    local session = Session.create(Range.worktree())
    Comments.create(session, {
      message = "导出意见",
      anchor = { file = "lua/foo.lua", line = 1, line_text = "return true", side = "right" },
    })
    Session.save(session)

    Init.export()
    assert.is_true(vim.fn.filereadable(Store.join(Store.session_dir(session.id), "notes.md")) == 1)
    assert.is_true(vim.fn.filereadable(Store.join(Store.session_dir(session.id), "notes.json")) == 1)
    assert.is_true(vim.fn.filereadable(Store.join(Store.session_dir(session.id), "fix-prompt.md")) == 1)
  end)
end)
