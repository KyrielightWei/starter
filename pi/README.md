# Pi 配置模板

本目录提供 Pi coding agent (`@earendil-works/pi-coding-agent`) 的完整配置模板，以及一键恢复脚本。

> Pi 是 [@earendil-works](https://github.com/earendil-works) 出品的极简终端 coding harness。

## 📁 目录结构

```
pi/
├── README.md                       # 本文件
├── CLI.md                          # CLI 命令行参考
├── PACKAGES.md                     # 包管理文档
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
├── prompts/                        # 12 个 prompt 模板
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
│   └── test.template.md            # 测试
│
├── skills/                         # 本地 skills
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
3. 安装 10 个 Pi packages:
   - `git:github.com/obra/superpowers` — 14 skills
   - `git:github.com/anthropics/skills` — 17 官方 skills
   - `git:github.com/badlogic/pi-skills` — 10 skills
   - `npm:flexoki-pi-theme` — Flexoki 主题
   - `npm:pi-markdown-preview` — Markdown 渲染
   - `npm:pi-subagents` — 子代理
   - `npm:pi-mcp-adapter` — MCP 支持
   - `npm:pi-web-access` — Web 搜索
   - `npm:pi-ask-user` — 交互询问
   - `npm:@fission-ai/openspec` — SDD 工作流

## 🔑 配置 API Key

```bash
export OPENAI_API_KEY='your-bailian-key'
```

或使用 `/keys` 命令在 Pi 中配置。

## 📊 配置统计

| 类型 | 数量 |
|------|------|
| Packages | 10 |
| Extensions | 13 (含 plan-mode) |
| Prompts | 12 |
| Skills (本地) | 1 |
| Skills (superpowers) | 14 |
| Skills (anthropics) | 17 |
| Skills (badlogic) | 10 |
| Skills (.claude) | 266 (可选) |
| Models | 5 |

## 🔧 验证

```bash
pi              # 启动
/settings       # 查看设置
/model          # 查看模型
/mcp            # MCP 状态
```
