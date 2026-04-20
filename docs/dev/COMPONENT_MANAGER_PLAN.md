# AI Component Manager - Implementation Plan

> 可扩展的组件管理架构，支持动态注册 ECC、GSD、ccstatusline 等组件

**创建时间**: 2026-04-18
**预计工作量**: 8-11 小时
**风险等级**: Medium

---

## 1. 项目概述

### 1.1 目标

构建一个可扩展的组件管理架构，实现：
- **插件式注册** — 新组件无需修改核心代码即可添加
- **自动发现** — 自动扫描并加载已安装的组件
- **统一管理** — 一个入口管理所有组件的安装、卸载、更新
- **版本管理** — 显示每个组件的当前版本和最新可用版本
- **工具切换** — 每个工具（OpenCode、Claude Code）可独立选择使用的组件

### 1.2 已有组件

| 组件 | 仓库 | 安装方式 | 当前实现位置 | 状态 |
|------|------|----------|--------------|------|
| ECC | https://github.com/affaan-m/everything-claude-code | git clone + npm install | `lua/ai/ecc.lua` | 已有模块，需迁移 |
| GSD | https://github.com/gsd-build/get-shit-done | `npx get-shit-done-cc@latest` | 无 | 待实现 |
| ccstatusline | https://github.com/nick-field/ccstatusline | `npx -y ccstatusline@latest` | `lua/ai/claude_code.lua` (部分) | 需迁移 |

### 1.3 ccstatusline 现有实现

ccstatusline 目前集成在 `lua/ai/claude_code.lua` 中：
- 模板文件：`ccstatusline.template.jsonc`
- 配置路径：`~/.config/ccstatusline/settings.json`
- 同步函数：`write_ccstatusline_settings()`
- 编辑命令：`:ClaudeCodeEditCCStatuslineTemplate`

需要迁移到组件系统，提供独立的管理入口。

### 1.3 现有代码参考

| 文件 | 用途 |
|------|------|
| `lua/ai/ecc.lua` | 现有 ECC 安装模块（需迁移） |
| `lua/ai/providers.lua` | Provider 注册模式（可参考） |
| `lua/ai/skill_studio/registry.lua` | Skill 发现机制（可参考） |

---

## 2. 架构设计

### 2.1 目录结构

```
lua/ai/
├── components/                    # [新建] 组件管理器目录
│   ├── init.lua                   # 组件管理器入口（整合所有模块）
│   ├── interface.lua              # 组件接口规范定义
│   ├── registry.lua               # 组件注册表（register/list/get）
│   ├── discovery.lua              # 自动发现机制（目录扫描）
│   ├── types.lua                  # LuaDoc 类型定义
│   ├── status_panel.lua           # 状态面板 UI（浮动窗口显示）
│   ├── switcher.lua               # 工具-组件切换逻辑
│   ├── version.lua                # 版本检测核心（npm/git 版本查询）
│   │
│   ├── ecc/                       # [新建] ECC 组件实现
│   │   ├── init.lua               # 组件入口（实现接口）
│   │   ├── installer.lua          # 安装逻辑（git clone + npm）
│   │   ├── status.lua             # 状态检查
│   │   ├── uninstaller.lua        # 卸载逻辑
│   │   ├── updater.lua            # 更新逻辑
│   │   └── commands.lua           # 命令注册
│   │
│   ├── gsd/                       # [新建] GSD 组件实现
│   │   ├── init.lua               # 组件入口
│   │   ├── installer.lua          # 安装逻辑（npx/npm）
│   │   ├── status.lua             # 状态检查
│   │   ├── uninstaller.lua        # 卸载逻辑
│   │   ├── updater.lua            # 更新逻辑
│   │   └── commands.lua           # 命令注册
│   │
│   ├── ccstatusline/              # [新建] ccstatusline 组件示例
│   │   ├── init.lua               # 组件入口
│   │   ├── config.lua             # 配置生成
│   │   └── commands.lua           # 命令注册
│   │
│   └── _template.lua              # [新建] 组件开发模板（文档化）
│
├── ecc.lua                        # [修改] 向后兼容 shim（重定向到 components/ecc）
├── gsd.lua                        # [新建] 向后兼容 shim（重定向到 components/gsd）
├── init.lua                       # [修改] AI 模块入口（集成组件管理器）
└── health.lua                     # [修改] 健康检查（集成组件 health_check）
```

### 2.2 组件接口规范

每个组件必须实现以下接口：

```lua
---@class AIComponent
---@field name string                    -- 组件唯一标识（如 "ecc", "gsd"）
---@field version string                 -- 组件版本号
---@field category string                -- 类别："framework" | "tool" | "integration"
---@field description string             -- 组件描述
---@field repo_url string                -- 仓库 URL
---@field npm_package string|nil         -- npm 包名（可选）
---@field dependencies string[]          -- 依赖列表（如 {"git", "npm"}）
---@field icon string|nil                -- 显示图标（用于 UI）
---@field supported_targets string[]     -- 支持的目标工具（如 {"claude", "opencode"}）

---@class AIComponentInterface
---@field setup fun(opts: table): boolean                           -- 初始化组件
---@field is_installed fun(): boolean                               -- 检测是否已安装
---@field get_status fun(): table|nil                               -- 获取状态信息
---@field get_version_info fun(): table                             -- 获取版本状态 { current, latest, status }
---@field check_dependencies fun(): table[]                         -- 检查依赖
---@field install fun(opts: table, callback: function|nil): boolean, string  -- 安装
---@field uninstall fun(opts: table): boolean, string               -- 卸载
---@field update fun(opts: table): boolean, string                  -- 更新
---@field get_commands fun(): table[]                               -- 命令列表
---@field get_keymaps fun(): table[]                                -- 快捷键列表
---@field health_check fun(): table                                 -- 健康检查
```

### 2.3 注册 API

```lua
-- lua/ai/components/registry.lua

local M = {}

--- 注册组件
---@param name string 组件名称
---@param component AIComponent 组件实例
function M.register(name, component)
  -- 验证组件实现了必要接口
  local required = { "name", "setup", "is_installed", "get_status" }
  for _, method in ipairs(required) do
    if not component[method] then
      error(string.format("Component '%s' missing required method: %s", name, method))
    end
  end
  M._registry[name] = component
  M._registry[name]._registered_at = os.time()
end

--- 获取组件列表
---@return table[]
function M.list()
  local out = {}
  for name, comp in pairs(M._registry) do
    table.insert(out, {
      name = name,
      category = comp.category,
      description = comp.description,
      installed = comp.is_installed(),
      icon = comp.icon,
    })
  end
  return out
end

--- 获取指定组件
---@param name string
---@return AIComponent|nil
function M.get(name)
  return M._registry[name]
end

--- 获取已安装的组件
---@return table[]
function M.list_installed()
  return vim.tbl_filter(function(c)
    return c.installed
  end, M.list())
end

return M
```

### 2.4 工具-组件切换状态

状态文件路径: `~/.local/state/nvim/ai_component_state.lua`

```lua
return {
  active = {
    opencode = "ecc",      -- OpenCode 当前使用 ECC
    claude = "gsd",        -- Claude Code 当前使用 GSD
    gemini = "gsd",        -- Gemini CLI 使用 GSD（GSD 支持）
    cursor = "gsd",        -- Cursor 使用 GSD
  },
  last_check = "2026-04-18T12:00:00",
  versions = {
    ecc = {
      current = "installed",
      latest = nil,
      status = "unknown",     -- ECC 无 npm 版本，用 git commit 作为版本
    },
    gsd = {
      current = "1.37.1",
      latest = "1.37.2",
      status = "outdated",
    },
  },
}
```

---

## 3. 实现步骤

### Phase 1: 核心架构 (可并行部分 ★)

#### Step 1.1: 组件接口规范 (独立)
- **文件**: `lua/ai/components/interface.lua`
- **任务**: 定义组件接口和类型
- **代码**:
  ```lua
  -- 定义 AIComponent 和 AIComponentInterface 类
  -- 定义接口验证函数 validate_component()
  -- 定义必要方法列表和可选方法列表
  ```
- **依赖**: 无
- **验证**: `lua require('ai.components.interface').validate_component({...})`

#### Step 1.2: 组件注册表 (独立 ★)
- **文件**: `lua/ai/components/registry.lua`
- **任务**: 实现 register, list, get, list_installed
- **代码**:
  ```lua
  local M = { _registry = {} }
  function M.register(name, component) ... end
  function M.list() ... end
  function M.get(name) ... end
  function M.list_installed() ... end
  return M
  ```
- **依赖**: 无
- **验证**: 手动注册一个测试组件

#### Step 1.3: 类型定义 (独立 ★)
- **文件**: `lua/ai/components/types.lua`
- **任务**: LuaDoc 类型定义文件
- **代码**:
  ```lua
  -- 仅包含类型注释，无运行时代码
  -- @class AIComponent, AIComponentInterface, ComponentStatus, VersionInfo
  ```
- **依赖**: 无
- **验证**: IDE/LSP 能正确解析类型

#### Step 1.4: 发现机制 (依赖 1.2)
- **文件**: `lua/ai/components/discovery.lua`
- **任务**: 目录扫描和自动加载
- **代码**:
  ```lua
  function M.scan_components_dir() ... end  -- 扫描 lua/ai/components/
  function M.scan_user_components() ... end -- 扫描 ~/.local/share/nvim/ai-components/
  function M.auto_load() ... end            -- 自动加载发现的组件
  ```
- **依赖**: Step 1.2 (registry.lua)
- **验证**: 创建测试组件目录，验证自动发现

#### Step 1.5: 版本检测核心 (独立 ★)
- **文件**: `lua/ai/components/version.lua`
- **任务**: npm/git 版本查询和比较
- **代码**:
  ```lua
  function M.get_installed_version(cmd) ... end       -- 执行 cmd --version
  function M.get_latest_npm_version(package) ... end  -- npm view package version
  function M.get_latest_git_version(repo) ... end     -- git ls-remote 获取最新 commit
  function M.compare_versions(v1, v2) ... end         -- 版本比较
  function M.get_version_status(component) ... end    -- 综合状态查询
  ```
- **依赖**: 无
- **验证**: 测试 npm 版本查询（如 `npm view react version`）

#### Step 1.6: 组件管理器入口 (依赖 1.1-1.5)
- **文件**: `lua/ai/components/init.lua`
- **任务**: 整合所有核心模块
- **代码**:
  ```lua
  local Registry = require("ai.components.registry")
  local Discovery = require("ai.components.discovery")
  local Interface = require("ai.components.interface")
  
  function M.setup(opts) ... end       -- 初始化，触发 auto_load
  function M.register(...) ... end     -- 代理到 Registry
  function M.list(...) ... end         -- 代理到 Registry
  function M.get(...) ... end          -- 代理到 Registry
  function M.install(name, opts) ... end
  function M.update(name) ... end
  function M.uninstall(name) ... end
  ```
- **依赖**: Steps 1.1-1.5 全部完成
- **验证**: `lua require('ai.components').setup()` 无报错

**Phase 1 可并行部分**: Steps 1.1, 1.2, 1.3, 1.5 可同时开发

---

### Phase 2: ECC 组件迁移

#### Step 2.1: ECC 组件目录创建 (独立)
- **文件**: `lua/ai/components/ecc/*.lua`
- **任务**: 创建组件文件结构
- **操作**: 创建 `ecc/` 目录和空文件

#### Step 2.2: ECC 安装逻辑 (依赖 1.5)
- **文件**: `lua/ai/components/ecc/installer.lua`
- **任务**: 从 ecc.lua 提取安装逻辑
- **代码**:
  ```lua
  local M = {}
  local ECC_REPO = "https://github.com/affaan-m/everything-claude-code.git"
  
  function M.clone_repo(on_progress) ... end
  function M.install_deps(on_progress) ... end
  function M.run_install(target, profile, on_progress) ... end
  function M.install(opts, callback) ... end
  return M
  ```
- **参考**: `lua/ai/ecc.lua` 现有实现
- **依赖**: Step 1.5 (version.lua)

#### Step 2.3: ECC 状态检查 (独立 ★)
- **文件**: `lua/ai/components/ecc/status.lua`
- **任务**: 从 ecc.lua 提取状态逻辑
- **代码**:
  ```lua
  local ECC_STATE_PATH = "~/.claude/ecc/install-state.json"
  
  function M.get_status() ... end
  function M.is_installed() ... end
  function M.format_status(status) ... end
  return M
  ```
- **参考**: `lua/ai/ecc.lua` 现有实现
- **依赖**: 无

#### Step 2.4: ECC 卸载逻辑 (独立 ★)
- **文件**: `lua/ai/components/ecc/uninstaller.lua`
- **任务**: 新增卸载功能
- **代码**:
  ```lua
  function M.uninstall(opts) ... end
  -- 删除 ~/.claude/ecc/
  -- 删除 ~/.claude/commands/ecc/
  -- 删除 ~/.claude/agents/ecc/
  -- 等等
  return M
  ```
- **依赖**: 无

#### Step 2.5: ECC 更新逻辑 (依赖 1.5)
- **文件**: `lua/ai/components/ecc/updater.lua`
- **任务**: 新增更新功能
- **代码**:
  ```lua
  function M.update(opts, callback) ... end
  -- git fetch 检查更新
  -- 如果有更新，重新安装
  return M
  ```
- **依赖**: Step 1.5 (version.lua)

#### Step 2.6: ECC 命令注册 (独立 ★)
- **文件**: `lua/ai/components/ecc/commands.lua`
- **任务**: 命令定义
- **代码**:
  ```lua
  function M.get_commands()
    return {
      { "ECCStatus", ... },
      { "ECCInstall", ... },
      { "ECCUninstall", ... },
      { "ECCUpdate", ... },
    }
  end
  return M
  ```
- **依赖**: 无

#### Step 2.7: ECC 组件入口 (依赖 2.2-2.6)
- **文件**: `lua/ai/components/ecc/init.lua`
- **任务**: 实现完整接口，整合所有子模块
- **代码**:
  ```lua
  local M = {}
  M.name = "ecc"
  M.version = "1.0.0"
  M.category = "framework"
  M.description = "Everything Claude Code"
  M.repo_url = "https://github.com/affaan-m/everything-claude-code.git"
  M.dependencies = { "git", "npm", "node" }
  M.icon = "🔧"
  M.supported_targets = { "claude", "opencode" }
  
  -- 引入子模块
  local Installer = require("ai.components.ecc.installer")
  local Status = require("ai.components.ecc.status")
  local Uninstaller = require("ai.components.ecc.uninstaller")
  local Updater = require("ai.components.ecc.updater")
  local Commands = require("ai.components.ecc.commands")
  
  function M.setup(opts) ... end
  function M.is_installed() return Status.is_installed() end
  function M.get_status() return Status.get_status() end
  function M.get_version_info() return require("ai.components.version").get_version_status(M) end
  function M.install(opts, cb) return Installer.install(opts, cb) end
  function M.uninstall(opts) return Uninstaller.uninstall(opts) end
  function M.update(opts) return Updater.update(opts) end
  function M.get_commands() return Commands.get_commands() end
  function M.health_check() ... end
  
  return M
  ```
- **依赖**: Steps 2.2-2.6 全部完成
- **验证**: 组件注册成功

#### Step 2.8: ECC 向后兼容 shim (依赖 2.7)
- **文件**: `lua/ai/ecc.lua`
- **任务**: 修改为 shim，重定向到新组件
- **代码**:
  ```lua
  -- ecc.lua - 向后兼容 shim
  -- 所有原有函数重定向到 ai.components.ecc
  local Component = require("ai.components.ecc")
  
  local M = {}
  M.get_status = Component.get_status
  M.is_installed = Component.is_installed
  M.install = Component.install
  -- ... 其他原有方法
  
  return M
  ```
- **依赖**: Step 2.7
- **验证**: 原有调用方式仍能工作

**Phase 2 可并行部分**: Steps 2.3, 2.4, 2.6 可同时开发

---

### Phase 3: GSD 组件实现

#### Step 3.1: GSD 组件目录创建 (独立)
- **文件**: `lua/ai/components/gsd/*.lua`
- **任务**: 创建组件文件结构

#### Step 3.2: GSD 安装逻辑 (独立 ★)
- **文件**: `lua/ai/components/gsd/installer.lua`
- **任务**: npx/npm 安装逻辑
- **代码**:
  ```lua
  local M = {}
  local GSD_PACKAGE = "get-shit-done-cc"
  
  function M.install(opts, callback) ... end
  -- 方式1: npx get-shit-done-cc@latest（按需）
  -- 方式2: npm install -g get-shit-done-cc（全局）
  return M
  ```
- **参考**: GSD 官方文档 `npx get-shit-done-cc@latest`
- **依赖**: 无

#### Step 3.3: GSD 状态检查 (独立 ★)
- **文件**: `lua/ai/components/gsd/status.lua`
- **任务**: 状态文件检测
- **代码**:
  ```lua
  function M.get_status() ... end
  function M.is_installed() ... end
  -- 检查 ~/.claude/gsd/ 目录是否存在
  -- 检查 npm 全局安装状态
  return M
  ```
- **依赖**: 无

#### Step 3.4: GSD 卸载逻辑 (独立 ★)
- **文件**: `lua/ai/components/gsd/uninstaller.lua`
- **代码**:
  ```lua
  function M.uninstall(opts) ... end
  -- npm uninstall -g get-shit-done-cc
  -- 删除 ~/.claude/gsd/
  return M
  ```
- **依赖**: 无

#### Step 3.5: GSD 更新逻辑 (依赖 1.5)
- **文件**: `lua/ai/components/gsd/updater.lua`
- **代码**:
  ```lua
  function M.update(opts) ... end
  -- npm update -g get-shit-done-cc
  -- 或重新运行 npx
  return M
  ```
- **依赖**: Step 1.5 (version.lua)

#### Step 3.6: GSD 命令注册 (独立 ★)
- **文件**: `lua/ai/components/gsd/commands.lua`
- **代码**:
  ```lua
  function M.get_commands()
    return {
      { "GSDStatus", ... },
      { "GSDInstall", ... },
      { "GSDUpdate", ... },
    }
  end
  return M
  ```
- **依赖**: 无

#### Step 3.7: GSD 组件入口 (依赖 3.2-3.6)
- **文件**: `lua/ai/components/gsd/init.lua`
- **任务**: 实现完整接口
- **代码**:
  ```lua
  local M = {}
  M.name = "gsd"
  M.version = "1.37.1"
  M.category = "framework"
  M.description = "Get Shit Done - Spec-driven development system"
  M.repo_url = "https://github.com/gsd-build/get-shit-done.git"
  M.npm_package = "get-shit-done-cc"
  M.dependencies = { "npx", "node" }
  M.icon = "🚀"
  M.supported_targets = { "claude", "opencode", "gemini", "cursor", "codex" }
  
  -- 实现所有接口方法
  return M
  ```
- **依赖**: Steps 3.2-3.6
- **验证**: 组件注册成功

#### Step 3.8: GSD 向后兼容 shim (依赖 3.7)
- **文件**: `lua/ai/gsd.lua`
- **任务**: 创建 shim
- **代码**: 类似 ECC shim

**Phase 3 可并行部分**: Steps 3.2, 3.3, 3.4, 3.6 可同时开发

---

### Phase 4: ccstatusline 组件迁移（现有功能）

**注意**: ccstatusline 已在 `lua/ai/claude_code.lua` 中有部分实现，需要迁移到组件系统。

#### Step 4.1: ccstatusline 组件目录 (独立)
- **文件**: `lua/ai/components/ccstatusline/*.lua`
- **任务**: 创建组件文件结构

#### Step 4.2: ccstatusline 配置逻辑 (迁移现有代码 ★)
- **文件**: `lua/ai/components/ccstatusline/config.lua`
- **任务**: 从 claude_code.lua 迁移配置逻辑
- **迁移内容**:
  ```lua
  -- 从 lua/ai/claude_code.lua 迁移：
  -- get_ccstatusline_template_path()
  -- get_ccstatusline_settings_path()
  -- read_ccstatusline_template()
  -- write_ccstatusline_settings()
  -- edit_ccstatusline_template()
  ```
- **依赖**: 无

#### Step 4.3: ccstatusline 命令注册 (迁移现有代码 ★)
- **文件**: `lua/ai/components/ccstatusline/commands.lua`
- **任务**: 从 plugins/opencode.lua 迁移命令
- **迁移内容**:
  ```lua
  -- 从 lua/plugins/opencode.lua 迁移：
  -- :CCStatuslineEditTemplate 命令
  ```
- **新增命令**:
  ```lua
  -- 新增组件管理命令：
  -- :CCStatuslineStatus - 显示配置状态
  -- :CCStatuslineSync - 同步模板到 settings.json
  ```
- **依赖**: 无

#### Step 4.4: ccstatusline 组件入口 (依赖 4.2-4.3)
- **文件**: `lua/ai/components/ccstatusline/init.lua`
- **任务**: 实现完整接口
- **代码**:
  ```lua
  local M = {}
  M.name = "ccstatusline"
  M.version = "1.0.0"
  M.category = "tool"
  M.description = "Claude Code status line configuration manager"
  M.repo_url = "https://github.com/nick-field/ccstatusline"
  M.npm_package = "ccstatusline"  -- npx -y ccstatusline@latest
  M.dependencies = { "npx", "node" }
  M.icon = "📊"
  M.supported_targets = { "claude" }
  
  local Config = require("ai.components.ccstatusline.config")
  
  function M.setup(opts) return true end
  function M.is_installed() return vim.fn.executable("npx") == 1 end
  
  function M.get_status()
    local settings_path = vim.fn.expand("~/.config/ccstatusline/settings.json")
    local template_path = vim.fn.stdpath("config") .. "/ccstatusline.template.jsonc"
    
    return {
      config_exists = vim.fn.filereadable(settings_path) == 1,
      config_path = settings_path,
      template_exists = vim.fn.filereadable(template_path) == 1,
      template_path = template_path,
    }
  end
  
  function M.get_version_info()
    -- ccstatusline 通过 npx 按需运行，无本地版本概念
    return {
      current = "npx latest",
      latest = nil,
      status = "on-demand",
    }
  end
  
  function M.install(opts)
    -- ccstatusline 无需安装，通过 npx 按需运行
    -- 仅同步配置
    return Config.sync(), "Config synced"
  end
  
  function M.uninstall(opts)
    -- 删除配置文件
    local settings_path = vim.fn.expand("~/.config/ccstatusline/settings.json")
    if vim.fn.filereadable(settings_path) == 1 then
      vim.fn.delete(settings_path)
    end
    return true, "Config removed"
  end
  
  function M.update(opts)
    -- npx 自动使用 latest，无需手动更新
    return true, "npx auto-updates to latest"
  end
  
  function M.get_commands()
    return {
      { "CCStatuslineStatus", M.show_status, desc = "Show ccstatusline config status" },
      { "CCStatuslineEditTemplate", Config.edit_template, desc = "Edit ccstatusline template" },
      { "CCStatuslineSync", Config.sync, desc = "Sync template to settings.json" },
    }
  end
  
  function M.health_check()
    local status = M.get_status()
    if status.config_exists then
      return { status = "ok", message = "ccstatusline config synced" }
    else
      return { status = "warn", message = "Run :CCStatuslineSync to generate config" }
    end
  end
  
  return M
  ```
- **依赖**: Steps 4.2-4.3

#### Step 4.5: claude_code.lua 清理 (依赖 4.4)
- **文件**: `lua/ai/claude_code.lua`
- **任务**: 移除 ccstatusline 相关代码，改为调用组件
- **修改**:
  ```lua
  -- 删除以下函数：
  -- get_ccstatusline_template_path()
  -- get_ccstatusline_settings_path()
  -- read_ccstatusline_template()
  -- write_ccstatusline_settings()
  -- edit_ccstatusline_template()
  
  -- 在 write_settings() 中改为：
  local CCStatusline = require("ai.components.ccstatusline")
  CCStatusline.install()  -- 同步配置
  ```
- **依赖**: Step 4.4

**Phase 4 可并行部分**: Steps 4.2, 4.3 可同时开发（迁移现有代码）

---

### Phase 5: 集成与 UI

#### Step 5.1: 状态面板 UI (依赖 1.6)
- **文件**: `lua/ai/components/status_panel.lua`
- **任务**: 浮动窗口显示所有组件状态
- **代码**:
  ```lua
  function M.show() ... end
  -- 创建浮动窗口
  -- 显示每个组件：名称 | 版本 | 最新 | 状态 | 操作
  -- 支持快捷键操作（安装、更新、切换）
  return M
  ```
- **依赖**: Step 1.6 (init.lua)

#### Step 5.2: 工具-组件切换器 (依赖 1.6)
- **文件**: `lua/ai/components/switcher.lua`
- **任务**: 切换逻辑和状态持久化
- **代码**:
  ```lua
  local STATE_PATH = "~/.local/state/nvim/ai_component_state.lua"
  
  function M.load_state() ... end
  function M.save_state(state) ... end
  function M.switch(tool, component) ... end
  function M.get_active(tool) ... end
  return M
  ```
- **依赖**: Step 1.6

#### Step 5.3: AI 模块集成 (依赖 1.6, 2.7, 3.7, 4.4)
- **文件**: `lua/ai/init.lua`
- **任务**: 在 setup() 中初始化组件管理器
- **代码**:
  ```lua
  -- 在现有 setup() 函数中添加：
  local Components = require("ai.components")
  Components.setup(opts.components or {})
  
  -- 注册组件命令
  for _, comp in ipairs(Components.list_installed()) do
    for _, cmd in ipairs(comp.get_commands()) do
      vim.api.nvim_create_user_command(cmd[1], cmd[2], { desc = cmd.desc })
    end
  end
  ```
- **依赖**: Phase 1-4 全部完成

#### Step 5.4: 组件管理命令注册 (依赖 5.3)
- **文件**: `lua/ai/components/init.lua` (扩展)
- **任务**: 注册全局组件管理命令
- **命令列表**:
  ```lua
  -- 全局命令
  :ComponentList              -- 显示所有已注册组件
  :ComponentStatus            -- 显示状态面板
  :ComponentInstall <name>    -- 安装指定组件
  :ComponentUpdate <name>     -- 更新指定组件
  :ComponentUninstall <name>  -- 卸载指定组件
  :ComponentSwitch            -- 打开切换 UI
  :ComponentSwitch <tool> <component>  -- 直接切换
  
  -- 各组件独立命令（保持向后兼容）
  :ECCStatus, :ECCInstall, :ECCUpdate, :ECCUninstall
  :GSDStatus, :GSDInstall, :GSDUpdate, :GSDUninstall
  :CCStatuslineConfig, :CCStatuslineEditTemplate
  ```
- **依赖**: Step 5.3

#### Step 5.5: 健康检查集成 (依赖 2.7, 3.7, 4.4)
- **文件**: `lua/ai/health.lua`
- **任务**: 集成各组件 health_check()
- **代码**:
  ```lua
  -- 在 check_ai() 中添加：
  local Components = require("ai.components")
  for _, comp in ipairs(Components.list()) do
    local health = comp.health_check()
    if health.status == "ok" then
      health.ok(comp.name .. ": " .. health.message)
    else
      health.warn(comp.name .. ": " .. health.message)
    end
  end
  ```
- **依赖**: Phase 2-4

#### Step 5.6: 组件开发模板 (独立)
- **文件**: `lua/ai/components/_template.lua`
- **任务**: 文档化的组件开发模板
- **代码**:
  ```lua
  -- 包含完整的组件接口实现模板
  -- 每个方法都有文档注释
  -- 类似 adapter_template.lua
  ```
- **依赖**: 无

**Phase 5 可并行部分**: Step 5.6 可独立开发

---

## 4. 并行开发策略

### 可并行矩阵

| Phase | 可并行步骤 | 必须顺序步骤 |
|-------|-----------|-------------|
| Phase 1 | 1.1, 1.2, 1.3, 1.5 | 1.4 (依赖1.2), 1.6 (依赖全部) |
| Phase 2 | 2.3, 2.4, 2.6 | 2.2(依赖1.5), 2.5(依赖1.5), 2.7(依赖全部), 2.8(依赖2.7) |
| Phase 3 | 3.2, 3.3, 3.4, 3.6 | 3.5(依赖1.5), 3.7(依赖全部), 3.8(依赖3.7) |
| Phase 4 | 4.2, 4.3 | 4.4(依赖全部) |
| Phase 5 | 5.6 | 5.1-5.5 (依赖前置阶段) |

### 建议并行组合

**组合 A (Phase 1 核心)**:
- 同时开发: 1.1 (interface) + 1.2 (registry) + 1.3 (types) + 1.5 (version)
- 预计时间: 2-3 小时（单人）/ 1 小时（4 人并行）

**组合 B (Phase 2 + 3 子模块)**:
- 同时开发: 2.3 + 2.4 + 2.6 + 3.2 + 3.3 + 3.4 + 3.6
- 预计时间: 2-3 小时（单人）/ 30 分钟（7 人并行）

---

## 5. 验证清单

### Phase 1 验证
- [ ] `interface.lua` 能正确验证组件
- [ ] `registry.lua` 能注册和列出组件
- [ ] `version.lua` 能查询 npm/git 版本
- [ ] `init.lua` setup() 无报错

### Phase 2 验证
- [ ] ECC 组件成功注册
- [ ] 选择器能显示 ECC 状态
- [ ] 选择器能执行安装/更新操作

### Phase 3 验证
- [ ] GSD 组件成功注册
- [ ] 选择器能显示 GSD 状态
- [ ] 选择器能执行安装/更新操作

### Phase 4 验证
- [ ] ccstatusline 组件成功注册
- [ ] 选择器能显示 ccstatusline 配置状态

### Phase 5 验证
- [ ] `:AIComponent` 命令打开选择器
- [ ] 选择器显示所有组件状态面板
- [ ] 选择器能切换工具使用的组件
- [ ] `:checkhealth ai` 包含组件健康检查
- [ ] keymap `<leader>km` 打开选择器

---

## 6. 测试用例

### 单元测试

```lua
-- tests/ai/components_spec.lua

describe("Component Manager", function()
  it("should register component", function()
    local Registry = require("ai.components.registry")
    Registry.register("test", { name = "test", setup = function() end, is_installed = function() return true end, get_status = function() return {} end })
    assert.are.same(Registry.get("test").name, "test")
  end)
  
  it("should validate component interface", function()
    local Interface = require("ai.components.interface")
    local valid, err = Interface.validate_component({ name = "test", setup = function() end })
    assert.is_false(valid)
    assert.matches("missing required method", err)
  end)
  
  it("should compare versions correctly", function()
    local Version = require("ai.components.version")
    assert.are.same(Version.compare_versions("1.0.0", "1.0.1"), "outdated")
    assert.are.same(Version.compare_versions("1.0.1", "1.0.0"), "newer")
    assert.are.same(Version.compare_versions("1.0.0", "1.0.0"), "current")
  end)
end)
```

### 集成测试

```bash
# 测试组件安装流程
nvim --headless -c "lua require('ai.components').install('gsd')" -c "q"

# 测试状态面板
nvim --headless -c "lua require('ai.components.status_panel').show()" -c "q"

# 测试组件切换
nvim --headless -c "lua require('ai.components.switcher').switch('opencode', 'gsd')" -c "q"
```

---

## 7. 风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 向后兼容破坏 | Medium | 保留 shim 文件，测试原有调用方式 |
| 组件加载顺序问题 | Medium | 延迟加载，setup() 时统一初始化 |
| 命名冲突 | Low | 组件命令使用前缀 (ECC/GSD) |
| npm 命令超时 | Low | 设置 30 秒超时，显示错误提示 |
| 状态文件损坏 | Low | 验证 JSON 解析，提供 reset 命令 |
| GSD 状态文件位置未知 | Medium | 多路径检测，支持配置 |

---

## 8. 后续扩展

### 未来可添加的组件

| 组件 | npm package | 类别 | 说明 |
|------|-------------|------|------|
| aider | `aider-chat` | integration | AI pair programming |
| cursor-rules | 无 | integration | Cursor rules 配置 |
| windsurf | 无 | integration | Windsurf 配置 |
| mcp-server | 无 | extension | MCP server 管理 |

### 扩展方向

1. **外部组件仓库** — 支持从 GitHub 直接安装组件定义
2. **组件热更新** — 无需重启 Neovim 即可更新组件
3. **组件依赖图** — 显示组件之间的依赖关系
4. **组件市场** — 类似 VSCode 插件市场的 UI

---

## 9. 文件清单

### 新建文件 (18 个)

| 文件路径 | Phase | 说明 |
|----------|-------|------|
| `lua/ai/components/interface.lua` | 1 | 组件接口规范 |
| `lua/ai/components/registry.lua` | 1 | 组件注册表 |
| `lua/ai/components/types.lua` | 1 | 类型定义 |
| `lua/ai/components/discovery.lua` | 1 | 发现机制 |
| `lua/ai/components/version.lua` | 1 | 版本检测 |
| `lua/ai/components/init.lua` | 1 | 管理器入口 |
| `lua/ai/components/status_panel.lua` | 5 | 状态面板 UI |
| `lua/ai/components/switcher.lua` | 5 | 切换逻辑 |
| `lua/ai/components/_template.lua` | 5 | 开发模板 |
| `lua/ai/components/ecc/init.lua` | 2 | ECC 组件入口 |
| `lua/ai/components/ecc/installer.lua` | 2 | ECC 安装 |
| `lua/ai/components/ecc/status.lua` | 2 | ECC 状态 |
| `lua/ai/components/ecc/uninstaller.lua` | 2 | ECC 卸载 |
| `lua/ai/components/ecc/updater.lua` | 2 | ECC 更新 |
| `lua/ai/components/ecc/commands.lua` | 2 | ECC 命令 |
| `lua/ai/components/gsd/init.lua` | 3 | GSD 组件入口 |
| `lua/ai/components/gsd/installer.lua` | 3 | GSD 安装 |
| `lua/ai/components/gsd/status.lua` | 3 | GSD 状态 |
| `lua/ai/components/gsd/uninstaller.lua` | 3 | GSD 卸载 |
| `lua/ai/components/gsd/updater.lua` | 3 | GSD 更新 |
| `lua/ai/components/gsd/commands.lua` | 3 | GSD 命令 |
| `lua/ai/components/ccstatusline/init.lua` | 4 | ccstatusline 入口 |
| `lua/ai/components/ccstatusline/config.lua` | 4 | ccstatusline 配置 |
| `lua/ai/components/ccstatusline/commands.lua` | 4 | ccstatusline 命令 |
| `lua/ai/gsd.lua` | 3 | GSD shim |
| `tests/ai/components_spec.lua` | 1 | 单元测试 |

### 修改文件 (5 个)

| 文件路径 | Phase | 说明 |
|----------|-------|------|
| `lua/ai/ecc.lua` | 2 | 改为 shim（重定向到 components/ecc） |
| `lua/ai/claude_code.lua` | 4 | 移除 ccstatusline 代码，改为调用组件 |
| `lua/ai/init.lua` | 5 | 集成组件管理器 |
| `lua/ai/health.lua` | 5 | 健康检查集成 |
| `lua/plugins/opencode.lua` | 4 | 移除 ccstatusline 命令（改用组件注册） |
| `tests/ai/ecc_spec.lua` | 2 | 更新测试 |

---

**文档版本**: 1.0
**最后更新**: 2026-04-18