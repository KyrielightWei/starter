# Everything Claude Code (ECC) 使用指南

## 概述

ECC 是一套增强 Claude Code 能力的工具集，包含：
- **规则 (Rules)** - 编码标准、最佳实践、安全检查清单
- **命令 (Commands)** - 可通过 `/command` 调用的快捷功能
- **代理 (Agents)** - 专门化的子代理，处理特定任务
- **技能 (Skills)** - 深度参考资料和模式

---

## 安装状态

```
~/.claude/
├── rules/           # ✅ 已安装 (多语言规则)
│   ├── common/      # 通用规则
│   ├── typescript/  # TypeScript 规则
│   ├── python/      # Python 规则
│   ├── golang/      # Go 规则
│   ├── rust/        # Rust 规则
│   └── zh/          # 中文翻译版本
├── commands/        # ✅ 已安装 (60+ 命令)
├── agents/          # ✅ 已安装 (30+ 代理)
├── skills/          # ✅ 已安装
└── ecc/             # ✅ 安装状态文件
```

---

## 安装

### 方式 1: 使用组件管理器（推荐）

通过 AI Component Manager 安装：

```vim
:AIComponents
```

在选择器中选择 ECC，按 `i` 安装。

### 方式 2: 手动安装

从 GitHub 克隆安装：

```bash
# 克隆仓库
git clone https://github.com/affaan-m/everything-claude-code.git /tmp/ecc --depth=1

# 安装依赖
cd /tmp/ecc && npm install --no-audit --no-fund --loglevel=error

# 安装到 Claude Code
node scripts/install-apply.js --profile developer

# 安装到 OpenCode
node scripts/install-apply.js --target opencode --profile developer
```

### Profile 选择

| Profile | 内容 |
|---------|------|
| `core` | 核心规则和命令 |
| `developer` | 开发者常用（推荐） |
| `security` | 安全相关工具 |
| `research` | 研究和学习工具 |
| `full` | 全量安装 |

---

## 状态检查

### 通过组件管理器

```vim
:AIComponents
```

选择器显示：
- 安装状态 (✓ 已安装 / ○ 未安装)
- 版本信息
- 依赖状态

### 通过命令

```vim
:AIComponentList
```

输出示例：
```
✓ ECC (Everything Claude Code) - Framework - installed
○ GSD (Get Shit Done) - Framework - not installed
```

### 健康检查

```vim
:checkhealth ai
```

---

## 更新

### 通过组件管理器

```vim
:AIComponents
```

选择 ECC，按 `u` 更新。

### 命令方式

```vim
:AIComponentUpdate ecc
```

---

## 卸载

### 通过组件管理器

```vim
:AIComponents
```

选择 ECC，按 `x` 卸载（会有确认对话框）。

---

## 配置目录

遵循 XDG Base Directory 规范：

| 工具 | 配置目录 | 数据目录 | 说明 |
|------|----------|----------|------|
| Claude Code | `~/.claude/` | - | rules, commands, agents, skills |
| OpenCode | `~/.config/opencode/` | `~/.local/share/opencode/` | 配置文件、API 凭证 |

---

## 快速开始

### 核心开发流程

```
需求 → /plan → /tdd → /code-review → /verify → commit
```

1. **规划**: `/plan` - 创建实现计划，等待确认
2. **开发**: `/tdd` - 测试驱动开发
3. **审查**: `/code-review` - 代码质量和安全审查
4. **验证**: `/verify` - 构建、类型、测试、覆盖率检查

---

## 常用命令速查

### 开发流程类

| 命令 | 用途 | 示例 |
|------|------|------|
| `/plan` | 创建实现计划，等待确认 | `/plan 添加用户认证功能` |
| `/tdd` | 测试驱动开发 (RED→GREEN→REFACTOR) | `/tdd 实现计算流动性分数的函数` |
| `/code-review` | 代码质量和安全审查 | `/code-review` |
| `/verify` | 完整验证 (构建/类型/测试/覆盖率) | `/verify` 或 `/verify quick` |

### 构建修复类

| 命令 | 用途 |
|------|------|
| `/go-build` | 修复 Go 构建错误 |
| `/rust-build` | 修复 Rust 构建错误 |
| `/kotlin-build` | 修复 Kotlin/Gradle 构建错误 |
| `/cpp-build` | 修复 C++ 构建错误 |
| `/build-fix` | 通用构建错误修复 |

### 代码审查类

| 命令 | 用途 |
|------|------|
| `/go-review` | Go 代码审查 |
| `/rust-review` | Rust 代码审查 |
| `/python-review` | Python 代码审查 |
| `/kotlin-review` | Kotlin 代码审查 |
| `/cpp-review` | C++ 代码审查 |

### 测试类

| 命令 | 用途 |
|------|------|
| `/go-test` | Go TDD 工作流 |
| `/rust-test` | Rust TDD 工作流 |
| `/kotlin-test` | Kotlin TDD 工作流 |
| `/cpp-test` | C++ TDD 工作流 |
| `/e2e` | Playwright E2E 测试 |
| `/test-coverage` | 测试覆盖率检查 |

### 学习与知识管理

| 命令 | 用途 | 示例 |
|------|------|------|
| `/learn` | 从当前会话提取可复用模式 | `/learn` |
| `/docs` | 查询库/框架的最新文档 | `/docs Next.js 中间件配置` |
| `/skill-create` | 从 git 历史创建技能文件 | `/skill-create` |
| `/instinct-status` | 查看已学习的本能模式 | `/instinct-status` |

### 会话管理

| 命令 | 用途 | 示例 |
|------|------|------|
| `/sessions` | 列出所有会话 | `/sessions list` |
| `/sessions load <id>` | 加载会话 | `/sessions load abc123` |
| `/sessions alias` | 创建会话别名 | `/sessions alias abc123 my-work` |
| `/save-session` | 保存当前会话状态 | `/save-session` |
| `/resume-session` | 恢复最近的会话 | `/resume-session` |

---

## 规则系统

### 已安装的规则

规则自动加载到每个会话中，指导 Claude 的行为：

```
~/.claude/rules/
├── common/
│   ├── coding-style.md    # 编码风格 (不可变性、文件组织)
│   ├── git-workflow.md    # Git 工作流 (提交格式、PR 流程)
│   ├── testing.md         # 测试要求 (80% 覆盖率)
│   ├── security.md        # 安全检查清单
│   ├── performance.md     # 性能优化策略
│   └── ...
├── typescript/            # TypeScript 特定规则
├── python/                # Python 特定规则
└── ...
```

### 规则优先级

- 语言特定规则 > 通用规则
- 例如: Go 的可变性规则覆盖 common 的不可变性建议

---

## 代理系统

代理是专门化的子代理，处理特定任务：

| 代理 | 用途 | 自动触发条件 |
|------|------|-------------|
| `planner` | 实现计划 | 复杂功能请求 |
| `tdd-guide` | 测试驱动开发 | 新功能、bug 修复 |
| `code-reviewer` | 代码审查 | 代码修改后 |
| `security-reviewer` | 安全分析 | 处理用户输入时 |
| `build-error-resolver` | 构建错误修复 | 构建失败时 |
| `architect` | 系统设计 | 架构决策 |

**代理会自动启动，无需手动调用。**

---

## 组件管理器集成

ECC 现已集成到 AI Component Manager：

### 组件信息

| 属性 | 值 |
|------|---|
| **名称** | ecc |
| **类别** | framework |
| **图标** | 🔧 |
| **依赖** | git, npm, node |
| **支持工具** | claude, opencode |

### 组件命令

| 命令 | 功能 |
|------|------|
| `:AIComponents` | 打开组件选择器 |
| `:AIComponentInstall ecc` | 安装 ECC |
| `:AIComponentUpdate ecc` | 更新 ECC |
| `:AIComponentSwitch opencode ecc` | 设置 OpenCode 使用 ECC |

### 快捷键

- `<leader>kc` — 打开组件选择器

---

## 常见问题

### Q: 规则会自动生效吗？
A: 是的，规则会自动加载到每个会话中。

### Q: 如何更新 ECC？
A: 运行 `:AIComponents` 然后选择 ECC 按 `u`，或使用 `:AIComponentUpdate ecc`。

### Q: 如何添加新的语言规则？
A: 在 `~/.claude/rules/<语言>/` 目录下创建规则文件。

### Q: 测试覆盖率要求是多少？
A: 最低 80%，关键代码 (财务、认证、安全) 要求 100%。

---

## 参考链接

- 规则目录: `~/.claude/rules/`
- 命令目录: `~/.claude/commands/`
- 代理目录: `~/.claude/agents/`
- 会话目录: `~/.claude/sessions/`
- 组件管理器文档: [docs/COMPONENT_MANAGER_GUIDE.md](docs/COMPONENT_MANAGER_GUIDE.md)

---