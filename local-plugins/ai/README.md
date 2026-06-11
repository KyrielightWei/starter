# ai.nvim

AI coding tool 配置管理插件 — 统一管理 OpenCode、Claude Code、Pi 的配置生成、Provider 管理、模型切换。

## 安装

通过 lazy.nvim 加载本地插件：

```lua
-- lua/plugins/ai.lua
return {
  {
    dir = vim.fn.stdpath("config") .. "/local-plugins/ai",
    name = "ai-tools",
    lazy = false,
    dependencies = { "nvim-lua/plenary.nvim" },
  },
}
```

## 快速开始

1. 配置 API Key（环境变量或 `ai.keys.edit()`）
2. `:AIProvider` 选择 Provider
3. `:AIModel` 切换模型
4. `:AISync` 同步配置到目标工具

## 命令

### 高频命令

| 命令 | 说明 | 快捷键 |
|------|------|--------|
| `:AIModel` | 切换模型（支持全局/工具级） | `<leader>kk` |
| `:AISync` | 选择并同步配置 | `<leader>ks` |
| `:AIKeys` | 编辑 API Keys | `<leader>ke` |
| `:AIProvider` | 打开 Provider Manager | `<leader>kp` |

### 工具配置命令

| 操作 | OpenCode | Claude Code | Pi |
|------|----------|-------------|-----|
| 生成配置 | `:OpenCodeGenerate` | `:ClaudeCodeGenerate` | `:PiGenerate` |
| 预览配置 | `:OpenCodePreview` | `:ClaudeCodePreview` | `:PiPreview` |
| 编辑模板 | `:OpenCodeEdit` | `:ClaudeCodeEdit` | `:PiEdit` |
| 查看状态 | `:OpenCodeStatus` | `:ClaudeCodeStatus` | `:PiStatus` |

OpenCode 额外支持 TUI 主题：`:OpenCodeTheme [generate|preview|edit]`

### 维护命令

```
:AI template list [tool]              列出模板版本
:AI template select [tool]            选择模板版本
:AI template create <tool> <name>     创建模板版本
:AI template delete <tool> <name>     删除模板版本
:AI template rename <tool> <old> <new> 重命名模板版本
:AI template edit                     编辑当前模板

:AI context copy                      复制上下文到剪贴板
:AI context show                      显示当前上下文

:AI prompt edit                       编辑提示词文件
:AI prompt list                       列出提示词

:AI watch                             启用配置热更新
:AI watch force                       强制同步配置

:AI export                            导出 API Keys 到 .env 文件

:AI backup <opencode|claude> [n]      恢复备份
```

### Commit Picker

| 命令/快捷键 | 说明 |
|-------------|------|
| `<leader>kC` | 打开 Commit Picker |
| `<leader>kf` | 下一个 Commit |
| `<leader>kb` | 上一个 Commit |
| `<leader>kd` | Diff 查看器 |

### AI Review Workbench

| 命令/快捷键 | 说明 |
|-------------|------|
| `:AIReviewStart` / `<leader>krr` | 开始 review session |
| `:AIReviewAdd` / `<leader>kra` | 在当前位置添加 review comment |
| `:AIReviewPanel` / `<leader>krl` | 打开 review comment 面板 |
| `:AIReviewExport` / `<leader>krx` | 导出 `notes.md`、`notes.json`、`fix-prompt.md` |
| `:AIReviewStatus` / `<leader>krs` | 查看当前 review session 状态 |
| `:AIReviewClose` | 关闭当前 review session |

Review 数据默认保存到项目内 `.ai-review/`，便于 AI 工具读取。该目录通常是本地工作产物，建议按需加入项目 `.gitignore`。

## 配置

```lua
require("ai").setup({
  template_dir = vim.fn.stdpath("config"),  -- 模板文件根目录
})
```

## 文档

- [配置指南](doc/configuration.md) — Provider、API Key、模板系统
- [模板参考](doc/templates.md) — 各工具模板结构和字段说明
- [架构说明](doc/architecture.md) — 模块依赖和扩展方式
- AI Review Workbench — 使用 `:AIReviewStart` 基于 diffview 记录和导出 review 意见
