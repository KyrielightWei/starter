# AI Component Manager - 用户指南

> 组件管理器提供统一的界面管理 AI 开发框架（ECC、GSD 等）

---

## 快速开始

### 打开组件管理器

```vim
:AIComponents
```

或使用快捷键：`<leader>kc`

### 选择器界面

```
╔══════════════════════════════════════════════════════════════╗
║  AI Component Manager                                    [?] Help ║
╠══════════════════════════════════════════════════════════════╣
║  > 🔧 ECC (Everything Claude Code)                            ║
║      Framework │ ✓ installed │ git: abc123                   ║
║                                                               ║
║    🚀 GSD (Get Shit Done)                                     ║
║      Framework │ ○ not installed │ npm: 1.37.2               ║
╠══════════════════════════════════════════════════════════════╣
║  Tool Assignments:                                            ║
║    OpenCode    → ECC ✓                                        ║
║    Claude Code → ECC                                          ║
╠══════════════════════════════════════════════════════════════╣
║  [Enter] Actions │ [i] Install │ [u] Update │ [x] Uninstall   ║
║  [s] Switch │ [v] Version │ [r] Refresh │ [q] Quit            ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 快捷键说明

| Key | 功能 | 说明 |
|-----|------|------|
| `Enter` | 打开操作菜单 | 显示二级菜单（安装、更新、卸载等） |
| `i` | 安装 | 安装选中的组件 |
| `u` | 更新 | 更新选中的组件 |
| `x` | 卸载 | 卸载选中的组件（有确认对话框） |
| `s` | 切换 | 选择工具使用该组件 |
| `v` | 版本 | 显示详细版本信息 |
| `r` | 刷新 | 重新扫描组件 |
| `q` / `Esc` | 关闭 | 关闭选择器 |

---

## 命令列表

### 主命令

| 命令 | 功能 |
|------|------|
| `:AIComponents` | 打开组件选择器（推荐） |
| `:AIComponentList` | 列出所有已注册组件 |
| `:AIComponentRefresh` | 刷新组件发现 |

### 快捷命令

| 命令 | 功能 |
|------|------|
| `:AIComponentInstall <name>` | 安装指定组件 |
| `:AIComponentUpdate [name]` | 更新组件（不指定则更新所有） |
| `:AIComponentSwitch <tool> <comp>` | 切换工具组件 |

---

## 已支持组件

### ECC (Everything Claude Code)

| 属性 | 值 |
|------|---|
| **类别** | Framework |
| **仓库** | https://github.com/affaan-m/everything-claude-code |
| **安装方式** | git clone + npm install |
| **支持工具** | claude, opencode |
| **图标** | 🔧 |

**功能**：
- 规则系统 (coding-style, testing, security)
- 命令集 (plan, tdd, code-review)
- 代理集 (planner, tdd-guide, code-reviewer)
- 技能集 (skill-studio)

### GSD (Get Shit Done)

| 属性 | 值 |
|------|---|
| **类别** | Framework |
| **仓库** | https://github.com/gsd-build/get-shit-done |
| **npm 包** | `get-shit-done-cc` |
| **安装方式** | `npx -y get-shit-done-cc@latest` |
| **支持工具** | claude, opencode, gemini, cursor, codex, windsurf |
| **图标** | 🚀 |

**功能**：
- Spec-driven 开发系统
- Meta-prompting 框架
- Context engineering

---

## 工具-组件切换

每个 AI CLI 工具可以独立选择使用的框架：

```
OpenCode    → ECC (当前)
Claude Code → GSD
Gemini CLI  → GSD
Cursor      → GSD
```

**切换方法**：
1. 在选择器中选择组件
2. 按 `s` 打开切换菜单
3. 选择要切换的工具

**命令方式**：
```vim
:AIComponentSwitch opencode gsd
```

---

## 依赖处理

### 缺少依赖时的行为

当尝试安装/更新组件时，如果缺少必需依赖：

1. **预览器显示** — 右侧显示 ✗ 标记和安装提示
2. **阻止操作** — 必需依赖缺失时无法安装
3. **显示对话框** — 提供各平台安装命令

```
╔══════════════════════════════════════════╗
║  ⚠️  Missing Dependencies                 ║
║                                          ║
║  Cannot install GSD:                     ║
║                                          ║
║  Required: npm                           ║
║                                          ║
║  Install:                                ║
║    Ubuntu:  apt install nodejs npm       ║
║    macOS:  brew install node npm         ║
║    Arch:   pacman -S nodejs npm          ║
║                                          ║
║  [Copy Command] [Close]                  ║
╚══════════════════════════════════════════╝
```

### 各组件依赖

| 组件 | 必需依赖 |
|------|----------|
| ECC | git, npm, node |
| GSD | npx, node |

---

## 版本管理

### 版本状态显示

| 状态 | 含义 |
|------|------|
| `current` | 已安装最新版本 |
| `outdated` | 有更新可用 |
| `newer` | 本地版本比远程新 |
| `unknown` | 无法获取版本信息 |
| `not_installed` | 未安装 |
| `on_demand` | 使用 npx 按需运行（GSD） |

### 版本来源

| 组件 | 版本来源 |
|------|----------|
| ECC | Git commit hash |
| GSD | npm package version |

---

## 扩展指南：添加新组件

### 步骤

1. **创建目录**
   ```bash
   mkdir -p lua/ai/components/my_component
   ```

2. **实现 init.lua**

   ```lua
   local M = {}

   -- 必需字段
   M.name = "my_component"
   M.display_name = "My Component"
   M.version = "1.0.0"
   M.category = "framework"  -- framework | tool | integration
   M.description = "Description"
   M.repo_url = "https://..."
   M.npm_package = "my-package"  -- 或 nil
   M.dependencies = { "npm" }
   M.icon = "📦"
   M.supported_targets = { "claude", "opencode" }

   -- 必需方法
   function M.setup(opts) return true end
   function M.is_installed() return vim.fn.filereadable(config_path) == 1 end
   function M.get_status() return { ... } end
   function M.get_version_info() return { current, latest, status } end
   function M.check_dependencies() return { ... } end
   function M.install(opts, cb) return true, "message" end
   function M.uninstall(opts) return true, "message" end
   function M.update(opts) return true, "message" end
   function M.health_check() return { status, message } end

   return M
   ```

3. **自动发现** — 无需手动注册，系统自动扫描

### 接口规范

必需字段：
- `name` (string)
- `setup` (function)
- `is_installed` (function)
- `get_status` (function)
- `get_version_info` (function)
- `check_dependencies` (function)
- `install` (function)
- `uninstall` (function)
- `update` (function)
- `health_check` (function)

可选字段：
- `display_name`
- `version`
- `category`
- `description`
- `repo_url`
- `npm_package`
- `dependencies`
- `icon`
- `supported_targets`

---

## 常见问题

### Q: 选择器无法打开？

检查 fzf-lua 是否安装：
```vim
:Lazy install fzf-lua
```

### Q: 组件显示未安装但实际已安装？

刷新组件状态：
```vim
:AIComponentRefresh
```

### Q: 如何查看组件详情？

在选择器中，右侧预览面板自动显示详细信息。

### Q: 切换后如何生效？

切换工具-组件分配后，下次启动对应工具时生效。状态持久化在 `~/.local/state/nvim/ai_component_state.lua`。

---

## 相关文档

- [ECC_GUIDE.md](ECC_GUIDE.md) — ECC 框架详细使用指南
- [COMPONENT_MANAGER_PLAN.md](docs/COMPONENT_MANAGER_PLAN.md) — 实现计划（开发者参考）

---

**文档版本**: 1.0  
**最后更新**: 2026-04-18