# Pi 配置模板完整版

本目录包含 **Pi coding agent 的完整配置模板**，用于在新机器上快速恢复全部配置。

## 📁 目录结构

```
pi/
├── README.md                      # 本文件
├── CLI.md                         # CLI 命令行参考
├── PACKAGES.md                    # 包管理文档
│
├── settings.template.jsonc        # 完整 settings.json 模板
├── models.template.jsonc          # Provider/Model 配置
├── keybindings.template.jsonc     # 快捷键配置
├── theme.template.json            # Kanagawa 主题
├── AGENTS.template.md             # Agent 指令模板
│
├── extensions/                    # 扩展模板
│   ├── statusbar.template.ts      # 三行状态栏
│   ├── todo.template.ts           # TODO 管理
│   ├── permission-gate.template.ts # 权限门控
│   ├── git-checkpoint.template.ts # Git checkpoint
│   ├── working-indicator.template.ts # 工作指示器
│   └── enhanced-exit.template.ts  # 增强退出
│
├── skills/                        # 技能模板
│   ├── openspec/SKILL.md          # Spec-driven development
│   ├── brainstorming/SKILL.md     # 需求探索
│   ├── systematic-debugging/SKILL.md # 系统化调试
│   ├── test-driven-development/SKILL.md # TDD
│   ├── using-git-worktrees/SKILL.md # Git worktree
│   └── verification-before-completion/SKILL.md # 完成前验证
│
└── prompts/                       # Prompt 模板
    ├── review.template.md         # 代码审查
    ├── refactor.template.md       # 重构
    ├── debug.template.md          # 调试
    ├── implement.template.md      # TDD 实现
    ├── explain.template.md        # 解释代码
    ├── commit.template.md         # 提交
    └── plan.template.md           # 计划
```

根目录还有:
- `pi.template.jsonc` - 主配置模板 (历史兼容，建议使用 settings.template.jsonc)

---

## 🚀 快速恢复配置

### 1. 创建目录结构

```bash
mkdir -p ~/.pi/agent/{themes,extensions,skills,prompts,sessions}
mkdir -p ~/.pi/agent/skills/{openspec,brainstorming,systematic-debugging,test-driven-development,using-git-worktrees,verification-before-completion}
```

### 2. 复制核心配置

```bash
# 主配置 (完整版)
cp pi/settings.template.jsonc ~/.pi/agent/settings.json

# Provider/Model 配置
cp pi/models.template.jsonc ~/.pi/agent/models.json

# 快捷键配置
cp pi/keybindings.template.jsonc ~/.pi/agent/keybindings.json

# 主题
cp pi/theme.template.json ~/.pi/agent/themes/kanagawa.json

# Agent 指令 (全局)
cp pi/AGENTS.template.md ~/.pi/agent/AGENTS.md
```

### 3. 安装扩展

```bash
# 复制所有扩展 (去掉 .template 后缀)
for f in pi/extensions/*.template.ts; do
  name=$(basename "$f" .template.ts)
  cp "$f" ~/.pi/agent/extensions/"$name".ts
done
```

扩展列表：
| 扩展 | 功能 |
|------|------|
| `statusbar.ts` | 三行状态栏 (Token/Context/Model) |
| `todo.ts` | TODO 管理工具 |
| `permission-gate.ts` | 危险命令确认 |
| `git-checkpoint.ts` | Git stash checkpoint |
| `working-indicator.ts` | 工作进度指示器 |
| `enhanced-exit.ts` | 增强退出确认 |

### 4. 安装技能

```bash
# 复制所有技能
for dir in pi/skills/*/; do
  name=$(basename "$dir")
  mkdir -p ~/.pi/agent/skills/$name
  cp "$dir/SKILL.md" ~/.pi/agent/skills/$name/SKILL.md
done
```

技能列表：
| 技能 | 功能 |
|------|------|
| `openspec` | Spec-driven development 工作流 |
| `brainstorming` | 需求探索流程 |
| `systematic-debugging` | 系统化调试流程 |
| `test-driven-development` | TDD 循环 |
| `using-git-worktrees` | Git worktree 工作流 |
| `verification-before-completion` | 完成前验证 |

### 5. 安装 Prompt 模板

```bash
# 复制所有 prompt 模板 (去掉 .template 后缀)
for f in pi/prompts/*.template.md; do
  name=$(basename "$f" .template.md)
  cp "$f" ~/.pi/agent/prompts/$name.md
done
```

Prompt 模板列表：
| 模板 | 功能 |
|------|------|
| `review.md` | 代码审查 `/review` |
| `refactor.md` | 重构 `/refactor` |
| `debug.md` | 调试 `/debug` |
| `implement.md` | TDD 实现 `/implement` |
| `explain.md` | 解释代码 `/explain` |
| `commit.md` | 提交 `/commit` |
| `plan.md` | 计划 `/plan` |

### 6. 设置 API Key

```bash
# 方法 1: 环境变量 (推荐)
export OPENAI_API_KEY="your-api-key"
export ANTHROPIC_API_KEY="your-api-key"

# 方法 2: 在 models.json 中配置
# apiKey 字段支持:
#   - 环境变量: "VAR_NAME"
#   - Shell 命令: "!command" (如 1Password: "!op read 'op://vault/item'")
#   - 直接值: "sk-..." (不要提交到版本控制)
```

### 7. 安装 Pi 包 (可选)

```bash
# 安装 superpowers 技能包
pi install git:github.com/obra/superpowers

# 其他推荐包
pi install npm:@earendil-works/pi-mcp  # MCP 集成
```

### 8. 验证配置

```bash
# 启动 pi
pi

# 在 pi 中验证:
/settings    # 查看设置
/model       # 查看可用模型
/hotkeys     # 查看快捷键
/statusbar   # 切换状态栏
/todos       # 查看 TODO
/brainstorming  # 使用技能
/review      # 使用 prompt 模板
```

---

## 📋 配置详解

### settings.json (主配置)

完整配置项列表：

| 类别 | 配置项 | 说明 |
|------|--------|------|
| **Model** | `defaultProvider` | 默认 Provider |
| | `defaultModel` | 默认 Model |
| | `defaultThinkingLevel` | 思考级别 (off/minimal/low/medium/high/xhigh) |
| **UI** | `theme` | 主题名称 |
| | `quietStartup` | 隐藏启动 header |
| **Compaction** | `compaction.enabled` | 自动压缩 |
| | `compaction.reserveTokens` | LLM 响应预留 |
| **Retry** | `retry.maxRetries` | 最大重试次数 |
| **Terminal** | `terminal.showImages` | 显示图片 |
| **Packages** | `packages[]` | Pi 包列表 |

详见 `settings.template.jsonc`。

### models.json (Provider 配置)

Provider 配置结构：

```json
{
  "providers": {
    "<provider-name>": {
      "name": "显示名称",
      "baseUrl": "API endpoint",
      "api": "openai-completions | anthropic | google",
      "apiKey": "VAR_NAME | !command | direct-value",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false
      },
      "models": [
        { "id": "model-id", "name": "显示名称", "contextWindow": 200000 }
      ]
    }
  }
}
```

### 快捷键配置

完整快捷键映射，详见 `keybindings.template.jsonc`。

常用：
| 键 | 功能 |
|-----|------|
| `Ctrl+L` | 模型选择器 |
| `Ctrl+P` | 循环模型 |
| `Shift+Tab` | 循环思考级别 |
| `Ctrl+O` | 折叠工具输出 |
| `Ctrl+T` | 折叠思考块 |

---

## 📚 文档参考

| 文档 | 内容 |
|------|------|
| `CLI.md` | CLI 命令行完整参考 |
| `PACKAGES.md` | 包安装和管理 |

---

## 🔗 相关链接

- Pi 主文档: `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/README.md`
- 扩展文档: `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/docs/extensions.md`
- 主题文档: `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/docs/themes.md`
- Settings 文档: `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/docs/settings.md`

---

## 📝 与本项目其他模板的关系

| 工具 | 模板文件 | 配置目录 |
|------|----------|----------|
| OpenCode | `opencode.template.jsonc` + `templates/opencode/` | `~/.config/opencode/` |
| Claude Code | `claude_code.template.jsonc` + `templates/claude_code/` | `~/.claude/` |
| Pi | `pi/settings.template.jsonc` + `pi/` | `~/.pi/agent/` |

本项目统一管理三个 AI 工具的配置模板，便于跨机器同步。

---

## 🔄 一键恢复脚本

创建恢复脚本 `restore-pi-config.sh`：

```bash
#!/bin/bash
# 从模板恢复 Pi 配置

PI_DIR=~/.pi/agent
TEMPLATE_DIR=/root/tool/starter/pi

# 创建目录
mkdir -p "$PI_DIR"/{themes,extensions,skills,prompts,sessions}
mkdir -p "$PI_DIR"/skills/{openspec,brainstorming,systematic-debugging,test-driven-development,using-git-worktrees,verification-before-completion}

# 复制核心配置
cp "$TEMPLATE_DIR/settings.template.jsonc" "$PI_DIR/settings.json"
cp "$TEMPLATE_DIR/models.template.jsonc" "$PI_DIR/models.json"
cp "$TEMPLATE_DIR/keybindings.template.jsonc" "$PI_DIR/keybindings.json"
cp "$TEMPLATE_DIR/theme.template.json" "$PI_DIR/themes/kanagawa.json"
cp "$TEMPLATE_DIR/AGENTS.template.md" "$PI_DIR/AGENTS.md"

# 复制扩展
for f in "$TEMPLATE_DIR/extensions/*.template.ts"; do
  name=$(basename "$f" .template.ts)
  cp "$f" "$PI_DIR/extensions/$name.ts"
done

# 复制技能
for dir in "$TEMPLATE_DIR/skills/*/"; do
  name=$(basename "$dir")
  mkdir -p "$PI_DIR/skills/$name"
  cp "$dir/SKILL.md" "$PI_DIR/skills/$name/SKILL.md"
done

# 复制 prompts
for f in "$TEMPLATE_DIR/prompts/*.template.md"; do
  name=$(basename "$f" .template.md)
  cp "$f" "$PI_DIR/prompts/$name.md"
done

echo "✓ Pi 配置已恢复"
echo "运行 'pi' 验证配置"
```