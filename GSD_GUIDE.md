# GSD (Get Shit Done) 使用指南

## 概述

GSD 是一个**元提示、上下文工程与规格驱动开发系统**，适用于 Claude Code、OpenCode、Gemini CLI 等多种 AI 编码工具。

**核心价值**：
- 解决 **context rot** 问题 — 随着上下文窗口被填满，AI 输出质量逐步劣化
- 提供清晰的规格驱动开发流程
- 支持多运行时、多项目的统一管理

---

## 安装状态

```
~/.claude/
├── commands/gsd/     # GSD 命令集
├── agents/gsd/       # GSD 代理集
├── hooks/gsd/        # GSD hooks
├── gsd/              # GSD 配置目录
└── skills/gsd-*/     # GSD skills (Claude Code 2.1.88+)
```

---

## 安装

### 方式 1: 使用组件管理器（推荐）

通过 AI Component Manager 安装：

```vim
:AIComponents
```

在选择器中选择 GSD，按 `i` 安装。

### 方式 2: npx 按需运行（官方推荐）

```bash
npx get-shit-done-cc@latest
```

安装器会提示你选择：
1. **运行时**：Claude Code、OpenCode、Gemini、Codex、Cursor 等
2. **安装位置**：全局（所有项目）或本地（仅当前项目）

### 方式 3: npm 全局安装

```bash
npm install -g get-shit-done-cc
get-shit-done-cc
```

### 方式 4: 非交互式安装（CI/Docker）

```bash
# Claude Code 全局安装
npx get-shit-done-cc --claude --global

# OpenCode 全局安装
npx get-shit-done-cc --opencode --global

# Gemini CLI
npx get-shit-done-cc --gemini --global

# 所有运行时
npx get-shit-done-cc --all --global
```

**支持的运行时**：
- Claude Code (`--claude`)
- OpenCode (`--opencode`)
- Gemini CLI (`--gemini`)
- Kilo (`--kilo`)
- Codex (`--codex`)
- Copilot (`--copilot`)
- Cursor (`--cursor`)
- Windsurf (`--windsurf`)
- Antigravity (`--antigravity`)
- Augment (`--augment`)
- Trae (`--trae`)
- CodeBuddy (`--codebuddy`)
- Cline (`--cline`)

---

## 状态检查

### 通过组件管理器

```vim
:AIComponents
```

选择器显示：
- 安装状态 (✓ 已安装 / ○ 未安装)
- 版本信息 (npm 版本 / npx latest)
- 依赖状态

### 通过命令

```vim
:AIComponentList
```

输出示例：
```
✓ GSD (Get Shit Done) - Framework - installed (npm: 1.37.1)
○ ECC (Everything Claude Code) - Framework - not installed
```

### 健康检查

```vim
:checkhealth ai
```

---

## 更新

### 通过组件管理器

```vim
:AIComponents
```

选择 GSD，按 `u` 更新。

### npx 方式

```bash
npx get-shit-done-cc@latest
```

npx 自动使用最新版本，无需手动更新。

### npm 全局安装更新

```bash
npm update -g get-shit-done-cc
```

---

## 卸载

### 通过组件管理器

```vim
:AIComponents
```

选择 GSD，按 `x` 卸载（会有确认对话框）。

### 手动卸载

```bash
# npm 全局卸载
npm uninstall -g get-shit-done-cc

# 删除配置目录
rm -rf ~/.claude/gsd
rm -rf ~/.claude/commands/gsd
rm -rf ~/.claude/agents/gsd
rm -rf ~/.claude/hooks/gsd
```

---

## 配置目录

遵循 XDG Base Directory 规范：

| 运行时 | 配置目录 | 说明 |
|--------|----------|------|
| Claude Code | `~/.claude/` | 全局安装 |
| Claude Code | `./.claude/` | 本地安装 |
| OpenCode | `~/.config/opencode/` | 全局安装 |
| Gemini CLI | `~/.gemini/` | 全局安装 |
| Codex | `~/.codex/` | 全局安装 |
| Cursor | `~/.cursor/` | 全局安装 |

---

## 快速开始

### 核心开发流程

```
想法 → /gsd-new-project → /gsd-discuss-phase → /gsd-plan-phase → /gsd-execute-phase → 验证
```

1. **初始化**: `/gsd-new-project` - 系统提问直到理解你的想法
2. **讨论**: `/gsd-discuss-phase N` - 填充阶段的灰区决策
3. **规划**: `/gsd-plan-phase N` - 研究并制定原子化任务计划
4. **执行**: `/gsd-execute-phase N` - 按 wave 执行，每个任务单独提交
5. **验证**: `/gsd-verify-phase N` - 检查是否交付承诺内容

---

## 常用命令速查

### 项目管理类

| 命令 | 用途 | 生成文件 |
|------|------|----------|
| `/gsd-new-project` | 初始化新项目 | PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md |
| `/gsd-map-codebase` | 分析现有代码库 | 技术栈、架构、约定分析 |
| `/gsd-help` | 显示帮助信息 | - |

### 阶段管理类

| 命令 | 用途 | 生成文件 |
|------|------|----------|
| `/gsd-discuss-phase N` | 讨论阶段灰区 | N-CONTEXT.md |
| `/gsd-plan-phase N` | 规划阶段任务 | N-RESEARCH.md, N-{N}-PLAN.md |
| `/gsd-execute-phase N` | 执行阶段任务 | N-{N}-SUMMARY.md, N-VERIFICATION.md |
| `/gsd-verify-phase N` | 验证阶段成果 | 验证报告 |

### 状态管理类

| 命令 | 用途 |
|------|------|
| `/gsd-state-validate` | 检测 STATE.md 与文件系统偏差 |
| `/gsd-state-sync` | 从实际项目状态重建 STATE.md |
| `/gsd-status` | 显示当前项目状态 |

---

## 工作原理

### Wave 执行模式

计划根据依赖关系分组为不同的 "wave"：

```
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE EXECUTION                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  WAVE 1 (parallel)          WAVE 2 (parallel)          WAVE 3       │
│  ┌─────────┐ ┌─────────┐    ┌─────────┐ ┌─────────┐    ┌─────────┐ │
│  │ Plan 01 │ │ Plan 02 │ →  │ Plan 03 │ │ Plan 04 │ →  │ Plan 05 │ │
│  │ User    │ │ Product │    │ Orders  │ │ Cart    │    │ Checkout│ │
│  │ Model   │ │ Model   │    │ API     │ │ API     │    │ UI      │ │
│  └─────────┘ └─────────┘    └─────────┘ └─────────┘    └─────────┘ │
│       │           │              ↑           ↑              ↑       │
│       └───────────┴──────────────┴───────────┘              │       │
│              Dependencies: Plan 03 needs Plan 01            │       │
│                          Plan 04 needs Plan 02              │       │
│                          Plan 05 needs Plans 03 + 04        │       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Wave 执行优势**：
- 独立计划 → 同一 wave → 并行执行
- 依赖计划 → 更晚的 wave → 等依赖完成
- 文件冲突 → 顺序执行或合并计划

### 文件结构

```
项目根目录/
├── PROJECT.md          # 项目概述
├── REQUIREMENTS.md     # 需求文档
├── ROADMAP.md          # 阶段路线图
├── STATE.md            # 当前状态追踪
├── .planning/
│   ├── research/       # 研究文档
│   ├── 1-CONTEXT.md    # 阶段 1 决策上下文
│   ├── 1-RESEARCH.md   # 阶段 1 研究结果
│   ├── 1-1-PLAN.md     # 阶段 1 计划 1
│   ├── 1-2-PLAN.md     # 阶段 1 计划 2
│   ├── 1-1-SUMMARY.md  # 阶段 1 计划 1 执行总结
│   └── 1-VERIFICATION.md # 阶段 1 验证报告
```

---

## 组件管理器集成

GSD 已集成到 AI Component Manager：

### 组件信息

| 属性 | 值 |
|------|---|
| **名称** | gsd |
| **类别** | framework |
| **图标** | 🚀 |
| **依赖** | npx, node |
| **npm 包** | get-shit-done-cc |
| **仓库** | https://github.com/gsd-build/get-shit-done.git |
| **支持工具** | claude, opencode, gemini, cursor, codex, windsurf |

### 组件命令

| 命令 | 功能 |
|------|------|
| `:AIComponents` | 打开组件选择器 |
| `:AIComponentInstall gsd` | 安装 GSD |
| `:AIComponentUpdate gsd` | 更新 GSD |
| `:AIComponentSwitch opencode gsd` | 设置 OpenCode 使用 GSD |

### 快捷键

- `<leader>kc` — 打开组件选择器

---

## 推荐配置

### 跳过权限确认模式

GSD 设计目标是无摩擦自动化。推荐使用：

```bash
claude --dangerously-skip-permissions
```

### 细粒度权限配置

如果不使用 `--dangerously-skip-permissions`，可在 `.claude/settings.json` 中配置：

```json
{
  "permissions": {
    "allow": [
      "Bash(date:*)",
      "Bash(echo:*)",
      "Bash(cat:*)",
      "Bash(ls:*)",
      "Bash(mkdir:*)",
      "Bash(wc:*)",
      "Bash(head:*)",
      "Bash(tail:*)",
      "Bash(sort:*)",
      "Bash(grep:*)",
      "Bash(tr:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git status:*)",
      "Bash(git log:*)",
      "Bash(git diff:*)",
      "Bash(git tag:*)"
    ]
  }
}
```

---

## 与 ECC 的区别

| 特性 | GSD | ECC |
|------|-----|-----|
| **核心理念** | Spec-driven 开发 | 规则/命令/代理框架 |
| **解决问题** | Context rot | 编码标准化 |
| **工作流** | 项目阶段管理 | 代码质量检查 |
| **主要命令** | `/gsd-*` | `/plan`, `/tdd`, `/code-review` |
| **依赖** | npx, node | git, npm, node |
| **安装方式** | npx 按需 / npm 全局 | git clone + npm install |

**建议**：可以同时安装两者，GSD 用于项目管理，ECC 用于代码质量。

---

## 常见问题

### Q: GSD 和 ECC 可以同时使用吗？
A: 可以。GSD 专注于项目阶段管理，ECC 专注于代码质量和规则。建议先用 GSD 规划项目，再用 ECC 审查代码。

### Q: npx 方式和 npm 全局安装有什么区别？
A: npx 每次运行自动使用最新版本，适合保持更新；npm 全局安装适合稳定版本偏好或 CI 环境。

### Q: 如何在 CI 环境安装 GSD？
A: 使用非交互式安装：`npx get-shit-done-cc --claude --global`

### Q: STATE.md 与实际文件不一致怎么办？
A: 运行 `/gsd-state-validate` 检测偏差，然后用 `/gsd-state-sync` 从实际状态重建。

### Q: 研究门控是什么？
A: 当 RESEARCH.md 有未解决的开放问题时，系统会阻止规划，确保研究完成后再继续。

---

## 参考链接

- 配置目录: `~/.claude/gsd/`
- 命令目录: `~/.claude/commands/gsd/`
- 代理目录: `~/.claude/agents/gsd/`
- Hooks 目录: `~/.claude/hooks/gsd/`
- Skills 目录: `~/.claude/skills/gsd-*/`
- GitHub: https://github.com/gsd-build/get-shit-done
- npm: https://www.npmjs.com/package/get-shit-done-cc
- Discord: https://discord.gg/mYgfVNfA2r
- 组件管理器文档: [docs/COMPONENT_MANAGER_GUIDE.md](docs/COMPONENT_MANAGER_GUIDE.md)

---