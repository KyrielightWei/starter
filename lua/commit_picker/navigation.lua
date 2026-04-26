-- lua/commit_picker/navigation.lua
-- Commit navigation state management — cycling next/prev through commits during diff review

local M = {}

----------------------------------------------------------------------
-- Module-local state (not persisted across Neovim sessions)
----------------------------------------------------------------------
local commit_list = nil      -- Array of {sha, short_sha, subject, date, refs}
local current_index = nil     -- 1-based index into commit_list
local view_mode = "single"    -- "single" (sha^..sha) or "range" (sha1..sha2)

----------------------------------------------------------------------
-- Injected dependencies (set via M.setup)
----------------------------------------------------------------------
local Git = nil
local Selection = nil
local Diff = nil

----------------------------------------------------------------------
-- M.setup(opts)
-- Accepts { Git, Selection, Diff } modules. Called from init.lua.
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}
  Git = opts.Git
  Selection = opts.Selection
  Diff = opts.Diff
end

----------------------------------------------------------------------
-- M.load_commits()
-- Fetches commits via Git.get_commits_for_mode(). Falls back to
-- Git.get_commit_list if none found. Resets position to 1.
-- Returns commit count.
----------------------------------------------------------------------
function M.load_commits()
  if not Git then
    vim.notify("导航模块未初始化", vim.log.levels.ERROR)
    return 0
  end

  -- Determine view mode from current selection
  local selected = Selection.get_selected()
  if #selected >= 2 then
    view_mode = "range"
  else
    view_mode = "single"
  end

  -- Fetch commits using config-aware mode
  local commits = Git.get_commits_for_mode()

  -- Fallback if no commits or error returned
  if type(commits) == "table" and (commits.error or #commits == 0) then
    local count = 20
    local ok_config, Config = pcall(require, "commit_picker.config")
    if ok_config and type(Config.get_config) == "function" then
      count = Config.get_config().count or 20
    end
    commits = Git.get_commit_list(nil, "HEAD", { count = count })
  end

  if type(commits) == "table" and commits.error then
    commit_list = {}
    current_index = nil
    return 0
  end

  commit_list = commits or {}
  current_index = 1

  return #commit_list
end

----------------------------------------------------------------------
-- Helper: Open diff for a given commit SHA
-- Closes existing diffview first, then reopens with new SHA
----------------------------------------------------------------------
local function open_commit_diff(sha, sha_index, total)
  if not Diff or not Selection then
    vim.notify("导航模块依赖项未加载", vim.log.levels.ERROR)
    return
  end

  local commit = commit_list[sha_index]
  local subject = commit and commit.subject or "unknown"

  -- Close existing diffview if open (pcall — may not be open)
  pcall(vim.cmd, "DiffviewClose")

  -- D-26a / R-01: 50ms defer between close and open to avoid race condition
  vim.defer_fn(function()
    -- Update selection to current commit
    Selection.set_selected({ sha })
    -- Open diff for this commit
    Diff.open_diff({ sha })
    -- Notify user of current position
    vim.notify(string.format("已导航到 [%d/%d]: %s", sha_index, total, subject), vim.log.levels.INFO)
  end, 50)
end

----------------------------------------------------------------------
-- M.cycle_next()
-- Advances position by 1. Disabled in range mode.
-- Shows boundary notification at end of list.
----------------------------------------------------------------------
function M.cycle_next()
  -- Range mode check (C-01/C-04 fix)
  if view_mode == "range" then
    vim.notify("范围模式下不支持逐条导航", vim.log.levels.INFO)
    return nil
  end

  if not commit_list or #commit_list == 0 then
    vim.notify("没有可导航的提交，请先打开 Commit Picker", vim.log.levels.INFO)
    return nil
  end

  if current_index >= #commit_list then
    vim.notify("已是最后一条提交", vim.log.levels.WARN)
    return current_index
  end

  -- Advance position
  current_index = current_index + 1
  local sha = commit_list[current_index].sha

  -- Validate SHA before opening (T-06-01)
  if not Diff.is_valid_sha(sha) then
    vim.notify("无效的 SHA 格式: " .. sha, vim.log.levels.ERROR)
    return nil
  end

  open_commit_diff(sha, current_index, #commit_list)

  return current_index
end

----------------------------------------------------------------------
-- M.cycle_prev()
-- Moves position back by 1. Disabled in range mode.
-- Shows boundary notification at position 1.
----------------------------------------------------------------------
function M.cycle_prev()
  -- Range mode check (C-01/C-04 fix)
  if view_mode == "range" then
    vim.notify("范围模式下不支持逐条导航", vim.log.levels.INFO)
    return nil
  end

  if not commit_list or #commit_list == 0 then
    vim.notify("没有可导航的提交，请先打开 Commit Picker", vim.log.levels.INFO)
    return nil
  end

  if current_index <= 1 then
    vim.notify("已是第一条提交", vim.log.levels.WARN)
    return current_index
  end

  -- Retreat position
  current_index = current_index - 1
  local sha = commit_list[current_index].sha

  -- Validate SHA before opening (T-06-01)
  if not Diff.is_valid_sha(sha) then
    vim.notify("无效的 SHA 格式: " .. sha, vim.log.levels.ERROR)
    return nil
  end

  open_commit_diff(sha, current_index, #commit_list)

  return current_index
end

----------------------------------------------------------------------
-- M.get_position()
-- Returns { position = N, total = M, commit = { ... } }
----------------------------------------------------------------------
function M.get_position()
  if not commit_list or #commit_list == 0 or not current_index then
    return nil
  end

  return {
    position = current_index,
    total = #commit_list,
    commit = commit_list[current_index],
  }
end

----------------------------------------------------------------------
-- M.get_current_sha()
-- Returns full SHA at current position, or nil if no commits loaded.
----------------------------------------------------------------------
function M.get_current_sha()
  if not commit_list or not current_index or current_index < 1 or current_index > #commit_list then
    return nil
  end
  return commit_list[current_index].sha
end

----------------------------------------------------------------------
-- M.is_loaded()
-- Returns true if commit_list is populated.
----------------------------------------------------------------------
function M.is_loaded()
  return commit_list ~= nil and #commit_list > 0
end

----------------------------------------------------------------------
-- M.clear()
-- Clears navigation state (for cleanup / session reset)
----------------------------------------------------------------------
function M.clear()
  commit_list = nil
  current_index = nil
  view_mode = "single"
end

----------------------------------------------------------------------
-- M.get_view_mode()
-- Returns current view mode ("single" or "range")
----------------------------------------------------------------------
function M.get_view_mode()
  return view_mode
end

return M
