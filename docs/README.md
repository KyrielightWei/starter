# 配置文档索引

本目录包含 Neovim 配置的详细使用说明。

## 文档列表

| 文档 | 说明 |
|------|------|
| [ai-module.md](ai-module.md) | AI 模块配置指南 - 快捷键、命令、后端切换 |
| [diffview.md](diffview.md) | Diffview 配置指南 - 代码审查工作流 |
| [terminal.md](terminal.md) | 终端管理配置 - 多终端、选择器、AI CLI |
| [skill-studio.md](skill-studio.md) | Skill Studio - Skill/MCP 创作工具 |
| [COMPONENT_MANAGER_GUIDE.md](COMPONENT_MANAGER_GUIDE.md) | AI Component Manager - 组件管理器使用指南 |

## 框架指南

| 文档 | 说明 |
|------|------|
| [ECC_GUIDE.md](../ECC_GUIDE.md) | Everything Claude Code - 规则/命令/代理框架 |
| [GSD_GUIDE.md](../GSD_GUIDE.md) | Get Shit Done - Spec-driven 开发系统 |
| [GSD_PI_GUIDE_CN.md](GSD_PI_GUIDE_CN.md) | GSD PI 中文指南 - Prompt Instrumentation |

---

## 开发者文档

内部设计文档和实现计划位于 [`dev/`](dev/) 目录：

| 文档 | 说明 |
|------|------|
| [CC_SWITCH_COMPARISON.md](dev/CC_SWITCH_COMPARISON.md) | CC Switch 对比分析 - 功能对比和互补方案 |
| [COMPONENT_MANAGER_PLAN.md](dev/COMPONENT_MANAGER_PLAN.md) | Component Manager 实现计划 |
| [PROVIDER_MODEL_SWITCHER_PLAN.md](dev/PROVIDER_MODEL_SWITCHER_PLAN.md) | Provider/Model Switcher 设计文档 |
| [skill-studio-plan.md](dev/skill-studio-plan.md) | Skill Studio 实现计划 |
| [skill-studio-todo.md](dev/skill-studio-todo.md) | Skill Studio 开发任务清单 |

---

## 快速参考

### AI 交互 (`<leader>k`)

| 快捷键 | 功能 |
|--------|------|
| `<leader>kc` | AI Component Manager (组件管理器) |
| `<leader>kC` | AI Chat |
| `<leader>ke` | AI Edit (visual) |
| `<leader>ks` | Model Switch |
| `<leader>kk` | Key Manager |

### Git Diff (`<leader>g`)

| 快捷键 | 功能 |
|--------|------|
| `<leader>gv` | Diffview Open |
| `<leader>gV` | Diffview Close |
| `<leader>gf` | File History |

### Terminal (`<leader>t`)

| 快捷键 | 功能 |
|--------|------|
| `<leader>tt` | Terminal Selector |
| `<leader>ta` | Toggle All Terminals |
| `<leader>tl` | Send Line |

---

## 配置文件位置

| 配置 | 路径 |
|------|------|
| 插件配置 | `lua/plugins/*.lua` |
| AI 模块 | `lua/ai/` |
| API Keys | `~/.local/state/nvim/ai_keys.lua` |
| 本地 Git 配置 | `~/.local/state/nvim/diffview_local.lua` |