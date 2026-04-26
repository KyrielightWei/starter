-- lua/ai/init.lua
-- AI 模块入口 - 重构版
-- 使用方法：
--   require("ai").setup()  -- 初始化（自动加载默认后端）
--   require("ai").setup({ default_backend = "copilot" })  -- 指定后端
--
-- 更换 AI 插件只需：
--   1. 修改 default_backend 配置
--   2. 创建对应的 xxx_adapter.lua 文件
--   3. 所有快捷键和命令会自动适配
--
-- 模块结构：
--   - init.lua        : 主入口，包含所有配置和快捷键（修改此文件即可切换后端）
--   - providers.lua   : Provider 注册中心
--   - keys.lua        : API Key 管理
--   - fetch_models.lua: 动态模型拉取
--   - model_switch.lua: FZF 模型选择器
--   - util.lua        : 工具函数
--   - avante_adapter.lua: Avante.nvim 后端实现（示例）

local M = {}

-- 后端注册表
local backend = nil
local config = {
  -- 默认配置
  default_backend = "avante",
  -- 快捷键前缀
  key_prefix = "<leader>k",
  -- 是否自动注册快捷键
  auto_setup_keys = true,
  -- 是否自动注册用户命令
  auto_setup_commands = true,
}

----------------------------------------------------------------------
-- 注册后端
-- @param name string: 后端名称（如 "avante", "copilot", "codeium"）
-- @param adapter table: 适配器模块
----------------------------------------------------------------------
function M.register_backend(name, adapter)
  -- 如果适配器有 setup 方法，调用它获取实现
  local impl = adapter
  if adapter.setup then
    local result = adapter.setup()
    if result then
      impl = result
    end
  end

  backend = {
    name = name,
    impl = impl,
  }

  -- 自动设置快捷键和命令
  if config.auto_setup_keys then
    M.setup_keys()
  end
  if config.auto_setup_commands then
    M.setup_commands()
  end

  vim.notify(string.format("AI backend '%s' registered", name), vim.log.levels.INFO)
end

----------------------------------------------------------------------
-- 获取当前后端
----------------------------------------------------------------------
function M.get_backend()
  return backend
end

----------------------------------------------------------------------
-- 命令包装器（安全调用）
----------------------------------------------------------------------
local function call(fn_name)
  return function()
    if not backend or not backend.impl then
      vim.notify("AI backend not registered", vim.log.levels.WARN)
      return
    end
    local fn = backend.impl[fn_name]
    if not fn then
      vim.notify(string.format("AI backend does not implement: %s", fn_name), vim.log.levels.WARN)
      return
    end
    fn()
  end
end

----------------------------------------------------------------------
-- 快捷键配置
-- 前缀：<leader>k（AI 相关功能）
----------------------------------------------------------------------
local keys = {
  -- AI 核心功能（<leader>k 前缀）
  { "<leader>k", group = "AI Interactive", icon = "🤖" },

  -- 核心交互
  { "<leader>kc", mode = "n", fn = call("chat"), desc = "AI Chat", icon = "💬" },
  { "<leader>kn", mode = "n", fn = call("chat_new"), desc = "AI New Chat", icon = "✨" },
  { "<leader>ke", mode = "v", fn = call("edit"), desc = "AI Edit Selection", icon = "✏️" },
  { "<leader>kq", mode = "n", fn = call("ask"), desc = "AI Quick Ask", icon = "❓" },

  -- 模型与配置
  { "<leader>ks", mode = "n", fn = call("model_switch"), desc = "AI Model Switch", icon = "🔄" },
  { "<leader>kk", mode = "n", fn = call("key_manager"), desc = "AI Key Manager", icon = "🔑" },
  { "<leader>kS", mode = "n", fn = call("sessions"), desc = "AI Chat Sessions", icon = "📁" },

  -- 面板控制
  { "<leader>kt", mode = "n", fn = call("toggle"), desc = "AI Toggle Panel", icon = "📋" },

  -- Diff 查看
  { "<leader>kd", mode = "n", fn = call("diff"), desc = "AI Diff Viewer", icon = "📊" },

  -- Suggestion 相关（插入模式）
  { "<M-]>", mode = "i", fn = call("suggestion_next"), desc = "Next AI Suggestion", icon = "⬇️" },
  { "<M-[>", mode = "i", fn = call("suggestion_prev"), desc = "Prev AI Suggestion", icon = "⬆️" },
  { "<M-\\>", mode = "i", fn = call("suggestion_accept"), desc = "Accept AI Suggestion", icon = "✅" },
}

----------------------------------------------------------------------
-- 用户命令注册
----------------------------------------------------------------------
local commands = {
  { "AIChat", call("chat"), desc = "Open AI Chat" },
  { "AIChatNew", call("chat_new"), desc = "Start New AI Chat" },
  { "AIEdit", call("edit"), desc = "AI Edit Selection", range = true },
  { "AIAsk", call("ask"), desc = "AI Quick Ask" },
  { "AIToggle", call("toggle"), desc = "Toggle AI Panel" },
  { "AIDiff", call("diff"), desc = "View AI Changes Diff" },
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

  -- 自动加载默认后端
  if config.default_backend and not backend then
    local ok, adapter = pcall(require, "ai." .. config.default_backend .. "_adapter")
    if ok then
      M.register_backend(config.default_backend, adapter)
    else
      vim.notify(string.format("Failed to load default backend: %s", config.default_backend), vim.log.levels.WARN)
    end
  end

  -- 初始化 Skill Studio
  local ok, SkillStudio = pcall(require, "ai.skill_studio")
  if ok then
    SkillStudio.setup()
  end

  -- 初始化组件管理器
  local ok2, Components = pcall(require, "ai.components")
  if ok2 then
    Components.setup({
      auto_discover = true,
      keymap = true,
      keymap_opts = { keymap = "<leader>kc" },
    })
  end

  return M
end

----------------------------------------------------------------------
-- 向后兼容性
----------------------------------------------------------------------
-- 保持旧的调用方式
setmetatable(M, {
  __index = function(_, key)
    if backend and backend.impl then
      return backend.impl[key]
    end
    -- 如果后端未加载，尝试加载默认后端
    if not backend and config.default_backend then
      local ok, adapter = pcall(require, "ai." .. config.default_backend .. "_adapter")
      if ok then
        M.register_backend(config.default_backend, adapter)
        if backend and backend.impl then
          return backend.impl[key]
        end
      end
    end
    return nil
  end,
})

return M
