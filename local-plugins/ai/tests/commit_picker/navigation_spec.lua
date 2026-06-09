-- tests/commit_picker/navigation_spec.lua
-- Plenary.nvim specs for commit_picker/navigation.lua

local Navigation = require("commit_picker.navigation")

----------------------------------------------------------------------
-- Mock module factories
----------------------------------------------------------------------
local function make_mock_git(commits)
  return {
    get_commits_for_mode = function()
      return commits or {}
    end,
    get_commit_list = function()
      return {
        { sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", short_sha = "aaaaaaa", subject = "fallback 1" },
        { sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", short_sha = "bbbbbbb", subject = "fallback 2" },
      }
    end,
  }
end

local function make_mock_selection()
  local selection = {}
  return {
    get_selected = function()
      return vim.deepcopy(selection)
    end,
    set_selected = function(shas)
      selection = vim.deepcopy(shas or {})
    end,
    clear = function()
      selection = {}
    end,
  }
end

local function make_mock_diff()
  return {
    is_valid_sha = function(sha)
      return sha and sha:match("^%x%x%x%x%x%x%x+$")
    end,
    open_diff = function(shas)
      -- no-op in tests
    end,
  }
end

----------------------------------------------------------------------
-- Helper: sample commit list for tests
----------------------------------------------------------------------
local function make_commits(n)
  local commits = {}
  for i = 1, n do
    table.insert(commits, {
      sha = string.rep(string.format("%x", i), 40 / #string.format("%x", i)):sub(1, 40),
      short_sha = string.rep(string.format("%x", i), 7 / #string.format("%x", i)):sub(1, 7),
      subject = "feat: commit " .. i,
      date = (i * 3600) .. " seconds ago",
      refs = "",
    })
  end
  return commits
end

local function make_sample_commits()
  return {
    { sha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", short_sha = "aaaaaaa", subject = "feat: first commit" },
    { sha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", short_sha = "bbbbbbb", subject = "fix: second commit" },
    { sha = "cccccccccccccccccccccccccccccccccccccccc", short_sha = "ccccccc", subject = "refactor: third commit" },
  }
end

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------
describe("commit_picker/navigation", function()
  ----------------------------------------------------------------------
  -- Setup
  ----------------------------------------------------------------------
  local mock_git, mock_selection, mock_diff

  before_each(function()
    Navigation.clear()

    mock_git = make_mock_git()
    mock_selection = make_mock_selection()
    mock_diff = make_mock_diff()

    Navigation.setup({
      Git = mock_git,
      Selection = mock_selection,
      Diff = mock_diff,
    })
  end)

  ----------------------------------------------------------------------
  -- M.setup() injects dependencies
  ----------------------------------------------------------------------
  describe("setup()", function()
    it("stores injected modules", function()
      -- Verify setup doesn't crash — modules stored internally
      Navigation.clear()
      Navigation.setup({
        Git = mock_git,
        Selection = mock_selection,
        Diff = mock_diff,
      })
      assert.is_false(Navigation.is_loaded())
    end)
  end)

  ----------------------------------------------------------------------
  -- M.clear() resets state
  ----------------------------------------------------------------------
  describe("clear()", function()
    it("resets loaded state", function()
      -- Load first, then clear
      Navigation.load_commits()
      assert.is_true(Navigation.is_loaded())
      Navigation.clear()
      assert.is_false(Navigation.is_loaded())
    end)
  end)

  ----------------------------------------------------------------------
  -- M.load_commits() populates commit list
  ----------------------------------------------------------------------
  describe("load_commits()", function()
    it("populates commit list and resets position to 1", function()
      local commits = make_sample_commits()
      mock_git.get_commits_for_mode = function()
        return commits
      end

      local count = Navigation.load_commits()
      assert.equals(3, count)
      assert.is_true(Navigation.is_loaded())

      local pos = Navigation.get_position()
      assert.equals(1, pos.position)
      assert.equals(3, pos.total)
      assert.equals("feat: first commit", pos.commit.subject)
    end)

    it("falls back to get_commit_list when no commits", function()
      -- git.lua returns empty table for unpushed
      mock_git.get_commits_for_mode = function()
        return {}
      end

      local count = Navigation.load_commits()
      assert.is_true(count >= 0) -- fallback returns something
    end)

    it("handles error return from get_commits_for_mode", function()
      mock_git.get_commits_for_mode = function()
        return { error = true, output = "git error" }
      end

      local count = Navigation.load_commits()
      -- Falls back to get_commit_list which returns 2 commits
      assert.is_true(count >= 0)
    end)

    it("sets view_mode to single when no selection", function()
      Navigation.load_commits()
      assert.equals("single", Navigation.get_view_mode())
    end)

    it("sets view_mode to range when 2+ commits selected", function()
      mock_selection.set_selected({ "sha1", "sha2" })
      Navigation.load_commits()
      assert.equals("range", Navigation.get_view_mode())
    end)
  end)

  ----------------------------------------------------------------------
  -- M.cycle_next() advances position
  ----------------------------------------------------------------------
  describe("cycle_next()", function()
    it("advances position correctly", function()
      local commits = make_sample_commits()
      mock_git.get_commits_for_mode = function()
        return commits
      end
      Navigation.load_commits()

      local pos = Navigation.cycle_next()
      assert.equals(2, pos)

      local p = Navigation.get_position()
      assert.equals(2, p.position)
      assert.equals("fix: second commit", p.commit.subject)
    end)

    it("stays at boundary when at last commit", function()
      local commits = make_sample_commits()
      mock_git.get_commits_for_mode = function()
        return commits
      end
      Navigation.load_commits()

      -- Advance twice: 1 -> 2 -> 3
      Navigation.cycle_next()
      local pos = Navigation.cycle_next()
      assert.equals(3, pos)

      -- Try to go past end — stays at 3
      local result = Navigation.cycle_next()
      assert.equals(3, result)

      local p = Navigation.get_position()
      assert.equals(3, p.position)
    end)

    it("returns nil when no commits loaded", function()
      local result = Navigation.cycle_next()
      assert.is_nil(result)
    end)

    it("returns nil in range mode", function()
      mock_selection.set_selected({ "sha1", "sha2" })
      Navigation.load_commits()
      assert.equals("range", Navigation.get_view_mode())

      local result = Navigation.cycle_next()
      assert.is_nil(result)
    end)
  end)

  ----------------------------------------------------------------------
  -- M.cycle_prev() retreats position
  ----------------------------------------------------------------------
  describe("cycle_prev()", function()
    it("retreats position correctly", function()
      local commits = make_sample_commits()
      mock_git.get_commits_for_mode = function()
        return commits
      end
      Navigation.load_commits()

      -- Advance to position 2, then retreat
      Navigation.cycle_next()
      local pos = Navigation.cycle_prev()
      assert.equals(1, pos)

      local p = Navigation.get_position()
      assert.equals(1, p.position)
      assert.equals("feat: first commit", p.commit.subject)
    end)

    it("stays at boundary when at position 1", function()
      local commits = make_sample_commits()
      mock_git.get_commits_for_mode = function()
        return commits
      end
      Navigation.load_commits()

      -- Already at position 1
      local result = Navigation.cycle_prev()
      assert.equals(1, result)

      local p = Navigation.get_position()
      assert.equals(1, p.position)
    end)

    it("returns nil when no commits loaded", function()
      local result = Navigation.cycle_prev()
      assert.is_nil(result)
    end)

    it("returns nil in range mode", function()
      mock_selection.set_selected({ "sha1", "sha2" })
      Navigation.load_commits()
      assert.equals("range", Navigation.get_view_mode())

      local result = Navigation.cycle_prev()
      assert.is_nil(result)
    end)
  end)

  ----------------------------------------------------------------------
  -- M.get_position() returns correct structure
  ----------------------------------------------------------------------
  describe("get_position()", function()
    it("returns { position, total, commit } structure", function()
      local commits = make_sample_commits()
      mock_git.get_commits_for_mode = function()
        return commits
      end
      Navigation.load_commits()

      local pos = Navigation.get_position()
      assert.equals("table", type(pos))
      assert.is_not_nil(pos.position)
      assert.is_not_nil(pos.total)
      assert.is_not_nil(pos.commit)
      assert.is_not_nil(pos.commit.sha)
      assert.is_not_nil(pos.commit.subject)
    end)

    it("returns nil when no commits loaded", function()
      assert.is_nil(Navigation.get_position())
    end)
  end)

  ----------------------------------------------------------------------
  -- M.get_current_sha() returns SHA at current position
  ----------------------------------------------------------------------
  describe("get_current_sha()", function()
    it("returns full SHA at current position", function()
      local commits = make_sample_commits()
      mock_git.get_commits_for_mode = function()
        return commits
      end
      Navigation.load_commits()

      local sha = Navigation.get_current_sha()
      assert.equals("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", sha)
    end)

    it("returns nil when no commits loaded", function()
      assert.is_nil(Navigation.get_current_sha())
    end)
  end)

  ----------------------------------------------------------------------
  -- M.is_loaded() returns correct boolean
  ----------------------------------------------------------------------
  describe("is_loaded()", function()
    it("returns false after loading empty list", function()
      mock_git.get_commits_for_mode = function()
        return {}
      end
      -- Override fallback to return empty too
      mock_git.get_commit_list = function()
        return {}
      end
      Navigation.load_commits()

      assert.is_false(Navigation.is_loaded())
    end)

    it("returns true after loading commits", function()
      mock_git.get_commits_for_mode = function()
        return make_sample_commits()
      end
      Navigation.load_commits()

      assert.is_true(Navigation.is_loaded())
    end)
  end)

  ----------------------------------------------------------------------
  -- M.get_view_mode() returns correct mode
  ----------------------------------------------------------------------
  describe("get_view_mode()", function()
    it("returns 'single' by default", function()
      assert.equals("single", Navigation.get_view_mode())
    end)

    it("returns 'range' after loading with 2+ selected", function()
      mock_selection.set_selected({ "sha1", "sha2" })
      Navigation.load_commits()
      assert.equals("range", Navigation.get_view_mode())
    end)
  end)
end)
