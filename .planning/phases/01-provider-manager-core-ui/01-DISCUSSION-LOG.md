# Phase 1: Provider Manager Core UI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-21
**Phase:** 01-provider-manager-core-ui
**Areas discussed:** 管理面板交互模式, CRUD 操作 UI 设计, Provider 编辑范围

---

## 管理面板交互模式

| Option | Description | Selected |
|--------|-------------|----------|
| 扩展现有 picker | 扩展 model_switch，增加 CRUD actions（如Ctrl-A添加、Ctrl-D删除、Ctrl-E编辑） | ✓ |
| 新建管理面板 | 新建独立管理面板，单步展示所有 Provider+Model，行级 CRUD | |
| 两者并存 | 两个入口共存：快速切换用 model_switch，管理用新 panel | |

**User's choice:** 扩展现有 picker
**Notes:** 保持与现有 model_switch.lua 一致的两步流程，用户熟悉

---

## CRUD 操作 UI 设计

### 添加操作

| Option | Description | Selected |
|--------|-------------|----------|
| Ctrl-A 添加 | Ctrl-A 触发添加，弹出 vim.ui.input 输入 provider 名称 | ✓ |
| 空行回车添加 | 空行回车触发添加（列表底部留空行） | |
| Ctrl-N 新建 | Ctrl-N 新建，更直观的新建快捷键 | |

**User's choice:** Ctrl-A 添加

### 删除操作

| Option | Description | Selected |
|--------|-------------|----------|
| Ctrl-D 删除 | Ctrl-D 删除当前选中项，确认后删除 | ✓ |
| Ctrl-X 删除 | Ctrl-X 删除，避免与Ctrl-D（diff）冲突 | |
| Shift-D 删除 | Shift-D 删除，区分删除和 diff 操作 | |

**User's choice:** Ctrl-D 删除

### 编辑操作

| Option | Description | Selected |
|--------|-------------|----------|
| Ctrl-E 编辑 | Ctrl-E 编辑，直接打开 providers.lua 编辑配置 | ✓ |
| Ctrl-R 编辑 | Ctrl-R 编辑（rename/revise），避免与Ctrl-E（其他功能）冲突 | |
| 弹出输入框编辑 | 弹出 vim.ui.input 编辑单字段，不直接打开文件 | |

**User's choice:** Ctrl-E 编辑
**Notes:** 直接打开文件更灵活，provider 配置涉及多个字段

---

## Provider 编辑范围

| Option | Description | Selected |
|--------|-------------|----------|
| endpoint/base_url | API endpoint 地址，用户可能需要自定义 | ✓ |
| 默认模型 | 默认模型名称，切换时使用 | ✓ |
| static_models 列表 | 可用模型列表，用于 picker 显示 | ✓ |
| Provider 名称（重命名） | Provider 显示名称，便于识别 | ✓ |

**User's choice:** 都要（所有字段）
**Notes:** 用户需要完整的配置管理能力

---

## 入口命令/Keymap

**the agent discretion** — 用户未深入讨论，由 the agent 决策

**Agent's decision:**
- `<leader>kp` keymap — 与 `<leader>ks` (Model Switch) 彼邻，符合 `<leader>k` 前缀习惯
- `:AIProviderManager` command — 直观的命名

---

## Deferred Ideas

None — discussion stayed within phase scope.