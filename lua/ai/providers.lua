-- lua/ai/providers.lua
-- Provider Registry（你未来只需要修改这个文件）

local M = {}

----------------------------------------------------------------------
-- 全局默认值（所有工具统一使用）
----------------------------------------------------------------------
M.default_provider = "bailian_coding"
M.default_model = "qwen3.6-plus"

-- 注册 provider
function M.register(name, conf)
  M[name] = {
    inherited = conf.inherited or "openai",
    api_key_name = conf.api_key_name, -- 用于自动生成 env_var_map
    endpoint = conf.endpoint,
    model = conf.model,
    timeout = conf.timeout or 30000,
    static_models = conf.static_models or {}, -- ModelSwitch fallback
  }
end

-- 返回 provider 列表
function M.list()
  local out = {}
  for name, def in pairs(M) do
    if type(def) == "table" and def.endpoint then
      table.insert(out, name)
    end
  end
  return out
end

-- 获取 provider 配置
function M.get(name)
  return M[name]
end

----------------------------------------------------------------------
-- 你所有 provider 在这里注册（未来新增 provider 只改这里）
----------------------------------------------------------------------

M.register("deepseek", {
  api_key_name = "DEEPSEEK_API_KEY",
  endpoint = "https://api.deepseek.com",
  model = "deepseek-chat",
  static_models = { "deepseek-chat", "deepseek-reasoner" },
})

M.register("openai", {
  api_key_name = "OPENAI_API_KEY",
  endpoint = "https://api.openai.com",
  model = "gpt-4o-mini",
  static_models = { "gpt-4o-mini", "gpt-4o" },
})

M.register("qwen", {
  api_key_name = "QWEN_API_KEY",
  endpoint = "https://{QWEN_BASE_ENDPOINT}",
  model = "qwen-2.5-chat",
  static_models = { "qwen-2.5-chat", "qwen-code" },
})

M.register("minimax", {
  api_key_name = "MINIMAX_API_KEY",
  endpoint = "https://{MINIMAX_BASE_ENDPOINT}",
  model = "minimax-latest",
  static_models = { "minimax-latest" },
})

M.register("kimi", {
  api_key_name = "KIMI_API_KEY",
  endpoint = "https://{KIMI_BASE_ENDPOINT}",
  model = "kimi-k2-0711-preview",
  static_models = { "kimi-k2-0711-preview" },
})

M.register("glm", {
  api_key_name = "GLM_API_KEY",
  endpoint = "https://{GLM_BASE_ENDPOINT}",
  model = "GLM-4.7",
  static_models = { "GLM-4.7" },
})

M.register("bailian", {
  api_key_name = "BAILIAN_API_KEY",
  endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1",
  model = "bailian-chat-v1",
  static_models = { "bailian-chat-v1", "bailian-code-v1", "bailian-embed-v1" },
})

M.register("bailian_coding", {
  api_key_name = "BAILIAN_CODING_API_KEY",
  endpoint = "https://coding.dashscope.aliyuncs.com/v1",
  model = "qwen3.6-plus",
static_models = { "glm-5", "qwen3.5-plus", "qwen3.6-plus", "kimi-k2.5", "MiniMax-M2.5", "test", "test2", "test3" },
})

M.register("dashscope", {
  api_key_name = "DASHSCOPE_API_KEY",
  endpoint = "https://api.dashscope.com",
  model = "qwen2.5-coder",
  static_models = { "qwen2.5-coder" },
})

M.register("moonshot", {
  api_key_name = "MOONSHOT_API_KEY",
  endpoint = "https://api.moonshot.ai",
  model = "moonshot-v1",
  static_models = { "moonshot-v1" },
})

M.register("ollama", {
  api_key_name = "OLLAMA_API_KEY",
  endpoint = "http://localhost:11434",
  model = "qwen2.5-coder:latest",
  static_models = { "qwen2.5-coder:latest" },
})

return M
