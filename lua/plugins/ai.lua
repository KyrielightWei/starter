-- lua/plugins/ai.lua
-- AI 插件配置：通过 lazy.nvim 加载本地插件
--
-- 插件代码在 local-plugins/ai/ 目录下，包含：
--   - AI 工具配置管理 (OpenCode, Claude Code, Pi)
--   - Provider/Key 管理
--   - Commit Picker
--   - Terminal 集成模块 (被 plugins/terminal.lua 调用)

return {
  {
    dir = vim.fn.stdpath("config") .. "/local-plugins/ai",
    name = "ai-tools",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
}
