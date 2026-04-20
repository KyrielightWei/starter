# GSD (gsd-pi) 中文指南

> 翻译整理自 https://github.com/gsd-build/gsd-2/tree/main/gitbook

---

## 什么是 GSD？

GSD 是一个 **AI驱动的开发代理**，能够将项目想法转化为可运行的软件。你描述想要构建的内容，GSD 会进行研究、规划、编码、测试和提交 — 生成干净的 git 历史，并提供完整的成本追踪。

### 工作原理

GSD 将项目分解为可管理的片段并系统性地完成它们：

```
你描述项目
    ↓
GSD 创建里程碑和切片（功能）
    ↓
每个切片被分解为任务
    ↓
任务在全新的 AI 会话中逐一执行
    ↓
代码提交、验证，下一个任务开始
```

你可以选择 **步进模式**（逐步审查）或让 GSD 以 **自动模式** 自主运行。

---

## 目录

1. [快速开始](#快速开始)
2. [核心概念](#核心概念)
3. [配置](#配置)
4. [功能特性](#功能特性)
5. [命令参考](#命令参考)
6. [CLI 参数](#cli-参数)
7. [环境变量](#环境变量)
8. [故障排查](#故障排查)

---

## 快速开始

### 安装

```bash
npm install -g gsd-pi
```

需要 **Node.js 22.0.0 或更高版本**（推荐 24 LTS）和 **Git**。

### 启动

```bash
gsd
```

首次启动会引导设置：
1. **LLM 提供商** — 选择 20+ 提供商（Anthropic、OpenAI、Google、OpenRouter、GitHub Copilot 等）
2. **工具 API Keys**（可选） — Brave Search、Context7、Jina、Slack、Discord

### 开始自动模式

```
/gsd auto
```

---

## 核心概念

### 三级层级结构

```
里程碑 (Milestone)  →  可交付版本（4-10 个切片）
  切片 (Slice)      →  可演示的垂直功能（1-7 个任务）
    任务 (Task)     →  一个上下文窗口大小的单位工作
```

**关键规则**：一个任务必须能在单个 AI 上下文窗口中完成。如果不能，就拆分成两个任务。

### `.gsd/` 目录结构

```
.gsd/
  PROJECT.md          — 项目描述（随项目演进更新）
  REQUIREMENTS.md     — 需求合约（追踪活跃/验证/延期的需求）
  DECISIONS.md        — 架构决策日志（追加式）
  KNOWLEDGE.md        — 跨会话规则、模式和经验教训
  RUNTIME.md          — 运行时上下文：API 端点、环境变量、服务
  STATE.md            — 当前工作状态一览（自动生成）
  PREFERENCES.md      — 项目级偏好设置（可选）
  milestones/
    M001/
      M001-ROADMAP.md — 切片计划，含风险级别和依赖关系
      M001-CONTEXT.md — 讨论阶段确定的范围和目标
      slices/
        S01/
          S01-PLAN.md     — 切片的任务分解
          S01-SUMMARY.md  — 构建内容和变更说明
          S01-UAT.md      — 人工测试脚本
          tasks/
            T01-PLAN.md   — 任务详细计划
            T01-SUMMARY.md — 任务完成内容
```

### 工作流程

每个切片按阶段流转：

```
计划 → 执行（每个任务） → 完成 → 重新评估路线图 → 下一个切片
```

1. **计划** — GSD 探索代码库、研究相关文档，将切片分解为任务
2. **执行** — 每个任务在全新的 AI 会话中运行
3. **完成** — GSD 编写总结、生成 UAT 脚本、提交代码
4. **重新评估** — 检查路线图是否符合实际情况
5. **下一个切片** — 循环继续直到所有切片完成

---

### 步进模式

步进模式是 GSD 的交互式、逐步执行工作流。你保持在循环中，每步之间审查输出。

```
/gsd
```

GSD 读取 `.gsd/` 目录状态，显示完成情况和下一步的向导，执行一个工作单位后暂停。

| 状态 | 发生什么 |
|------|----------|
| 没有 `.gsd/` 目录 | 启动讨论流程，捕获项目愿景 |
| 里程碑存在，无路线图 | 开启里程碑讨论或研究阶段 |
| 路线图存在，切片待处理 | 规划下一个切片或执行下一个任务 |
| 任务进行中 | 从上次位置恢复 |

**适合场景**：
- 新项目，想塑造架构
- 关键工作，想审查每一步
- 在信任自动模式之前，学习 GSD 工作方式

---

### 自动模式

自动模式是 GSD 的自主执行引擎。运行 `/gsd auto`，离开，回来就是已构建的软件和干净的 git 历史。

```
/gsd auto
```

**执行循环**：

```
计划 → 执行（每个任务） → 完成 → 重新评估路线图 → 下一个切片
                                                           ↓ (全部完成)
                                                   验证里程碑
```

**控制方式**：

| 操作 | 方法 |
|------|------|
| 暂停 | 按 **Escape** |
| 恢复 | `/gsd auto` |
| 停止 | `/gsd stop` |
| 引导 | `/gsd steer` |
| 捕获想法 | `/gsd capture "想法内容"` |

**每次任务使用全新会话**：每个任务获得干净的 AI 上下文窗口，避免累积垃圾和质量劣化。

---

## 配置

### 偏好设置文件

| 范围 | 路径 | 适用范围 |
|------|------|----------|
| 全局 | `~/.gsd/PREFERENCES.md` | 所有项目 |
| 项目 | `.gsd/PREFERENCES.md` | 仅当前项目 |

**合并规则**：
- **标量字段**（`budget_ceiling`、`token_profile`）：项目定义则项目优先
- **数组字段**：拼接（全局先，项目后）
- **对象字段**：浅合并，项目按键覆盖

### 偏好设置示例

```yaml
---
version: 1

# 模型选择
models:
  research: claude-sonnet-4-6
  planning: claude-opus-4-7
  execution: claude-sonnet-4-6

# Token 优化
token_profile: balanced

# 预算
budget_ceiling: 25.00
budget_enforcement: pause

# 监督
auto_supervisor:
  soft_timeout_minutes: 15
  hard_timeout_minutes: 25

# Git
git:
  auto_push: true
  merge_strategy: squash
  isolation: worktree

# 验证
verification_commands:
  - npm run lint
  - npm run test
---
```

### 模型选择

**按阶段配置模型**：

```yaml
models:
  research: claude-sonnet-4-6        # 探索和研究
  planning: claude-opus-4-7          # 架构决策
  execution: claude-sonnet-4-6       # 编写代码
  execution_simple: claude-haiku-4-5 # 简单任务（文档、配置）
  completion: claude-sonnet-4-6      # 总结和收尾
  subagent: claude-sonnet-4-6        # 委派的子任务
```

**模型后备**：

```yaml
models:
  planning:
    model: claude-opus-4-7
    fallbacks:
      - openrouter/z-ai/glm-5
      - openrouter/moonshotai/kimi-k2.5
```

---

### 提供商设置

| 提供商 | 认证方式 | 环境变量 |
|--------|----------|----------|
| Anthropic | OAuth 或 API key | `ANTHROPIC_API_KEY` |
| OpenAI | API key | `OPENAI_API_KEY` |
| Google Gemini | API key | `GEMINI_API_KEY` |
| OpenRouter | API key | `OPENROUTER_API_KEY` |
| Groq | API key | `GROQ_API_KEY` |
| xAI (Grok) | API key | `XAI_API_KEY` |
| Mistral | API key | `MISTRAL_API_KEY` |
| GitHub Copilot | OAuth | `GH_TOKEN` |
| Amazon Bedrock | IAM 凭证 | `AWS_PROFILE` 或 `AWS_ACCESS_KEY_ID` |
| Vertex AI | ADC | `GOOGLE_APPLICATION_CREDENTIALS` |
| Azure OpenAI | API key | `AZURE_OPENAI_API_KEY` |
| Ollama | 无（本地） | — |
| LM Studio | 无（本地） | — |

### 本地提供商配置

创建 `~/.gsd/agent/models.json`：

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false
      },
      "models": [
        { "id": "llama3.1:8b" }
      ]
    }
  }
}
```

---

### Git 与 Worktree

**隔离模式**：

| 模式 | 工作目录 | 分支 | 适用场景 |
|------|----------|------|----------|
| `worktree`（默认） | `.gsd/worktrees/<MID>/` | `milestone/<MID>` | 大多数项目 — 完全隔离 |
| `branch` | 项目根目录 | `milestone/<MID>` | 子模块多的仓库 |
| `none` | 项目根目录 | 当前分支 | 热重载工作流 |

**分支模型**：

```
main ────────────────────────────────────────────
  │                                          ↑
  └── milestone/M001 (worktree) ─────────────┘
       commit: feat: core types
       commit: feat: markdown parser
       commit: feat: file writer
       → squash-merged to main
```

---

## 功能特性

### 成本管理

GSD 在自动模式下追踪每个工作单位的 token 使用量和成本。

**预算上限**：

```yaml
budget_ceiling: 50.00
budget_enforcement: pause    # warn / pause / halt
```

| 模式 | 行为 |
|------|------|
| `warn` | 记录警告，继续 |
| `pause` | 暂停自动模式（默认） |
| `halt` | 完全停止自动模式 |

**预算压力**：接近预算上限时，自动降级使用更便宜的模型。

| 预算使用 | 效果 |
|----------|------|
| < 50% | 无调整 |
| 50-75% | 标准任务降级为轻量模型 |
| 75-90% | 更激进的降级 |
| > 90% | 几乎全部降级 |

---

### Token 优化

**Token Profile 协调模型选择、阶段跳过和上下文压缩**：

| Profile | 成本节省 | 适用场景 |
|---------|----------|----------|
| `budget` | 40-60% | 原型开发、小项目、熟悉的代码库 |
| `balanced` | 10-20% | 大多数项目、日常开发（默认） |
| `quality` | 0%（基准） | 复杂架构、全新项目、关键工作 |

---

### 动态模型路由

自动为简单工作选择便宜模型，为复杂任务保留昂贵模型。

```yaml
dynamic_routing:
  enabled: true
```

| 层级 | 典型工作 | 模型级别 |
|------|----------|----------|
| Light | 切片完成、UAT、hooks | Haiku 级 |
| Standard | 研究、规划、执行 | Sonnet 级 |
| Heavy | 重规划、路线图重评估 | Opus 级 |

**关键规则**：你配置的模型始终是上限 — 路由不会升级超过你设定的模型。

---

### Skills（技能系统）

Skills 是 GSD 在任务匹配时加载的专用指令集，提供领域特定指导。

**技能目录**：

| 位置 | 范围 | 说明 |
|------|------|------|
| `~/.agents/skills/` | 全局 | 所有项目共享 |
| `.agents/skills/` | 项目 | 项目特定，可提交到 git |

**安装技能**：

```bash
npx skills add dpearson2699/swift-ios-skills
npx skills add dpearson2699/swift-ios-skills --skill swift-concurrency -y
```

**技能发现模式**：

| 模式 | 行为 |
|------|------|
| `auto` | 自动发现并应用 |
| `suggest` | 发现但需确认（默认） |
| `off` | 禁用发现 |

---

### 并行编排

在隔离的 git worktree 中同时运行多个里程碑。

```yaml
parallel:
  enabled: true
  max_workers: 2
```

**命令**：

| 命令 | 说明 |
|------|------|
| `/gsd parallel start` | 分析并启动 workers |
| `/gsd parallel status` | 显示 workers 状态和进度 |
| `/gsd parallel stop [MID]` | 停止 workers |
| `/gsd parallel merge [MID]` | 合并完成的里程碑 |

---

### 捕获与分类

在自动模式执行期间捕获想法，让 GSD 在任务间隙进行分类处理。

```
/gsd capture "添加 API 端点速率限制"
```

**分类类型**：

| 类型 | 含义 | 处理方式 |
|------|------|----------|
| `quick-task` | 小型、独立的修复 | 立即执行 |
| `inject` | 当前切片需要新任务 | 添加到活跃切片 |
| `defer` | 重要但不紧急 | 延后到路线图重评估 |
| `replan` | 改变当前方法 | 触发切片重规划 |
| `note` | 信息性，无需操作 | 确认，无变更 |

---

### 远程问答

通过 Slack、Discord 或 Telegram 在无头自动模式下获取你的输入。

```yaml
remote_questions:
  channel: discord
  channel_id: "1234567890123456789"
  timeout_minutes: 5
```

**响应方式**：
- 用数字 emoji 反应（1️⃣、2️⃣ 等）
- 回复数字、逗号分隔数字或自由文本

---

### 无头与 CI 模式

无终端 UI 运行 GSD 命令，适合 CI 管道、cron 任务和脚本自动化。

```bash
gsd headless                    # 运行自动模式
gsd headless --timeout 600000   # 带超时
gsd headless --json auto        # 流式输出 JSONL
gsd headless query              # 即时状态查询（~50ms）
```

**创建里程碑**：

```bash
gsd headless new-milestone --context brief.md --auto
gsd headless new-milestone --context-text "构建带认证的 REST API"
```

---

### 工作流可视化器

全屏终端覆盖显示项目进度、依赖关系、成本指标和执行时间线。

```
/gsd visualize
```

**标签页**：
1. **进度** — 里程碑、切片、任务的树状视图
2. **依赖** — ASCII 依赖图
3. **指标** — 成本和 token 使用柱状图
4. **时间线** — 执行历史

---

### Web 界面

浏览器界面用于项目管理和实时进度监控。

```bash
gsd --web
```

**参数**：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--host` | `localhost` | 绑定地址 |
| `--port` | `3000` | 端口 |
| `--allowed-origins` | 无 | CORS 来源 |

---

### GitHub 同步

自动将里程碑、切片和任务同步到 GitHub Issues、PRs 和 Milestones。

```yaml
github:
  enabled: true
  repo: "owner/repo"
  labels: [gsd, auto-generated]
```

---

### 团队协作

设置团队模式：

```yaml
mode: team
```

启用：
- **唯一里程碑 ID** — 如 `M001-eh88as` 避免冲突
- **推送分支** — 里程碑分支推送到远程
- **合并前检查** — 合并前运行验证

---

### 工作流模板

预构建的常用开发任务模式。

```
/gsd start              # 选择模板
/gsd templates          # 列出可用模板
```

**可用模板**：

| 模板 | 用途 |
|------|------|
| `bugfix` | 修复特定 bug |
| `spike` | 时间盒调查或原型 |
| `feature` | 标准功能开发 |
| `hotfix` | 紧急生产修复 |
| `refactor` | 代码重构和清理 |
| `security-audit` | 安全审查和修复 |
| `dep-upgrade` | 依赖更新和迁移 |

---

## 命令参考

### 会话命令

| 命令 | 说明 |
|------|------|
| `/gsd` | 步进模式 |
| `/gsd auto` | 自动模式 |
| `/gsd stop` | 停止自动模式 |
| `/gsd pause` | 暂停自动模式 |
| `/gsd steer` | 执行期间修改计划 |
| `/gsd discuss` | 讨论架构和决策 |
| `/gsd status` | 进度仪表板 |
| `/gsd queue` | 队列和排序未来里程碑 |
| `/gsd capture` | 捕获想法 |
| `/gsd history` | 查看执行历史 |
| `/gsd forensics` | 自动模式失败完整调试 |
| `/gsd cleanup` | 清理状态文件和过期 worktree |
| `/gsd visualize` | 打开工作流可视化器 |
| `/gsd export --html` | 生成 HTML 报告 |
| `/gsd knowledge` | 添加持久项目知识 |

### 配置与诊断

| 命令 | 说明 |
|------|------|
| `/gsd prefs` | 偏好设置向导 |
| `/gsd config` | 提供商设置向导 |
| `/gsd doctor` | 运行时健康检查 |
| `/gsd init` | 项目初始化向导 |

### 里程碑管理

| 命令 | 说明 |
|------|------|
| `/gsd new-milestone` | 创建新里程碑 |
| `/gsd skip` | 阻止单位被自动模式调度 |
| `/gsd undo` | 撤销最后完成的单位 |
| `/gsd park` | 停放里程碑 |
| `/gsd unpark` | 激活已停放的里程碑 |

### Debug 会话

| 命令 | 说明 |
|------|------|
| `/gsd debug <issue>` | 创建 debug 会话 |
| `/gsd debug list` | 列出持久化会话 |
| `/gsd debug status <slug>` | 查看会话状态 |
| `/gsd debug continue <slug>` | 恢复会话 |

---

## CLI 参数

### 启动

| 参数 | 说明 |
|------|------|
| `gsd` | 启动交互式会话 |
| `gsd --continue` (-c) | 恢复最近会话 |
| `gsd --model <id>` | 覆盖默认模型 |
| `gsd --web` | 启动 Web 界面 |
| `gsd --worktree` (-w) | 在 git worktree 中启动 |
| `gsd --version` (-v) | 打印版本 |

### 无头模式

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `gsd headless` | — | 无 TUI 运行 |
| `--timeout N` | 300000 | 超时（毫秒） |
| `--max-restarts N` | 3 | 崩溃自动重启次数 |
| `--json` | — | 流式 JSONL 输出 |

### 其他

| 命令 | 说明 |
|------|------|
| `gsd sessions` | 会话选择器 |
| `gsd config` | 设置全局 API keys |
| `gsd update` | 更新到最新版本 |

---

## 环境变量

### GSD 配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `GSD_HOME` | `~/.gsd` | 全局 GSD 目录 |
| `GSD_PROJECT_ID` | 自动哈希 | 覆盖项目身份哈希 |
| `GSD_STATE_DIR` | `$GSD_HOME` | 项目状态根目录 |
| `GSD_CODING_AGENT_DIR` | `$GSD_HOME/agent` | 代理目录 |

### LLM 提供商 Keys

| 变量 | 提供商 |
|------|--------|
| `ANTHROPIC_API_KEY` | Anthropic |
| `OPENAI_API_KEY` | OpenAI |
| `GEMINI_API_KEY` | Google Gemini |
| `OPENROUTER_API_KEY` | OpenRouter |
| `GROQ_API_KEY` | Groq |
| `XAI_API_KEY` | xAI |
| `MISTRAL_API_KEY` | Mistral |
| `GH_TOKEN` | GitHub Copilot |

---

## 故障排查

### `/gsd doctor`

内置诊断工具验证 `.gsd/` 完整性。

### 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `command not found: gsd` | npm 全局 bin 不在 PATH | 添加 `$(npm prefix -g)/bin` 到 PATH |
| 自动模式循环同一单位 | 状态损坏 | 运行 `/gsd doctor` |
| 预算上限达到 | 超出设置预算 | 增加 `budget_ceiling` 或使用 `budget` profile |
| 过期锁文件 | 另一个会话运行 | `rm -f .gsd/auto.lock` |
| macOS 通知不出现 | 权限问题 | 安装 `terminal-notifier` |

### 恢复操作

```bash
# 重置自动模式状态
rm .gsd/auto.lock
rm .gsd/completed-units.json

# 重置路由历史
rm .gsd/routing-history.json

# 完整状态重建
/gsd doctor
```

---

## 快捷键

| 快捷键 | 操作 |
|--------|------|
| `Ctrl+Alt+G` | 切换仪表板覆盖 |
| `Ctrl+Alt+V` | 切换语音转录 |
| `Ctrl+Alt+B` | 显示后台 shell 进程 |
| `Ctrl+V` / `Alt+V` | 从剪贴板粘贴图片 |
| `Escape` | 暂停自动模式 |

---

## 参考链接

- GitHub: https://github.com/gsd-build/gsd-2
- npm: https://www.npmjs.com/package/gsd-pi
- Discord: https://discord.gg/mYgfVNfA2r