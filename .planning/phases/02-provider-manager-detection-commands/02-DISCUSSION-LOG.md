# Phase 2: Provider Manager Detection Commands - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 02-provider-manager-detection-commands
**Mode:** discuss
**Areas discussed:** 检测方式, 结果展示, 执行策略, 缓存策略

---

## 检测方式

| Option | Description | Selected |
|--------|-------------|----------|
| 发送最小 Chat 请求 | 向 /v1/chat/completions 发送 max_tokens=1 请求，最准确反映实际可用性 | ✓ |
| 调用 /v1/models 列表接口 | 复用 fetch_models.lua 模式，成本低但不反映 Chat 能力 | |
| HTTP HEAD 探测端点 | 只探测端点是否可达，最快但无法验证 API Key | |

**User's choice:** 发送最小 Chat 请求（推荐）
**Notes:** 用户确认使用 Chat 请求检测，确保能验证完整的 API 链路（端点 + Key + 模型）

## 结果展示

| Option | Description | Selected |
|--------|-------------|----------|
| vim.notify 通知 | 简单通知，单条结果一行 | |
| 浮动窗口汇总 | 表格形式展示所有结果，信息量大 | ✓ |
| 仅输出到命令行 | 最轻量但体验简陋 | |

**User's choice:** 浮动窗口汇总
**Notes:** 用户希望看到完整的检测结果表格，而非简单通知

## 执行策略

| Option | Description | Selected |
|--------|-------------|----------|
| 全部逐个同步执行 | 简单但耗时长 | |
| 全部异步并发执行 | 最快但复杂 | |
| 异步但有并发限制 | 平衡速度和复杂度，限制为 3 个并发 | ✓ |

**User's choice:** 异步但有并发限制
**Notes:** 并发数限制为 3，避免触发 API 速率限制

## 缓存策略

| Option | Description | Selected |
|--------|-------------|----------|
| 不缓存，每次实时检测 | 确保最新但成本高 | |
| 按超时时间缓存 | 缓存结果，超过 timeout 后失效 | ✓ (变体) |
| 仅会话内缓存 | 简单实用但重启后丢失 | |

**User's choice:** 按需检测 + 缓存 + 切换 provider 时自动检测默认模型 + 其它时候靠手动命令驱动
**Notes:** 这是一个综合策略：日常依赖缓存，切换 provider 时自动检测默认模型，其他时候手动触发。缓存存储在 `~/.local/state/nvim/ai_detection_cache.lua`。

---

## the agent's Discretion

- 浮动窗口的具体样式（边框、高亮颜色、宽度）
- 具体的 vim.loop 异步实现方式
- 错误分类的细化程度
- 测试覆盖的具体用例设计

## Deferred Ideas

- 自动检测并更新状态指示器（Phase 3）
- Agent-Model 配置（v2 requirements）
- 检测历史记录
