# Skill Studio 配置指南

> Skill/MCP 创作工具，用于创建和管理 Claude Code 和 OpenCode 的 Skills、Rules、Commands 和 MCP 服务器

## 功能特性

- **创建 Skills/Rules/Commands/MCPs**：支持 Claude Code 和 OpenCode 格式
- **AI 生成**：从需求模板自动生成 skill/rule/mcp
- **格式转换**：在 Claude 和 OpenCode 格式之间转换
- **验证工具**：检查 skill 文件格式正确性
- **备份管理**：自动备份创建的内容
- **需求管理**：本地存储需求，选择性同步到项目/全局目录
- **代码审查**：审查 skill 内容质量
- **提取工具**：从现有 skill/rule/mcp 提取需求

---

## 用户命令

### 需求管理（新增）

| 命令 | 说明 |
|------|------|
| `:SkillRequirements` | 打开需求列表 Picker |
| `:SkillDeployed` | 查看已部署的 skills/rules/mcps |
| `:SkillNewRequirement [type] [target]` | 创建新需求 |
| `:SkillGenerate <name> [platform]` | 从需求生成 skill/rule/mcp |
| `:SkillSync <name> <target>` | 启用同步到项目/全局目录 |
| `:SkillUnsync <name>` | 禁用同步 |
| `:SkillExtract <path>` | 从现有文件提取需求 |
| `:SkillImport <name> <platform>` | 从剪贴板导入生成结果 |

### 创建

| 命令 | 说明 |
|------|------|
| `:SkillNew [type] [target] [scope]` | 创建新的 skill/command/mcp |

**参数说明：**
- `type`: `skill`（默认）、`command`、`mcp`
- `target`: `claude`（默认）、`opencode`
- `scope`: `project`（默认）、`global`

**示例：**
```vim
:SkillNew                           " 创建 project scope 的 claude skill
:SkillNew skill claude global       " 创建 global scope 的 claude skill
:SkillNew command opencode project  " 创建 opencode command
:SkillNew mcp claude global         " 创建 MCP 服务器配置
```

### 管理

| 命令 | 说明 |
|------|------|
| `:SkillList` | 列出所有 skills/commands/mcps |
| `:SkillEdit <id>` | 编辑指定项目 |
| `:SkillDel <id>` | 删除指定项目 |
| `:SkillReview <id>` | 审查项目内容 |

### 转换

| 命令 | 说明 |
|------|------|
| `:SkillConvert <id> <target>` | 转换格式 |

**示例：**
```vim
:SkillConvert my-skill claude    " 转为 Claude 格式
:SkillConvert my-skill opencode  " 转为 OpenCode 格式
```

---

## Requirements Picker 快捷键

打开 `:SkillRequirements` 后可用：

| 快捷键 | 说明 |
|--------|------|
| `<CR>` | 编辑需求文件 |
| `<C-s>` | 切换同步状态 |
| `<C-g>` | 生成 skill/rule/mcp |
| `<C-d>` | 部署到目标平台 |
| `<C-v>` | 查看生成的版本 |
| `<C-x>` | 删除需求 |
| `<C-n>` | 创建新需求 |
| `<C-e>` | 从已部署内容提取 |
| `<C-?>` | 显示帮助 |

### 状态图标

| 图标 | 含义 |
|------|------|
| ✓ | 已启用/已生成/已部署 |
| ✗ | 已禁用/未生成 |
| ⚡ | Skill |
| 📜 | Rule |
| 🔌 | MCP |
| ⌨ | Command |
| C | Claude |
| O | OpenCode |

---

## 目录结构

### 需求存储

```
~/.local/state/nvim/skill_studio/
├── requirements/              # 需求文件存储
│   ├── my-skill.req.md       # 需求 markdown 文件
│   └── ...
├── generated/                 # 生成的内容
│   ├── claude/               # Claude 版本
│   │   ├── skills/
│   │   ├── rules/
│   │   └── mcps/
│   └── opencode/             # OpenCode 版本
│       └── agents/
└── index.json                # 索引文件
```

### 同步目标

| 目标 | 路径 |
|------|------|
| Project | `<project>/.claude/skills/` |
| Global | `~/.claude/skills/` |
| Project Rules | `<project>/.claude/rules/` |
| Global Rules | `~/.claude/rules/` |

---

## Skill 模板

创建的 Skill 文件结构：

```markdown
---
name: skill-name
description: When this skill should be used
version: 1.0.0
---

# Skill Name

Brief description of what this skill does.

## When This Skill Applies

This skill activates when:
- User mentions "keyword1" or "keyword2"
- Task involves specific domain

## Instructions

1. Step 1
2. Step 2
3. Step 3

## Examples

**Example 1:**
Input: ...
Output: ...
```

---

## Command 模板

```markdown
---
description: Command description
argument_hint: "<required> [optional]"
allowed_tools: [Read, Write, Bash]
---

# Command Name

## Arguments

$ARGUMENTS

## Instructions

1. Parse the arguments
2. Perform the action
3. Report results
```

---

## MCP 模板

### stdio 类型

```lua
{
  server_name = {
    type = "stdio",
    command = "npx",
    args = { "-y", "@modelcontextprotocol/server-example" },
    env = {
      API_KEY = "${YOUR_API_KEY}",
    },
  },
}
```

### http 类型

```lua
{
  server_name = {
    type = "http",
    url = "https://mcp.example.com/api",
    headers = {
      Authorization = "Bearer ${YOUR_TOKEN}",
    },
  },
}
```

---

## 存储位置

### Claude Code

| Scope | 路径 |
|-------|------|
| Global | `~/.claude/plugins/skill_studio/` |
| Project | `<project>/.claude/plugins/skill_studio/` |

### OpenCode

| Scope | 路径 |
|-------|------|
| Global | `~/.config/opencode/` |
| Project | `<project>/.opencode/` |

### 备份

| 路径 | 说明 |
|------|------|
| `~/.local/share/nvim/skill_studio/backups/` | 自动备份目录 |

---

## 使用流程

### 1. 创建新 Skill

```vim
:SkillNew skill claude project
```

这将：
1. 从模板生成 skill 文件
2. 在新 buffer 中打开编辑
3. 保存时自动验证

### 2. 编辑现有 Skill

```vim
:SkillList              " 列出所有
:SkillEdit my-skill     " 编辑指定
```

### 3. 审查和发布

```vim
:SkillReview my-skill   " 审查内容
:SkillConvert my-skill opencode  " 转换格式（可选）
```

### 4. 删除

```vim
:SkillDel my-skill      " 删除（会自动备份）
```

---

## 验证规则

Skill Studio 会自动验证：

1. **Frontmatter 格式**
   - 必需字段存在
   - YAML 格式正确

2. **内容结构**
   - 标题层级合理
   - 示例格式正确

3. **安全性检查**
   - 无硬编码密钥
   - 无危险命令

---

## 完整工作流程

### 工作流程一：从需求生成 Skill

```vim
" 1. 创建新需求
:SkillNewRequirement skill claude

" 2. 在打开的 buffer 中编辑需求内容
"    填写 name, description, triggers, instructions 等

" 3. 生成 Skill
:SkillGenerate my-skill claude

" 4. 选择 AI 后端（avante/opencode/claude）
"    生成的结果保存在 ~/.local/state/nvim/skill_studio/generated/

" 5. 启用同步到项目目录
:SkillSync my-skill project

" 6. 部署
:SkillDeploy my-skill claude
```

### 工作流程二：使用 Picker 管理

```vim
" 打开需求列表 Picker
:SkillRequirements

" 在 Picker 中：
" <CR>  - 编辑需求
" <C-g> - 生成
" <C-s> - 切换同步
" <C-d> - 部署
" <C-?> - 查看帮助
```

### 工作流程三：从现有 Skill 提取需求

```vim
" 从已部署的 Skill 文件提取需求
:SkillExtract ~/.claude/skills/my-skill/SKILL.md

" 或在 Picker 中使用 <C-e> 批量提取
:SkillRequirements
" 按 <C-e> 选择提取范围（project/global/all）
```

### 工作流程四：导入 AI 生成的结果

```vim
" 1. 复制 AI 生成的 Skill 内容到剪贴板

" 2. 导入到指定需求
:SkillImport my-skill claude

" 3. 查看生成的文件
:SkillRequirements
" 按 <C-v> 查看生成的版本
```

---

## 需求文件格式

### Skill 需求示例

```markdown
# code-review - Skill Requirement

## 基本信息

- **名称**: code-review
- **类型**: skill
- **目标平台**: claude

## 触发条件

### 关键词
- review
- 代码审查
- 检查代码

### 文件模式
- *.lua
- *.ts
- *.go

## 描述

### 简短描述
执行全面的代码审查，检查质量、安全和性能

### 详细目的
帮助开发者发现代码中的潜在问题，提高代码质量和可维护性

## 执行指令

### 执行步骤
1. 获取当前文件或选区的代码
2. 分析代码结构和逻辑
3. 检查命名规范和代码风格
4. 识别潜在的安全问题
5. 检查性能瓶颈
6. 生成审查报告和改进建议

### 验证检查点
- [ ] 检查报告是否完整
- [ ] 确认建议是否可执行

## 示例

### 示例 1
**输入**: review this function
**输出**: 生成包含命名、逻辑、安全、性能的审查报告
**说明**: 标准审查流程

## 约束条件

### 允许的工具
- Read
- Grep
- Glob

### 禁止的操作
- 删除文件
- 执行危险命令

### 安全规则
- 不执行用户提供的代码
- 不泄露敏感信息
```

### Rule 需求示例

```markdown
# no-hardcoded-secrets - Rule Requirement

## 基本信息

- **名称**: no-hardcoded-secrets
- **类型**: rule
- **目标平台**: claude
- **优先级**: high

## 规则描述

禁止在代码中硬编码密钥、密码、Token 等敏感信息

## 规则内容

所有敏感信息必须通过环境变量或密钥管理服务获取。

## 存在原因

硬编码的密钥会被提交到版本控制，造成安全风险。

## 正确示例

```lua
local api_key = os.getenv("API_KEY")
```

## 错误示例

```lua
local api_key = "sk-abc123..."
```
```

---

## AI 后端说明

| 后端 | 说明 |
|------|------|
| `avante` | 使用 Avante 插件（需要在 Neovim 中安装） |
| `opencode` | 使用 OpenCode CLI（通过终端） |
| `claude` | 使用 Claude Code CLI（通过终端） |

生成时选择后端：
- **Avante**: 如果已安装，prompt 会复制到剪贴板，在 sidebar 中粘贴
- **OpenCode**: 打开终端运行 OpenCode，prompt 保存到临时文件
- **Claude Code**: 打开终端运行 Claude Code，prompt 保存到临时文件

---

## 故障排除

### 问题：生成后找不到文件

检查生成路径：
```vim
:lua print(vim.fn.stdpath("data") .. "/skill_studio/generated/")
```

### 问题：同步失败

1. 确认需求已生成：`:SkillRequirements` 查看状态
2. 确认同步已启用：查看 `[✓]` 图标
3. 检查目标目录权限

### 问题：Picker 无法打开

确保安装了 `fzf-lua` 插件。

### 问题：提取失败

确保文件格式正确，包含必要的 frontmatter 或结构。