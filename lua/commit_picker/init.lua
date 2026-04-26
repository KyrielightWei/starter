-- lua/commit_picker/init.lua
-- Commit Picker entry point — wires git → display → selection → diff

local M = {}

----------------------------------------------------------------------
-- Lazy-load submodules with pcall to prevent cascading failures
-- Verifies exported functions exist (WR-01 fix)
----------------------------------------------------------------------
local function get_modules()
  local ok, Git = pcall(require, "commit_picker.git")
  if not ok or type(Git.get_commit_list) ~= "function" or type(Git.get_unpushed) ~= "function" then
    return nil, "git"
  end
  local ok, Display = pcall(require, "commit_picker.display")
  if not ok or type(Display.show_picker) ~= "function" then
    return nil, "display"
  end
  local ok, Selection = pcall(require, "commit_picker.selection")
  if not ok or type(Selection.set_selected) ~= "function" or type(Selection.get_selected) ~= "function" then
    return nil, "selection"
  end
  local ok, Diff = pcall(require, "commit_picker.diff")
  if not ok or type(Diff.open_diff) ~= "function" then
    return nil, "diff"
  end
  -- Navigation module (Phase 6) — optional, non-blocking
  local ok_nav = nil
  local ok_nav, Navigation = pcall(require, "commit_picker.navigation")
  if ok_nav and type(Navigation.load_commits) ~= "function" then
    ok_nav = false
  end
  return { Git = Git, Display = Display, Selection = Selection, Diff = Diff, Navigation = ok_nav and Navigation or nil }
end

----------------------------------------------------------------------
-- M.setup()
-- Registers :AICommitPicker and :AICommitConfig commands
-- Note: <leader>kC keymap is registered in ai/init.lua keys table
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}

  -- Initialize Navigation module (Phase 6)
  local ok_nav, Nav = pcall(require, "commit_picker.navigation")
  if ok_nav then
    Nav.setup({
      Git = require("commit_picker.git"),
      Selection = require("commit_picker.selection"),
      Diff = require("commit_picker.diff"),
    })
  end

  -- User command: :AICommitPicker
  vim.api.nvim_create_user_command("AICommitPicker", function()
    M.open()
  end, { desc = "Open commit picker to review diffs" })

  -- User command: :AICommitConfig (Phase 5)
  vim.api.nvim_create_user_command("AICommitConfig", function()
    local ok, Settings = pcall(require, "commit_picker.settings")
    if ok then
      Settings.open()
    else
      vim.notify("[commit_picker] settings module 加载失败", vim.log.levels.ERROR)
    end
  end, { desc = "Open commit picker settings" })

  return M
end

----------------------------------------------------------------------
-- M.open()
-- Fetches commits using configured mode (D-02), falls back to last N (D-15)
-- Shows picker; on selection, stores SHAs and opens diff (D-03, D-13)
-- Phase 5: uses get_commits_for_mode() for config-aware fetching
----------------------------------------------------------------------
function M.open()
  local mods, err = get_modules()
  if not mods then
    vim.notify("[commit_picker] " .. err .. " module failed to load", vim.log.levels.ERROR)
    return
  end

  local Git, Display, Selection, Diff = mods.Git, mods.Display, mods.Selection, mods.Diff

  -- Use config-aware mode routing (Phase 5)
  local commits, base_commit = Git.get_commits_for_mode()

  -- Handle error from git command (D-16)
  if type(commits) == "table" and commits.error then
    vim.notify("获取提交失败: " .. tostring(commits.output), vim.log.levels.ERROR)
    commits = {}
  end

  -- Fallback: no commits -> show last N (D-15)
  if #commits == 0 then
    local config_ok, Config = pcall(require, "commit_picker.config")
    local count = 20
    if config_ok and type(Config) == "table" and type(Config.get_config) == "function" then
      count = Config.get_config().count or 20
    end
    commits = Git.get_commit_list(nil, "HEAD", { count = count })
    if #commits == 0 then
      vim.notify("没有找到提交", vim.log.levels.INFO)
      return
    end
  end

  Display.show_picker(commits, {
    on_select = function(selected_shas)
      -- Store selection
      Selection.set_selected(selected_shas)
      -- Open diff with selection (D-03, D-06, D-08)
      if #selected_shas > 0 then
        if mods.Navigation then
          -- Update navigation view_mode based on selection count
          mods.Navigation.load_commits()
        end
        Diff.open_diff(selected_shas)
      end
    end,
    base_commit = base_commit,
  })
end

return M
