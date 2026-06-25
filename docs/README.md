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
| [diffview.md](diffview.md) | Diffview 配置指南 |
| [terminal.md](terminal.md) | 终端管理配置 |
| [skill-studio.md](skill-studio.md) | Skill Studio 工具 |

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
| AI 模块 | `local-plugins/ai/lua/ai/` |
| Provider Manager | `local-plugins/ai/lua/ai/provider_manager/` |
| Commit Picker | `local-plugins/ai/lua/commit_picker/` |
| API Keys | `~/.local/state/nvim/ai_keys.lua` |

