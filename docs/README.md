# 配置文档索引

本目录包含 Neovim 配置的详细使用说明。

## 文档列表

| 文档 | 说明 |
|------|------|
| [AI_KEYMAPS.md](AI_KEYMAPS.md) | AI 快捷键完整参考 |
| [PROVIDER_MANAGER_GUIDE.md](PROVIDER_MANAGER_GUIDE.md) | Provider Manager 使用指南 |
| [COMMIT_PICKER_GUIDE.md](COMMIT_PICKER_GUIDE.md) | Commit Picker & Diff 使用指南 |
| [COMPONENT_MANAGER_GUIDE.md](COMPONENT_MANAGER_GUIDE.md) | Component Manager 使用指南 |
| [COMPONENT_MANAGER_API.md](COMPONENT_MANAGER_API.md) | Component Manager API 参考 |
| [ai-module.md](ai-module.md) | AI 模块配置指南 |
| [OPENCODE_CLAUDE_COMPARISON.md](OPENCODE_CLAUDE_COMPARISON.md) | OpenCode vs Claude Code 对比 |
| [MULTI_MODEL_AI_CODING_TOOLS_COMPARISON.md](MULTI_MODEL_AI_CODING_TOOLS_COMPARISON.md) | 多模型 AI 编码工具对比 |
| [diffview.md](diffview.md) | Diffview 配置指南 |
| [terminal.md](terminal.md) | 终端管理配置 |
| [skill-studio.md](skill-studio.md) | Skill Studio 工具 |

## 模型测试报告

| 报告 | 说明 |
|------|------|
| [../BAILIAN_CODING_TEST_REPORT.md](../BAILIAN_CODING_TEST_REPORT.md) | 百炼模型编码测试报告 |
| [../BAILIAN_CODING_TEST_REPORT_FINAL.md](../BAILIAN_CODING_TEST_REPORT_FINAL.md) | 百炼模型测试最终报告 |

## 快速参考

### AI 快捷键 (`<leader>k`)

| 快捷键 | 功能 |
|--------|------|
| `<leader>kc` | AI Chat |
| `<leader>kp` | Provider Manager |
| `<leader>kC` | Commit Picker |
| `<leader>kd` | Diff Viewer |
| `<leader>ks` | Model Switch |

### 配置文件位置

| 配置 | 路径 |
|------|------|
| AI 模块 | `lua/ai/` |
| Provider Manager | `lua/ai/provider_manager/` |
| Commit Picker | `lua/commit_picker/` |
| Component Manager | `lua/ai/components/` |
| API Keys | `~/.local/state/nvim/ai_keys.lua` |
| Providers 注册 | `lua/ai/providers.lua` |
