---@diagnostic disable: unicode

-- Neovim AI All‑in‑One Config
-- 默认使用 DeepSeek‑Coder，支持运行时切换模型（avante.nvim + gp.nvim）

---------------------------------------------------------------------
-- Provider 配置
---------------------------------------------------------------------
local providers = {
  openai = {
    secret = os.getenv("OPENAI_API_KEY"),
    base_url = "https://api.openai.com/v1/chat/completions",
  },
  deepseek = {
    secret = os.getenv("DEEPSEEK_API_KEY"),
    base_url = "https://api.deepseek.com/v1/chat/completions",
  },
  dashscope = {
    secret = os.getenv("DASHSCOPE_API_KEY"),
    base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
  },
  moonshot = {
    secret = os.getenv("MOONSHOT_API_KEY"),
    base_url = "https://api.moonshot.cn/v1/chat/completions",
  },
  ollama = {
    base_url = "http://localhost:11434",
  },
}

---------------------------------------------------------------------
-- 模型列表（可切换）
---------------------------------------------------------------------
local M = {}

M.models = {
  { name = "deepseek-coder", provider = "deepseek" },  -- 默认
  { name = "deepseek-chat", provider = "deepseek" },
  { name = "gpt-4.1-mini", provider = "openai" },
  { name = "qwen-max", provider = "dashscope" },
  { name = "moonshot-v1", provider = "moonshot" },
  { name = "qwen2.5:3b", provider = "ollama" },
}

-- 默认模型
M.current = { provider = "deepseek", model = "deepseek-coder" }

local function provider_has_key(provider)
  if provider == "ollama" then
    return true
  end

  local p = providers[provider]
  return p and p.secret ~= nil and p.secret ~= ""
end

local function ensure_valid_current()
  if provider_has_key(M.current.provider) then
    return
  end

  for _, m in ipairs(M.models) do
    if provider_has_key(m.provider) then
      M.current = { provider = m.provider, model = m.name }
      vim.notify(
        "AI provider key missing; switched to " .. m.name .. " (" .. m.provider .. ")",
        vim.log.levels.WARN
      )
      return
    end
  end

  vim.notify("No valid AI provider keys found", vim.log.levels.ERROR)
end

---------------------------------------------------------------------
-- 模型切换器（同步 avante + gp.nvim）
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
        if not provider_has_key(m.provider) then
          vim.notify(
            "Missing API key for " .. m.provider .. "; set it in env first",
            vim.log.levels.WARN
          )
          return
        end

        M.current = { provider = m.provider, model = m.name }

        -- 更新 avante.nvim
        require("avante.config").options.provider = m.provider
        require("avante.config").options.model = m.name

        -- 更新 gp.nvim（官方 API）
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
-- 插件定义（avante.nvim + gp.nvim）
---------------------------------------------------------------------
return {
  -------------------------------------------------------------------
  -- avante.nvim（Cursor 风格 AI 编辑器）
  -------------------------------------------------------------------
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make",
    init = function()
      if vim.fn.sign_getdefined("AvanteInputPromptSign")[1] == nil then
        vim.fn.sign_define("AvanteInputPromptSign", { text = "> " })
      end
    end,
    opts = function()
      ensure_valid_current()
      local provider = M.current.provider
      local model = M.current.model
      return {
        provider = provider,
        model = model,
        auto_apply_diff = true,
        use_floating_window = true,
        providers = {
          openai = {
            endpoint = "https://api.openai.com/v1",
            api_key_name = "OPENAI_API_KEY",
            model = provider == "openai" and model or nil,
          },
          deepseek = {
            __inherited_from = "openai",
            endpoint = "https://api.deepseek.com/v1",
            api_key_name = "DEEPSEEK_API_KEY",
            model = provider == "deepseek" and model or nil,
          },
          dashscope = {
            __inherited_from = "openai",
            endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1",
            api_key_name = "DASHSCOPE_API_KEY",
            model = provider == "dashscope" and model or nil,
          },
          moonshot = {
            __inherited_from = "openai",
            endpoint = "https://api.moonshot.cn/v1",
            api_key_name = "MOONSHOT_API_KEY",
            model = provider == "moonshot" and model or nil,
          },
          ollama = {
            endpoint = "http://localhost:11434/api/chat",
            model = provider == "ollama" and model or nil,
          },
        },
      }
    end,
    config = function(_, opts)
      require("avante").setup(opts)
      vim.api.nvim_create_user_command("AIModelSwitch", function()
        M.switch_model()
      end, {})
      vim.keymap.set("n", "<leader>as", "<cmd>AIModelSwitch<cr>", { desc = "Switch AI Model" })
    end,
    keys = {
      { "<leader>ae", "<cmd><C-u>AvanteEdit<cr>", desc = "AI Edit" },
      { "<leader>ar", "<cmd><C-u>AvanteRewrite<cr>", desc = "AI Rewrite" },
      { "<leader>ao", "<cmd><C-u>AvanteOptimize<cr>", desc = "AI Optimize" },
      { "<leader>ax", "<cmd><C-u>AvanteExplain<cr>", desc = "AI Explain" },
      { "<leader>af", "<cmd><C-u>AvanteFix<cr>", desc = "AI Fix" },
    },
  },

  -------------------------------------------------------------------
  -- gp.nvim（ChatGPT 风格 AI 工具箱）
  -------------------------------------------------------------------
  {
    "robitx/gp.nvim",
    event = "VeryLazy",
    opts = function()
      ensure_valid_current()
      local cur = M.current
      local agent_name = "CurrentProvider"
      local providers_cfg = {
        openai = {
          disable = cur.provider ~= "openai",
          secret = providers.openai.secret,
          endpoint = providers.openai.base_url,
        },
      }

      providers_cfg[cur.provider] = {
        secret = providers[cur.provider].secret,
        endpoint = providers[cur.provider].base_url,
        model = cur.model,
      }

      return {
        vault = false,                       -- 禁用 vault，避免 openai_api_key 报错
        openai_api_key = providers.openai.secret or "", -- 覆盖默认 vault 读取
        default_chat_agent = agent_name,
        default_command_agent = agent_name,
        default_provider = cur.provider,     -- 动态 provider
        providers_order = { cur.provider },  -- 只加载当前 provider
        providers = providers_cfg,
        agents = {
          {
            name = agent_name,
            provider = cur.provider,
            chat = true,
            command = true,
            model = { model = cur.model },
            system_prompt = require("gp.defaults").chat_system_prompt,
          },
        },
        chat_confirm_delete = false,
        chat_shortcut = "<leader>ac",
      }
    end,
    keys = {
      { "<leader>ac", "<cmd>GpChatNew<cr>", desc = "AI Chat" },
      { "<leader>ag", "<cmd>GpChatToggle<cr>", desc = "Toggle Chat" },
      { "<leader>ad", "<cmd>GpExplain<cr>", desc = "Explain Code" },
      { "<leader>ai", "<cmd>GpImplement<cr>", desc = "Implement Code" },
      { "<leader>au", "<cmd>GpUnitTests<cr>", desc = "Generate Unit Tests" },
      { "<leader>am", "<cmd>GpCommit<cr>", desc = "Generate Commit Message" },
    },
  },

}

