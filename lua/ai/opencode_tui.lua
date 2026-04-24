-- lua/ai/opencode_tui.lua
-- OpenCode TUI 主题和界面配置生成模块

local M = {}

-- 获取 OpenCode 配置目录
local function get_opencode_config_dir()
  local xdg_config = os.getenv("XDG_CONFIG_HOME") or vim.fn.expand("~/.config")
  return xdg_config .. "/opencode"
end

local function get_opencode_tui_path()
  return get_opencode_config_dir() .. "/tui.json"
end

local function get_opencode_themes_dir()
  return get_opencode_config_dir() .. "/themes"
end

-- 生成 tui.json 配置
local function build_tui_config()
  return {
    ["$schema"] = "https://opencode.ai/tui.json",
    theme = "lytmode", -- 使用自定义主题
    layout = "default",
    -- 快捷键配置
    keys = {
      -- 可以在此自定义快捷键
    },
    -- 显示选项
    show_header = true,
    show_model = true,
    show_tokens = true,
  }
end

-- 生成 lytmode 主题配置（基于现代深色主题）
local function build_lytmode_theme()
  return {
    ["$schema"] = "https://opencode.ai/theme.json",
    defs = {
      -- 主色调 - 蓝紫色系
      primary = "#7C3AED",
      primary_light = "#8B5CF6",
      -- 辅助色 - 青绿色
      secondary = "#06B6D4",
      -- 强调色 - 琥珀色
      accent = "#F59E0B",
      -- 状态色
      error = "#EF4444",
      warning = "#F59E0B",
      success = "#10B981",
      info = "#3B82F6",
      -- 文本色
      text = "#F1F5F9",
      text_muted = "#94A3B8",
      text_dim = "#64748B",
      -- 背景色
      bg_primary = "#0F172A",
      bg_secondary = "#1E293B",
      bg_tertiary = "#334155",
      -- 边框色
      border = "#334155",
      border_active = "#7C3AED",
      border_subtle = "#1E293B",
      -- Diff 颜色
      diff_added = "#10B981",
      diff_removed = "#EF4444",
      diff_context = "#64748B",
      diff_added_bg = "#064E3B20",
      diff_removed_bg = "#7F1D1D20",
    },
    theme = {
      primary = "primary",
      secondary = "secondary",
      accent = "accent",
      error = "error",
      warning = "warning",
      success = "success",
      info = "info",
      text = "text",
      textMuted = "text_muted",
      background = "bg_primary",
      backgroundPanel = "bg_secondary",
      backgroundElement = "bg_tertiary",
      border = "border",
      borderActive = "border_active",
      borderSubtle = "border_subtle",
      -- Diff 相关
      diffAdded = "diff_added",
      diffRemoved = "diff_removed",
      diffContext = "diff_context",
      diffAddedBg = "diff_added_bg",
      diffRemovedBg = "diff_removed_bg",
      -- Markdown 样式
      markdownText = "text",
      markdownHeading = "primary_light",
      markdownLink = "secondary",
      markdownLinkText = "primary",
      markdownCode = "accent",
      markdownCodeBlock = "text",
      -- 语法高亮
      syntaxComment = "text_dim",
      syntaxKeyword = "primary_light",
      syntaxFunction = "secondary",
      syntaxVariable = "accent",
      syntaxString = "success",
      syntaxType = "info",
      syntaxNumber = "warning",
      syntaxOperator = "primary",
    },
  }
end

-- 格式化 JSON（美观的格式）
local function format_json_pretty(obj, indent)
  indent = indent or 0
  local spacing = string.rep("  ", indent)

  if type(obj) == "table" then
    if next(obj) == nil then
      return "{}"
    end

    local is_array = #obj > 0
    local items = {}

    if is_array then
      for i, v in ipairs(obj) do
        table.insert(items, spacing .. "  " .. M.format_json_pretty(v, indent + 1))
      end
      return "[\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "]"
    else
      local sorted_keys = {}
      for k in pairs(obj) do
        table.insert(sorted_keys, k)
      end
      table.sort(sorted_keys)

      for _, k in ipairs(sorted_keys) do
        local v = obj[k]
        local key = type(k) == "number" and k or string.format("%q", k)
        table.insert(items, spacing .. "  " .. key .. ": " .. M.format_json_pretty(v, indent + 1))
      end
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "}"
    end
  elseif type(obj) == "string" then
    return '"' .. obj .. '"'
  elseif type(obj) == "number" or type(obj) == "boolean" then
    return tostring(obj)
  elseif obj == nil then
    return "null"
  else
    return tostring(obj)
  end
end

M.format_json_pretty = format_json_pretty

-- 生成并写入 TUI 配置
function M.generate_tui_config()
  local opencode_dir = get_opencode_config_dir()
  local themes_dir = get_opencode_themes_dir()

  -- 确保目录存在
  if vim.fn.isdirectory(opencode_dir) == 0 then
    vim.fn.mkdir(opencode_dir, "p")
  end
  if vim.fn.isdirectory(themes_dir) == 0 then
    vim.fn.mkdir(themes_dir, "p")
  end

  -- 写入 tui.json
  local tui_path = get_opencode_tui_path()
  local tui_config = build_tui_config()
  local tui_content = format_json_pretty(tui_config)
  vim.fn.writefile(vim.split(tui_content, "\n"), tui_path)

  -- 写入 lytmode 主题
  local theme_path = themes_dir .. "/lytmode.json"
  local theme_config = build_lytmode_theme()
  local theme_content = format_json_pretty(theme_config)
  vim.fn.writefile(vim.split(theme_content, "\n"), theme_path)

  vim.notify("✅ OpenCode TUI 配置和主题已生成\n" .. "TUI: " .. tui_path .. "\n" .. "主题: " .. theme_path, vim.log.levels.INFO)

  return true
end

-- 预览 TUI 配置
function M.preview_tui_config()
  local tui_config = build_tui_config()
  local preview = format_json_pretty(tui_config)
  local lines = vim.split(preview, "\n")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "json")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_name(buf, "OpenCode TUI Config Preview")

  vim.api.nvim_win_set_buf(0, buf)
  vim.notify("预览模式: q 退出", vim.log.levels.INFO)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
end

-- 预览主题配置
function M.preview_theme()
  local theme_config = build_lytmode_theme()
  local preview = format_json_pretty(theme_config)
  local lines = vim.split(preview, "\n")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "json")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_name(buf, "OpenCode lytmode Theme Preview")

  vim.api.nvim_win_set_buf(0, buf)
  vim.notify("预览模式: q 退出", vim.log.levels.INFO)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
end

-- 编辑主题
function M.edit_theme()
  local themes_dir = get_opencode_themes_dir()
  local theme_path = themes_dir .. "/lytmode.json"

  -- 确保目录存在
  if vim.fn.isdirectory(themes_dir) == 0 then
    vim.fn.mkdir(themes_dir, "p")
  end

  -- 如果主题文件不存在，创建默认主题
  if vim.fn.filereadable(theme_path) == 0 then
    M.generate_tui_config()
  end

  vim.cmd("edit " .. theme_path)
  vim.api.nvim_buf_set_option(0, "filetype", "json")
end

return M
