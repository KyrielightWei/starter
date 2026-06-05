# Pi 配置模板

本目录提供 Pi coding agent (`@earendil-works/pi-coding-agent`) 的完整配置模板，以及一键恢复脚本。

> Pi 是 [@earendil-works](https://github.com/earendil-works) 出品的极简终端 coding harness。

## 📁 目录结构

```
pi/
├── README.md                       # 本文件
├── CLI.md                          # CLI 命令行参考
├── PACKAGES.md                     # 包管理文档
├── AUTH.md                         # 认证 & Provider 配置（auth.json / models.json 详解）
├── INTEGRATION_WITH_CLAUDE_CODE.md # Pi × Claude Code 跨工具对接指南
├── AGENTS.template.md              # 全局工作流约定
├── pi.template.jsonc               # 主 settings (→ ~/.pi/agent/settings.json)
├── models.template.jsonc           # 5 个模型 (→ ~/.pi/agent/models.json)
├── keybindings.template.jsonc      # Emacs 风格快捷键
├── theme.template.jsonc            # Flexoki Dark 主题
├── mcp.template.jsonc              # MCP 配置 (→ ~/.config/mcp/mcp.json)
├── restore.sh                      # 一键恢复脚本
├── optimize-existing.sh            # 优化现有配置
│
├── extensions/                     # 13 个扩展模板 + plan-mode
│   ├── statusbar.template.ts       # 三行状态栏
│   ├── todo.template.ts            # TODO 管理
│   ├── permission-gate.template.ts # 危险命令拦截
│   ├── protected-paths.template.ts # 系统路径保护
│   ├── git-checkpoint.template.ts  # Git stash 自动备份
│   ├── dirty-repo-guard.template.ts# 工作区脏时警告
│   ├── notify.template.ts          # OSC 通知
│   ├── handoff.template.ts         # 会话转移
│   ├── working-indicator.template.ts# 工作进度
│   ├── enhanced-exit.template.ts   # 退出确认
│   ├── claude-rules.template.ts    # .claude/rules 加载
│   ├── confirm-destructive.template.ts # 破坏性操作确认
│   ├── model-status.template.ts    # 模型状态
│   └── plan-mode/                  # 计划模式扩展
│       ├── index.template.ts
│       ├── utils.template.ts
│       └── README.md
│
├── prompts/                        # 12 个基础 + 2 个链式工作流
│   ├── commit.template.md          # 提交消息
│   ├── debug.template.md           # 调试
│   ├── docs.template.md            # 文档生成
│   ├── explain.template.md         # 代码解释
│   ├── implement.template.md       # 实现
│   ├── perf.template.md            # 性能分析
│   ├── plan.template.md            # 计划
│   ├── pr.template.md              # PR 创建
│   ├── refactor.template.md        # 重构
│   ├── review.template.md          # 代码审查
│   ├── security.template.md        # 安全检查
│   ├── test.template.md            # 测试
│   ├── scout-and-plan.template.md      # 链式: scout → planner
│   └── implement-and-review.template.md# 链式: worker → reviewer → worker
│
├── agents/                         # 4 个子代理模板 (→ ~/.pi/agent/agents/)
│   ├── scout.template.md           # 快速代码侦察
│   ├── planner.template.md         # 实现计划生成
│   ├── worker.template.md          # 通用执行代理
│   └── reviewer.template.md        # 代码评审代理
│
├── skills/                         # 本地 skills (仅 1 个；其余由包提供)
│   └── openspec/SKILL.md           # SDD 工作流
│
└── themes/                         # 可选主题
    └── flexoki-light.template.jsonc
```

## 🚀 一键恢复

```bash
cd pi
./restore.sh
```

脚本会：
1. 创建 `~/.pi/agent/` 目录结构
2. 复制所有模板文件
3. 安装 11 个 Pi packages:
   - `git:github.com/obra/superpowers` — 14 skills
   - `git:github.com/anthropics/skills` — 17 官方 skills
   - `git:github.com/badlogic/pi-skills` — 10 skills
   - `npm:flexoki-pi-theme` — Flexoki 主题
   - `npm:pi-markdown-preview` — Markdown 渲染
   - `npm:pi-subagents` — 子代理
   - `npm:pi-mcp-adapter` — MCP 支持
   - `npm:pi-web-access` — Web 搜索
   - `npm:pi-ask-user` — 交互询问
   - `npm:pi-codex-limit` — Codex/quota 限制
   - `npm:@fission-ai/openspec` — SDD 工作流

## 🔑 配置 API Key

最简：环境变量

```bash
export OPENAI_API_KEY='your-bailian-key'
```

更推荐：使用 `~/.pi/agent/auth.json` 集中管理凭据（不污染 shell、文件权限 0600、多 provider 共存）。

详见 [AUTH.md](./AUTH.md)，覆盖：

- `auth.json` 的两种类型（`api_key` / `oauth`）和支持的 `key` 引用格式
- `models.json` 中 `apiKey` 字段的语义（环境变量名而非密钥本身）
- API Key 解析优先级（CLI → auth.json api_key → oauth → 环境变量 → fallback）
- 完整 Bailian Coding 配置链路 + 常见问题（401 / MCP 空配置）
- 与 OpenCode 凭据管理的对比

## 🔗 Claude Code 对接

模板已启用 Claude Code skill 自动加载（全局 + 项目级），并通过 `claude-rules` 扩展暴露项目 rule。

详见 [INTEGRATION_WITH_CLAUDE_CODE.md](./INTEGRATION_WITH_CLAUDE_CODE.md)，覆盖：

- **Skill** — `~/.claude/skills` + `.claude/skills` 自动扫描，暴露为 `/skill:name`
- **Rule** — `claude-rules` 扩展列出 `.claude/rules/`，模型按需 read
- **Command** — 不兼容，需手动转为 `.pi/prompts/*.md`（附转换步骤）
- **Agent** — 格式不同，不可直接共享

## 📊 配置统计

| 类型 | 数量 |
|------|------|
| Packages | 11 |
| Extensions | 13 (含 plan-mode) |
| Agents (本地) | 4 (scout/planner/worker/reviewer) |
| Prompts | 14 (12 基础 + 2 链式) |
| Skills (本地) | 1 (openspec) |
| Skills (superpowers) | 14 (含 systematic-debugging, TDD, using-git-worktrees, verification-before-completion 等) |
| Skills (anthropics) | 17 |
| Skills (badlogic) | 10 |
| Skills (.claude) | 自动加载（全局 + 项目级 .claude/skills） |
| Models | 5 |

> **说明**：`systematic-debugging`、`test-driven-development`、`using-git-worktrees`、`verification-before-completion` 等 skill 由 `git:github.com/obra/superpowers` 包提供，不是本地模板。

## 🔧 验证

```bash
pi              # 启动
/settings       # 查看设置
/model          # 查看模型
/mcp            # MCP 状态
```
