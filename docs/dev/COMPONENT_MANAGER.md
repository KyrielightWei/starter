# AI 组件管理系统 - 设计与实现文档

> 最后更新: 2026-04-19
> 状态: 开发中 (核心基础完成，关键集成待修复)

---

## 1. 项目概述

### 1.1 设计目标

构建一个可扩展的组件管理架构，实现：

- **插件式注册** — 新组件无需修改核心代码即可添加
- **自动发现** — 自动扫描并加载已安装的组件
- **统一管理** — 一个入口管理所有组件的安装、卸载、更新
- **版本管理** — 显示每个组件的当前版本和最新可用版本
- **工具切换** — 每个工具（OpenCode、Claude Code）可独立选择使用的组件
- **本地缓存 + 分发** — 组件下载到本地缓存，通过软链接/拷贝分发到具体工具，避免重复网络请求

### 1.2 组件清单

| 组件 | 仓库 | 安装方式 | 支持目标 | npm 包 |
|------|------|----------|----------|--------|
| ECC | `github.com/affaan-m/everything-claude-code` | `git clone + npm install` | claude, opencode | 无 (git) |
| GSD | `github.com/gsd-build/get-shit-done` | `npx get-shit-done-cc@latest` | claude, opencode, gemini, cursor, codex, windsurf | `get-shit-done-cc` |

### 1.3 组件接口规范

每个组件必须实现以下方法：

| 方法 | 返回值 | 说明 | 网络请求 |
|------|--------|------|----------|
| `setup(opts)` | boolean | 初始化组件 | 无 |
| `is_installed()` | boolean | 检测是否已安装 | 无 |
| `get_status()` | table\|nil | 获取状态信息 | 无 |
| `get_version_info()` | VersionInfo | 获取版本状态（带缓存） | **可能有** |
| `check_dependencies()` | table[] | 检查依赖 | 无 |
| `install(opts, callback)` | boolean, string | 安装 | **是** |
| `uninstall(opts)` | boolean, string | 卸载 | 无 |
| `update(opts)` | boolean, string | 更新 | **可能有** |
| `health_check()` | HealthStatus | 健康检查 | 无 |
| `get_config_dir()` | string | 配置目录路径 | 无 |

```lua
---@class VersionInfo
---@field current string|nil    -- 当前版本
---@field latest string|nil     -- 最新版本
---@field status string         -- "current"|"outdated"|"not_installed"|"unknown"|"on_demand"

---@class HealthStatus
---@field status string         -- "ok"|"warn"|"error"
---@field message string        -- 描述信息
```

---

## 2. 架构设计

### 2.1 目录结构

```
lua/ai/
├── components/                    # 组件管理器
│   ├── init.lua                   # 入口：setup, 命令注册, 快捷键
│   ├── interface.lua              # 组件接口规范定义 + 验证
│   ├── registry.lua               # 组件注册表 (register/list/get)
│   ├── discovery.lua              # 自动发现机制 (目录扫描)
│   ├── version.lua                # 版本检测 (npm/git, 同步+异步)
│   ├── switcher.lua               # 工具-组件切换逻辑 + 版本缓存
│   ├── picker.lua                 # fzf-lua 选择器 UI
│   ├── previewer.lua              # 预览器 (详情查看)
│   ├── actions.lua                # 安装/卸载/更新操作
│   ├── ecc/                       # ECC 组件实现
│   │   ├── init.lua
│   │   ├── installer.lua
│   │   ├── status.lua
│   │   ├── uninstaller.lua
│   │   └── updater.lua
│   └── gsd/                       # GSD 组件实现
│       ├── init.lua
│       ├── installer.lua
│       ├── status.lua
│       ├── uninstaller.lua
│       └── updater.lua
│
├── ecc.lua                        # 向后兼容 shim → components/ecc
├── gsd.lua                        # 向后兼容 shim → components/gsd
├── opencode.lua                   # OpenCode 配置生成 (⚠️ 待修复)
├── claude_code.lua                # Claude Code 配置生成 (⚠️ 待集成组件系统)
├── init.lua                       # AI 模块入口 (已集成组件管理器)
└── health.lua                     # 健康检查

lua/plugins/
└── opencode.lua                   # OpenCode 插件 (命令定义)
```

### 2.2 数据流

#### 2.2.1 组件发现与注册

```
Neovim 启动
  → require("ai.components").setup()
    → Discovery.auto_load()
      → scan_all_dirs() → 扫描 lua/ai/components/ 目录
      → 对每个发现的目录 require("ai.components." .. name)
      → Registry.register(name, component) → Interface.validate()
    → 注册全局命令 (:AIComponents, :AIComponentList, ...)
    → 注册快捷键 (<leader>kc)
```

#### 2.2.2 工具选择组件 (当前有 BUG)

```
用户操作: :AIComponents → 选择 GSD → 切换到 opencode
  → Switcher.switch("opencode", "gsd")
    → 写入 ~/.local/state/nvim/ai_component_state.lua:
      { active = { opencode = "gsd", claude = "ecc" } }

⚠️ BUG: opencode.lua:write_config() 硬编码使用 ECC，忽略 switcher 状态
⚠️ BUG: claude_code.lua:write_settings() 直接 require("ai.ecc")，不走组件系统
```

#### 2.2.3 版本查询 (异步优化)

```
打开选择器 (秒开)
  → build_entries() → 读缓存 (ms 级，无网络)
  → fzf 窗口显示
  → vim.defer_fn(500ms): Switcher.refresh_versions_async()
    → jobstart("npm view ...") → 回调更新缓存
    → jobstart("git ls-remote ...") → 回调更新缓存
```

#### 2.2.4 安装流程 (应改为缓存+分发模式，待实现)

```
当前实现 (有问题):
  → Picker: Install → Actions.install()
  → ECC: git clone /tmp → npm install → 复制到 ~/.claude/
  → GSD: npx --opencode --claude → 写入各工具目录

理想架构 (待实现):
  → 下载组件到本地缓存 (~/.local/share/nvim/ai_components/cache/)
  → 更新缓存后，soft link 或 copy 到具体工具目录
  → 优点: 避免重复网络请求，多工具共享一份缓存，离线可用
```

### 2.3 状态文件

路径: `~/.local/state/nvim/ai_component_state.lua`

```lua
return {
  active = {
    opencode = "gsd",    -- OpenCode 当前使用的组件
    claude = "ecc",      -- Claude Code 当前使用的组件
  },
  last_check = "2026-04-19T11:44:22",
  versions = {
    ecc = {
      current = nil,           -- 应为 git commit hash
      latest = "<commit_hash>",
      status = "unknown",      -- 缓存未更新时
    },
    gsd = {
      current = "npx latest",  -- npx 模式无本地版本
      latest = "1.37.1",       -- npm 最新版本
      status = "on_demand",    -- npx 按需运行
    },
  },
}
```

---

## 3. 核心模块说明

### 3.1 Registry (registry.lua)

```lua
M._registry = {}              -- 内部注册表

M.register(name, component)   -- 注册组件 (通过 Interface.validate)
M.register_batch(components)  -- 批量注册
M.get(name)                   -- 获取组件
M.list()                      -- 列出所有组件 (调用 is_installed, 无网络)
M.list_installed()            -- 已安装列表
M.list_uninstalled()          -- 未安装列表
M.list_outdated()             -- ⚠️ BUG: 始终返回空 (version_info 未填充)
M.count()                     -- 组件数量
M.clear()                     -- 清空注册表 (测试用)
```

### 3.2 Discovery (discovery.lua)

```lua
COMPONENT_DIRS = {
  "~/.config/nvim/lua/ai/components",     -- 项目内组件
  "~/.local/share/nvim/ai-components",    -- 用户自定义组件
}

EXCLUDE_NAMES = {
  "init.lua", "interface.lua", "registry.lua", "discovery.lua",
  "version.lua", "switcher.lua", "actions.lua", "picker.lua", "previewer.lua", "types.lua", "_template.lua"
}

M.scan_all_dirs()   -- 扫描目录
M.auto_load()       -- 自动加载发现的组件
M.add_dir(path)     -- 添加额外目录
M.reload()          -- 重新扫描 (清空注册表)
```

### 3.3 Switcher (switcher.lua)

```lua
M.load_state()                    -- 从文件加载 (带缓存)
M.save_state(state)              -- 写入文件
M.switch(tool, component_name)   -- 切换并保存
M.get_active(tool)               -- 获取工具当前组件
M.get_all()                      -- 获取所有工具分配
M.get_tools_using(component_name)-- 获取使用某组件的工具
M.update_version_cache()         -- 更新缓存版本信息
M.get_version_cache()            -- 获取缓存版本信息
M.refresh_versions_async()       -- 异步刷新所有远程版本 (jobstart)
M.clear_cache()                  -- 清除会话缓存
M.reset()                        -- 重置状态到默认值
```

### 3.4 Version (version.lua)

```lua
-- 同步方法 (供 installer/updater 调用)
M.get_latest_npm_version(package)    -- npm view | vim.fn.system
M.get_latest_git_version(repo)       -- git ls-remote | vim.fn.system

-- 异步方法 (供 UI 后台刷新调用)
M.get_latest_npm_version_async(package, callback)  -- jobstart
M.get_latest_git_version_async(repo, callback)     -- jobstart

-- 本地版本
M.get_installed_version(cmd)         -- cmd --version
M.get_local_git_version(path)        -- git rev-parse HEAD

-- 工具方法
M.parse_semver(str)                  -- 解析 semver
M.compare_versions(v1, v2)           -- 比较版本
M.parse_from_string(str)             -- 从文本提取版本号
```

### 3.5 Picker (picker.lua)

fzf-lua 选择器 UI，主入口为 `:AIComponents` 或 `<leader>kc`。

```
主列表:
  ✓ 🔧 Everything Claude Code │ framework │ ⚠️  (outdated)
  ○ 🚀 Get Shit Done          │ framework │

按键:
  Enter  →  操作菜单 (Install/Update/Uninstall/Switch/Version/Config)
  Ctrl+I →  安装
  Ctrl+U →  更新
  Ctrl+X →  卸载
  Ctrl+S →  切换工具
  Ctrl+V →  版本详情
  Ctrl+R →  刷新
```

---

## 4. 已知问题与修复记录

### 4.1 Critical (必须修复)

| # | 问题 | 文件 | 行号 | 状态 |
|---|------|------|------|------|
| C1 | `Ecc.ensure_installed()` 不存在，`opencode:write_config()` 崩溃 | `opencode.lua:520` | - | **待修复** |
| C2 | `opencode.lua` 有死代码 (453-516行)，引用未定义变量 | `opencode.lua:453-516` | - | **待修复** |
| C3 | `Registry.list_outdated()` 始终返回空 (version_info 未填充) | `registry.lua:119` | - | **待修复** |
| C4 | 组件切换状态未被配置生成器读取 | `opencode.lua`, `claude_code.lua` | - | **待修复** |
| C5 | ECC uninstaller 删除整个 `~/.claude/commands/` 等目录，不区分内容 | `ecc/uninstaller.lua` | - | **待修复** (高风险) |

### 4.2 Medium (重要)

| # | 问题 | 文件 | 行号 | 状态 |
|---|------|------|------|------|
| M1 | GSD `is_installed()` 在 npx 模式下应返回 true (已修复: 优先检查 npx) | `gsd/status.lua:20` | - | ✅ 已修复 |
| M2 | `version.lua` 的同步方法曾被误删 (已恢复) | `version.lua` | - | ✅ 已修复 |
| M3 | fzf-lua `previewer` API 变更 (已改为 `winopts.preview.fn`) | `previewer.lua:130`, `picker.lua:108` | - | ✅ 已修复 |
| M4 | GSD 安装命令未显式指定 `--opencode` 目标 | `gsd/installer.lua:60` | - | ✅ 已修复 |
| M5 | `vim.api.nvim_buf_set_option` 在 0.10+ 已弃用 | 多个文件 | - | 待修复 |
| M6 | 安装是黑盒，无进度显示 | `actions.lua`, 各 installer | - | **待实现** |

### 4.3 Low (改进项)

| # | 问题 | 状态 |
|---|------|------|
| L1 | `types.lua` 未创建 | 待创建 |
| L2 | `status_panel.lua` 未创建 | 待创建 |
| L3 | `ecc/commands.lua`, `gsd/commands.lua` 未创建 | 待创建 |
| L4 | ccstatusline 组件未迁移 | Phase 4 未开始 |
| L5 | `_template.lua` 未创建 | 待创建 |
| L6 | `manager.lua` (缓存+分发) 未实现 | 架构改进待实现 |
| L7 | `syncer.lua` (文件系统同步器) 未实现 | 架构改进待实现 |
| L8 | 安装流程应改为"缓存 + 分发"模式 | 架构改进待实现 |

---

## 5. 实施计划

详见 [COMPONENT_MANAGER_PLAN.md](./COMPONENT_MANAGER_PLAN.md)

### 5.1 新增计划: 缓存 + 分发架构

```
当前: 工具A 安装 → npx/git → 写入工具A目录
      工具B 安装 → npx/git → 写入工具B目录  (重复下载)

理想: 下载/更新 → 本地缓存 → 分发(软链接/拷贝) → 工具目录
      (一次下载，多次分发，多工具共享)

目录结构:
~/.local/share/nvim/ai_components/
├── cache/
│   ├── ecc/              ← git clone 此处
│   └── gsd/              ← npx 解析资源存放此处
└── state/
    └── component_state.lua  (已有)
```

---

## 6. 用户命令

| 命令 | 说明 |
|------|------|
| `:AIComponents` | 打开组件管理选择器 |
| `:AIComponentList` | 显示所有已注册组件 |
| `:AIComponentInstall <name>` | 安装指定组件 |
| `:AIComponentUpdate <name>` | 更新指定组件 |
| `:AIComponentUninstall <name>` | 卸载指定组件 |
| `:AIComponentSwitch` | 打开切换选择器 |
| `:AIComponentRefresh` | 重新发现组件 |

快捷键: `<leader>kc` → 打开选择器

---

## 7. 参考资源

- [ECC 官方文档](https://github.com/affaan-m/everything-claude-code)
- [GSD 官方文档](https://github.com/gsd-build/get-shit-done)
- [COMPONENT_MANAGER_PLAN.md](./COMPONENT_MANAGER_PLAN.md) - 原始设计文档
- [CC_SWITCH_COMPARISON.md](./CC_SWITCH_COMPARISON.md) - CC Switch 对比分析
