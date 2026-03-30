# Skill Studio 配置指南

> Skill/MCP 创作工具，用于创建和管理 Claude Code 和 OpenCode 的 Skills、Commands 和 MCP 服务器

## 功能特性

- **创建 Skills/Commands/MCPs**：支持 Claude Code 和 OpenCode 格式
- **格式转换**：在 Claude 和 OpenCode 格式之间转换
- **验证工具**：检查 skill 文件格式正确性
- **备份管理**：自动备份创建的内容
- **代码审查**：审查 skill 内容质量

---

## 用户命令

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