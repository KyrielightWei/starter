# Basic Memory 中文 README

> 翻译自：https://github.com/basicmachines-co/basic-memory

<!-- mcp-name: io.github.basicmachines-co/basic-memory -->
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![PyPI version](https://badge.fury.io/py/basic-memory.svg)](https://badge.fury.io/py/basic-memory)
[![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
![](https://badge.mcpx.dev?type=server 'MCP Server')

---

## 跳过安装 — 在云端试用 Basic Memory

Claude、Codex 或 Cursor 30 秒连接。无需 Python，无需 JSON，无需终端。
**$15.00/月终身锁定**（年付 $12.50/月）。7 天免费试用 — 第 7 天前随时取消。
Beta 定价 — 立即注册，价格永不上调。OSS 用户：代码 `BMFOSS` 享受额外 20% 折扣（3 个月）。

[开始免费试用 →](https://basicmemory.com)

### Basic Memory Teams 已上线！

为团队提供单一共享云工作空间。知识不再局限于个人 — 队友写的任何内容立即对所有人及其 AI 助手可用。
实时协作编辑笔记，人类与代理之间交接工作，构建一个连通的知识库而非分散的副本。

---

# Basic Memory

### 你的 AI 永不再遗忘。

在 Claude、Codex、Cursor、ChatGPT 或任何支持 [MCP](https://modelcontextprotocol.io) 的工具中继续上次的工作。
你的知识以 Markdown 文件形式存在，你和 AI 都可以读取、写入和搜索。

- **本地优先。** 磁盘上的纯文本。永久保存。
- **双向协作。** AI 和人类写入同一文件；同步保持一致。
- **真正的知识图谱。** 观察和 wikilink 累积形成上下文。
- **语义搜索。** 按意义查找笔记，不只是关键词。
- **MCP原生。** 与所有主流 AI 客户端和 IDE 兼容。
- **渐进式工具发现。** 每个工具都标记行为提示（只读、破坏性、幂等），代理按需选择正确的工具 — 不浪费上下文试探。
- **云端可选。** 想跨设备同步时使用 — 永不强制。

---

## 快速开始

选择适合你的路径。两者在同一 Markdown 上运行同一产品。

<table>
<tr>
<th width="50%">☁️ &nbsp; 云端</th>
<th width="50%">💻 &nbsp; 本地安装</th>
</tr>
<tr>
<td valign="top">

**30 秒。** 注册，连接 AI 客户端，完成。

- 在任何浏览器中工作
- 移动端、Web、桌面
- 内置跨设备同步
- 我们处理托管、备份、快照

**$15.00/月终身锁定** · 7 天免费试用 · 随时取消

[**开始免费试用 →**](https://basicmemory.com)

</td>
<td valign="top">

**2 分钟。** 安装，配置 AI 客户端，运行。

- 永久免费（AGPL-3.0）
- 所有数据在你的磁盘上
- 支持离线环境
- 需要通过 [`uv`](https://docs.astral.sh/uv/) 安装 Python

```bash
uv tool install basic-memory
```

[**配置你的客户端 ↓**](#连接你的-ai-客户端)

</td>
</tr>
</table>

---

## 用户评价

> Basic Memory 改变了我与 LLM 的整个关系。我从 GPT 和 Gemini 切换到只使用 Claude 和 Claude Code，正是因为这个集成，并正在全面改造我们公司的流程以围绕 Basic Memory 工作流。
>
> — **Alex**, TrainerDay

> Basic Memory 是 AI 聊天机器人缺失的"惊叹"因素。现在我无法想象没有它的 Claude 或 Claude Code。
>
> — **Caleb**, Caleb Picker Consulting

> 我不再在没有 Basic Memory 的情况下编码。它节省了大量时间，可以引用我当前未激活的项目并保持所有学习和 ProTips 的运行日志。
>
> — **@groksrc**, Developer

---

## Basic Memory Cloud

Basic Memory 的托管版本。同一产品，同一 Markdown 文件，同一 MCP 工具 — 我们只是托管数据库、运行同步、并放在你的手机上。

### 你获得什么

- **所有设备，同一个大脑。** 你的知识图谱在 Web、移动端和桌面上一致。无需机器间复制粘贴。
- **连接任何 MCP 客户端。** Claude Desktop、Claude Code、Codex、Cursor、ChatGPT（Custom GPTs）、VS Code — 从 Web 应用一键连接。
- **双向同步到本地。** 在手机上编辑，在笔记本电脑的 Obsidian 中看到。rclone 驱动，支持冲突解决。
- **快照和备份。** 时间点恢复。浏览历史。永不丢失笔记。
- **无锁定。** 你的笔记是纯 Markdown。随时导出到本地 Markdown — 同一文件，同一格式，同一 wikilink。随时取消，数据仍是你的。

基于 WorkOS AuthKit、Neon Postgres 和 Tigris S3 构建。

### 定价

**$15.00/月，订阅期间终身锁定**（正常价格 $19）。Beta 期间注册，价格永不上调 — 只要保持订阅，价格不变。
一个方案，无分级，无意外升级。无限笔记，无限项目，所有功能。

- 7 天免费试用。第 7 天前随时取消。
- 之后也可随时取消 — 随时导出笔记。
- OSS 用户：代码 `BMFOSS` 额外 20% 折扣（3 个月，约 $11.40/月）。

[**开始 7 天免费试用 →**](https://basicmemory.com)

---

## 云端 vs 本地

| | 云端 | 本地 |
|---|---|---|
| **设置时间** | 30 秒 | 2 分钟（需 Python） |
| **成本** | $15.00/月，终身锁定（7 天试用） | 免费 |
| **存储** | 我们托管（Tigris S3） | 你的磁盘 |
| **跨设备同步** | 内置 | 手动（Git、Syncthing 等） |
| **移动访问** | 有（Web + App） | 无 |
| **离线支持** | 无 | 有 |
| **数据归属** | 有 — 随时导出 | 有 — 已经在那里 |
| **源代码** | AGPL-3.0 | AGPL-3.0 |
| **快照 & 备份** | 内置 | 自己管理 |

两种路径使用同一 OSS 引擎和同一 Markdown 文件。无论哪种都没有锁定 — 需求变化时可切换。

---

## 与你已有的工具兼容

| 客户端 | 传输方式 | 说明 |
|---|---|---|
| Cloud web app | https | 登录 basicmemory.com — 无需安装 |
| [Claude Desktop](#claude-desktop) | stdio/https | macOS / Windows / Linux |
| [Claude Code](#claude-code) | stdio/https | `claude mcp add` |
| [Codex](#codex-cli) | stdio/https | OpenAI 的编码代理 |
| [Cursor](#cursor) | stdio/https | `.cursor/mcp.json` |
| [VS Code](#vs-code) | stdio/https | 原生 MCP 支持 |
| [ChatGPT](#chatgpt) | https | Custom GPT actions（`search` / `fetch`） |
| [Obsidian](#obsidian) | — | 直接读写同一 Markdown |
| **Pi** | stdio/https | MCP 兼容 — 见下方集成分析 |
| 任何 MCP 客户端 | stdio/https | 只要支持 MCP 就能用 |

---

## 为什么选择 Basic Memory

大多数 LLM 对话是短暂的。你提问，获得答案，然后一切被遗忘。变通方案有局限：

- **聊天历史** 捕获对话但不是结构化知识。
- **RAG** 让 LLM 查询你的文档但不能回写。
- **向量数据库** 需要复杂基础设施，通常在别人的云端。
- **知识图谱** 需要专门工具维护。

Basic Memory 选择更简单的路径：**人类和 LLM 都可读写结构化 Markdown 文件。**

- 所有知识保持在你控制的纯文件中。
- 双方读写同一文件。
- 熟悉的 Markdown 加语义模式 — 无需学习新格式。
- 可遍历的图谱，LLM 可逐链接跟随。
- 与你已有的编辑器兼容（Obsidian、VS Code、任何编辑器）。
- 仅文件加本地 SQLite 索引。无需服务器。

---

## 工作原理

你正在正常聊天关于咖啡：

> 我一直在尝试冲泡方法。手冲比法压壶更清晰，205°F 的水温最好，新鲜研磨的豆子差别巨大。

让 LLM 捕获：

> "创建关于咖啡冲泡方法的笔记。"

一个 Markdown 文件实时出现在你的项目目录中：

```markdown
---
title: Coffee Brewing Methods
permalink: coffee-brewing-methods
tags: [coffee, brewing]
---

# Coffee Brewing Methods

## Observations
- [method] 手冲比法压壶更能突显风味而非醇厚度
- [technique] 205°F (96°C) 水温提取最佳化合物
- [principle] 新鲜研磨的豆子保留芳香物质

## Relations
- relates_to [[Coffee Bean Origins]]
- requires [[Proper Grinding Technique]]
- affects [[Flavor Extraction]]
```

下次会话，LLM 拾起线索。它跟随关系链接，调出你已知关于埃塞俄比亚豆子和磨豆机的信息，在此基础上继续而非从头开始。
你在 Obsidian 或编辑器中看到同一文件。手动编辑 — AI 也看到你的更改。

真正的双向流动：人类编辑 Markdown，LLM 通过 MCP 读写，同步保持一切一致，真相来源永远是你的文件。

---

## Markdown 格式

每个文件是一个 `Entity`。Entity 有 `Observations`（关于它的事实）和 `Relations`（到其他 entity 的链接）。这就是整个语法。

### Frontmatter

```markdown
---
title: <Entity 标题>
type: note
permalink: <uri-slug>
tags: [可选, 列表]
---
```

### Observations

关于 entity 的事实。`[brackets]` 中分类，`#` 标签，`(parens)` 可选上下文。

```markdown
- [method] 手冲突显微妙风味而非醇厚度
- [tip] V60 用中细研磨 #brewing
- [fact] 浅烘焙比深烘焙含更多咖啡因
- [resource] James Hoffmann 的 V60 技法视频
- [question] 温度如何影响化合物提取？
```

### Relations

Wiki 风格链接形成图谱。单字关系类型，或引用多字类型。

```markdown
- pairs_well_with [[Chocolate Desserts]]
- grown_in [[Ethiopia]]
- requires [[Burr Grinder]]
- "pairs well with" [[Dark Chocolate]]
```

裸 `- [[Target]]` 和散文 `- Worth checking out [[Target]]` 索引为 `links_to`。

---

## MCP 工具

Basic Memory 向任何 MCP 客户端暴露这些工具。每个工具都标注 MCP 行为提示（只读、破坏性、幂等、开放世界）：

- **内容：** `write_note`、`read_note`、`edit_note`、`move_note`、`delete_note`、`read_content`、`view_note`
- **搜索 & 发现：** `search`、`search_notes`、`recent_activity`、`list_directory`
- **知识图谱：** `build_context`（导航 `memory://` URL）、`canvas`（Obsidian canvas 生成）
- **项目：** `list_memory_projects`、`create_memory_project`、`get_current_project`、`sync_status`
- **Schema：** `schema_infer`、`schema_validate`、`schema_diff`
- **云端：** `cloud_info`、`release_notes`

所有 MCP 工具默认文本输出；传入 `output_format="json"` 获取结构化响应。

---

## CLI 常用命令

```bash
# 项目管理
basic-memory project list
basic-memory project add research ~/research
basic-memory project set-cloud research   # 通过云端路由
basic-memory project set-local research   # 恢复本地

# 健康检查 & 维护
basic-memory status
basic-memory doctor              # 文件 <-> DB 一致性检查
basic-memory tool edit-note ...  # CLI 访问 MCP 工具
basic-memory update              # 检查并安装更新

# 导入
basic-memory import claude conversations
basic-memory import chatgpt
basic-memory import memory-json
```

---

## 架构特点

### 三种入口

- **API** — FastAPI REST 服务器，用于 HTTP 访问
- **MCP** — Model Context Protocol 服务器，用于 LLM 集成
- **CLI** — Typer 命令行界面

### Composition Root 模式

每个入口有自己的 composition root 来管理配置和依赖：
- 从 `ConfigManager` 读取配置
- 解析运行时模式（local/test）
- 创建并向下游代码提供依赖

**关键原则：** 只有 composition roots 读取全局配置。所有其他模块显式接收配置。

---

## Schema 系统

Basic Memory 支持 Picoschema — 一种紧凑的 YAML frontmatter schema 语法：

```yaml
schema:
  name: string, 全名              # 必填字段加描述
  email?: string, 联系邮箱        # ? = 可选
  role?: string, 职位
  works_at?: Organization, 雇主   # 大写类型 = entity 引用
  tags?(array): string, 分类      # 类型数组
  status?(enum): [active, inactive]  # 枚举允许值
```

### Schema 验证

三种验证模式：
- `warn` — 输出警告，不阻塞（默认）
- `strict` — 错误阻塞同步，用于 CI/CD
- `off` — 无验证

---

## 许可证

[AGPL-3.0](LICENSE)

---

## Star 历史

<a href="https://www.star-history.com/#basicmachines-co/basic-memory&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=basicmachines-co/basic-memory&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=basicmachines-co/basic-memory&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=basicmachines-co/basic-memory&type=Date" />
 </picture>
</a>

由 [Basic Machines](https://basicmachines.co) 用 ♥️ 构建