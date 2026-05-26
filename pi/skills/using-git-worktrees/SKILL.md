---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans. Creates an isolated workspace via git worktree.
license: MIT
compatibility: Pi coding agent
metadata:
  author: obra
  version: 1.0.0
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Using Git Worktrees Skill - Git Worktree 工作流                       ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/skills/using-git-worktrees/SKILL.md           ║
║  调用: /skill:using-git-worktrees                                      ║
╚════════════════════════════════════════════════════════════════════════╝
-->

# Using Git Worktrees: Git Worktree 工作流

## 触发条件

在以下情况使用此技能：
- 开始需要隔离的功能开发
- 执行实施计划前
- 需要并行开发多个功能
- 当前工作区有未提交更改

## 为什么使用 Worktree

**优点：**

- 不影响主工作区
- 可以同时开发多个功能
- 每个 worktree 独立状态
- 共享同一个 git 仓库

**vs 分支切换：**

```
分支切换:
- stash 未提交更改
- 切换分支
- 可能丢失上下文

Worktree:
- 无需 stash
- 独立工作区
- 保持上下文
```

## 流程

### 1. 检查当前状态

```bash
# 检查当前分支
git branch

# 检查未提交更改
git status

# 检查现有 worktree
git worktree list
```

### 2. 创建 Worktree

```bash
# 新分支 worktree
git worktree add ../feature-branch -b feature/name

# 已有分支 worktree
git worktree add ../existing-branch existing-branch-name

# 带路径前缀
git worktree add ../project-feature -b feature/name
```

### 3. 进入 Worktree

```bash
cd ../feature-branch

# 确认分支
git branch --show-current

# 确认状态
git status
```

### 4. 完成后清理

```bash
# 回到主工作区
cd ../main-project

# 删除 worktree
git worktree remove ../feature-branch

# 或先合并分支再删除
git merge feature/name
git worktree remove ../feature-branch
git branch -d feature/name
```

## Worktree 结构

```
main-project/           # 主工作区 (main 分支)
├── .git/               # 主仓库
├── src/
└── tests/

feature-branch/         # Worktree (feature 分支)
├── .git                # 指向主仓库的文件
├── src/
└── tests/

另一个-feature/         # 另一个 Worktree
├── .git
├── src/
└── tests/
```

## 最佳实践

### 目录命名

```
../project-feature-xyz   # 项目名-功能名
../project-bugfix-123    # 项目名-bugfix-ID
../hotfix-urgent         # 简短描述
```

### 分支命名

```
feature/add-auth         # 功能分支
bugfix/login-error       # Bugfix 分支
refactor/simplify-api    # 重构分支
hotfix/security-issue    # 热修复分支
```

### 清理顺序

```
1. 合并分支 (如果需要)
2. git worktree remove
3. git branch -d (如果合并了)
```

## 常见场景

### 并行开发多个功能

```bash
git worktree add ../feature-a -b feature/a
git worktree add ../feature-b -b feature/b

# 可以同时在两个目录工作
```

### 紧急 Bugfix

```bash
# 不打断当前工作
git worktree add ../hotfix-bug -b hotfix/bug-123

cd ../hotfix-bug
# 修复 bug
git commit -m "fix: bug #123"
git push

cd ../main-project
git merge hotfix/bug-123
git worktree remove ../hotfix-bug
```

### 执行实施计划

```bash
# 创建隔离工作区
git worktree add ../implementation -b feature/plan-xyz

cd ../implementation
# 执行实施计划
# 完成后合并或保留
```

## 命令速查

| 命令 | 说明 |
|------|------|
| `git worktree add <path> -b <branch>` | 创建新分支 worktree |
| `git worktree add <path> <branch>` | 使用已有分支 |
| `git worktree list` | 列出所有 worktree |
| `git worktree remove <path>` | 删除 worktree |
| `git worktree prune` | 清理已删除的 worktree |
| `git branch --show-current` | 显示当前分支 |

## 注意事项

### 禁止

- ❌ 在同一 worktree 切换分支
- ❌ 删除未合并的 worktree 分支
- ❌ 修改 .git 文件

### 必须

- ✅ 检查 worktree 状态
- ✅ 完成后清理 worktree
- ✅ 使用清晰的命名