-- lua/commit_picker/settings.lua
-- FZF-lua settings picker for commit picker configuration
-- Implements mode selector, count input, base commit selection

local M = {}

local Config = require("commit_picker.config")

----------------------------------------------------------------------
-- ANSI color codes
----------------------------------------------------------------------
local RESET = "\27[0m"
local GREEN = "\27[38;5;114m"
local YELLOW = "\27[38;5;220m"
local CYAN = "\27[38;5;111m"
local DIM = "\27[2m"

----------------------------------------------------------------------
-- Format setting display line
----------------------------------------------------------------------
local function format_setting(name, value, icon)
  icon = icon or "◦"
  return string.format("%s %s: %s%s%s  %s[▶ change]%s",
    icon, name, GREEN, tostring(value), RESET, DIM, RESET)
end

----------------------------------------------------------------------
-- M.open() — fzf-lua picker showing current settings
----------------------------------------------------------------------
function M.open()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("[commit_picker] fzf-lua not installed", vim.log.levels.ERROR)
    return
  end

  -- Get current config
  Config.invalidate_cache()
  local config = Config.get_config()

  -- Build display items
  local mode_label = {
    unpushed = "未推送提交",
    last_n = "最近 N 条",
    since_base = "从基础提交开始",
  }
  local base_display = config.base_commit
      and config.base_commit:sub(1, 7)
      or "无"

  local items = {}
  local action_map = {}

  -- Mode setting
  local mode_display = format_setting("Mode", mode_label[config.mode] or config.mode, "◦")
  table.insert(items, mode_display)
  action_map[mode_display] = { action = "change_mode" }

  -- Count setting
  local count_display = format_setting("Count", tostring(config.count), "◦")
  table.insert(items, count_display)
  action_map[count_display] = { action = "change_count" }

  -- Base commit setting
  local base_icon = config.mode == "since_base" and "◦" or DIM .. "◦" .. RESET
  local base_display_line = format_setting("Base", base_display, base_icon)
  table.insert(items, base_display_line)
  action_map[base_display_line] = { action = "change_base" }

  -- Save action
  local save_display = string.format("%s %s[保存并退出]%s%s", CYAN, GREEN, RESET, YELLOW)
  table.insert(items, save_display)
  action_map[save_display] = { action = "save" }

  -- Reset action
  local reset_display = string.format("%s [重置为默认值]%s", DIM, RESET)
  table.insert(items, reset_display)
  action_map[reset_display] = { action = "reset" }

  -- In-memory config for editing (changes applied here before save)
  local pending = {
    mode = config.mode,
    count = config.count,
    base_commit = config.base_commit,
  }
  local changed = false

  -- Helper: refresh picker with updated pending values
  local function refresh()
    local new_items = {}
    local new_action_map = {}

    local new_mode_display = format_setting("Mode", mode_label[pending.mode] or pending.mode, "◦")
    table.insert(new_items, new_mode_display)
    new_action_map[new_mode_display] = { action = "change_mode" }

    local new_count_display = format_setting("Count", tostring(pending.count), "◦")
    table.insert(new_items, new_count_display)
    new_action_map[new_count_display] = { action = "change_count" }

    local new_base_display = pending.base_commit and pending.base_commit:sub(1, 7) or "无"
    local new_base_icon = pending.mode == "since_base" and "◦" or DIM .. "◦" .. RESET
    local new_base_line = format_setting("Base", new_base_display, new_base_icon)
    table.insert(new_items, new_base_line)
    new_action_map[new_base_line] = { action = "change_base" }

    local new_save = string.format("%s%s保存并退出: %s%s%s",
      changed and YELLOW or GREEN,
      changed and "[★ " or "[",
      mode_label[pending.mode] or pending.mode,
      changed and " ★]" or "]",
      RESET)
    table.insert(new_items, new_save)
    new_action_map[new_save] = { action = "save" }

    local new_reset = string.format("%s [重置为默认值]%s", DIM, RESET)
    table.insert(new_items, new_reset)
    new_action_map[new_reset] = { action = "reset" }

    M._render_picker(new_items, new_action_map, pending, function(p) changed = true; pending = p end)
  end

  M._render_picker(items, action_map, pending, function(p) changed = true; pending = p end)
end

----------------------------------------------------------------------
-- Internal: render the fzf-lua picker with actions
----------------------------------------------------------------------
function M._render_picker(items, action_map, pending, on_update)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end

  fzf.fzf_exec(items, {
    prompt = " Commit Picker Settings > ",
    winopts = {
      width = 0.5,
      height = 0.35,
      border = "rounded",
    },
    fzf_opts = {
      ["--header"] = string.format(
        "%s <CR> Edit  %s <C-s> Save  %s <C-r> Reset  %s <C-?> Help",
        "<Enter>", "<Ctrl-s>", "<Ctrl-r>", "<Ctrl-/>"
      ),
    },
    actions = {
      -- <CR>: edit selected setting
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local action = action_map[selected[1]]
        if not action then return end
        M._handle_action(action.action, pending, on_update)
      end,

      -- <C-s>: save and exit
      ["ctrl-s"] = function()
        M._save_and_close(pending)
      end,

      -- <C-r>: reset to defaults
      ["ctrl-r"] = function()
        local ok = Config.reset_to_defaults()
        if ok then
          vim.notify("提交选择器配置已重置", vim.log.levels.INFO)
        else
          vim.notify("重置配置失败", vim.log.levels.ERROR)
        end
        Config.invalidate_cache()
      end,

      -- <C-?>: show help
      ["ctrl-/"] = function()
        M._show_help()
      end,
    },
  })
end

----------------------------------------------------------------------
-- Handle setting action
----------------------------------------------------------------------
function M._handle_action(action_name, pending, on_update)
  if action_name == "change_mode" then
    M._select_mode(pending, on_update)

  elseif action_name == "change_count" then
    M._input_count(pending, on_update)

  elseif action_name == "change_base" then
    M._select_base_commit(pending, on_update)
  end
end

----------------------------------------------------------------------
-- Mode selector: fzf-lua picker for mode selection
----------------------------------------------------------------------
function M._select_mode(pending, on_update)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end

  local modes = {
    { value = "unpushed", display = "未推送提交 (origin/HEAD..HEAD)" },
    { value = "last_n", display = "最近 N 条提交" },
    { value = "since_base", display = "从基础提交开始 (base..HEAD)" },
  }

  local items = {}
  local value_map = {}
  for _, m in ipairs(modes) do
    local mark = pending.mode == m.value and " ★ " or "   "
    local display = mark .. m.display
    table.insert(items, display)
    value_map[display] = m.value
  end

  fzf.fzf_exec(items, {
    prompt = " Select Mode > ",
    winopts = {
      width = 0.5,
      height = 0.25,
      border = "rounded",
    },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local new_mode = value_map[selected[1]]
        if new_mode then
          pending.mode = new_mode
          -- Clear base_commit if switching away from since_base
          if new_mode ~= "since_base" then
            pending.base_commit = nil
          end
          on_update(pending)
        end
      end,
    },
  })
end

----------------------------------------------------------------------
-- Count input: floating input dialog for count value
----------------------------------------------------------------------
function M._input_count(pending, on_update)
  vim.ui.input({
    prompt = "显示提交数量 (1-500): ",
    default = tostring(pending.count),
  }, function(input)
    if not input or input == "" then return end

    local num = tonumber(input)
    if not num or num < 1 or num > 500 or num ~= math.floor(num) then
      vim.notify("请输入 1-500 之间的整数", vim.log.levels.ERROR)
      return
    end

    pending.count = num
    on_update(pending)
  end)
end

----------------------------------------------------------------------
-- Base commit selector: fzf-lua picker with recent commits
----------------------------------------------------------------------
function M._select_base_commit(pending, on_update)
  local Git = require("commit_picker.git")

  -- Fetch recent 100 commits
  local commits = Git.get_commit_list(nil, nil, { count = 100 })
  if not commits or #commits == 0 then
    vim.notify("没有找到提交，无法选择基础提交", vim.log.levels.WARN)
    return
  end

  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end

  -- Build display items
  local items = {}
  local sha_map = {}

  -- Clear option
  local clear_display = "⟳ 清除基础提交 (设为 nil)"
  table.insert(items, clear_display)
  sha_map[clear_display] = "__CLEAR__"

  for _, c in ipairs(commits) do
    local display = string.format("[%s]  %s  (%s)", c.short_sha, c.subject, c.date)
    table.insert(items, display)
    sha_map[display] = c.sha
  end

  fzf.fzf_exec(items, {
    prompt = " Select Base Commit > ",
    winopts = {
      width = 0.6,
      height = 0.4,
      border = "rounded",
      preview = {
        layout = "vertical",
        vertical = "down:40%",
      },
    },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local line = selected[1]
        local sha = sha_map[line]
        if sha == "__CLEAR__" then
          pending.base_commit = nil
        elseif sha then
          pending.base_commit = sha
        end
        on_update(pending)
      end,
    },
    preview = function(selected)
      if not selected or #selected == 0 then return "" end
      local line = type(selected) == "table" and selected[1] or selected
      local sha = line:match("^%[([%x]+)%]")
      if not sha then return "" end
      local result = vim.system({ "git", "show", sha, "--stat" }):wait()
      return result.stdout or ""
    end,
  })
end

----------------------------------------------------------------------
-- Save and close
----------------------------------------------------------------------
function M._save_and_close(pending)
  -- Validate before saving
  local validation = Config.validate_config(pending)
  if not validation.ok then
    vim.notify("配置验证失败: " .. validation.error, vim.log.levels.ERROR)
    return
  end

  local ok, err = Config.save_config(pending)
  if ok then
    vim.notify("提交选择器配置已保存", vim.log.levels.INFO)
    Config.invalidate_cache()
  else
    vim.notify("保存配置失败: " .. err, vim.log.levels.ERROR)
  end
end

----------------------------------------------------------------------
-- Help window
----------------------------------------------------------------------
function M._show_help()
  local help_text = [[
 Commit Picker 设置帮助

设置项:
  Mode     选择提交显示模式
           unpushed: 仅显示未推送的提交
           last_n:   显示最近 N 条提交
           since_base: 显示从基础提交到 HEAD

  Count    在 last_n 模式下显示的提交数量 (1-500)

  Base     在 since_base 模式下选择的基础提交

快捷键:
  <CR>     编辑选中的设置
  <C-s>    保存并退出
  <C-r>    重置为默认值
  <C-?>    显示此帮助
  <Esc>    关闭

命令:
  :AICommitConfig  打开此设置面板
  :AICommitPicker  打开提交选择器
]]

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(help_text, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "help")

  local width = 50
  local height = 20
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Settings Help ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

return M
