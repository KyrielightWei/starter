-- Neovim AI All‑in‑One Config
-- avante.nvim + gp.nvim + 多模型 provider + 运行时模型切换（无需改配置文件）

local M = {}

---------------------------------------------------------------------
-- 1. Provider 配置（字段名与官方 API 文档一致）
---------------------------------------------------------------------
local providers = {
  openai = {
    api_key = os.getenv("OPENAI_API_KEY"),
    base_url = "https://api.openai.com/v1/chat/completions",
  },
  deepseek = {
    api_key = os.getenv("DEEPSEEK_API_KEY"),
    base_url = "https://api.deepseek.com/v1/chat/completions",
  },
  dashscope = {
    api_key = os.getenv("DASHSCOPE_API_KEY"),
    base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
  },
  moonshot = {
    api_key = os.getenv("MOONSHOT_API_KEY"),
    base_url = "https://api.moonshot.cn/v1/chat/completions",
  },
  ollama = {
    base_url = "http://localhost:11434",
  },
}

---------------------------------------------------------------------
-- 2. 可切换模型列表（你可以随时添加）
---------------------------------------------------------------------
M.models = {
  { name = "gpt-4.1-mini", provider = "openai" },
  { name = "deepseek-chat", provider = "deepseek" },
  { name = "qwen-max", provider = "dashscope" },
  { name = "moonshot-v1", provider = "moonshot" },
  { name = "qwen2.5:3b", provider = "ollama" },
}

-- 默认模型
M.current = { provider = "openai", model = "gpt-4.1-mini" }

---------------------------------------------------------------------
-- 3. 运行时模型切换（无需修改配置文件）
---------------------------------------------------------------------
function M.switch_model()
  local items = {}
  for _, m in ipairs(M.models) do
    table.insert(items, string.format("%s (%s)", m.name, m.provider))
  end

  vim.ui.select(items, { prompt = "Select AI Model:" }, function(choice)
    if not choice then return end

    for _, m in ipairs(M.models) do
      if choice:find(m.name, 1, true) then
        M.current = { provider = m.provider, model = m.name }

        -- 更新 avante.nvim
        require("avante.config").options.provider = m.provider
        require("avante.config").options.model = m.name

        -- 更新 gp.nvim（关键修复点）
        local gp = require("gp")
        gp.set_provider(m.provider)
        gp.set_model(m.name)

        vim.notify("AI Model switched to: " .. m.name .. " (" .. m.provider .. ")")
        break
      end
    end
  end)
end

---------------------------------------------------------------------
-- 4. 插件定义（avante.nvim + gp.nvim）
---------------------------------------------------------------------
return {
  -------------------------------------------------------------------
  -- avante.nvim（Cursor 风格 AI 编辑器）
  -------------------------------------------------------------------
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    opts = {
      provider = M.current.provider,
      model = M.current.model,
      auto_apply_diff = true,
      use_floating_window = true,
    },
    keys = {
      { "<leader>ae", "<cmd>AvanteEdit<cr>", desc = "AI Edit" },
      { "<leader>ar", "<cmd>AvanteRewrite<cr>", desc = "AI Rewrite" },
      { "<leader>ao", "<cmd>AvanteOptimize<cr>", desc = "AI Optimize" },
      { "<leader>ax", "<cmd>AvanteExplain<cr>", desc = "AI Explain" },
      { "<leader>af", "<cmd>AvanteFix<cr>", desc = "AI Fix" },
    },
  },

  -------------------------------------------------------------------
  -- gp.nvim（ChatGPT 风格 AI 工具箱）
  -------------------------------------------------------------------
  {
    "robitx/gp.nvim",
    event = "VeryLazy",
    opts = {
      providers = {
        openai = {
          api_key = providers.openai.api_key,
          endpoint = providers.openai.base_url,
          model = "gpt-4.1-mini",
        },
      },
      chat_confirm_delete = false,
      chat_shortcut = "<leader>ac",
    },
    keys = {
      { "<leader>ac", "<cmd>GpChatNew<cr>", desc = "AI Chat" },
      { "<leader>ag", "<cmd>GpChatToggle<cr>", desc = "Toggle Chat" },
      { "<leader>ad", "<cmd>GpExplain<cr>", desc = "Explain Code" },
      { "<leader>ai", "<cmd>GpImplement<cr>", desc = "Implement Code" },
      { "<leader>au", "<cmd>GpUnitTests<cr>", desc = "Generate Unit Tests" },
      { "<leader>am", "<cmd>GpCommit<cr>", desc = "Generate Commit Message" },
    },
  },

  -------------------------------------------------------------------
  -- 5. 注册模型切换命令
  -------------------------------------------------------------------
  {
    "yetone/avante.nvim",
    dependencies = { "robitx/gp.nvim" },
    config = function()
      vim.api.nvim_create_user_command("AIModelSwitch", function()
        M.switch_model()
      end, {})

      vim.keymap.set("n", "<leader>as", "<cmd>AIModelSwitch<cr>", { desc = "Switch AI Model" })
    end,
  },
}
