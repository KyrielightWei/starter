# 配置指南

## Provider 配置

### 内置 Provider

插件预置了以下 Provider 定义（在 `ai.providers` 中）：

| Provider | 端点 | 默认模型 |
|----------|------|---------|
| bailian_coding | coding.dashscope.aliyuncs.com | qwen3.7-plus |
| deepseek | api.deepseek.com | deepseek-chat |
| openai | api.openai.com | gpt-4o |
| moonshot | api.moonshot.ai | moonshot-v1-auto |

### 添加自定义 Provider

通过 Provider Manager (`:AIProvider`) 交互式添加，或直接编辑 `lua/ai/providers.lua`。

每个 Provider 需要：
- `name`: 标识名
- `endpoint`: API 端点 URL
- `model`: 默认模型
- `api_key_name`: 环境变量名（如 `OPENAI_API_KEY`）
- `static_models`: 可用模型列表

## API Key 管理

### 方式 1：环境变量

```bash
export OPENAI_API_KEY="your-key"
export BAILIAN_CODING_API_KEY="your-key"
```

### 方式 2：Neovim 内编辑

`:AIKeys` 打开 key 配置文件，格式：

```lua
return {
  bailian_coding = {
    api_key = "env:BAILIAN_CODING_API_KEY",  -- 引用环境变量
    base_url = "https://coding.dashscope.aliyuncs.com/v1",
  },
  openai = {
    api_key = "sk-...",  -- 直接填写（不推荐）
  },
}
```

### 方式 3：auth.json（Pi 专用）

Pi 支持 `~/.pi/agent/auth.json` 集中管理凭据，详见 `pi/AUTH.md`。

### Key 解析优先级

1. `ai.keys` 模块配置（`:AIKeys` 编辑的文件）
2. 环境变量（`env:VAR_NAME` 格式引用）
3. 工具特定的 auth 文件（如 `~/.pi/agent/auth.json`）

## 模板系统

### 版本化模板

每个工具支持多个模板版本，存储在 `templates/<tool>/` 下：

```
templates/
├── pi/
│   └── default.template.jsonc
├── opencode/
│   ├── core.template.jsonc
│   └── omo.template.jsonc
└── claude_code/
    ├── ecc.template.jsonc
    └── minimal.template.jsonc
```

### 切换模板版本

```vim
:AI template list opencode      " 查看可用版本
:AI template select opencode    " 交互式选择
:AI template create opencode v2 " 从当前版本创建新版本
```

### Legacy 回退

如果版本化模板不存在，系统回退到根目录的 legacy 模板：
- `opencode.template.jsonc`
- `claude_code.template.jsonc`
- `ccstatusline.template.jsonc`

## 配置热更新

`:AI watch` 启用文件监听器，当以下文件变化时自动同步：
- `opencode.template.jsonc`
- Provider 配置文件
- API Key 文件

`:AI watch force` 强制立即同步所有配置。

## 同步流程

`:AISync` 打开选择器，选择目标工具后执行：

1. 读取模板文件
2. 合并当前 Provider/Key/Model 配置
3. 保守合并用户自定义字段（不覆盖用户添加的配置）
4. 写入目标配置文件
5. 如有变更，自动备份旧版本
