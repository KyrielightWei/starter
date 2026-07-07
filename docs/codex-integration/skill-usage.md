# Codex Delegate Skill 使用指南

本文档介绍如何使用 codex-delegate skill 将任务委托给 Codex CLI。

## 触发方式和边界

`codex-delegate` 是一个 skill 指令包，不是 OMP 内置命令。它可以指导助手在识别到 Codex 委托意图时调用 Codex MCP 工具，但不会自动给 OMP 二进制添加 `/codex` 命令、全局关键词路由或子代理注册。

### 1. 关键词/意图触发

在对话中使用以下关键词，助手应选择 `codex-delegate` skill：

- `用 codex` - 中文关键词
- `use codex` - 英文关键词
- `委托给 codex` - 中文关键词
- `交给 codex` - 中文关键词

**示例：**
```
用 codex 帮我重构这个函数
use codex to analyze this bug
委托给 codex 优化这些文件
```

### 2. 意图触发

当你的请求符合以下场景时，助手也应选择 `codex-delegate`：

- 需要审计日志用于报销
- 任务需要 OpenAI 模型
- 明确提到需要 Codex 的能力

## 上下文模式

Skill 支持三种上下文提取模式：

### 1. 智能模式（默认）

自动提取：
- 当前编辑的文件
- 相关文件（通过 import 分析）
- 最近 3 轮对话摘要

**使用示例：**
```
用 codex 重构这个函数
```

### 2. 完整模式

传递完整的会话历史和所有工具调用结果。

**使用示例：**
```
用 codex（完整上下文）分析这个问题
```

### 3. 手动模式

手动指定文件和行范围。

**使用示例：**
```
用 codex 优化这些文件：src/auth.ts:10-50, src/user.ts
```

## 多轮对话

Codex 支持多轮对话，通过 threadId 维持上下文。

### 第一轮对话

```
用户：用 codex 分析这个 bug
OMP：[调用 codex，显示分析结果]
```

### 后续对话

```
用户：那如何修复呢？
OMP：[使用 codex-reply 继续对话，显示修复方案]
```

首次调用 `codex` MCP 工具会返回 `threadId`。后续问题只有在当前助手会话保存了这个 `threadId` 时，才能通过 `codex-reply` 发送到同一个 Codex 会话。不要假设 OMP 二进制会跨会话自动持久化该值。

## 实际示例

### 示例 1: 代码重构

```
用户：用 codex 帮我重构 login 函数，改用 JWT token

OMP 处理：
1. 检测到 "用 codex"
2. 提取当前文件和上下文
3. 调用 `codex` MCP 工具
4. 显示重构方案
```

### 示例 2: Bug 分析

```
用户：用 codex 分析为什么用户登录后 session 会丢失

OMP 处理：
1. 提取相关代码和错误日志
2. 调用 `codex` MCP 工具分析
3. 显示问题原因和修复建议
```

### 示例 3: 手动指定文件

```
用户：委托给 codex 优化这些文件：src/auth.ts, src/user.ts

OMP 处理：
1. 解析文件列表
2. 只加载指定文件
3. 调用 `codex` MCP 工具优化
4. 显示优化结果
```

## 查看示例

更多详细示例请参考：

- [简单任务委托](../../skill/codex-delegate/examples/simple-delegation.md)
- [多轮对话](../../skill/codex-delegate/examples/multiturn-conversation.md)
- [手动指定上下文](../../skill/codex-delegate/examples/manual-context.md)

## 常见问题

### Q: 如何知道 skill 是否被触发？

A: 当助手选择该 skill 时，应显示类似 "使用 codex-delegate skill" 的提示。是否有额外 UI 提示取决于当前 OMP/技能运行时。

### Q: 可以跳过 skill 直接调用 Codex 吗？

A: 可以，但使用 skill 可以获得上下文提取、多轮对话等增强功能。

### Q: threadId 保存在哪里？

A: threadId 应保存在当前助手会话的显式状态或笔记中。如果运行时没有提供会话变量，后续追问需要重新提供 threadId 或重新开始 Codex 会话。

## 下一步

- 了解 [上下文提取](./context-extraction.md) 的详细工作原理
- 配置 [代理设置](./proxy-config.md)（如需要）
- 查看 [故障排除](./troubleshooting.md) 解决常见问题
