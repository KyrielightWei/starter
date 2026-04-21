# Requirements: Neovim AI Integration Enhancement

**Defined:** 2026-04-21
**Core Value:** 让用户能够高效管理多个 AI Provider/Model，并在 GSD 多 commit 工作流中便捷地 Review 历史变更。

## v1 Requirements

MVP必需功能，覆盖 P1优先级。

### Provider Manager - Core UI

- [ ] **PMGR-01**: 用户可以通过管理面板查看所有已配置的 Provider 和 Model
- [ ] **PMGR-02**: 用户可以在管理面板中添加新的 Provider/Model 配置
- [ ] **PMGR-03**: 用户可以在管理面板中删除 Provider/Model 配置
- [ ] **PMGR-04**: 用户可以在管理面板中编辑 Provider/Model 配置（重命名、修改 endpoint 等）

### Provider Manager - Availability Detection

- [ ] **PMGR-05**: 用户可以通过命令手动触发检测指定 Provider/Model 的可用性
- [ ] **PMGR-06**: 用户可以通过命令手动触发检测所有 Provider/Model 的可用性
- [ ] **PMGR-07**: 用户修改默认模型时，系统自动检测该模型的可用性（确保默认模型有效）
- [ ] **PMGR-08**: 可用性检测结果以状态标识呈现（可用/不可用/超时/错误）

### Commit Review - Picker & Diff

- [ ] **CDRV-01**: 用户可以通过浮动窗口选择 Commit 进行 Review
- [ ] **CDRV-02**: 默认显示未 Push 的 Commit 列表
- [ ] **CDRV-03**: 用户可以配置显示的 Commit 数量（从最新往前计数）
- [ ] **CDRV-04**: 用户可以设置 Base Commit 作为 Review 范围边界
- [ ] **CDRV-05**: 用户选择单个 Commit 时，显示该 Commit 与前一 Commit 的 Diff
- [ ] **CDRV-06**: 用户选择两个 Commit 时，显示这两个 Commit 之间的 Diff

## v2 Requirements

P2/P3 功能，后续版本实现。

### Provider Manager - Agent Config

- **PMGR-09**: 用户可以为不同类型的 Agent（如 ECC/GSD 的 planner、coder、reviewer）配置合适的 Model
- **PMGR-10**: Agent-Model 配置按任务类型自动匹配（编码类任务匹配 coding-capable 模型等）
- **PMGR-11**: 用户可以手动修改 Agent-Model 配置
- **PMGR-12**: Agent-Model 配置与 API Key 存储在同一位置（`~/.local/state/nvim/ai_keys.lua`）
- **PMGR-13**: 用户可以为 Agent-Model 配置设置重命名（多个配置方案）
- **PMGR-14**: 系统提供默认 Agent-Model 配置方案
- **PMGR-15**: 用户切换默认模型时，系统自动加载与该模型关联的 Agent 配置方案
- **PMGR-16**: 对于支持多 Provider 的工具（如 OpenCode），可用模型列表可来自多个 Provider

### Commit Review - Comments & Summary

- **CDRV-07**: 用户可以在 Diff View 中为某行追加持久化评论
- **CDRV-08**: Review 完成后，系统自动生成 Markdown 结构化的 Review 汇总文件
- **CDRV-09**: Review 汇总文件包含 Commit SHA、文件名、行号、评论内容
- **CDRV-10**: Review 汇总文件存放于项目 `.tmp/` 目录
- **CDRV-11**: Review 汇总文件命名格式为时间 + 涉及的 Commit 范围

## Out of Scope

明确排除的功能及原因。

| Feature | Reason |
|---------|--------|
| 动态修改历史 Commit | rebase 后续 commit 过于复杂，风险高 |
| Claude Code 多 Provider 支持 | Claude Code 仅支持 Claude 模型，无需多 Provider |
| 成本/速度自动优化 | 由用户手动调整解决，系统不做自动决策 |
| 全量 Provider 自动检测 | 改为手动命令驱动，避免启动时大量 API 调用 |
| Review 期间动态修改代码 | 放弃此功能，专注于 Review 注释能力 |

## Traceability

各Phase覆盖的需求映射。Roadmap 创建时更新。

### v1 Requirements (Current Roadmap)

| Requirement | Phase | Status |
|-------------|-------|--------|
| PMGR-01 | Phase 1 | Pending |
| PMGR-02 | Phase 1 | Pending |
| PMGR-03 | Phase 1 | Pending |
| PMGR-04 | Phase 1 | Pending |
| PMGR-05 | Phase 2 | Pending |
| PMGR-06 | Phase 2 | Pending |
| PMGR-07 | Phase 3 | Pending |
| PMGR-08 | Phase 3 | Pending |
| CDRV-01 | Phase 4 | Pending |
| CDRV-02 | Phase 4 | Pending |
| CDRV-03 | Phase 5 | Pending |
| CDRV-04 | Phase 5 | Pending |
| CDRV-05 | Phase 6 | Pending |
| CDRV-06 | Phase 6 | Pending |

### v2 Requirements (Future Roadmap)

| Requirement | Status |
|-------------|--------|
| PMGR-09 | Deferred |
| PMGR-10 | Deferred |
| PMGR-11 | Deferred |
| PMGR-12 | Deferred |
| PMGR-13 | Deferred |
| PMGR-14 | Deferred |
| PMGR-15 | Deferred |
| PMGR-16 | Deferred |
| CDRV-07 | Deferred |
| CDRV-08 | Deferred |
| CDRV-09 | Deferred |
| CDRV-10 | Deferred |
| CDRV-11 | Deferred |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14 ✓
- Unmapped: 0 ✓
- v2 requirements: 13 (deferred for future milestone)

---
*Requirements defined: 2026-04-21*
*Last updated: 2026-04-21 after roadmap creation*