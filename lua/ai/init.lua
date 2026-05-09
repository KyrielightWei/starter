-- lua/ai/init.lua
-- AI 模块入口 - 无 Avante 版本
--
-- 主要 AI 工具：
--   - OpenCode (CLI + Components)
--   - Claude Code (CLI + Components)
--   - Provider Manager
--   - Commit Picker
--   - Skill Studio
--
-- 快捷键分类：
--   p/P/A    - Provider Manager
--   C/f/b/d  - Commit Picker & Diff
--   k/S/K/T  - 配置与同步
--   s        - Model Switch (Provider Manager)

local M = {}

-- 配置
local config = {
  key_prefix = "<leader>k",
  auto_setup_keys = true,
  auto_setup_commands = true,
}

----------------------------------------------------------------------
-- 命令包装器（用于向后兼容）
----------------------------------------------------------------------
local function call(fn_name)
  return function()
    vim.notify("功能 '" .. fn_name .. "' 需要安装 Avante 或其他 AI backend", vim.log.levels.WARN)
  end
end

----------------------------------------------------------------------
-- 快捷键配置（移除 Avante 特定的，保留通用功能）
----------------------------------------------------------------------
local keys = {
  -- AI 功能组（<leader>k 前缀）
  { "<leader>k", group = "AI Tools", icon = "🤖" },

  -- === Provider Manager ===
  {
    "<leader>kp",
    mode = "n",
    fn = function()
      local ok, PM = pcall(require, "ai.provider_manager")
      if ok then
        PM.open()
      end
    end,
    desc = "Provider Manager",
    icon = "📊",
  },

  -- === Model Switch ===
  {
    "<leader>ks",
    mode = "n",
    fn = function()
      local ok, MS = pcall(require, "ai.model_switch")
      if ok then
        MS.select(function(choice)
          if choice then
            vim.notify("Switched to " .. choice.provider .. "/" .. choice.model, vim.log.levels.INFO)
          end
        end)
      end
    end,
    desc = "Model Switch",
    icon = "🔄",
  },

  -- === Commit Picker & Diff ===
  {
    "<leader>kC",
    mode = "n",
    fn = function()
      local ok, CP = pcall(require, "commit_picker.init")
      if ok then
        CP.open()
      end
    end,
    desc = "Commit Picker",
    icon = "📝",
  },

  {
    "<leader>kf",
    mode = "n",
    fn = function()
      local ok_nav, Nav = pcall(require, "commit_picker.navigation")
      if not ok_nav or not Nav.is_loaded() then
        local ok_cp, CP = pcall(require, "commit_picker.init")
        if ok_cp then
          local ok_git, Git = pcall(require, "commit_picker.git")
          if ok_git then
            local ok_diff, Diff = pcall(require, "commit_picker.diff")
            if ok_diff then
              local commits = Git.get_commits_for_mode()
              if commits and #commits > 0 then
                Diff.open_diff({ commits[1].sha })
                if ok_nav and Nav.load_commits then
                  Nav.load_commits()
                end
                vim.notify(string.format("1/%d: %s", #commits, commits[1].subject), vim.log.levels.INFO)
              else
                vim.notify("没有可导航的提交", vim.log.levels.INFO)
              end
            end
          end
        end
      else
        Nav.cycle_next()
      end
    end,
    desc = "Next Commit",
    icon = "⬇️",
  },

  {
    "<leader>kb",
    mode = "n",
    fn = function()
      local ok, Nav = pcall(require, "commit_picker.navigation")
      if not ok or not Nav.is_loaded() then
        vim.notify("请先打开 Commit Picker 加载提交列表", vim.log.levels.INFO)
        return
      end
      Nav.cycle_prev()
    end,
    desc = "Prev Commit",
    icon = "⬆️",
  },

  {
    "<leader>kd",
    mode = "n",
    fn = function()
      -- 使用 DiffviewOpenEnhanced（支持 worktree 和自定义 git 路径）
      local ok_dv = pcall(require, "diffview")
      if ok_dv then
        local ok_cmd, err = pcall(vim.cmd, "DiffviewOpenEnhanced")
        if not ok_cmd then
          vim.notify("Diffview 打开失败: " .. tostring(err), vim.log.levels.ERROR)
        end
        return
      end

      -- fallback: 使用 vim-fugitive
      local ok_fug = pcall(vim.cmd, "Git diff")
      if not ok_fug then
        vim.notify("Git diff 不可用，请安装 diffview.nvim 或 vim-fugitive", vim.log.levels.WARN)
      end
    end,
    desc = "Diff Viewer",
    icon = "📊",
  },

  -- === 配置与同步 ===
  {
    "<leader>kK",
    mode = "n",
    fn = function()
      local ok, Keys = pcall(require, "ai.keys")
      if ok then
        Keys.edit()
      end
    end,
    desc = "Edit API Keys",
    icon = "🔑",
  },

  {
    "<leader>kS",
    mode = "n",
    fn = function()
      local ok, Sync = pcall(require, "ai.sync")
      if ok then
        Sync.select_and_sync()
      end
    end,
    desc = "Sync Configs",
    icon = "🔄",
  },

  -- === Components 管理 ===
  {
    "<leader>kc",
    mode = "n",
    fn = function()
      local ok, Picker = pcall(require, "ai.components.picker")
      if ok then
        Picker.open()
      end
    end,
    desc = "Component Manager",
    icon = "📦",
  },
}

----------------------------------------------------------------------
-- 用户命令注册（移除 Avante 特定的）
----------------------------------------------------------------------
local commands = {
  {
    "AIKeys",
    function()
      local ok, Keys = pcall(require, "ai.keys")
      if ok then
        Keys.edit()
      end
    end,
    desc = "Edit API Keys",
  },

  {
    "AISync",
    function()
      local ok, Sync = pcall(require, "ai.sync")
      if ok then
        Sync.select_and_sync()
      end
    end,
    desc = "Sync AI Configs",
  },

  {
    "AIComponents",
    function()
      local ok, Picker = pcall(require, "ai.components.picker")
      if ok then
        Picker.open()
      end
    end,
    desc = "Open Component Manager",
  },

  -- ECC 命令（向后兼容）
  {
    "ECCInstall",
    function()
      require("ai.ecc").open_installer()
    end,
    desc = "Install ECC Framework",
  },

  {
    "ECCStatus",
    function()
      require("ai.ecc").show_status()
    end,
    desc = "Show ECC Status",
  },

  -- OpenCode 命令
  {
    "OpenCodeWriteConfig",
    function()
      local ok, OpenCode = pcall(require, "ai.opencode")
      if ok then
        OpenCode.write_config()
      end
    end,
    desc = "Generate OpenCode Config",
  },

  {
    "OpenCodeEditTemplate",
    function()
      local ok, OpenCode = pcall(require, "ai.opencode")
      if ok then
        OpenCode.edit_template()
      end
    end,
    desc = "Edit OpenCode Template",
  },

  {
    "OpenCodePreviewConfig",
    function()
      local ok, OpenCode = pcall(require, "ai.opencode")
      if ok then
        OpenCode.preview_config()
      end
    end,
    desc = "Preview OpenCode Config",
  },

  -- Claude Code 命令
  {
    "ClaudeCodeGenerateConfig",
    function()
      local ok, ClaudeCode = pcall(require, "ai.claude_code")
      if ok then
        ClaudeCode.write_settings()
      end
    end,
    desc = "Generate Claude Code Settings",
  },

  {
    "ClaudeCodeEditSettings",
    function()
      local ok, ClaudeCode = pcall(require, "ai.claude_code")
      if ok then
        ClaudeCode.edit_settings()
      end
    end,
    desc = "Edit Claude Code Settings",
  },

  {
    "ClaudeCodeEditTemplate",
    function()
      local ok, ClaudeCode = pcall(require, "ai.claude_code")
      if ok then
        ClaudeCode.edit_template()
      end
    end,
    desc = "Edit Claude Code Template",
  },

  {
    "ClaudeCodePreviewSettings",
    function()
      local ok, ClaudeCode = pcall(require, "ai.claude_code")
      if ok then
        ClaudeCode.preview_settings()
      end
    end,
    desc = "Preview Claude Code Settings",
  },
}

----------------------------------------------------------------------
-- 设置快捷键
----------------------------------------------------------------------
function M.setup_keys()
  for _, key in ipairs(keys) do
    if key.group then
      -- which-key group，由 which-key 自动处理
    elseif key.fn then
      local modes = type(key.mode) == "table" and key.mode or { key.mode }
      for _, mode in ipairs(modes) do
        vim.keymap.set(mode, key[1], key.fn, { desc = key.desc })
      end
    end
  end
end

----------------------------------------------------------------------
-- 设置用户命令
----------------------------------------------------------------------
function M.setup_commands()
  for _, cmd in ipairs(commands) do
    local opts = { desc = cmd.desc }
    if cmd.range then
      opts.range = true
    end
    vim.api.nvim_create_user_command(cmd[1], cmd[2], opts)
  end
end

----------------------------------------------------------------------
-- 配置函数
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)

  -- Initialize Component System (ECC, GSD, etc.)
  local ok_comp, Components = pcall(require, "ai.components")
  if ok_comp then
    Components.setup()
  else
    vim.notify("Failed to initialize component system", vim.log.levels.WARN)
  end

  -- 初始化 Skill Studio
  local ok, SkillStudio = pcall(require, "ai.skill_studio")
  if ok then
    SkillStudio.setup()
  end

  -- Load Provider Manager subsystem
  local ok_pm, ProviderManager = pcall(require, "ai.provider_manager")
  if ok_pm then
    ProviderManager.setup()
  end

  -- Initialize Commit Picker (Phase 4)
  local ok_cp, CommitPicker = pcall(require, "commit_picker.init")
  if ok_cp then
    CommitPicker.setup()
  end

  -- 注册快捷键和命令
  if config.auto_setup_keys then
    M.setup_keys()
  end
  if config.auto_setup_commands then
    M.setup_commands()
  end

  vim.notify("AI Module initialized (OpenCode + Claude Code)", vim.log.levels.INFO)

  return M
end

return M
