---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs. Run verification commands and confirm output before making any success claims.
license: MIT
compatibility: Pi coding agent
metadata:
  author: obra
  version: 1.0.0
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Verification Before Completion Skill - 完成前验证                     ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/skills/verification-before-completion/SKILL.md║
║  调用: /skill:verification-before-completion                          ║
╚════════════════════════════════════════════════════════════════════════╝
-->

# Verification Before Completion: 完成前验证

## 触发条件

在以下情况使用此技能：
- 声称工作完成
- 声称问题修复
- 声称测试通过
- 准备提交代码
- 准备创建 PR

**禁止在验证前声称成功。**

## 核心原则

```
证据 → 声称

不是:
声称 → (可能验证)
```

## 验证清单

### 1. 代码变更

```bash
# 查看变更
git diff
git diff --cached

# 确认变更范围
git diff --stat
```

必须确认：
- 只修改了预期文件
- 变更符合预期
- 无意外删除

### 2. 语法检查

```bash
# Lua
stylua --check lua/

# TypeScript
npm run lint
tsc --noEmit

# Python
ruff check src/
pylint src/
```

### 3. 测试运行

```bash
# Lua (plenary)
nvim --headless -c "PlenaryBustedDirectory tests/" -c "q"

# TypeScript
npm test

# Python
pytest tests/
```

必须看到：
- 测试输出
- 通过数量
- 无失败信息

### 4. 功能验证

```bash
# 手动验证
# 运行应用/服务
# 检查预期功能
```

### 5. 边界检查

```bash
# 空输入
# 极值
# 错误输入
```

## 输出要求

### 声称完成时，必须提供：

```markdown
## 验证结果

### 1. 变更确认
git diff --stat 输出:
[粘贴输出]

### 2. Lint 检查
[lint 命令] 输出:
[粘贴输出 - 无错误]

### 3. 测试运行
[test 命令] 输出:
[粘贴输出 - 所有通过]

### 4. 功能验证
[手动验证步骤和结果]

### 5. 结论
✓ 所有验证通过
```

### 声称修复时，必须提供：

```markdown
## 修复验证

### 问题
[原问题描述]

### 修复
[修复内容]

### 验证
1. 重现问题: [步骤和结果]
2. 应用修复: [步骤]
3. 再次验证: [步骤和结果 - 问题消失]

### 测试
[test 命令] 输出:
[粘贴输出]

### 结论
✓ 问题已修复，测试通过
```

## 禁止的行为

### ❌ 不验证就声称

```
"修复完成"
"测试通过"
"工作完成"
```

必须先运行命令并看到输出。

### ❌ 假设测试通过

```
"应该通过了"
"看起来没问题"
"我写了测试"
```

必须实际运行测试。

### ❌ 忽略失败

```
"有一个失败，但..."
"那个测试本来就有问题"
```

必须解决所有失败。

## 常见验证命令

| 语言 | Lint | Test |
|------|------|------|
| Lua | `stylua --check` | `nvim --headless -c "PlenaryBustedDirectory"` |
| TypeScript | `npm run lint` | `npm test` |
| Python | `ruff check` | `pytest` |
| Go | `golangci-lint` | `go test ./...` |

## 注意事项

### 必须

- ✅ 运行验证命令
- ✅ 看到并粘贴输出
- ✅ 确认无错误/失败
- ✅ 输出完整验证报告

### 禁止

- ❌ 不验证就声称成功
- ❌ 假设或推测
- ❌ 忽略失败
- ❌ 简略验证