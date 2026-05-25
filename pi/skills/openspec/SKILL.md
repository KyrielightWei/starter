---
name: openspec
description: Spec-driven development (SDD) workflow for AI coding assistants. Use when planning features, managing changes, or implementing specs. Provides /opsx:propose, /opsx:apply, /opsx:archive workflow.
license: MIT
compatibility: Pi coding agent
metadata:
  author: earendil-works
  version: 1.0.0
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  OpenSpec Skill - Spec-Driven Development                              ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/skills/openspec/SKILL.md                      ║
║  调用: /skill:openspec                                                 ║
╚════════════════════════════════════════════════════════════════════════╝
-->

# OpenSpec: Spec-Driven Development

## Overview

OpenSpec 提供规范驱动开发 (SDD) 工作流，帮助 AI 编码助手：
- 在实施前先定义规范
- 分阶段实施变更
- 归档完成的规范

## Commands

### /opsx:propose

创建新规范提案：

```
/opsx:propose <feature-description>
```

步骤：
1. 分析需求
2. 创建规范文件 `.specs/<name>.md`
3. 定义约束、数据模型、API、测试用例

### /opsx:apply

应用规范进行实施：

```
/opsx:apply <spec-name>
```

步骤：
1. 读取规范文件
2. 分阶段实施
3. 运行验证
4. 更新规范状态

### /opsx:archive

归档完成的规范：

```
/opsx:archive <spec-name>
```

步骤：
1. 移动到 `.specs/archive/`
2. 更新状态为 completed
3. 清理临时文件

## Workflow

```
需求 → /opsx:propose → 规范文件 → /opsx:apply → 实施 → /opsx:archive → 归档
```

## Spec File Format

```markdown
# Spec: <name>

## Status
proposed | in-progress | completed

## Requirements
- 需求描述

## Constraints
- 约束条件

## Data Model
- 数据结构

## API
- API 定义

## Tests
- 测试用例

## Implementation Notes
- 实施笔记
```