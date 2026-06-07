# Basic Memory 与 Pi / Obsidian 集成分析

> 基于 https://github.com/basicmachines-co/basic-memory 项目研究

---

## 一、Basic Memory 核心概念

### 1.1 架构概述

Basic Memory 是一个本地优先的知识管理系统，核心特点：

| 特性 | 说明 |
|------|------|
| **存储格式** | 纯 Markdown 文件 + SQLite 索引 |
| **知识图谱** | Observations（事实） + Relations（链接） |
| **搜索** | 混合全文 + 向量语义搜索（FastEmbed） |
| **协议** | MCP (Model Context Protocol) 原生支持 |
| **同步** | 本地文件系统 + 可选云端同步 |
| **Schema** | Picoschema 验证系统 |

### 1.2 Markdown 格式

```markdown
---
title: <Entity 标题>
permalink: <uri-slug>
tags: [可选, 标签]
---

# Observations
- [category] 内容 #标签 (上下文)

# Relations
- relation_type [[Target Entity]]
```

**关键点：**
- `Observations` = 分类的事实陈述
- `Relations` = Wiki 风格的实体链接
- `permalink` = 稳定的 URI 标识符
- 与 Obsidian 完全兼容（wikilink、frontmatter）

---

## 二、与 Pi 的集成可行性

### 2.1 Pi 的 MCP 支持

Pi 已支持 MCP 协议，配置路径：

```bash
# Pi MCP 配置 ~/.pi/agent/mcp.template.jsonc
{
  "servers": {
    "basic-memory": {
      "type": "stdio",
      "command": "uvx",
      "args": ["basic-memory", "mcp"]
    }
  }
}
```

### 2.2 集成方式：参考 OpenClaw 实现

OpenClaw 的集成方式（`integrations/openclaw/`）：

**核心组件：**

1. **Plugin 入口** (`index.ts`)
   - 注册 MCP 工具
   - 管理 long-lived BM 进程连接
   - Auto-capture / Auto-recall hooks

2. **Context Engine** (`context-engine/basic-memory-context-engine.ts`)
   - 组合搜索：MEMORY.md + 知识图谱 + 活跃任务
   - Session start 时注入上下文

3. **Hooks**
   - `capture.ts` — 自动记录对话到每日笔记
   - `recall.ts` — 会话开始时加载活跃任务

**Pi 可复用的模式：**

| 模式 | 说明 | Pi 实现路径 |
|------|------|-------------|
| **Extension** | Pi extension 作为 MCP client | `~/.pi/agent/extensions/basic-memory.ts` |
| **Skill** | Pi skill 指导 BM 使用 | `~/.pi/agent/skills/basic-memory/SKILL.md` |
| **Hook** | Pi hook 自动 capture/recall | `~/.pi/agent/hooks/basic-memory-capture.ts` |
| **Command** | Pi prompt/slash command | `~/.pi/agent/prompts/bm-*.md` |

### 2.3 推荐集成方案

**方案 A：Minimal MCP 集成（推荐起步）**

只需添加 MCP server 配置：

```jsonc
// ~/.pi/agent/mcp.json
{
  "servers": {
    "basic-memory": {
      "type": "stdio",
      "command": "uvx",
      "args": ["basic-memory", "mcp"],
      "env": {
        "BASIC_MEMORY_PROJECT": "pi-agent"
      }
    }
  }
}
```

Pi 通过 MCP 获得所有 BM 工具：
- `write_note`、`read_note`、`edit_note`
- `search`、`search_notes`
- `build_context`
- `schema_*` 系列

**方案 B：完整 Plugin 集成（参考 OpenClaw）**

创建 Pi extension：

```typescript
// ~/.pi/agent/extensions/basic-memory.ts
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export default async function (api: ExtensionAPI, ctx: ExtensionContext) {
  // 1. 注册工具（透传 MCP）
  api.registerTool({
    name: "memory_search",
    description: "搜索 Basic Memory 知识图谱",
    inputSchema: { ... },
    handler: async (params) => {
      return await api.mcp.call("basic-memory", "search", params);
    }
  });

  // 2. Session start hook
  api.onSessionStart(async () => {
    const recent = await api.mcp.call("basic-memory", "recent_activity", {
      timeframe: "24h"
    });
    // 注入上下文...
  });

  // 3. Auto-capture hook
  api.onMessage(async (message) => {
    if (message.role === "assistant" && message.content.length > 100) {
      await api.mcp.call("basic-memory", "write_note", {
        title: `Session ${new Date().toISOString().split('T')[0]}`,
        content: message.content,
      });
    }
  });
}
```

**方案 C：Skill + Command 集成**

创建 Pi skill 指导 BM 使用模式：

```markdown
# ~/.pi/agent/skills/basic-memory/SKILL.md

## Use when
- 需要持久化知识跨会话
- 需要搜索过往决策和上下文
- 需要构建知识图谱

## Tools
- `write_note`: 创建/更新笔记
- `search`: 语义搜索知识库
- `build_context`: 导航关系链

## Patterns
1. **Session Briefing**: 会话开始时调用 `recent_activity` 获取近期工作
2. **Decision Capture**: 重要决策后用 `write_note` 记录
3. **Context Recovery**: 需要历史上下文时用 `search` + `build_context`
```

### 2.4 集成优先级建议

| 优先级 | 任务 | 工作量 |
|--------|------|--------|
| **P0** | MCP server 配置 | 5 分钟 |
| **P1** | 创建 BM skill 文档 | 30 分钟 |
| **P2** | 创建 capture/recall hooks | 2 小时 |
| **P3** | 完整 extension 实现 | 4-8 小时 |

---

## 三、与 Obsidian 的集成

### 3.1 天然兼容性

Basic Memory 与 Obsidian **无需额外集成**：

| 兼容点 | 说明 |
|--------|------|
| **文件格式** | BM 的 Markdown 文件直接在 Obsidian 中打开 |
| **Wikilinks** | BM 的 `[[Target]]` 链接 = Obsidian 的 wikilink |
| **Frontmatter** | BM 的 YAML frontmatter = Obsidian 的 properties |
| **Graph View** | BM 的 Relations 在 Obsidian graph view 中可视化 |
| **双向编辑** | Obsidian 编辑 → BM 同步；BM 写入 → Obsidian 可见 |

### 3.2 配置方式

**Obsidian 配置：**

1. 将 Obsidian vault 指向 BM project 目录：
   ```
   ~/basic-memory/  → Obsidian vault root
   ```

2. BM project 配置：
   ```bash
   basic-memory project add my-vault ~/basic-memory
   ```

3. 在 Obsidian 中启用：
   - **核心插件：** Backlinks、Graph view、Outgoing links
   - **社区插件：** Dataview（读取 frontmatter）、Templater（模板）

### 3.3 Obsidian + BM 工作流

**场景 1：AI 写入，人类编辑**

```
AI (via MCP) → write_note("Meeting Notes") → ~/basic-memory/meeting-notes.md
Obsidian     → 打开 meeting-notes.md → 手动补充细节
AI           → read_note("Meeting Notes") → 看到人类编辑的内容
```

**场景 2：人类创建，AI 索引**

```
Obsidian     → 创建 project-ideas.md → 添加 wikilinks [[Project A]]
BM sync      → 检测文件 → 索引到知识图谱
AI           → search("project ideas") → 返回结果 + 相关链接
```

**场景 3：Graph View 双向可视化**

```
BM Relations → relates_to [[Project A]] → depends_on [[Task B]]
Obsidian     → Graph view 显示节点和边
AI           → build_context("memory://project-ideas") → 遍历图谱
```

### 3.4 推荐的 Obsidian 插件

| 插件 | 用途 | 与 BM 的关系 |
|------|------|--------------|
| **Dataview** | Query frontmatter 和内容 | 可查询 BM 的 tags、permalink、observations |
| **Templater** | 模板系统 | 创建符合 BM schema 的模板 |
| **Graph Analysis** | 图谱分析 | 可视化 BM 的 Relations |
| **Calendar** | 日历视图 | BM 的每日笔记按日期显示 |

---

## 四、完整集成架构

### 4.1 三端协作架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        Basic Memory Core                        │
│                    (Markdown + SQLite + MCP)                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓↑ MCP              ↓↑ File System
        ┌─────────────────────┴─────────┐    ┌────┴──────────────┐
        │         Pi Agent              │    │     Obsidian      │
        │  - MCP client                 │    │  - 直接读写 Markdown │
        │  - Extension (optional)       │    │  - Graph view     │
        │  - Skills & Hooks             │    │  - Backlinks      │
        │  - Auto-capture/recall        │    │  - Dataview       │
        └───────────────────────────────┘    └───────────────────┘
                              ↓↑
        ┌─────────────────────────────────────────────────────────┐
        │                    Basic Memory Cloud                   │
        │                   (可选：跨设备同步)                      │
        └─────────────────────────────────────────────────────────┘
```

### 4.2 数据流

```
Pi 会话开始
  ↓
BM MCP: recent_activity(24h) + list_directory(memory/tasks)
  ↓
注入活跃任务和近期笔记到 Pi context
  ↓
Pi 对话进行
  ↓
重要决策 → BM MCP: write_note()
用户提问 → BM MCP: search() + build_context()
  ↓
对话结束 → BM MCP: write_note(daily summary)
  ↓
Obsidian 打开 vault → 看到所有 BM 生成的笔记
  ↓
手动编辑 → BM sync 检测 → 索引更新
  ↓
下次 Pi 会话 → 看到人类编辑的内容
```

---

## 五、实施建议

### 5.1 快速开始（30 分钟）

**步骤 1：安装 Basic Memory CLI**

```bash
# macOS/Linux
brew install uv
uv tool install basic-memory

# 验证
basic-memory status
```

**步骤 2：创建 Pi project**

```bash
basic-memory project add pi-agent ~/.pi-memory
basic-memory project default pi-agent
```

**步骤 3：配置 Pi MCP**

```bash
# 添加到 ~/.pi/agent/mcp.json
cat >> ~/.pi/agent/mcp.json << 'EOF'
{
  "servers": {
    "basic-memory": {
      "type": "stdio",
      "command": "uvx",
      "args": ["basic-memory", "mcp"]
    }
  }
}
EOF
```

**步骤 4：重启 Pi**

```bash
pi
# 测试：在 Pi 中输入
# "用 Basic Memory 搜索关于项目架构的笔记"
```

### 5.2 Obsidian 配置（10 分钟）

1. 打开 Obsidian → Create new vault
2. 选择路径：`~/.pi-memory`
3. 启用核心插件：Graph view、Backlinks、Outgoing links
4. 安装社区插件：Dataview、Templater

### 5.3 验证集成

**在 Pi 中：**

```
> 创建一个关于 Basic Memory 集成的笔记，记录架构决策。

> 搜索我关于知识管理的笔记。

> 构建关于 Basic Memory 的上下文图谱。
```

**在 Obsidian 中：**

- 打开 `~/.pi-memory` vault
- 查看刚创建的笔记
- 查看 Graph view 中的节点和链接

---

## 六、潜在问题与解决方案

| 问题 | 解决方案 |
|------|----------|
| **BM CLI 未找到** | `uv tool install basic-memory`；或用 Homebrew |
| **搜索无结果** | 检查 BM connected；验证 `basic-memory status`；等待 sync |
| **同步冲突** | BM Cloud 使用 rclone 冲突解决；本地用 git merge |
| **Schema 验证失败** | 设置 `validation: warn`；调整 schema 或笔记内容 |
| **性能问题** | 禁用语义搜索：`BASIC_MEMORY_SEMANTIC_SEARCH_ENABLED=false` |

---

## 七、与现有 ECC 技术栈的关系

### 7.1 与 Superpowers Skills 的互补

| Superpowers Skill | Basic Memory 角色 |
|-------------------|-------------------|
| **verification-before-completion** | BM 记录验证结果，跨会话追踪 |
| **systematic-debugging** | BM 搜索过往类似 bug 和解决方案 |
| **test-driven-development** | BM 记录测试策略和覆盖率决策 |
| **writing-plans** | BM 存储长期计划，跨会话引用 |
| **knowledge-ops** | BM 作为底层存储引擎 |

### 7.2 与 OpenSpec 的整合

```markdown
---
title: integrate-pi-neovim-ai-sync
type: openspec-change
schema: OpenSpecChange
---

## Observations
- [decision] Pi sync target added to Neovim AI module
- [status] Implementation complete, review passed
- [artifact] lua/ai/pi.lua created

## Relations
- implements [[OpenSpec Spec]]
- relates_to [[Neovim AI Module]]
- depends_on [[Pi Settings Template]]
```

BM 可作为 OpenSpec 变更的持久化存储，跨会话追踪设计决策和实现状态。

---

## 八、结论

### 可行性评估

| 集成目标 | 可行性 | 工作量 | 推荐度 |
|----------|--------|--------|--------|
| **Pi MCP 集成** | ✅ 完全可行 | 5 分钟 | ⭐⭐⭐⭐⭐ |
| **Pi Extension** | ✅ 参考 OpenClaw | 4-8 小时 | ⭐⭐⭐⭐ |
| **Obsidian 集成** | ✅ 天然兼容 | 10 分钟 | ⭐⭐⭐⭐⭐ |
| **三端协作** | ✅ 已验证 | 30 分钟 | ⭐⭐⭐⭐⭐ |

### 推荐下一步

1. **立即执行：** MCP server 配置 + Obsidian vault 配置（30 分钟）
2. **短期规划：** 创建 BM skill + capture/recall hooks（1-2 天）
3. **长期优化：** 完整 Pi extension + Schema 定义 + 团队协作流程（1-2 周）

---

**参考资源：**

- Basic Memory GitHub: https://github.com/basicmachines-co/basic-memory
- Basic Memory Docs: https://docs.basicmemory.com
- OpenClaw Integration: https://github.com/basicmachines-co/basic-memory/tree/main/integrations/openclaw
- MCP Protocol: https://modelcontextprotocol.io
- Obsidian: https://obsidian.md