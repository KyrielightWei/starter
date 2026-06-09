-- plugin/ai.lua
-- AI 插件入口 — 所有命令和键映射的唯一注册点
--
-- 由 lazy.nvim 自动加载（local-plugins/ai/ 在 runtimepath 上）

----------------------------------------------------------------------
-- Helper: 安全注册命令（避免重复注册报错）
----------------------------------------------------------------------
local function cmd(name, fn, opts)
  if vim.fn.exists(":" .. name) == 0 then
    vim.api.nvim_create_user_command(name, fn, opts)
  end
end

----------------------------------------------------------------------
-- Helper: 安全调用模块（带错误通知）
----------------------------------------------------------------------
local function safe_require(mod, fn, ...)
  local ok, M = pcall(require, mod)
  if not ok then
    vim.notify("AI: " .. mod .. " 加载失败: " .. tostring(M), vim.log.levels.DEBUG)
    return
  end
  if not M[fn] then
    vim.notify("AI: " .. mod .. "." .. fn .. " 不存在", vim.log.levels.DEBUG)
    return
  end
  return M[fn](...)
end

----------------------------------------------------------------------
-- 高频命令
----------------------------------------------------------------------

cmd("AISync", function()
  safe_require("ai.sync", "select_and_sync")
end, { desc = "Select and sync AI tool config" })

cmd("AIKeys", function()
  safe_require("ai.keys", "edit")
end, { desc = "Edit API keys and base URLs" })

cmd("AIProvider", function()
  safe_require("ai.provider_manager", "open")
end, { desc = "Open AI Provider Manager" })

cmd("AIModel", function()
  safe_require("ai.model_switch", "select")
end, { desc = "Switch AI model (with scope selection)" })

----------------------------------------------------------------------
-- OpenCode 命令
----------------------------------------------------------------------

cmd("OpenCodeGenerate", function()
  safe_require("ai.opencode", "write_config")
end, { desc = "Generate OpenCode config" })

cmd("OpenCodePreview", function()
  safe_require("ai.opencode", "preview_config")
end, { desc = "Preview merged OpenCode config" })

cmd("OpenCodeEdit", function()
  safe_require("ai.opencode", "edit_template")
end, { desc = "Edit OpenCode template" })

cmd("OpenCodeStatus", function()
  local status = safe_require("ai.opencode", "get_status")
  if status then
    local lines = {
      "OpenCode Status:",
      "  Installed: " .. tostring(status.installed),
      "  Config: " .. tostring(status.config_exists),
      "  Template: " .. tostring(status.template_exists),
      "",
      "Paths:",
      "  Config: " .. status.config_path,
      "  Template: " .. status.template_path,
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end
end, { desc = "Show OpenCode status" })

cmd("OpenCodeTheme", function(opts)
  local sub = opts.fargs[1] or "generate"
  if sub == "generate" then
    safe_require("ai.opencode_tui", "generate_tui_config")
  elseif sub == "preview" then
    safe_require("ai.opencode_tui", "preview_tui_config")
  elseif sub == "edit" then
    safe_require("ai.opencode_tui", "edit_theme")
  else
    vim.notify("Usage: OpenCodeTheme [generate|preview|edit]", vim.log.levels.ERROR)
  end
end, {
  desc = "OpenCode TUI theme (generate|preview|edit)",
  nargs = "?",
  complete = function()
    return { "generate", "preview", "edit" }
  end,
})

----------------------------------------------------------------------
-- Claude Code 命令
----------------------------------------------------------------------

cmd("ClaudeCodeGenerate", function()
  safe_require("ai.claude_code", "write_settings")
end, { desc = "Generate Claude Code settings" })

cmd("ClaudeCodePreview", function()
  safe_require("ai.claude_code", "preview_settings")
end, { desc = "Preview Claude Code settings" })

cmd("ClaudeCodeEdit", function()
  safe_require("ai.claude_code", "edit_template")
end, { desc = "Edit Claude Code template" })

cmd("ClaudeCodeStatus", function()
  local status = safe_require("ai.claude_code", "get_status")
  if not status then
    return
  end
  local lines = {
    "Claude Code Status:",
    "  Installed: " .. tostring(status.installed),
    "  Config: " .. tostring(status.config_exists),
    "  Message: " .. status.message,
    "",
    "Config Path: " .. status.config_path,
  }
  if status.ecc then
    table.insert(lines, "")
    table.insert(lines, "ECC Framework:")
    table.insert(lines, "  Version: " .. (status.ecc.repo_version or "unknown"))
    table.insert(lines, "  Modules: " .. table.concat(status.ecc.modules, ", "))
  end
  if #status.missing_deps > 0 then
    table.insert(lines, "")
    table.insert(lines, "Missing Dependencies:")
    for _, dep in ipairs(status.missing_deps) do
      table.insert(lines, "  - " .. dep.name .. ": " .. dep.install_hint)
    end
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "Show Claude Code status (includes dependency check)" })

----------------------------------------------------------------------
-- Pi 命令
----------------------------------------------------------------------

cmd("PiGenerate", function()
  safe_require("ai.pi", "write_config")
end, { desc = "Generate Pi config" })

cmd("PiPreview", function()
  safe_require("ai.pi", "preview_config")
end, { desc = "Preview Pi config" })

cmd("PiEdit", function()
  safe_require("ai.pi", "edit_template")
end, { desc = "Edit Pi settings template" })

cmd("PiStatus", function()
  safe_require("ai.pi", "show_status")
end, { desc = "Show Pi status" })

----------------------------------------------------------------------
-- AI 子命令 (低频操作)
----------------------------------------------------------------------

cmd("AI", function(opts)
  local args = opts.fargs
  local sub = args[1]

  if sub == "template" then
    local action = args[2]
    local tool = args[3] or "opencode"
    -- tool 白名单验证
    local valid_tools = { opencode = true, claude_code = true, pi = true }
    if not valid_tools[tool] then
      vim.notify("Invalid tool: " .. tool .. ". Valid tools: opencode, claude_code, pi", vim.log.levels.ERROR)
      return
    end

    if action == "list" then
      local versions = safe_require("ai.template_version", "list", tool)
      if versions and #versions > 0 then
        local ok_s, State = pcall(require, "ai.state")
        if not ok_s then
          vim.notify("AI: state 模块加载失败", vim.log.levels.WARN)
          return
        end
        local current = State.get_template_version(tool)
        local lines = {}
        for _, v in ipairs(versions) do
          local prefix = v == current and "* " or "  "
          table.insert(lines, prefix .. v)
        end
        vim.notify("Templates for " .. tool .. ":\n" .. table.concat(lines, "\n"), vim.log.levels.INFO)
      else
        vim.notify("No templates found for " .. tool, vim.log.levels.INFO)
      end
    elseif action == "select" then
      safe_require("ai.template_picker", "open", tool)
    elseif action == "create" then
      local name = args[4]
      local source = args[5]
      if not name then
        vim.notify("Usage: AI template create <tool> <name> [source]", vim.log.levels.ERROR)
        return
      end
      local ok, result = safe_require("ai.template_version", "create", tool, name, source)
      vim.notify(ok and ("Created: " .. result) or result, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
    elseif action == "delete" then
      local name = args[4]
      if not name then
        vim.notify("Usage: AI template delete <tool> <name>", vim.log.levels.ERROR)
        return
      end
      local ok, result = safe_require("ai.template_version", "delete", tool, name)
      vim.notify(result, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
    elseif action == "rename" then
      local old_name = args[4]
      local new_name = args[5]
      if not old_name or not new_name then
        vim.notify("Usage: AI template rename <tool> <old> <new>", vim.log.levels.ERROR)
        return
      end
      local ok, result = safe_require("ai.template_version", "rename", tool, old_name, new_name)
      vim.notify(result, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
    elseif action == "edit" then
      local ok_s, State = pcall(require, "ai.state")
      local ok_tv, TemplateVersion = pcall(require, "ai.template_version")
      if not ok_s or not ok_tv then
        vim.notify("AI: 模块加载失败", vim.log.levels.WARN)
        return
      end
      local version = State.get_template_version(tool)
      local path = TemplateVersion.get_template_path(tool, version)
      if vim.fn.filereadable(path) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(path))
      else
        vim.notify("Template not found: " .. path, vim.log.levels.ERROR)
      end
    else
      vim.notify("Usage: AI template [list|select|create|delete|rename|edit] [tool]", vim.log.levels.ERROR)
    end
  elseif sub == "context" then
    local action = args[2]
    if action == "copy" then
      local ok, Context = pcall(require, "ai.context")
      if ok then
        Context.copy_to_clipboard({ file = true, project = true, diagnostics = true })
      else
        vim.notify("AI: context 模块加载失败", vim.log.levels.WARN)
      end
    elseif action == "show" then
      local ok, Context = pcall(require, "ai.context")
      if not ok then
        vim.notify("AI: context 模块加载失败", vim.log.levels.WARN)
        return
      end
      local context = Context.get_context()
      local formatted = Context.format_context_for_prompt(context)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(formatted, "\n"))
      vim.api.nvim_set_option_value("filetype", "text", { buf = buf })
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
      vim.api.nvim_buf_set_name(buf, "AI Context")
      vim.api.nvim_win_set_buf(0, buf)
      vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
    else
      vim.notify("Usage: AI context [copy|show]", vim.log.levels.ERROR)
    end
  elseif sub == "prompt" then
    local action = args[2]
    if action == "edit" then
      safe_require("ai.system_prompt", "edit_prompts")
    elseif action == "list" then
      safe_require("ai.system_prompt", "show_status")
    else
      vim.notify("Usage: AI prompt [edit|list]", vim.log.levels.ERROR)
    end
  elseif sub == "watch" then
    if args[2] == "force" then
      safe_require("ai.config_watcher", "force_sync")
    else
      safe_require("ai.config_watcher", "watch")
      vim.notify("AI config watcher enabled", vim.log.levels.INFO)
    end
  elseif sub == "export" then
    safe_require("ai.sync", "export_to_env_file")
  elseif sub == "backup" then
    local tool = args[2]
    local num = tonumber(args[3]) or 1
    -- 范围检查
    if num < 1 or num > 100 then
      vim.notify("Backup number must be between 1 and 100", vim.log.levels.ERROR)
      return
    end
    -- tool 白名单验证
    local valid_tools = { opencode = true, claude = true, claude_code = true }
    if not tool or not valid_tools[tool] then
      vim.notify("Usage: AI backup <opencode|claude> [n]", vim.log.levels.ERROR)
      return
    end
    if tool == "opencode" then
      safe_require("ai.opencode", "restore_backup", num)
    else
      safe_require("ai.claude_code", "restore_backup", num)
    end
  else
    vim.notify(
      "AI subcommands:\n"
        .. "  template [list|select|create|delete|rename|edit] [tool]\n"
        .. "  context [copy|show]\n"
        .. "  prompt [edit|list]\n"
        .. "  watch [force]\n"
        .. "  export\n"
        .. "  backup <opencode|claude> [n]",
      vim.log.levels.INFO
    )
  end
end, {
  desc = "AI tools (template/context/prompt/watch/export/backup)",
  nargs = "*",
  complete = function(arg_lead, cmdline, _)
    local args = vim.split(cmdline, "%s+")
    if #args <= 2 then
      return vim.tbl_filter(function(s)
        return s:find(arg_lead, 1, true) == 1
      end, { "template", "context", "prompt", "watch", "export", "backup" })
    end
    if args[2] == "template" and #args <= 3 then
      return vim.tbl_filter(function(s)
        return s:find(arg_lead, 1, true) == 1
      end, { "list", "select", "create", "delete", "rename", "edit" })
    end
    if args[2] == "context" and #args <= 3 then
      return vim.tbl_filter(function(s)
        return s:find(arg_lead, 1, true) == 1
      end, { "copy", "show" })
    end
    if args[2] == "prompt" and #args <= 3 then
      return vim.tbl_filter(function(s)
        return s:find(arg_lead, 1, true) == 1
      end, { "edit", "list" })
    end
    if args[2] == "backup" and #args <= 3 then
      return vim.tbl_filter(function(s)
        return s:find(arg_lead, 1, true) == 1
      end, { "opencode", "claude" })
    end
    return {}
  end,
})

----------------------------------------------------------------------
-- 快捷键
----------------------------------------------------------------------

-- AI 功能组 (which-key)
vim.api.nvim_set_keymap("n", "<leader>k", "", { desc = "🤖 AI Tools" })

-- 高频操作
vim.keymap.set("n", "<leader>kk", "<cmd>AIModel<CR>", { desc = "Switch Model" })
vim.keymap.set("n", "<leader>ks", "<cmd>AISync<CR>", { desc = "Sync Configs" })
vim.keymap.set("n", "<leader>ke", "<cmd>AIKeys<CR>", { desc = "Edit API Keys" })
vim.keymap.set("n", "<leader>kp", "<cmd>AIProvider<CR>", { desc = "Provider Manager" })

-- Commit Picker (TODO: 后续重新设计快捷键)
vim.keymap.set("n", "<leader>kC", function()
  safe_require("commit_picker.init", "open")
end, { desc = "Commit Picker" })

-- Commit Picker 命令
cmd("AICommitPicker", function()
  safe_require("commit_picker.init", "open")
end, { desc = "Open commit picker" })

cmd("AICommitConfig", function()
  safe_require("commit_picker.settings", "open")
end, { desc = "Open commit picker settings" })

-- Commit Picker 导航辅助函数
local function commit_navigate_next()
  -- 已加载时直接切换
  local ok_nav, Nav = pcall(require, "commit_picker.navigation")
  if ok_nav and Nav.is_loaded() then
    Nav.cycle_next()
    return
  end

  -- 首次加载：获取模块
  local ok_cp, CP = pcall(require, "commit_picker.init")
  if not ok_cp then
    vim.notify("Commit Picker 加载失败", vim.log.levels.WARN)
    return
  end

  local ok_git, Git = pcall(require, "commit_picker.git")
  if not ok_git then
    vim.notify("Git 模块加载失败", vim.log.levels.WARN)
    return
  end

  local ok_diff, Diff = pcall(require, "commit_picker.diff")
  if not ok_diff then
    vim.notify("Diff 模块加载失败", vim.log.levels.WARN)
    return
  end

  -- 获取提交并打开 diff
  local commits = Git.get_commits_for_mode()
  if not commits or #commits == 0 then
    vim.notify("没有可导航的提交", vim.log.levels.INFO)
    return
  end

  Diff.open_diff({ commits[1].sha })
  if ok_nav and Nav.load_commits then
    Nav.load_commits()
  end
  vim.notify(string.format("1/%d: %s", #commits, commits[1].subject), vim.log.levels.INFO)
end

vim.keymap.set("n", "<leader>kf", commit_navigate_next, { desc = "Next Commit" })

vim.keymap.set("n", "<leader>kb", function()
  local ok, Nav = pcall(require, "commit_picker.navigation")
  if not ok or not Nav.is_loaded() then
    vim.notify("请先打开 Commit Picker 加载提交列表", vim.log.levels.INFO)
    return
  end
  Nav.cycle_prev()
end, { desc = "Prev Commit" })

vim.keymap.set("n", "<leader>kd", function()
  local ok_dv = pcall(require, "diffview")
  if ok_dv then
    local ok_cmd, err = pcall(vim.cmd, "DiffviewOpenEnhanced")
    if not ok_cmd then
      vim.notify("Diffview 打开失败: " .. tostring(err), vim.log.levels.ERROR)
    end
    return
  end
  local ok_fug = pcall(vim.cmd, "Git diff")
  if not ok_fug then
    vim.notify("Git diff 不可用，请安装 diffview.nvim 或 vim-fugitive", vim.log.levels.WARN)
  end
end, { desc = "Diff Viewer" })
