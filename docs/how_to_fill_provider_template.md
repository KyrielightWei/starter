# 如何填写 Provider 模板

当你使用 `<leader>kp → Ctrl-a` 添加新 provider 时，系统会在两个文件中生成模板：

## 📋 文件1：`lua/ai/providers.lua`（Provider 定义）

自动生成的模板：
```lua
M.register("new_provider", {
  api_key_name = "NEW_PROVIDER_API_KEY",      ← [1] 环境变量名/标识符
  endpoint = "https://api.new_provider.com/v1", ← [2] API endpoint
  model = "default-model",                     ← [3] 默认模型
  static_models = { "default-model" },         ← [4] 可用模型列表
})
```

### 字段说明

**[1] `api_key_name`**（通常不需要修改）
- 作用：定义 API key 的标识符
- 格式：`PROVIDER_NAME_API_KEY`
- 用途：
  - OpenAI 风格：作为环境变量名 `{env:NEW_PROVIDER_API_KEY}`
  - Key 管理标识：`ai_keys.lua` 中对应的 key

**[2] `endpoint`**（需要修改）
- 作用：API 的 base URL
- 格式：完整的 URL，通常以 `/v1` 结尾
- 示例：
  ```lua
  -- OpenAI 风格
  endpoint = "https://api.openai.com/v1"
  
  -- 阿里云百炼
  endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1"
  
  -- DeepSeek
  endpoint = "https://api.deepseek.com"
  
  -- 本地 Ollama
  endpoint = "http://localhost:11434"
  ```

**[3] `model`**（需要修改）
- 作用：默认使用的模型
- 格式：模型 ID（字符串）
- 示例：
  ```lua
  model = "gpt-4o-mini"
  model = "deepseek-chat"
  model = "glm-5"
  ```

**[4] `static_models`**（需要修改）
- 作用：可用的模型列表（用于模型切换）
- 格式：字符串数组
- 示例：
  ```lua
  static_models = { 
    "gpt-4o-mini", 
    "gpt-4o", 
    "gpt-4-turbo",
  }
  ```

---

## 📋 文件2：`~/.local/state/nvim/ai_keys.lua`（API Key 配置）

自动生成的模板：
```lua
new_provider = {
  default = {
    api_key = "",             ← [A] 填写真实 API key
    base_url = "",            ← [B] 可选：覆盖 endpoint
    base_url_claude = "",     ← [C] 可选：Claude Code 专用 endpoint
  },
}
```

### 字段说明

**[A] `api_key`**（必须填写）
- 格式1：直接写 API key（推荐用于本地开发）
  ```lua
  api_key = "sk-xxxxxxxxxxxx",
  ```
  
- 格式2：环境变量引用（推荐用于生产环境）
  ```lua
  api_key = "${env:NEW_PROVIDER_API_KEY}",
  ```
  然后在 shell 中设置：
  ```bash
  export NEW_PROVIDER_API_KEY="sk-xxxxxxxxxxxx"
  ```

**[B] `base_url`**（可选）
- 作用：覆盖 `providers.lua` 中的 `endpoint`
- 使用场景：
  - 使用代理服务器
  - 使用自定义 endpoint
  - 测试环境
- 示例：
  ```lua
  base_url = "https://proxy.example.com/v1",
  ```

**[C] `base_url_claude`**（可选）
- 作用：Claude Code 专用的 endpoint
- 使用场景：某些 provider 有专门的 Claude 接口
- 示例：
  ```lua
  base_url_claude = "https://api.example.com/anthropic",
  ```

---

## 📝 完整示例：添加 DeepSeek Provider

### 步骤1：添加 Provider
```vim
<leader>kp   " 打开 Provider Manager
Ctrl-a       " 添加新 provider
输入：deepseek
```

系统自动生成：
```lua
-- providers.lua
M.register("deepseek", {
  api_key_name = "DEEPSEEK_API_KEY",
  endpoint = "https://api.deepseek.com/v1",  ← 需要修改
  model = "default-model",                    ← 需要修改
  static_models = { "default-model" },        ← 需要修改
})

-- ai_keys.lua
deepseek = {
  default = {
    api_key = "",  ← 需要填写
    base_url = "",
    base_url_claude = "",
  },
}
```

### 步骤2：编辑 providers.lua
光标会自动定位到 `endpoint` 行，修改为：
```lua
M.register("deepseek", {
  api_key_name = "DEEPSEEK_API_KEY",
  endpoint = "https://api.deepseek.com",  ← DeepSeek 官方 endpoint
  model = "deepseek-chat",                ← 默认模型
  static_models = {                       ← 可用模型列表
    "deepseek-chat",
    "deepseek-coder",
  },
})
```

### 步骤3：编辑 ai_keys.lua
```vim
<leader>kK   " 打开 API Keys 编辑
```

填写：
```lua
deepseek = {
  default = {
    api_key = "sk-xxxxxxxxxxxxxxxxxxxx",  ← 你的真实 API key
    -- 或者使用环境变量：
    -- api_key = "${env:DEEPSEEK_API_KEY}",
    
    base_url = "",  ← 空表示使用 providers.lua 的 endpoint
    base_url_claude = "",
  },
}
```

### 步骤4：同步配置
```vim
<leader>kS   " 同步到 OpenCode/Claude Code
```

---

## 🎯 快速填写流程

### 方式1：完整流程（推荐）
```vim
" 1. 打开 Provider Manager
<leader>kp

" 2. 按 Ctrl-a 添加新 provider
"    输入名称（如：gemini）
"    自动打开 providers.lua，光标在 endpoint 行

" 3. 直接修改 providers.lua（光标已定位）
"    endpoint → model → static_models
:w          " 保存

" 4. 编辑 API key
<leader>kK   " 打开 ai_keys.lua
"    填写 api_key = "sk-xxx"
:w          " 保存

" 5. 同步配置
<leader>kS
```

### 方式2：分开编辑
```vim
" 1. 添加 Provider
<leader>kp → Ctrl-a → 输入名称

" 2. 编辑 providers.lua
:e lua/ai/providers.lua
" 修改 endpoint、model、static_models

" 3. 编辑 API key
<leader>kK
" 填写 api_key

" 4. 同步配置
<leader>kS
```

---

## ⚠️ 常见错误和注意事项

### ❌ 错误1：直接在 providers.lua 写 API key
```lua
M.register("deepseek", {
  endpoint = "https://api.deepseek.com",
  model = "deepseek-chat",
  api_key = "sk-xxx",  ← ❌ 错误！不要在这里写 API key
})
```
**正确做法**：API key 在 `ai_keys.lua` 中填写

### ❌ 错误2：endpoint 格式不完整
```lua
endpoint = "deepseek.com",  ← ❌ 缺少 https://
endpoint = "api.deepseek",  ← ❌ 缺少完整路径
```
**正确做法**：
```lua
endpoint = "https://api.deepseek.com",
endpoint = "https://api.deepseek.com/v1",
```

### ❌ 错误3：static_models 格式错误
```lua
static_models = "deepseek-chat",  ← ❌ 应该是数组
static_models = { deepseek-chat },  ← ❌ 缺少引号
```
**正确做法**：
```lua
static_models = { "deepseek-chat", "deepseek-coder" },
```

### ✅ 正确的完整配置示例
```lua
-- providers.lua
M.register("deepseek", {
  api_key_name = "DEEPSEEK_API_KEY",  ← 自动生成，通常不改
  endpoint = "https://api.deepseek.com",  ← 完整 URL
  model = "deepseek-chat",  ← 模型 ID
  static_models = {  ← 字符串数组
    "deepseek-chat",
    "deepseek-coder",
  },
})

-- ai_keys.lua
deepseek = {
  default = {
    api_key = "sk-xxxxxxxxxx",  ← 真实 API key
    base_url = "",  ← 空 = 使用 providers.lua 的 endpoint
  },
}
```

---

## 🔍 查看现有 Provider 作为参考

```vim
" 打开 providers.lua 查看其他 provider 的配置
:e lua/ai/providers.lua

" 搜索已有的 provider 定义
/theta    " 搜索 theta provider
/bailian_coding  " 搜索 bailian_coding provider
```

---

## 📊 查询 Provider API 文档

常见 Provider 的官方文档：
- **DeepSeek**: https://platform.deepseek.com/api-docs/
- **OpenAI**: https://platform.openai.com/docs/api-reference
- **阿里云百炼**: https://help.aliyun.com/zh/model-studio/
- **智谱 GLM**: https://bigmodel.cn/dev/api
- **Moonshot Kimi**: https://platform.moonshot.cn/docs

---

## 总结

✅ **providers.lua 填写内容**
- `api_key_name`: 通常不改（自动生成）
- `endpoint`: 必须修改（完整 URL）
- `model`: 必须修改（默认模型 ID）
- `static_models`: 必须修改（模型列表数组）

✅ **ai_keys.lua 填写内容**
- `api_key`: 必须填写（真实 API key 或环境变量引用）
- `base_url`: 可选（覆盖 endpoint）
- `base_url_claude`: 可选（Claude Code 专用）

✅ **填写顺序**
1. 添加 Provider（自动生成模板）
2. 编辑 providers.lua（修改 endpoint/model）
3. 编辑 ai_keys.lua（填写 API key）
4. 同步配置（导出到 CLI 工具）

✅ **验证配置**
```vim
<leader>kp   " 查看 Provider 状态
<leader>ks   " 测试模型切换
:OpenCodeWriteConfig  " 生成配置并检查
```