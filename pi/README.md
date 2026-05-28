# Pi 配置模板

本目录提供 Pi coding agent (`@earendil-works/pi-coding-agent`) 的完整配置模板：默认 settings、provider、快捷键、主题、扩展、自定义 skill、prompt 库、MCP server 列表，以及一键安装脚本。

> Pi 是 [@earendil-works](https://github.com/earendil-works) 出品的极简终端 coding harness。文档：`/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/docs/`

## 📁 目录结构

```
pi/
├── README.md                       # 本文件
├── CLI.md                          # CLI 命令行参考
├── PACKAGES.md                     # 包管理文档
├── AGENTS.template.md              # 全局工作流约定（→ ~/.pi/agent/AGENTS.md）
├── models.template.jsonc           # Provider/Model 配置（bailian/ollama，其他注释）
├── keybindings.template.jsonc      # 快捷键（Emacs 风格 + Pi 命名空间）
├── theme.template.jsonc            # Flexoki Dark 主题 (专注阅读/代码)
├── themes/                         # 可选主题
│   └── flexoki-light.template.jsonc # Flexoki Light 主题
├── mcp.template.jsonc              # MCP server 列表（→ ~/.config/mcp/mcp.json，跨工具共享）
├── restore.sh                      # 一键恢复脚本
├── optimize-existing.sh            # 优化现有配置脚本
│
├── extensions/                     # 扩展模板 (13 个)
│   ├── statusbar.template.ts       # 三行状态栏（token/cache/context/git branch/cost）
│   ├── todo.template.ts            # 会话内 TODO 管理
│   ├── permission-gate.template.ts # 拦 rm -rf / sudo / chmod 777（弹出确认）
│   ├── protected-paths.template.ts # 阻止写入 .env / .git / node_modules（硬阻止）
│   ├── git-checkpoint.template.ts  # 每个 turn 自动 git stash，/fork 可回滚
│   ├── dirty-repo-guard.template.ts# 工作区脏时禁止切 session
│   ├── notify.template.ts          # OSC 终端通知（agent 等待用户输入）
│   ├── handoff.template.ts         # lossless 跨 session 上下文转移
│   ├── working-indicator.template.ts# 工作进度指示器
│   ├── enhanced-exit.template.ts   # 增强退出确认
│   ├── claude-rules.template.ts    # 扫描 .claude/rules/ 规则文件
│   ├── confirm-destructive.template.ts # 确认破坏性操作
│   └── model-status.template.ts    # 模型状态显示
│
├── skills/                         # 技能模板 (5 个本地 + superpowers 提供)
│   └── openspec/SKILL.md           # SDD（spec-driven development）工作流
│   └── systematic-debugging/SKILL.md # 系统化调试流程
│   └── test-driven-development/SKILL.md # TDD 循环
│   └── using-git-worktrees/SKILL.md # Git worktree 工作流
│   └── verification-before-completion/SKILL.md # 完成前验证
│
└── prompts/                        # /command 模板 (12 个)
    ├── review.template.md          # 代码审查
    ├── refactor.template.md        # 重构
    ├── test.template.md            # 测试生成
    ├── commit.template.md          # 提交消息
    ├── pr.template.md              # PR 创建
    ├── debug.template.md           # 调试
    ├── security.template.md        # 安全检查
    ├── docs.template.md            # 文档生成
    ├── explain.template.md         # 代码解释
    ├── perf.template.md            # 性能分析
    ├── implement.template.md       # TDD 实现
    └── plan.template.md            # 计划
```

根目录还有 `pi.template.jsonc`（主 settings，→ `~/.pi/agent/settings.json`）。

---

## 🚀 一键安装

```bash
./scripts/install-pi-dev.sh
```

脚本会：
1. 创建 `~/.pi/agent/` 目录结构和 `~/.config/mcp/`
2. 拷贝所有模板（已存在文件备份为 `*.bak.<timestamp>`）
3. 通过 `pi install` 装 community packages：
   - `git:github.com/obra/superpowers` — 14 个工程方法论 skill
   - `npm:pi-mcp-adapter` — MCP 支持
   - `git:github.com/anthropics/skills` — 文档处理
   - `git:github.com/badlogic/pi-skills` — web search / 浏览器 / Google API

---

## 🔑 配 API key

`models.json` 默认 provider 是百炼编码版。设置环境变量：

```bash
export BAILIAN_CODING_API_KEY="sk-..."

# MCP 用到的（按需）
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."
export DATABASE_URL="postgres://..."
```

也可在 `models.json` 里直接写值（不推荐入 git）或 `!command` 形式从外部读取。

---

## 🎯 设计要点

### 跨工具 skill 复用

`pi.template.jsonc` 配置了：
```json
"skills": ["~/.claude/skills", "~/.codex/skills"]
```
Pi 会直接读取这两个目录下的 skill，无需复制。Claude Code / Codex CLI 写的 skill 立即对 Pi 可用，反之亦然。

**Superpowers 包提供的 Skills (14 个)**：
- brainstorming, systematic-debugging, test-driven-development
- using-git-worktrees, verification-before-completion
- dispatching-parallel-agents, subagent-driven-development
- executing-plans, writing-plans, writing-skills
- requesting-code-review, receiving-code-review
- finishing-a-development-branch, using-superpowers

### MCP 支持（社区方案）

Pi 官方故意不内置 MCP（[原因见 Mario 博文](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/)），通过 [`pi-mcp-adapter`](https://github.com/nicobailon/pi-mcp-adapter) 接入。

特性：
- **Lazy 启动** — server 首次 tool call 才连接
- **单 proxy tool** — `mcp({...})` 接管所有 server（仅 ~200 tokens，替代直接注入 10k+ tokens 的 tool 定义）
- **按需 directTools** — 高频工具可提升为顶级 pi tool
- **metadata 缓存** — `/mcp` 搜索/列表无需活连接
- **跨工具配置导入** — `/mcp setup` 可吸收 cursor/claude-code/codex 的 mcp 配置
- **OAuth 自动化** — `autoAuth: true` 时按需走 OAuth

常用：
```
/mcp                                          # 状态面板
/mcp setup                                    # 首次向导
mcp({ search: "screenshot navigate" })        # 找工具
mcp({ describe: "chrome_devtools_navigate" }) # 看签名
mcp({ tool: "chrome_devtools_navigate",       # 调用
       args: '{"url": "..."}' })
```

### 安全 extension 防线

Pi 没有 OpenCode/Claude Code 那种 JSON permission DSL，安全靠 extension：

| Extension | 职责 |
|---|---|
| `permission-gate` | 拦 `rm -rf` / `sudo` / `chmod 777` 等高危 bash，弹出确认 |
| `protected-paths` | 阻止 `.env` / `.git/` / `node_modules/` 的写入（直接阻止） |
| `git-checkpoint` | 每个 turn 自动 `git stash`，可在 `/fork` 时回滚代码状态 |
| `dirty-repo-guard` | 工作区有未提交改动时阻止 `/clear`、`/new`、`/switch` |

**来源**: 这些扩展均来自 Pi 官方 examples 目录，遵循官方设计意图。

**设计说明**: `permission-gate` 和 `protected-paths` 功能独立：
- `permission-gate`: 交互式确认（用户可选择允许）
- `protected-paths`: 系统路径硬阻止（不给用户选择，防止意外损坏）

### 状态栏

`extensions/statusbar.template.ts` 提供三行状态栏：
1. **第一行**：模式（⚡Running / ✓Idle）+ 累计 input/output/cost/cache 命中率 + 速度 + turn 数 + 会话时长
2. **第二行**：当前 git branch + cwd + provider/model + context window 大小
3. **第三行**：context 进度条（>60% 黄色，>85% 红色）

切换：`/statusbar`

---

## 🧩 添加新内容

### 新 Provider
编辑 `pi/models.template.jsonc`：
```json
{
  "providers": {
    "my-provider": {
      "baseUrl": "https://api.example.com/v1",
      "api": "openai-completions",
      "apiKey": "MY_API_KEY",
      "models": [{ "id": "model-1", "name": "Model 1" }]
    }
  }
}
```
重装：`./scripts/install-pi-dev.sh`

### 新 Extension
1. 在 `pi/extensions/` 新建 `<name>.template.ts`（参考 Pi 官方 `examples/extensions/` 70+ 模板）
2. `./scripts/install-pi-dev.sh` 重装
3. 在 pi 内 `/reload`

### 新 Skill
项目独有的 skill 放 `pi/skills/<name>/SKILL.md`，跑 install 脚本。
通用 skill 优先用 community package（`pi install ...`），不要重复造。

### 新 Prompt
在 `pi/prompts/` 加 `<name>.template.md`，frontmatter：
```yaml
---
description: One-line description shown in autocomplete
argument-hint: "<required-arg>"   # 或 "[optional-arg]"
---
```
重装后 `/name` 可用。

---

## 🆚 与其他工具的关系

| 工具 | 配置位置 | 本仓库模板 |
|---|---|---|
| OpenCode | `~/.config/opencode/` | `opencode.template.jsonc` |
| Claude Code | `~/.claude/` | `claude_code.template.jsonc` |
| Pi | `~/.pi/agent/` | `pi.template.jsonc` + `pi/` |
| MCP（共享） | `~/.config/mcp/mcp.json` | `pi/mcp.template.jsonc` |

`lua/ai/` 模块统一管理前两者；Pi 独立用本目录 + community packages。

---

## 🔗 相关链接

- Pi 官方文档：`/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/docs/`
- Pi 官方示例：`/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/`
- Pi 发布博文：[mariozechner.at/posts/2025-11-30-pi-coding-agent](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/)
- Skills 标准：[agentskills.io/specification](https://agentskills.io/specification)
- Superpowers：[github.com/obra/superpowers](https://github.com/obra/superpowers)
- pi-mcp-adapter：[github.com/nicobailon/pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter)
- Anthropic Skills：[github.com/anthropics/skills](https://github.com/anthropics/skills)
- Pi Skills（badlogic）：[github.com/badlogic/pi-skills](https://github.com/badlogic/pi-skills)