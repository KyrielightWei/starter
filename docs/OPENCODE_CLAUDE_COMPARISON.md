# OpenCode vs Claude Code 配置迁移指南

## 当前差距分析

| 功能 | Claude Code | OpenCode | 迁移策略 |
|------|-------------|----------|----------|
| Skills | skills/ 目录 | commands/ 目录 | 创建 commands 并移植 |
| Agents | agents/ 目录 | 内置 plan/build/auto | 使用 `opencode agent create` |
| Memory | memory/ 文件 | instructions.md | 合并到 instructions |
| Hooks | hooks 配置 | plugin 系统 | 待验证 |
| Rules | rules/ 目录 | 无 | 合并到 instructions |
| MCP | mcp 配置 | mcp 命令 | 直接复用 |
| Permissions | allow/deny/ask | permission 对象 | 已支持 |

## 配置步骤

### 1. 创建 Commands 目录（Skills 对应）

```bash
mkdir -p ~/.config/opencode/commands
```

Commands 是 OpenCode 的 "slash commands"，类似 Claude Code 的 Skills。

### 2. 添加 MCP Servers

```bash
# 示例：添加 Context7
opencode mcp add context7 --command "npx -y @context7/mcp-server"

# 查看已添加的 MCP
opencode mcp list
```

### 3. 自定义 Agents

```bash
# 创建新 agent
opencode agent create my-custom-agent

# 查看已有 agents
opencode agent list
```

### 4. 配置 instructions.md

编辑 `~/.config/opencode/instructions.md`，合并 Claude Code 的：
- 规则（rules/）
- 记忆（memory/）
- 系统提示

### 5. 完整配置示例

```json
{
  "model": "anthropic/claude-3.7-sonnet",
  "small_model": "anthropic/claude-3.5-haiku",
  "default_agent": "build",

  "agent": {
    "plan": {
      "permission": {
        "read": "allow",
        "glob": "allow",
        "grep": "allow",
        "bash": "ask",
        "edit": "ask",
        "write": "ask"
      }
    },
    "build": {
      "permission": {
        "read": "allow",
        "glob": "allow",
        "grep": "allow",
        "bash": "allow",
        "edit": "allow",
        "write": "allow",
        "webfetch": "allow",
        "websearch": "allow"
      }
    },
    "auto": {
      "permission": {
        "read": "allow",
        "glob": "allow",
        "grep": "allow",
        "bash": "allow",
        "edit": "allow",
        "write": "allow",
        "webfetch": "allow",
        "websearch": "allow"
      }
    }
  },

  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 10000
  },

  "watcher": {
    "ignore": ["node_modules/**", "dist/**", ".git/**", "*.log"]
  },

  "autoupdate": "notify"
}
```

## Commands 创建示例

创建一个简单的 command：

```bash
# 创建 command 文件
cat > ~/.config/opencode/commands/review.md << 'EOF'
# Code Review

Review the current file or selection for:
- Code quality
- Security issues
- Performance concerns
- Best practices

Provide actionable feedback with severity levels.
EOF
```

使用：在 OpenCode 中输入 `/review`

## MCP 配置复用

将 Claude Code 的 MCP 配置迁移：

```bash
# Claude Code MCP 配置位置
cat ~/.claude/settings.json | jq '.mcpServers'

# 在 OpenCode 中逐个添加
opencode mcp add <server-name> --command "<command>"
```

## 差距总结

OpenCode 目前缺少：
1. **丰富的预置 Skills** - 需要手动创建 commands
2. **Hooks 系统** - 可能通过 plugin 实现
3. **Memory 自动管理** - 需手动维护 instructions.md
4. **ccstatusline** - 无状态栏工具

OpenCode 优势：
1. 内置多 agent 模式（plan/build/auto）
2. 更简洁的配置结构
3. 原生支持多 provider
4. Web/serve 模式支持