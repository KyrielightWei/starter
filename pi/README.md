# Pi 配置模板

本目录包含 Pi coding agent 的完整配置模板，用于在新机器上快速恢复配置。

## 📁 目录结构

```
pi/
├── README.md                    # 本文件
├── models.template.jsonc        # Provider/Model 配置
├── keybindings.template.jsonc   # 快捷键配置
├── theme.template.json          # Kanagawa 主题
├── AGENTS.template.md           # Agent 指令模板
├── extensions/                  # 扩展模板
│   ├── statusbar.template.ts    # 三行状态栏
│   └── todo.template.ts         # TODO 管理
├── skills/                      # 技能模板
│   ├── openspec/SKILL.md        # Spec-driven development
│   └── brainstorming/SKILL.md   # 需求探索
└── prompts/                     # Prompt 模板
    ├── review.template.md       # 代码审查
    └── refactor.template.md     # 重构
```

根目录还有:
- `pi.template.jsonc` - 主配置模板 (settings.json)

## 🚀 快速恢复配置

### 1. 复制配置文件

```bash
# 创建配置目录
mkdir -p ~/.pi/agent/themes ~/.pi/agent/extensions ~/.pi/agent/skills ~/.pi/agent/prompts

# 主配置
cp pi.template.jsonc ~/.pi/agent/settings.json

# Provider/Model
cp pi/models.template.jsonc ~/.pi/agent/models.json

# 快捷键
cp pi/keybindings.template.jsonc ~/.pi/agent/keybindings.json

# 主题
cp pi/theme.template.json ~/.pi/agent/themes/kanagawa.json

# Agent 指令 (全局)
cp pi/AGENTS.template.md ~/.pi/agent/AGENTS.md
```

### 2. 安装扩展

```bash
# 状态栏扩展
cp pi/extensions/statusbar.template.ts ~/.pi/agent/extensions/statusbar.ts

# TODO 扩展
cp pi/extensions/todo.template.ts ~/.pi/agent/extensions/todo.ts
```

### 3. 安装技能

```bash
# OpenSpec skill
mkdir -p ~/.pi/agent/skills/openspec
cp pi/skills/openspec/SKILL.md ~/.pi/agent/skills/openspec/SKILL.md

# Brainstorming skill
mkdir -p ~/.pi/agent/skills/brainstorming
cp pi/skills/brainstorming/SKILL.md ~/.pi/agent/skills/brainstorming/SKILL.md
```

### 4. 安装 Prompt 模板

```bash
# 复制 prompt 模板 (去掉 .template 后缀)
cp pi/prompts/review.template.md ~/.pi/agent/prompts/review.md
cp pi/prompts/refactor.template.md ~/.pi/agent/prompts/refactor.md
```

### 5. 设置 API Key

```bash
# 方法 1: 环境变量
export OPENAI_API_KEY="your-api-key"

# 方法 2: 在 models.json 中配置
# apiKey 字段支持:
#   - 环境变量: "VAR_NAME"
#   - Shell 命令: "!command"
#   - 直接值: "sk-..." (不要提交到版本控制)
```

### 6. 验证配置

```bash
# 启动 pi
pi

# 在 pi 中:
/settings    # 查看设置
/model       # 查看可用模型
/hotkeys     # 查看快捷键
/statusbar   # 切换状态栏
/todos       # 查看 TODO
```

## 📋 配置说明

### settings.json (主配置)

| 字段 | 说明 |
|------|------|
| `defaultProvider` | 默认 Provider (bailian) |
| `defaultModel` | 默认 Model (glm-5) |
| `defaultThinkingLevel` | 思考级别 (medium) |
| `theme` | 主题名称 (kanagawa) |
| `packages` | Pi 包列表 |
| `compaction` | 上下文压缩配置 |
| `retry` | 重试策略 |

### models.json (Provider 配置)

| Provider | 说明 |
|----------|------|
| `bailian` | 阿里百炼编码版 (主 Provider) |
| `ollama` | 本地 LLM |

### 扩展功能

| 扩展 | 功能 |
|------|------|
| `statusbar.ts` | 三行状态栏 (Token/Context/Model) |
| `todo.ts` | TODO 管理工具 |

### 技能功能

| 技能 | 功能 |
|------|------|
| `openspec` | Spec-driven development 工作流 |
| `brainstorming` | 需求探索流程 |

## 🔧 自定义配置

### 添加新 Provider

编辑 `models.json`:

```json
{
  "providers": {
    "my-provider": {
      "baseUrl": "https://api.example.com/v1",
      "api": "openai-completions",
      "apiKey": "MY_API_KEY",
      "models": [
        { "id": "model-1", "name": "Model 1" }
      ]
    }
  }
}
```

### 添加新扩展

创建 `~/.pi/agent/extensions/my-extension.ts`:

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.notify("Extension loaded!", "info");
  });
}
```

### 添加新技能

创建 `~/.pi/agent/skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: What this skill does and when to use it.
---

# My Skill

Instructions here...
```

## 🔗 相关文档

- Pi 主文档: `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/README.md`
- 扩展文档: `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/docs/extensions.md`
- 主题文档: `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/docs/themes.md`

## 📝 与本项目其他模板的关系

| 工具 | 模板文件 | 配置目录 |
|------|----------|----------|
| OpenCode | `opencode.template.jsonc` | `~/.config/opencode/` |
| Claude Code | `claude_code.template.jsonc` | `~/.claude/` |
| Pi | `pi.template.jsonc` + `pi/` | `~/.pi/agent/` |

本项目统一管理三个 AI 工具的配置模板，便于跨机器同步。