## Context

当前配置模版系统架构：
- **模版文件**: 单一文件 `{tool}.template.jsonc` 位于 `~/.config/nvim/`
- **生成流程**: `read_template_config()` → 合合动态 providers → `write_config()`
- **工具支持**: OpenCode (`opencode.lua`) 和 Claude Code (`claude_code.lua`)

现有代码结构：
```
lua/ai/
  opencode.lua        # 主生成逻辑 + 模版读取
  claude_code.lua     # Claude Code 生成逻辑
  sync.lua            # 多工具同步入口
```

限制：
- 模版路径硬编码，无法切换版本
- 无版本管理功能（创建、删除、重命名）
- 无 UI 选择界面

## Goals / Non-Goals

**Goals:**
- 支持多版本模版存储和管理
- 提供 Picker UI 进行版本选择
- 配置生成基于当前选择的版本
- 配置覆盖时备份原有配置并显示覆盖提醒
- 向后兼容现有单模版使用方式

**Non-Goals:**
- 不实现模版内容的智能合并（用备份 + 提醒替代）
- 不支持模版版本间的差异比较（用版本描述替代）
- 不提供独立模版编辑器（Picker `<CR>` 已覆盖）

## Decisions

### Decision 1: 存储结构设计

**选择**: `vim.fn.stdpath("config") .. "/templates/{tool}/{version}.template.jsonc"`

即：`~/.config/nvim/templates/{tool}/{version}.template.jsonc`

**理由**:
- 随 Neovim 配置仓库（starter）在 git 中同步
- 按 tool 分目录，便于扩展新工具
- 文件名包含 `.template.jsonc` 后缀，保持与现有模版格式一致
- 版本名作为文件名前缀，便于人类阅读和文件系统排序

**目录结构示例**:
```
~/.config/nvim/ (starter 仓库)
  config/
    templates/
      opencode/
        default.template.jsonc
        secure.template.jsonc
        dev.template.jsonc
      claude_code/
        default.template.jsonc
        minimal.template.jsonc
```

**安全设计**:
- 模版文件不包含 API key 等敏感信息
- API key 继续由 `~/.config/nvim/ai_keys.lua` 管理（保持现有机制）
- 配置生成时，动态注入 API key（不写入模版）

### Decision 2: 版本状态存储

**选择**: 使用现有 State 模块 (`lua/ai/state.lua`) 扩展

```lua
State.set_template_version(tool, version)  -- 新增方法
State.get_template_version(tool)           -- 返回当前版本，默认 "default"
```

**理由**:
- 复用现有状态管理基础设施
- 状态持久化通过 State 模块已有的订阅机制实现
- 与 provider/model 状态管理模式一致

**持久化位置**: `~/.local/state/nvim/ai_state.lua`

### Decision 3: Picker UI 后端

**选择**: 基于 FZF-lua（复用项目现有 picker）

**快捷操作**:
| 快捷键 | 功能 |
|--------|------|
| `<CR>` (Enter) | 打开模版文件编辑 |
| `<C-d>` | 删除版本（需确认） |
| `<C-n>` | 创建新版本 |
| `<C-y>` | 复制选中版本为新版本 |

**显示内容**:
- 版本名称
- 最后修改时间
- 文件大小
- 版本描述（从模版文件顶部注释提取）

**理由**:
- 项目已依赖 FZF-lua (`lua/plugins/editor.lua`)
- 与 `model_switch.lua` 和 `sync.lua` 的 picker 实现模式一致
- 性能优异，适合版本列表场景

### Decision 4: 配置覆盖备份策略

**选择**: 备份原有配置 + 显示覆盖提醒

**备份机制**:
```
~/.config/opencode/
  opencode.json           # 当前配置
  opencode.json.bak1      # 最近备份
  opencode.json.bak2      # 第二备份（更早）
```

**备份规则**:
- 最多保留 2 份备份，防止过多占用空间
- 生成新配置前备份现有配置
- 循环覆盖旧备份（bak2 被 bak1 替换，bak1 变为 bak2）

**覆盖提醒示例**:
```
⚠️ 以下字段将被覆盖：
  - model: "gpt-4" → "glm-5"
  - provider.bailian_coding.apiKey: "..." → "{file:${API_KEY_PATH}}"

备份已保存至: opencode.json.bak1
可使用 :OpenCodeRestoreBackup 恢复
```

**恢复命令**: `:OpenCodeRestoreBackup [1|2]`

### Decision 5: 自动迁移策略

**选择**: 首次使用时检测旧模版并迁移

**流程**:
1. 检测 `~/.config/nvim/opencode.template.jsonc` 存在
2. 检测 `templates/opencode/` 目录不存在
3. 创建目录并复制文件到 `default.template.jsonc`
4. 显示迁移通知
5. 不删除原文件（保留备份）
6. 创建 `.migration_done` 标记文件

**理由**:
- 一次性迁移，不重复执行
- 保留原文件作为备份
- 用户明确感知迁移发生

## Risks / Trade-offs

**风险 1**: 用户误删当前版本的模版文件
→ **缓解**: 选择版本时检测文件存在性，不存在时提示创建或选择其他版本

**风险 2**: 模版版本过多导致 Picker 列表冗长
→ **缓解**: 按修改时间排序，最近使用的版本优先显示

**风险 3**: 覆盖用户自定义配置字段
→ **缓解**: 备份原有配置（最多 2 份），显示覆盖提醒，提供恢复命令

**风险 4**: starter 仓库不在 `stdpath('config')` 位置
→ **缓解**: 启动时检测配置目录结构，提示用户正确配置 symlink 或路径

**权衡**: 不做智能合并，用备份 + 提醒替代，简化实现。用户可通过恢复命令回滚到备份版本。