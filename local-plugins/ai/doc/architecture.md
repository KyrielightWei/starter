# 架构说明

## 模块依赖图

```
plugin/ai.lua (命令/键映射注册 — 唯一入口)
    │
    ▼
ai.init (setup — 子系统初始化)
    │
    ├── ai.paths ──────────────── 统一路径解析
    │
    ├── ai.provider_manager ──── Provider 检测和管理 UI
    │   ├── provider_manager.picker      (主面板)
    │   ├── provider_manager.detector    (异步检测)
    │   ├── provider_manager.registry    (Provider 注册表)
    │   ├── provider_manager.results     (结果展示)
    │   ├── provider_manager.cache       (检测结果缓存)
    │   ├── provider_manager.status      (状态聚合)
    │   ├── provider_manager.ui_util     (UI 工具函数)
    │   ├── provider_manager.file_util   (文件操作)
    │   └── provider_manager.validator   (输入验证)
    │
    ├── commit_picker ─────────── Git commit 浏览器
    │   ├── commit_picker.config
    │   ├── commit_picker.git
    │   ├── commit_picker.display
    │   ├── commit_picker.navigation
    │   ├── commit_picker.selection
    │   ├── commit_picker.diff
    │   ├── commit_picker.settings
    │   └── commit_picker.init
    │
    └── ai.system_prompt ─────── 系统提示词管理
```

```
命令触发的模块（按需加载）:

:AISync ──→ ai.sync ──→ ai.opencode / ai.claude_code / ai.pi
:AIKeys ──→ ai.keys ──→ ai.providers
:AIModel ─→ ai.model_switch ──→ ai.fetch_models
                              ──→ ai.provider_manager.registry
:OpenCodeGenerate ──→ ai.opencode ──→ ai.config_resolver
                                   ──→ ai.json_util
                                   ──→ ai.template_version
:ClaudeCodeGenerate ──→ ai.claude_code ──→ ai.json_util
                                         ──→ ai.providers
:PiGenerate ──→ ai.pi ──→ ai.json_util
                        ──→ ai.providers
                        ──→ ai.keys
:AI context ──→ ai.context
:AI prompt ──→ ai.system_prompt
:AI watch ──→ ai.config_watcher
:AI backup ──→ ai.opencode / ai.claude_code (restore_backup)
:AI export ──→ ai.sync (export_to_env_file)
```

## 数据流

```
                    ┌─────────────────┐
                    │  ai.providers   │  Provider 定义（静态）
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   ai.keys       │  API Key + Base URL（用户配置）
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ ai.config_      │  合并 Provider + Key + Model
                    │ resolver        │  生成工具特定的配置数据
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌────────────┐  ┌────────────┐  ┌────────────┐
     │ ai.opencode│  │ai.claude_  │  │  ai.pi     │
     │            │  │code        │  │            │
     │ 读取模板    │  │ 读取模板    │  │ 读取模板    │
     │ 合并配置    │  │ 合并配置    │  │ 合并配置    │
     │ 写入目标    │  │ 写入目标    │  │ 同步资源    │
     └────────────┘  └────────────┘  └────────────┘
              │              │              │
              ▼              ▼              ▼
     ~/.config/       ~/.claude/       ~/.pi/agent/
     opencode/        settings.json    settings.json
     opencode.json                     models.json
                                       extensions/
                                       prompts/
```

## 路径解析

所有模板路径通过 `ai.paths` 模块统一管理：

```lua
local Paths = require("ai.paths")

Paths.setup({ template_dir = vim.fn.stdpath("config") })

Paths.config_dir()                          -- → <template_dir>
Paths.settings_template("pi")               -- → <template_dir>/templates/pi/default.template.jsonc
Paths.settings_template("opencode", "core") -- → <template_dir>/templates/opencode/core.template.jsonc
Paths.legacy_template("opencode")           -- → <template_dir>/opencode.template.jsonc
Paths.resource("pi/AGENTS.template.md")     -- → <template_dir>/pi/AGENTS.template.md
Paths.ccstatusline_template()               -- → <template_dir>/ccstatusline.template.jsonc
Paths.templates_dir("pi")                   -- → <template_dir>/templates/pi
```

## 扩展方式

### 添加新的 AI 工具

1. 创建 `lua/ai/<tool>.lua`，实现：
   - `write_config(opts)` — 生成配置
   - `preview_config(opts)` — 预览配置
   - `edit_template(opts)` — 编辑模板
   - `get_status(opts)` — 返回状态表
2. 在 `plugin/ai.lua` 中注册命令：`<Tool>Generate/Preview/Edit/Status`
3. 在 `ai.sync` 的 `sync_targets` 中注册
4. 在 `ai.health` 中添加 health check

### 添加新的 AI 子命令

在 `plugin/ai.lua` 的 `AI` 命令 handler 中添加新的 `sub` 分支。

### 添加新的快捷键

在 `plugin/ai.lua` 的快捷键区域添加 `vim.keymap.set()` 调用。
