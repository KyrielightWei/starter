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
    model_info = conf.model_info or {}, -- Model详细信息(OpenCode配置)
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
  model = "z-ai/glm-4.7",  -- 智谱GLM-4.7，热门模型
  static_models = {
    -- GLM 系列 (Top Weekly)
    "z-ai/glm-4.7",
    "z-ai/glm-4.6",
    "z-ai/glm-4.6v",
    "z-ai/glm-4.6v-flash",
    
    -- DeepSeek 系列
    "deepseek/deepseek-chat",
    "deepseek/deepseek-reasoner",
    "deepseek/deepseek-v3.2",
    
    -- Claude 系列
    "anthropic/claude-opus-4.5",
    "anthropic/claude-sonnet-4.5",
    "anthropic/claude-haiku-4.5",
    
    -- GPT-5 系列
    "openai/gpt-5.2",
    "openai/gpt-5.2-pro",
    "openai/gpt-5.1",
    "openai/gpt-5.1-codex",
    
    -- Gemini 3 系列
    "google/gemini-3-pro-preview",
    "google/gemini-3-flash-preview",
    
    -- 其他热门模型
    "minimax/minimax-m2.1",
    "moonshotai/kimi-k2-thinking",
    "qwen/qwen3-max-preview",
    "x-ai/grok-4.1-fast",
    "xiaomi/mimo-v2-flash",
    "volcengine/doubao-seed-code",
  },
  -- 模型详细信息（来自 ZenMux Top Weekly）
  model_info = {
    ["zenmux/auto"] = {
      description = "ZenMux 自动路由模型，根据查询选择最优性价比模型",
    },
    ["z-ai/glm-4.7"] = {
      limit = { context = 200000, output = 128000 },
      description = "智谱最新旗舰模型，专为 Agentic Coding 优化，强化长任务规划和工具协作",
    },
    ["z-ai/glm-4.6"] = {
      limit = { context = 200000, output = 128000 },
      description = "智谱旗舰模型，355B 总参数/32B 活跃参数，200K 上下文",
    },
    ["z-ai/glm-4.6v"] = {
      limit = { context = 200000, output = 128000 },
      description = "GLM 多模态演进，首个原生集成工具调用的视觉模型",
    },
    ["z-ai/glm-4.6v-flash"] = {
      limit = { context = 200000, output = 128000 },
      description = "GLM-4.6V FlashX 付费版，更高的容量和稳定性",
    },
    ["minimax/minimax-m2.1"] = {
      limit = { context = 204800, output = 131070 },
      description = "轻量级 SOTA 模型，10B 活跃参数，专为编码和 Agent 优化",
    },
    ["minimax/minimax-m2"] = {
      limit = { context = 204800, output = 128000 },
      description = "紧凑高效模型，专为端到端编码和 Agentic 工作流优化",
    },
    ["deepseek/deepseek-chat"] = {
      limit = { context = 128000, output = 8000 },
      description = "DeepSeek-V3.2 非思考模式，生产级模型，自动更新版本",
    },
    ["deepseek/deepseek-reasoner"] = {
      limit = { context = 128000, output = 64000 },
      description = "DeepSeek-V3.2 思考模式，推理优先，集成工具调用",
    },
    ["deepseek/deepseek-v3.2"] = {
      limit = { context = 128000, output = 8000 },
      description = "推理优先的 LLM，专注于 Agentic 能力和工具使用",
    },
    ["anthropic/claude-opus-4.5"] = {
      limit = { context = 200000, output = 32000 },
      description = "Anthropic 最新前沿推理模型，专为复杂软件工程和 Agent 设计",
    },
    ["anthropic/claude-sonnet-4.5"] = {
      limit = { context = 200000, output = 64000 },
      description = "Anthropic 最先进 Sonnet，优化实时 Agent 和编码工作流",
    },
    ["anthropic/claude-haiku-4.5"] = {
      limit = { context = 200000, output = 64000 },
      description = "Anthropic 最快最高效模型，成本仅为大模型的零头",
    },
    ["openai/gpt-5.2-pro"] = {
      limit = { context = 400000, output = 128000 },
      description = "OpenAI 最先进模型，Agentic Coding 和长上下文大幅改进",
    },
    ["openai/gpt-5.2"] = {
      limit = { context = 400000, output = 128000 },
      description = "GPT-5 家族最新前沿模型，自适应推理，动态分配计算",
    },
    ["openai/gpt-5.2-chat"] = {
      limit = { context = 128000, output = 16380 },
      description = "GPT-5.2 快速轻量版，低延迟聊天优化",
    },
    ["openai/gpt-5.1"] = {
      limit = { context = 400000, output = 128000 },
      description = "GPT-5 系列最新前沿模型，更强推理和指令遵循",
    },
    ["openai/gpt-5.1-codex"] = {
      limit = { context = 400000, output = 128000 },
      description = "GPT-5.1 专用版本，优化软件工程和编码工作流",
    },
    ["google/gemini-3-pro-preview"] = {
      limit = { context = 1050000, output = 65530 },
      description = "Gemini 下一代系列，Google 处理复杂任务的最先进模型",
    },
    ["google/gemini-3-flash-preview"] = {
      limit = { context = 1050000, output = 65530 },
      description = "Gemini 3 家族低延迟模型，快速高吞吐推理优化",
    },
    ["moonshotai/kimi-k2-thinking"] = {
      limit = { context = 262140, output = 262140 },
      description = "通用 Agent 和推理能力的思考模型，专注深度推理",
    },
    ["moonshotai/kimi-k2-thinking-turbo"] = {
      limit = { context = 262140, output = 262140 },
      description = "Kimi K2 Thinking 高速版，深度推理+极速响应",
    },
    ["qwen/qwen3-max-preview"] = {
      limit = { context = 262140, output = 65540 },
      description = "通义千问 3 Max 预览版，思考与非思考模式集成",
    },
    ["x-ai/grok-4.1-fast"] = {
      limit = { context = 2000000, output = 30000 },
      description = "xAI 最佳 Agent 工具调用模型，2M 上下文",
    },
    ["xiaomi/mimo-v2-flash"] = {
      limit = { context = 262140, output = 262140 },
      description = "小米开源基础模型，MoE 309B 总参数/15B 活跃",
    },
    ["volcengine/doubao-seed-code"] = {
      limit = { context = 256000, output = 32000 },
      description = "深度优化 Agentic 编程任务，256K 上下文",
    },
    ["volcengine/doubao-seed-1.8"] = {
      limit = { context = 256000, output = 32000 },
      description = "专为多模态 Agent 场景优化的全新模型",
    },
    ["mistralai/mistral-large-2512"] = {
      limit = { context = 256000, output = 256000 },
      description = "Mistral Large 3，SOTA 开源权重通用多模态模型",
    },
    ["baidu/ernie-5.0-thinking-preview"] = {
      limit = { context = 128000, output = 64000 },
      description = "文心大模型 5.0，原生统一多模态建模",
    },
    ["kuaishou/kat-coder-pro-v1"] = {
      limit = { context = 256000, output = 32000 },
      description = "快手 KAT-Coder Pro V1，多工具并行调用，AI 编程极致性能",
    },
    ["inclusionai/ring-1t"] = {
      limit = { context = 128000, output = 32000 },
      description = "万亿参数稀疏 MoE 思考模型，50B 活跃参数",
    },
  },
})
return M
