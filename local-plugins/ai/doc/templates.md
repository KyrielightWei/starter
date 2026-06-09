# 模板结构参考

本文档说明各 AI 工具配置模板的文件结构和关键字段。

## Pi

### settings.json

由 `templates/pi/default.template.jsonc` 生成。关键字段：

```jsonc
{
  "defaultProvider": "bailian",        // 默认 Provider
  "defaultModel": "glm-5",             // 默认模型
  "defaultThinkingLevel": "medium",    // off/minimal/low/medium/high/xhigh
  "theme": "flexoki-dark",             // 主题名
  "packages": [...],                   // 已安装包列表
  "skills": ["~/.claude/skills"],      // skill 扫描路径
  "compaction": { "enabled": true },   // 上下文压缩
  "terminal": { "showTerminalProgress": true }
}
```

### models.json

由 `ai.pi.generate_models()` 动态生成，从 Provider 注册表和 Key 配置构建。不需要手动编辑模板。

### 资源文件

Pi 的资源模板在 `pi/` 目录下，通过 `:PiGenerate` 同步到 `~/.pi/agent/`：

| 源文件 | 目标 |
|--------|------|
| `pi/AGENTS.template.md` | `~/.pi/agent/AGENTS.md` |
| `pi/keybindings.template.jsonc` | `~/.pi/agent/keybindings.json` |
| `pi/extensions/*.template.ts` | `~/.pi/agent/extensions/*.ts` |
| `pi/skills/openspec/` | `~/.pi/agent/skills/openspec/` |

## OpenCode

### opencode.json

由 `opencode.template.jsonc`（legacy）或 `templates/opencode/<version>.template.jsonc` 生成。

```jsonc
{
  // Provider 配置 — 动态注入，不需要手动填写
  "provider": {},

  // 权限配置
  "permission": {
    "read": { "*": "allow", "*.env": "ask" },
    "edit": { "*": "ask" },
    "bash": {
      "*": "ask",
      "ls *": "allow",
      "git status*": "allow",
      "rm *": "ask"
    }
  },

  // 文件监视
  "watcher": { "ignore": ["node_modules/**", ".git/**"] },

  // 上下文压缩
  "compaction": { "auto": true, "reserved": 10000 }
}
```

### TUI 配置

`:OpenCodeTheme generate` 生成 `~/.config/opencode/tui.json`，包含主题颜色和 UI 配置。

## Claude Code

### settings.json

由 `claude_code.template.jsonc` 生成，写入 `~/.claude/settings.json`。

```jsonc
{
  // 环境变量
  "env": { "XDG_STATE_HOME": "/tmp/claude-state" },

  // 状态栏
  "statusLine": {
    "type": "command",
    "command": "npx -y ccstatusline@latest"
  },

  // 权限（示例）
  // "permissions": {
  //   "allow": ["Read", "Write", "Edit", "Bash"],
  //   "deny": ["Bash(rm -rf /*)"]
  // }
}
```

### ccstatusline 配置

由 `ccstatusline.template.jsonc` 生成，写入 `~/.config/ccstatusline/settings.json`。

定义 4 行状态栏，包含 19 个 widget：

```jsonc
{
  "version": 3,
  "lines": [
    // Line 1: model, git-branch, git-changes, session-cost, session-clock
    // Line 2: tokens-input, tokens-output, tokens-cached, context-bar, compaction-counter
    // Line 3: output-speed, session-usage, weekly-usage, block-timer, block-reset-timer
    // Line 4: extra-usage-utilization, extra-usage-remaining, session-name, git-root-dir
  ]
}
```

## 合并策略

所有工具的配置生成都采用**保守合并**：

1. 读取模板文件作为基础
2. 动态注入 Provider/Key/Model 配置
3. 如果目标文件已存在，保留用户添加的额外字段
4. 模板中的字段覆盖已有值，但不删除模板中没有的字段
5. 数组类型字段（如 `packages`）采用 union 合并（去重）
