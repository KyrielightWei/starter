local plugin_lua = vim.fn.getcwd() .. "/local-plugins/ai/lua"
package.path = plugin_lua .. "/?.lua;" .. plugin_lua .. "/?/init.lua;" .. package.path

local Store = require("ai_review.store")
local Range = require("ai_review.range")
local Session = require("ai_review.session")
local Comments = require("ai_review.comments")
local Export = require("ai_review.export")
local Cache = require("ai_review.range_cache")
local Init = require("ai_review.init")

local function rm_rf(path)
  vim.fn.delete(path, "rf")
end

describe("ai_review review fixes", function()
  local root
  local original_notify
  local original_write_json
  local original_writefile

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    Store._set_root_for_tests(root)
    Session._reset_for_tests()
    package.loaded.diffview = nil
    original_notify = vim.notify
    vim.notify = function() end
    original_write_json = Store.write_json
    original_writefile = vim.fn.writefile
  end)

  after_each(function()
    Store.write_json = original_write_json
    vim.fn.writefile = original_writefile
    vim.notify = original_notify
    Store._set_root_for_tests(nil)
    Session._reset_for_tests()
    package.loaded.diffview = nil
    rm_rf(root)
  end)

  it("does not keep active session when diffview open fails", function()
    Init.start({ range = Range.worktree() })
    assert.is_nil(Session.get_active())
  end)

  it("export returns error when markdown write fails", function()
    local session = Session.create(Range.worktree())
    vim.fn.writefile = function()
      error("write failed")
    end
    local ok, err = Export.export(session)
    assert.is_false(ok)
    assert.truthy(tostring(err):match("write failed"))
  end)

  it("export returns error when json write fails", function()
    local session = Session.create(Range.worktree())
    Store.write_json = function()
      return false, "json failed"
    end
    local ok, err = Export.export(session)
    assert.is_false(ok)
    assert.truthy(tostring(err):match("json failed"))
  end)

  it("comment ids remain unique after deleting comments", function()
    local session = Session.create(Range.worktree())
    local c1 = Comments.create(session, { message = "one" })
    local c2 = Comments.create(session, { message = "two" })
    local c3 = Comments.create(session, { message = "three" })
    assert.equals("comment-001", c1.id)
    assert.equals("comment-002", c2.id)
    assert.equals("comment-003", c3.id)

    Comments.delete(session, c2.id)
    local c4 = Comments.create(session, { message = "four" })
    assert.equals("comment-004", c4.id)
  end)

  it("cached ranges are validated in git repository before reuse", function()
    local range = Range.commit_range(string.rep("a", 40), string.rep("b", 40))
    local ok = Cache.save(range)
    assert.is_true(ok)
    local loaded, err = Cache.load_last({ validate_repo = true })
    assert.is_nil(loaded)
    assert.truthy(err)
  end)
end)
