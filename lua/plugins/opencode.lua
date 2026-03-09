-- lua/plugins/opencode.lua
-- OpenCode & Claude Code 插件配置：注册命令和快捷键

-- OpenCode 命令
vim.api.nvim_create_user_command("OpenCodeGenerateConfig", function()
  require("ai.opencode").write_config()
end, { desc = "Generate OpenCode config from template and AI module" })

vim.api.nvim_create_user_command("OpenCodeEditTemplate", function()
  require("ai.opencode").edit_template()
end, { desc = "Edit OpenCode template config" })

vim.api.nvim_create_user_command("OpenCodeValidateTemplate", function()
  require("ai.opencode").validate_template()
end, { desc = "Validate OpenCode template config" })

vim.api.nvim_create_user_command("OpenCodePreviewConfig", function()
  require("ai.opencode").preview_config()
end, { desc = "Preview merged OpenCode config" })

vim.api.nvim_create_user_command("OpenCodeTerminal", function()
  require("ai.opencode").toggle_terminal()
end, { desc = "Toggle OpenCode Terminal" })

vim.api.nvim_create_user_command("OpenCodeWithContext", function()
  require("ai.opencode").open_with_context()
end, { desc = "Open OpenCode with current context" })

vim.api.nvim_create_user_command("OpenCodeStatus", function()
  local status = require("ai.opencode").get_status()
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
end, { desc = "Show OpenCode status" })

-- Claude Code 命令
vim.api.nvim_create_user_command("ClaudeCodeGenerateConfig", function()
  require("ai.claude_code").write_settings()
end, { desc = "Generate Claude Code settings" })

vim.api.nvim_create_user_command("ClaudeCodeEditConfig", function()
  require("ai.claude_code").edit_settings()
end, { desc = "Edit Claude Code settings" })

vim.api.nvim_create_user_command("ClaudeCodePreviewConfig", function()
  require("ai.claude_code").preview_settings()
end, { desc = "Preview Claude Code settings" })

vim.api.nvim_create_user_command("ClaudeCodeTerminal", function()
  require("ai.claude_code").toggle_terminal()
end, { desc = "Toggle Claude Code Terminal" })

vim.api.nvim_create_user_command("ClaudeCodeWithContext", function()
  require("ai.claude_code").open_with_context()
end, { desc = "Open Claude Code with current context" })

vim.api.nvim_create_user_command("ClaudeCodeStatus", function()
  local status = require("ai.claude_code").get_status()
  local lines = {
    "Claude Code Status:",
    "  Installed: " .. tostring(status.installed),
    "  Config: " .. tostring(status.config_exists),
    "  Message: " .. status.message,
    "",
    "Config Path: " .. status.config_path,
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "Show Claude Code status" })

-- 同步命令
vim.api.nvim_create_user_command("AISyncAll", function()
  require("ai.sync").sync_all()
end, { desc = "Sync all AI tool configs" })

vim.api.nvim_create_user_command("AISyncSelect", function()
  require("ai.sync").select_and_sync()
end, { desc = "Select and sync AI tool config" })

vim.api.nvim_create_user_command("AIExportKeys", function()
  require("ai.sync").export_to_env_file()
end, { desc = "Export API keys to env file" })

-- 上下文命令
vim.api.nvim_create_user_command("AICopyContext", function()
  local Context = require("ai.context")
  Context.copy_to_clipboard({
    file = true,
    project = true,
    diagnostics = true,
  })
end, { desc = "Copy current context to clipboard" })

vim.api.nvim_create_user_command("AIShowContext", function()
  local Context = require("ai.context")
  local context = Context.get_context()
  local formatted = Context.format_context_for_prompt(context)

  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(formatted, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_name(buf, "AI Context")
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
end, { desc = "Show current context" })

-- Prompt 文件管理命令
vim.api.nvim_create_user_command("AIEditPrompts", function()
  require("ai.system_prompt").edit_prompts()
end, { desc = "Open prompts directory for editing" })

vim.api.nvim_create_user_command("AIListPrompts", function()
  require("ai.system_prompt").show_status()
end, { desc = "List all available prompt files" })

-- 终端选择器命令
vim.api.nvim_create_user_command("AITerminalSelect", function()
  require("ai.terminal").select_and_open()
end, { desc = "Select and open AI terminal" })

vim.api.nvim_create_user_command("AITerminalCloseAll", function()
  require("ai.terminal").close_all()
end, { desc = "Close all AI terminals" })

-- 配置热更新命令
vim.api.nvim_create_user_command("AIConfigWatch", function()
  require("ai.config_watcher").watch()
  vim.notify("AI config watcher enabled", vim.log.levels.INFO)
end, { desc = "Enable AI config watcher" })

vim.api.nvim_create_user_command("AIConfigForceSync", function()
  require("ai.config_watcher").force_sync()
end, { desc = "Force sync AI configs" })

-- 快捷键配置
return {
  "akinsho/toggleterm.nvim",
  optional = true,
  keys = {
    { "<leader>to", "<cmd>OpenCodeTerminal<CR>", desc = "OpenCode AI Terminal" },
    { "<leader>tO", "<cmd>OpenCodeWithContext<CR>", desc = "OpenCode with Context" },
    { "<leader>tc", "<cmd>ClaudeCodeTerminal<CR>", desc = "Claude Code Terminal" },
    { "<leader>tC", "<cmd>ClaudeCodeWithContext<CR>", desc = "Claude Code with Context" },
    { "<leader>ts", "<cmd>AITerminalSelect<CR>", desc = "Select AI Terminal" },
    { "<leader>kC", "<cmd>AICopyContext<CR>", desc = "Copy AI Context" },
    { "<leader>kY", "<cmd>AISyncAll<CR>", desc = "Sync All AI Configs" },
  },
config = function()
    vim.schedule(function()
      local ok, Watcher = pcall(require, "ai.config_watcher")
      if ok and not Watcher.enabled then
        Watcher.watch()
      end
    end)
  end,
}