# Pi 配置模板

本目录提供 Pi coding agent (`@earendil-works/pi-coding-agent`) 的配置模板，通过 Neovim AI 模块同步到 `~/.pi/agent/`。

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
├── models.template.jsonc           # 模型配置基础 (→ 生成 models.json)
├── keybindings.template.jsonc      # Emacs 风格快捷键
├── mcp.template.jsonc              # MCP 配置 (→ ~/.config/mcp/mcp.json)
│
├── extensions/                     # 13 个扩展模板 + plan-mode
│   ├── statusbar.template.ts       # 三行状态栏 (自定义)
│   ├── enhanced-exit.template.ts   # 退出确认 (自定义)
│   ├── todo.template.ts            # TODO 管理
│   ├── permission-gate.template.ts # 危险命令拦截
│   ├── protected-paths.template.ts # 系统路径保护
│   ├── git-checkpoint.template.ts  # Git stash 自动备份
│   ├── dirty-repo-guard.template.ts# 工作区脏时警告
│   ├── notify.template.ts          # OSC 通知
│   ├── handoff.template.ts         # 会话转移
│   ├── working-indicator.template.ts# 工作进度
│   ├── claude-rules.template.ts    # .claude/rules 加载
│   ├── confirm-destructive.template.ts # 破坏性操作确认
│   ├── model-status.template.ts    # 模型状态
│   └── plan-mode/                  # 计划模式扩展
│       ├── index.template.ts
│       ├── utils.template.ts
│       └── README.md
│
└── skills/                         # 本地 skills
    └── openspec/SKILL.md           # SDD 工作流
```

## 📦 包管理

Settings 模板 (`templates/pi/default.template.jsonc`) 声明了 11 个 Pi packages：

| 包 | 提供内容 |
|---|---|
| `git:github.com/obra/superpowers` | 14 skills (brainstorming/TDD/debugging/worktrees/verification 等) |
| `git:github.com/anthropics/skills` | 17 官方 skills (docx/pdf/pptx 等) |
| `git:github.com/badlogic/pi-skills` | 10 skills (search 等) |
| `npm:flexoki-pi-theme` | Flexoki Dark/Light 主题 |
| `npm:pi-subagents` | 子代理委托 (scout/planner/worker/reviewer + 更多) |
| `npm:pi-markdown-preview` | Markdown + LaTeX 渲染 |
| `npm:pi-mcp-adapter` | MCP 协议支持 |
| `npm:pi-web-access` | Web 搜索 / URL fetch |
| `npm:pi-ask-user` | 交互式询问 UI |
| `npm:pi-codex-limit` | Codex/quota 限制提示 |
| `npm:@fission-ai/openspec` | SDD 工作流 |

包自动提供的内容无需本地复制：
- **Agents**: scout/planner/worker/reviewer 等由 pi-subagents 包提供
- **Themes**: flexoki-dark/light 由 flexoki-pi-theme 包提供
- **Extensions**: 6 个 npm 包各自提供扩展逻辑

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
- **Command** — 不兼容，需手动转为 `.pi/prompts/*.md`
- **Agent** — 格式不同，不可直接共享

## 📊 配置统计

| 类型 | 数量 | 来源 |
|------|------|------|
| Packages | 11 | settings 声明 |
| Extensions (本地) | 13 (含 plan-mode) | 本仓库模板 |
| Extensions (包) | 6 | npm 包提供 |
| Agents | 8+ | pi-subagents 包 |
| Prompts (subagent) | 3 | pi-coding-agent subagent example |
| Skills (本地) | 1 (openspec) | 本仓库 |
| Skills (superpowers) | 14 | 包提供 |
| Skills (anthropics) | 17 | 包提供 |
| Skills (badlogic) | 10 | 包提供 |
| Skills (.claude) | 自动加载 | 全局 + 项目级 |
| Themes | 2 | flexoki-pi-theme 包 |

## 🧠 Neovim AI 同步

通过 Neovim AI 模块管理 Pi 配置：

```vim
:PiGenerateConfig   " 同步全局 ~/.pi/agent 配置
:PiPreviewConfig    " 预览 settings/models/resources
:PiEditTemplate     " 编辑 Pi settings 模板
:PiStatus           " 查看 CLI、配置、资源和 package 状态
:AISync             " 在 OpenCode / Claude Code / Pi 中选择同步目标
```

同步范围：

- `~/.pi/agent/settings.json` (从 `templates/pi/default.template.jsonc` 生成)
- `~/.pi/agent/models.json` (从 Neovim provider/key/model 体系生成)
- `~/.pi/agent/keybindings.json`
- `~/.pi/agent/extensions/` (13 个扩展)
- `~/.pi/agent/skills/openspec/`
- `~/.pi/agent/AGENTS.md`

同步策略：

- 只写全局 `~/.pi/agent`，不修改项目 `.pi/`。
- JSON 配置保守合并，保留用户自定义字段。
- 文件资源通过 `.starter-sync-manifest.json` 记录 hash；检测到用户改动时先备份再更新。
- 只同步本仓库拥有的 local `openspec` skill；其他 skills 由包提供。
- 不自动执行 `pi install` 或 `pi update`。`:PiStatus` 只报告缺失 packages，并给出手动安装提示。

## 🔧 验证

```bash
pi              # 启动
/settings       # 查看设置
/model          # 查看模型
/mcp            # MCP 状态
```

Neovim 内验证：

```vim
:PiStatus
:checkhealth ai
```
