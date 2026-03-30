# AI 模块配置指南

> 统一的 AI 插件接口，支持多后端切换（Avante、Copilot 等）

## 架构概览

```
lua/ai/
├── init.lua           # 主入口，快捷键和命令注册
├── providers.lua      # Provider 注册中心
├── keys.lua           # API Key 管理
├── model_switch.lua   # 模型选择器
├── state.lua          # 状态管理
├── terminal.lua       # AI CLI 终端管理
├── opencode.lua       # OpenCode 配置生成
├── claude_code.lua    # Claude Code 集成
├── context.lua        # 上下文收集
├── system_prompt.lua  # System Prompt 管理
└── skill_studio/      # Skill/MCP 创作工具
```

## 快捷键

前缀：`<leader>k`（AI Interactive）

### 核心交互

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>kc` | n | AI Chat | 打开 AI 对话 |
| `<leader>kn` | n | AI New Chat | 新建对话 |
| `<leader>ke` | v | AI Edit Selection | 编辑选中代码 |
| `<leader>kq` | n | AI Quick Ask | 快速提问浮窗 |

### 配置管理

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>ks` | n | AI Model Switch | 切换模型 |
| `<leader>kk` | n | AI Key Manager | 管理 API Key |
| `<leader>kS` | n | AI Chat Sessions | 对话历史 |

### 面板控制

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>kt` | n | AI Toggle Panel | 切换面板显示 |
| `<leader>kd` | n | AI Diff Viewer | 查看 AI 修改差异 |

### 代码建议（插入模式）

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<M-]>` | i | Next Suggestion | 下一个建议 |
| `<M-[>` | i | Prev Suggestion | 上一个建议 |
| `<M-\>` | i | Accept Suggestion | 接受建议 |

### 高级功能

| 快捷键 | 模式 | 功能 | 说明 |
|--------|------|------|------|
| `<leader>kC` | n | Copy AI Context | 复制上下文到剪贴板 |
| `<leader>kY` | n | Sync All AI Configs | 同步所有 AI 配置 |

---

## 用户命令

### 基础命令

| 命令 | 说明 |
|------|------|
| `:AIChat` | 打开 AI 对话 |
| `:AIChatNew` | 新建对话 |
| `:AIEdit` | 编辑选中代码 |
| `:AIAsk` | 快速提问 |
| `:AIToggle` | 切换面板 |
| `:AIDiff` | 查看修改差异 |

### OpenCode 命令

| 命令 | 说明 |
|------|------|
| `:OpenCodeGenerateConfig` | 从模板生成配置 |
| `:OpenCodeEditTemplate` | 编辑配置模板 |
| `:OpenCodeValidateTemplate` | 验证模板 |
| `:OpenCodePreviewConfig` | 预览合并后的配置 |
| `:OpenCodeStatus` | 查看状态 |

### Claude Code 命令

| 命令 | 说明 |
|------|------|
| `:ClaudeCodeGenerateConfig` | 生成 Claude Code 配置 |
| `:ClaudeCodeEditTemplate` | 编辑模板 |
| `:ClaudeCodeEditConfig` | 编辑已生成的配置 |
| `:ClaudeCodeEditStatusline` | 编辑状态栏模板 |
| `:ClaudeCodePreviewConfig` | 预览配置 |
| `:ClaudeCodeStatus` | 查看状态 |
| `:ClaudeCodeCheckDeps` | 检查依赖 |

### 配置同步命令

| 命令 | 说明 |
|------|------|
| `:AISyncAll` | 同步所有 AI 工具配置 |
| `:AISyncSelect` | 选择并同步配置 |
| `:AIExportKeys` | 导出 API Key 到 env 文件 |
| `:AIEditKeys` | 编辑 API Key 和 Base URL |

### 上下文命令

| 命令 | 说明 |
|------|------|
| `:AICopyContext` | 复制当前上下文到剪贴板 |
| `:AIShowContext` | 显示当前上下文 |
| `:AIEditPrompts` | 编辑 prompts 目录 |
| `:AIListPrompts` | 列出所有 prompt 文件 |

---

## 切换 AI 后端

修改 `lua/plugins/ai.lua`：

```lua
return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make",
    config = function()
      -- 切换后端只需修改这里
      require("ai").setup({ default_backend = "copilot" })
    end,
  },
}
```

然后创建对应的适配器文件 `lua/ai/copilot_adapter.lua`。

---

## API Key 管理

API Key 存储在 `~/.local/state/nvim/ai_keys.lua`：

```lua
return {
  openai_api_key = "sk-xxx",
  deepseek_api_key = "sk-xxx",
  -- 自定义 base URL
  openai_base_url = "https://api.openai.com/v1",
}
```

使用 `:AIEditKeys` 或 `<leader>kk` 打开编辑。

---

## Provider 配置

编辑 `lua/ai/providers.lua` 添加新的 Provider：

```lua
M.register("new_provider", {
  api_key_name = "NEW_PROVIDER_API_KEY",
  endpoint = "https://api.newprovider.com",
  model = "default-model",
  static_models = { "model-1", "model-2" },
})
```

---

## 配置文件路径

| 文件 | 路径 |
|------|------|
| API Keys | `~/.local/state/nvim/ai_keys.lua` |
| OpenCode 模板 | `opencode.template.jsonc` |
| OpenCode 配置 | `~/.config/opencode/opencode.json` |
| Claude Code 配置 | `~/.claude/settings.json` |
| Prompts 目录 | `~/.claude/prompts/` |