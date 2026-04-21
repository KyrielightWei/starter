# LazyVim Neovim AI Integration Enhancement

## What This Is

这是一个成熟的 LazyVim Neovim 配置，带有一个完整的 AI 集成层。核心价值是 `lua/ai/` 模块，它为多个 AI 后端（Avante、OpenCode）和提供商（OpenAI、DeepSeek、Qwen、GLM 等）提供统一接口。本次目标是增强 Provider/Model 管理能力和 Commit Diff Review 功能。

## Core Value

**让用户能够高效管理多个 AI Provider/Model，并在 GSD 多 commit 工作流中便捷地 Review 历史变更。**

## Requirements

### Validated

从现有代码库推断的已实现功能：

- ✓ Provider 注册系统 — 12 个 LLM provider 支持（deepseek, openai, qwen, minimax, kimi, glm, bailian, bailian_coding, dashscope, moonshot, ollama）
- ✓ API Key 管理 — 存储于 `~/.local/state/nvim/ai_keys.lua`，支持 CRUD
- ✓ 配置解析器 — 4层合并（defaults → template → project → dynamic providers），支持 `${ref:...}` 动态引用
- ✓ Backend 适配器模式 — avante_adapter.lua 为默认后端，接口标准化
- ✓ 模型快速切换 — `<leader>ks` keymap，FZF-lua picker
- ✓ 终端集成 — toggleterm 封装，支持 OpenCode/Claude Code/Aider
- ✓ Skill Studio — 10 模块技能生命周期管理
- ✓ 同步引擎 — 向 OpenCode/Claude Code 自动同步配置
- ✓ 配置监听器 — 文件变更自动热更新
- ✓ 测试套件 — 5 个 spec 文件覆盖核心模块
- ✓ DiffView 集成 — diffview.nvim 支持未提交变更查看

### Active

本次开发目标：

**功能 1: Provider/Model 交互式管理系统**

- [ ] **PMGR-01**: 用户可以通过管理面板查看所有已配置的 Provider 和 Model
- [ ] **PMGR-02**: 用户可以在管理面板中添加新的 Provider/Model 配置
- [ ] **PMGR-03**: 用户可以在管理面板中删除 Provider/Model 配置
- [ ] **PMGR-04**: 用户可以在管理面板中编辑 Provider/Model 配置（重命名、修改 endpoint 等）
- [ ] **PMGR-05**: 用户可以通过命令手动触发检测指定 Provider/Model 的可用性
- [ ] **PMGR-06**: 用户可以通过命令手动触发检测所有 Provider/Model 的可用性
- [ ] **PMGR-07**: 用户修改默认模型时，系统自动检测该模型的可用性（确保默认模型有效）
- [ ] **PMGR-08**: 可用性检测结果以状态标识呈现（可用/不可用/超时/错误）
- [ ] **PMGR-09**: 用户可以为不同类型的 Agent（如 ECC/GSD 的 planner、coder、reviewer）配置合适的 Model
- [ ] **PMGR-10**: Agent-Model 配置按任务类型自动匹配（编码类任务匹配 coding-capable 模型等）
- [ ] **PMGR-11**: 用户可以手动修改 Agent-Model 配置
- [ ] **PMGR-12**: Agent-Model 配置与 API Key 存储在同一位置（`~/.local/state/nvim/ai_keys.lua`）
- [ ] **PMGR-13**: 用户可以为 Agent-Model 配置设置重命名（多个配置方案）
- [ ] **PMGR-14**: 系统提供默认 Agent-Model 配置方案
- [ ] **PMGR-15**: 用户切换默认模型时，系统自动加载与该模型关联的 Agent 配置方案
- [ ] **PMGR-16**: 对于支持多 Provider 的工具（如 OpenCode），可用模型列表可来自多个 Provider

**功能 2: 交互式 Commit Diff Review**

- [ ] **CDRV-01**: 用户可以通过浮动窗口选择 Commit 进行 Review
- [ ] **CDRV-02**: 默认显示未 Push 的 Commit 列表
- [ ] **CDRV-03**: 用户可以配置显示的 Commit 数量（从最新往前计数）
- [ ] **CDRV-04**: 用户可以设置 Base Commit 作为 Review 范围边界
- [ ] **CDRV-05**: 用户选择单个 Commit 时，显示该 Commit 与前一 Commit 的 Diff
- [ ] **CDRV-06**: 用户选择两个 Commit 时，显示这两个 Commit 之间的 Diff
- [ ] **CDRV-07**: 用户可以在 Diff View 中为某行追加持久化评论
- [ ] **CDRV-08**: Review 完成后，系统自动生成 Markdown 结构化的 Review 汇总文件
- [ ] **CDRV-09**: Review 汇总文件包含 Commit SHA、文件名、行号、评论内容
- [ ] **CDRV-10**: Review 汇总文件存放于项目 `.tmp/` 目录
- [ ] **CDRV-11**: Review 汇总文件命名格式为时间 + 涉及的 Commit 范围

### Out of Scope

明确不做的事项及原因：

- 动态修改历史 Commit — rebase 后续 commit 过于复杂，风险高
- Claude Code 多 Provider 支持 — Claude Code 仅支持 Claude 模型，无需多 Provider
- 成本/速度自动优化 — 由用户手动调整解决，系统不做自动决策
- 全量 Provider 自动检测 —改为手动命令驱动，避免启动时大量 API 调用
- Review 期间动态修改代码 — 放弃此功能，专注于 Review 注释能力

## Context

**技术背景：**
- Lua 语言，LazyVim 插件系统架构
- 已有成熟的 Provider 注册、Key 管理、配置解析系统
- 已有 Backend 适配器模式，易于扩展
- 已有 FZF-lua/Telescope picker UI 基础
- 已有 diffview.nvim 集成

**用户痛点：**
- API Key 文件中定义了大量 Provider/Model，但部分无有效 Key
- 无法便捷地判断和管理哪些模型实际可用
- Agent 模型分配缺乏交互式配置能力
- DiffView 仅支持未提交变更，无法 Review GSD 生成的多 commit 历史

**已有模块可复用：**
- `providers.lua` — Provider 注册表
- `keys.lua` — Key 管理CRUD
- `model_switch.lua` — 模型切换 picker
- `config_resolver.lua` — 多层配置合并
- `plugins/git.lua` — diffview.nvim 配置
- `plugins/editor.lua` — fzf-lua/telescope picker

## Constraints

- **技术栈**: Lua 5.1/5.4（Neovim），必须兼容现有 LazyVim 模块结构
- **UI 框架**: 使用现有 FZF-lua 或 Telescope 作为 picker 后端
- **配置存储**: 与现有 `ai_keys.lua` 文件格式兼容
- **依赖限制**: 不引入新的 heavyweight 插件，优先复用现有依赖
- **性能要求**: 管理面板启动时间 < 500ms，可用性检测单次< 10s

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Provider 管理面板使用 FZF-lua | 已有 fzf-lua 集成，picker UI 经验成熟 | — Pending |
| 可用性检测采用手动命令驱动 | 避免 Neovim 启动时大量 API 调用，用户可控 | — Pending |
| Agent-Model 配置与 API Key 同文件存储 | 统一管理，用户熟悉该文件位置 | — Pending |
| Review 汇总文件存放 .tmp/ | 临时性质，不污染 .planning/ 目录 | — Pending |
| 放弃动态修改历史 Commit | rebase 操作复杂且风险高，专注 Review 注释 | — Pending |
| OpenCode 多 Provider 待验证 | 需调研 OpenCode 是否支持多 Provider endpoint| — Pending |

---

## Evolution

本文档在 phase 过渡和 milestone 边界时演进。

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-21 after initialization*