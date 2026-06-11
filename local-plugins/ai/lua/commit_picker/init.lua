-- lua/commit_picker/init.lua
-- Commit Picker entry point — wires git → display → selection → diff

local M = {}

local function make_review_range(selected_shas)
  local ok_range, Range = pcall(require, "ai_review.range")
  if not ok_range then
    return nil
  end
  if #selected_shas == 1 then
    return Range.single_commit(selected_shas[1])
  end
  if #selected_shas >= 2 then
    return Range.commit_range(selected_shas[1], selected_shas[2], { selected_shas[1], selected_shas[2] })
  end
  return nil
end

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
  local ok_nav, Navigation = pcall(require, "commit_picker.navigation")
  if ok_nav and type(Navigation.load_commits) ~= "function" then
    ok_nav = false
  end
  return { Git = Git, Display = Display, Selection = Selection, Diff = Diff, Navigation = ok_nav and Navigation or nil }
end

----------------------------------------------------------------------
-- M.setup()
-- 命令注册在 plugin/ai.lua
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

  -- 命令注册在 plugin/ai.lua
  return M
end

----------------------------------------------------------------------
-- M.open()
-- Fetches commits using configured mode (D-02), falls back to last N (D-15)
-- Shows picker; on selection, stores SHAs and opens diff (D-03, D-13)
-- Phase 5: uses get_commits_for_mode() for config-aware fetching
----------------------------------------------------------------------
function M.open(opts)
  opts = opts or {}
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
      if #selected_shas == 0 then
        return
      end

      local review_range = make_review_range(selected_shas)
      if opts.review_mode then
        if review_range then
          local ok_cache, Cache = pcall(require, "ai_review.range_cache")
          if ok_cache then
            local ok_save, err_save = Cache.save(review_range)
            if not ok_save then
              vim.notify("Review range 缓存失败: " .. tostring(err_save), vim.log.levels.ERROR)
              return
            end
          else
            vim.notify("Review range cache 模块加载失败", vim.log.levels.ERROR)
            return
          end
          if opts.on_range_selected then
            opts.on_range_selected(review_range)
          end
          vim.notify("Review range 已缓存", vim.log.levels.INFO)
        end
        return
      end

      -- Open diff with selection (D-03, D-06, D-08)
      if mods.Navigation then
        -- Update navigation view_mode based on selection count
        mods.Navigation.load_commits()
      end
      Diff.open_diff(selected_shas)
    end,
    base_commit = base_commit,

    -- Phase 6+: action handling for Set Base / Config / Help
    refresh_picker = function()
      -- Reopen picker with updated config (base commit mode, etc.)
      M.open(opts)
    end,
    on_action = function(action_name)
      if action_name == "config" then
        -- Open settings panel using :AICommitConfig command
        vim.schedule(function()
          local ok, Settings = pcall(require, "commit_picker.settings")
          if ok then
            Settings.open()
          end
        end)
      elseif action_name == "help" then
        local help_text = [[
 Commit Picker 快捷键帮助

 <Enter>       打开选中提交的 Diff
 <Ctrl+Space>  切换多选
 <Ctrl+A>      全选
 <Ctrl+B>      设为基础提交 (Set Base)
 <Ctrl+C>      打开配置面板
 <Ctrl+?>      显示此帮助
 <Esc>         关闭

 选择多个提交可查看范围 Diff；
 设置基础提交后，picker 将自动刷新显示从基础提交到 HEAD 的变更。
]]
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
        vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
        local lines = vim.split(help_text, "\n")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        -- Responsive sizing
        local max_width = math.min(80, vim.o.columns - 4)
        local width = max_width
        local height = math.min(#lines, math.floor(vim.o.lines * 0.5))
        local win_opts = {
          relative = "editor",
          width = width,
          height = height,
          col = math.floor((vim.o.columns - width) / 2),
          row = math.floor((vim.o.lines - height) / 2),
          style = "minimal",
          border = "rounded",
          title = " Commit Picker Help ",
          title_pos = "center",
        }

        local win = vim.api.nvim_open_win(buf, true, win_opts)
        vim.keymap.set("n", "q", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf })
        vim.keymap.set("n", "<Esc>", function()
          vim.api.nvim_win_close(win, true)
        end, { buffer = buf })
      end
    end,
  })
end

return M
