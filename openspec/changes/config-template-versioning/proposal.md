## Why

当前的配置模版系统只支持单一模版文件，无法管理多个版本的配置模版。用户在不同场景下需要不同的配置策略（例如：安全审查模式、开发模式、快速模式等），切换配置需要手动编辑模版文件，操作繁琐且容易出错。

引入多版本模版管理后，用户可以：
- 维护多个预设模版版本（如 `secure`、`dev`、`quick`）
- 通过 Picker UI 快速选择所需版本
- 配置生成自动基于选择的版本构建

## What Changes

- 新增模版版本目录结构：`~/.config/nvim/templates/{tool}/{version}.template.jsonc`（随 starter 仓库 git 同步）
- 新增模版版本管理器模块 `lua/ai/template_version.lua`
- 新增模版版本 Picker UI（基于 FZF-lua）
- 修改 `opencode.lua` 和 `claude_code.lua` 支持版本选择
- 新增配置覆盖备份策略：备份原有配置（最多 2 份），显示覆盖提醒
- 新增恢复命令 `:OpenCodeRestoreBackup`
- 新增用户命令 `:AITemplateSelect`、`:AITemplateList`、`:AITemplateCreate`
- 支持模版版本之间的复制、删除、重命名操作

**安全设计**: 模版不含 API key 等敏感信息，API key 继续由 `ai_keys.lua` 管理

## Capabilities

### New Capabilities

- `template-version-manager`: 模版版本的 CRUD 操作、存储结构、版本发现
- `template-picker-ui`: 基于 FZF-lua 的模版版本选择界面
- `config-generation-with-version`: 基于选择版本的配置生成流程

### Modified Capabilities

无现有 capabilities 的 REQUIREMENTS 变更（这是新增功能）。

## Impact

**Affected Files**:
- `lua/ai/opencode.lua` - 添加版本参数支持
- `lua/ai/claude_code.lua` - 添加版本参数支持
- 新增 `lua/ai/template_version.lua` - 版本管理核心模块
- 新增 `lua/ai/template_picker.lua` - Picker UI

**Affected Commands**:
- `:OpenCodeGenerateConfig` - 支持可选版本参数
- `:ClaudeCodeGenerateConfig` - 支持可选版本参数
- 新增 `:AITemplateSelect` - 选择模版版本
- 新增 `:AITemplateList` - 列出所有版本
- 新增 `:AITemplateCreate` - 创建新版本

**存储结构变更**:
```
~/.config/nvim/
  templates/
    opencode/
      default.template.jsonc   (迁移现有模版)
      secure.template.jsonc    (安全审查模式)
      dev.template.jsonc       (开发模式)
    claude_code/
      default.template.jsonc
      minimal.template.jsonc
```

**向后兼容**:
- 现有 `opencode.template.jsonc` 自动迁移到 `templates/opencode/default.template.jsonc`
- 不指定版本时默认使用 `default` 版本
- 保留原有命令的无参数调用方式