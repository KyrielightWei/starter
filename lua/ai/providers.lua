-- lua/ai/providers.lua
-- Provider Registry（你未来只需要修改这个文件）

local M = {}

-- Private registry table to separate data from methods
local registry = {}

----------------------------------------------------------------------
-- 全局默认值获取函数（动态从 ai_keys.lua 读取）
-- 不再硬编码，由 Registry.get_global_default() 管理
----------------------------------------------------------------------
function M.get_default_provider()
  local ok, Registry = pcall(require, "ai.provider_manager.registry")
  if ok then
    local provider, _ = Registry.get_global_default()
    return provider
  end
  return "bailian_coding" -- fallback
end

function M.get_default_model()
  local ok, Registry = pcall(require, "ai.provider_manager.registry")
  if ok then
    local _, model = Registry.get_global_default()
    return model
  end
  return "qwen3.6-plus" -- fallback
end

-- 注册 provider
function M.register(name, conf)
  registry[name] = {
    inherited = conf.inherited or "openai",
    api_key_name = conf.api_key_name, -- 用于自动生成 env_var_map
    endpoint = conf.endpoint,
    model = conf.model,
    timeout = conf.timeout or 30000,
    static_models = conf.static_models or {}, -- ModelSwitch fallback
    model_info = conf.model_info or {}, -- Model详细信息(OpenCode配置)
  }
end

-- 返回 provider 列表
function M.list()
  local out = {}
  for name, def in pairs(registry) do
    if type(def) == "table" and def.endpoint then
      table.insert(out, name)
    end
  end
  return out
end

-- 获取 provider 配置
function M.get(name)
  return registry[name]
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
  model = "glm-5",
  static_models = { "glm-5", "qwen3.5-plus", "qwen3.6-plus", "kimi-k2.5", "MiniMax-M2.5" },
  -- 模型详细信息（用于 OpenCode 配置生成）
  -- 数据来源: https://help.aliyun.com/zh/model-studio/getting-started/models
  model_info = {
    ["glm-5"] = {
      limit = { context = 202752, output = 16384 }, -- 200k context
      description = "默认模型 - 智谱GLM-5，复杂推理和代码审查",
    },
    ["qwen3.5-plus"] = {
      limit = { context = 1000000, output = 65536 }, -- 1M context
      description = "快速模型 - 阿里Qwen3.5-Plus，适合简单任务和文档生成",
    },
    ["qwen3.6-plus"] = {
      limit = { context = 1000000, output = 65536 }, -- 1M context
      description = "备选模型 - 阿里Qwen3.6-Plus，效果均衡",
    },
    ["kimi-k2.5"] = {
      limit = { context = 262144, output = 98304 }, -- 256k context
      description = "长文本专家 - Moonshot Kimi，超长上下文处理",
    },
    ["MiniMax-M2.5"] = {
      limit = { context = 196608, output = 32768 }, -- 192k context
      description = "备选方案 - MiniMax模型，多场景支持",
    },
  },
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

M.register("zenmux", {
  api_key_name = "ZENMUX_API_KEY",
  endpoint = "https://work.oceanbase-dev.com/tokensflow/api/v1",
  model = "z-ai/glm-5.1", -- 智谱 GLM-5.1，默认主力模型
  static_models = {
    -- GLM 系列 (Z.AI)
    "z-ai/glm-5.1",

    -- DeepSeek 系列
    "deepseek/deepseek-v4-pro",
    "deepseek/deepseek-v4-flash",

    -- Claude 系列
    "anthropic/claude-opus-4.7",
    "anthropic/claude-opus-4.6",
    "anthropic/claude-sonnet-4.6",
    "anthropic/claude-haiku-4.5",

    -- GPT 系列
    "openai/gpt-5.5",
    "openai/gpt-5.5-pro",
  },
  -- 模型详细信息（数据来源: https://zenmux.ai/models + https://mastra.ai/models/providers/zenmux）
  model_info = {
    -- GLM 系列 (Z.AI)
    ["z-ai/glm-5.1"] = {
      limit = { context = 200000, output = 128000 },
      description = "智谱 GLM-5.1，200K 上下文，输入 $0.88/M，输出 $4/M",
    },
    -- DeepSeek 系列
    ["deepseek/deepseek-v4-pro"] = {
      limit = { context = 1000000, output = 8000 },
      description = "DeepSeek-V4 Pro，1M 上下文，输入 $2/M，输出 $3/M",
    },
    ["deepseek/deepseek-v4-flash"] = {
      limit = { context = 1000000, output = 8000 },
      description = "DeepSeek-V4 Flash，1M 上下文，输入 $0.14/M，输出 $0.28/M，极致性价比",
    },
    -- Claude 系列
    ["anthropic/claude-opus-4.7"] = {
      limit = { context = 1000000, output = 32000 },
      description = "Claude Opus 4.7，Anthropic 最新旗舰推理模型，1M 上下文，输入 $5/M，输出 $25/M",
    },
    ["anthropic/claude-opus-4.6"] = {
      limit = { context = 1000000, output = 32000 },
      description = "Claude Opus 4.6，上一代旗舰模型，1M 上下文，输入 $5/M，输出 $25/M",
    },
    ["anthropic/claude-sonnet-4.6"] = {
      limit = { context = 1000000, output = 64000 },
      description = "Claude Sonnet 4.6，平衡性能与成本，1M 上下文，输入 $3/M，输出 $15/M",
    },
    ["anthropic/claude-haiku-4.5"] = {
      limit = { context = 200000, output = 64000 },
      description = "Claude Haiku 4.5，最快最高效模型，200K 上下文，输入 $1/M，输出 $5/M",
    },
    -- GPT 系列
    ["openai/gpt-5.5"] = {
      limit = { context = 1100000, output = 128000 },
      description = "GPT-5.5，OpenAI 最新前沿模型，1.1M 上下文，输入 $5/M，输出 $30/M",
    },
    ["openai/gpt-5.5-pro"] = {
      limit = { context = 1100000, output = 128000 },
      description = "GPT-5.5 Pro，OpenAI 最先进专业版，1.1M 上下文，输入 $30/M，输出 $180/M",
    },
  },
})

----------------------------------------------------------------------
-- Glink Provider - Claude Opus 4.x 本地代理
-- 使用本地代理服务器访问 Anthropic Claude API
-- 模型名称格式: glink/<model-id>
----------------------------------------------------------------------
M.register("glink", {
  api_key_name = "ANTHROPIC_AUTH_TOKEN",
  endpoint = "http://127.0.0.1:9129",
  model = "glink/claude-opus-4-7", -- 默认使用最强模型
  static_models = { "glink/claude-opus-4-7", "glink/claude-opus-4-6" },
  model_info = {
    ["glink/claude-opus-4-7"] = {
      limit = { context = 200000, output = 32000 },
      description = "Claude Opus 4.7，Anthropic 最新旗舰推理模型，顶级代码能力",
    },
    ["glink/claude-opus-4-6"] = {
      limit = { context = 200000, output = 32000 },
      description = "Claude Opus 4.6，Anthropic 上一代旗舰模型，强大推理能力",
    },
  },
})

return M
