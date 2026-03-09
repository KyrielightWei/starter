-- lua/plugins/opencode.lua
-- OpenCode 插件配置：注册命令

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

return {
  "akinsho/toggleterm.nvim",
  optional = true,
  keys = {
    { "<leader>to", "<cmd>OpenCodeTerminal<CR>", desc = "OpenCode AI Terminal" },
  },
}