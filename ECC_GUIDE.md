# Everything Claude Code (ECC) 使用指南

## 概述

ECC 是一套增强 Claude Code 能力的工具集，包含：
- **规则 (Rules)** - 编码标准、最佳实践、安全检查清单
- **命令 (Commands)** - 可通过 `/command` 调用的快捷功能
- **代理 (Agents)** - 专门化的子代理，处理特定任务
- **技能 (Skills)** - 深度参考资料和模式

## 当前安装状态

```
~/.claude/
├── rules/           # ✅ 已安装 (多语言规则)
│   ├── common/      # 通用规则
│   ├── typescript/  # TypeScript 规则
│   ├── python/      # Python 规则
│   ├── golang/      # Go 规则
│   ├── rust/        # Rust 规则
│   └── ...          # 其他语言
├── commands/        # ✅ 已安装 (60+ 命令)
├── agents/          # ✅ 已安装 (30+ 代理)
└── ecc/             # ✅ 安装状态文件
```

---

## 安装

ECC 需要从 GitHub 克隆安装：

```bash
# 克隆仓库
git clone https://github.com/affaan-m/everything-claude-code.git /tmp/ecc --depth=1

# 安装依赖
cd /tmp/ecc && npm install --no-audit --no-fund --loglevel=error

# 安装到 Claude Code (默认)
node scripts/install-apply.js --profile developer

# 安装到 OpenCode
node scripts/install-apply.js --target opencode --profile developer

# 可选 profiles: core, developer, security, research, full
```

## 配置目录

遵循 XDG Base Directory 规范：

| 工具 | 配置目录 | 数据目录 | 说明 |
|------|----------|----------|------|
| Claude Code | `~/.claude/` | - | rules, commands, agents, skills |
| OpenCode | `~/.config/opencode/` | `~/.local/share/opencode/` | 配置文件、API 凭证 |

> **迁移提示**: 如果你有旧版 `~/.opencode/` 目录，系统会自动迁移到 `~/.config/opencode/`

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

## 详细使用示例

### 1. 规划功能实现

```
用户: /plan 我需要添加实时通知功能

Claude 会:
1. 重述需求
2. 识别风险和依赖
3. 分阶段实现步骤
4. 估算复杂度
5. 等待你确认后才开始写代码
```

**输出示例:**
```
# 实现计划: 实时通知功能

## 需求重述
- 用户收到市场结算通知
- 支持多渠道 (应用内、邮件、webhook)

## 实现阶段

### Phase 1: 数据库设计
- 添加 notifications 表
- 添加用户通知偏好表

### Phase 2: 通知服务
- 创建通知队列
- 实现重试逻辑

...

## 风险评估
- HIGH: 邮件送达率
- MEDIUM: 大量用户性能

**等待确认**: 是否按此计划执行？
```

### 2. 测试驱动开发 (TDD)

```
用户: /tdd 实现一个验证邮箱格式的函数

Claude 会:
1. 定义接口 (SCAFFOLD)
2. 写失败的测试 (RED)
3. 实现最小代码 (GREEN)
4. 重构优化 (REFACTOR)
5. 验证覆盖率 (80%+)
```

**TDD 循环:**
```
RED → GREEN → REFACTOR → REPEAT

RED:      写一个会失败的测试
GREEN:    写最少代码让测试通过
REFACTOR: 优化代码，保持测试通过
REPEAT:   下一个场景
```

### 3. 代码审查

```
用户: /code-review

Claude 会检查:

安全问题 (CRITICAL):
- 硬编码凭证、API 密钥
- SQL 注入
- XSS 漏洞
- 输入验证缺失

代码质量 (HIGH):
- 函数超过 50 行
- 文件超过 800 行
- 嵌套深度超过 4 层
- 缺少错误处理

最佳实践 (MEDIUM):
- 可变模式
- 缺少测试
- 无障碍问题
```

### 4. 完整验证

```
用户: /verify

输出:
VERIFICATION: PASS

Build:    OK
Types:    OK
Lint:     OK
Tests:    45/45 passed, 87% coverage
Secrets:  OK
Logs:     OK (无 console.log)

Ready for PR: YES
```

### 5. 查询文档

```
用户: /docs React 如何使用 useEffect?

Claude 会:
1. 通过 Context7 获取最新文档
2. 返回简洁答案和代码示例
```

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

## 高级功能

### 多模型协作

```
/multi-plan      # 多模型协作规划
/multi-execute   # 多模型协作执行
/multi-backend   # 后端开发工作流
/multi-frontend  # 前端开发工作流
```

### 会话持久化

```bash
# 保存会话
/save-session

# 列出会话
/sessions list

# 创建别名方便记忆
/sessions alias 2026-03-23 my-feature

# 加载会话
/sessions load my-feature

# 恢复最近的会话
/resume-session
```

### 学习与进化

```bash
# 从当前会话提取模式
/learn

# 查看已学习的本能
/instinct-status

# 将项目范围的本能提升到全局
/promote

# 清理过期未提升的本能
/prune
```

---

## 开发工作流最佳实践

### 新功能开发

```
1. /plan <功能描述>
2. 确认计划
3. /tdd <具体实现>
4. /code-review
5. /verify
6. 提交代码
```

### Bug 修复

```
1. /tdd <先写能复现 bug 的测试>
2. 实现修复
3. /verify
4. 提交代码
```

### 代码重构

```
1. /plan <重构范围>
2. 确认计划
3. 确保测试覆盖
4. 执行重构
5. /verify
6. /code-review
```

---

## 常见问题

### Q: 规则会自动生效吗？
A: 是的，规则会自动加载到每个会话中。

### Q: 如何更新 ECC？
A: 运行 `/configure-ecc` 重新安装或更新。

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

---