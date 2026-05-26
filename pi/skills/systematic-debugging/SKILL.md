---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes. Follow a structured investigation process.
license: MIT
compatibility: Pi coding agent
metadata:
  author: obra
  version: 1.0.0
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Systematic Debugging Skill - 系统化调试流程                           ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/skills/systematic-debugging/SKILL.md          ║
║  调用: /skill:systematic-debugging                                     ║
╚════════════════════════════════════════════════════════════════════════╝
-->

# Systematic Debugging: 系统化调试

## 触发条件

遇到以下情况时使用此技能：
- Bug 或错误
- 测试失败
- 意外行为
- 性能问题

**禁止在调查前直接提出修复方案。**

## 流程

### 1. 收集信息

先回答这些问题：

```
1. 预期行为是什么？
2. 实际行为是什么？
3. 错误消息/日志是什么？
4. 问题何时开始？
5. 最近有什么变更？
```

使用工具：
- `read` 查看相关代码
- `bash` 运行测试、查看日志
- `grep` 搜索错误消息

### 2. 确定范围

定位问题边界：

```
- 哪个模块？
- 哪个函数？
- 哪个文件？
- 哪个调用路径？
```

使用方法：
- 添加日志
- 检查输入/输出
- 追踪调用链

### 3. 简化问题

创建最小复现：

```
- 去除无关代码
- 简化输入
- 隔离环境
```

目标：
- 能稳定复现
- 代码最少化
- 易于理解

### 4. 假设验证

提出假设并验证：

```
假设 A: 原因是 X
验证: 执行 Y，预期结果 Z

假设 B: 原因是 P
验证: 执行 Q，预期结果 R
```

每个假设：
- 明确陈述
- 设计验证方法
- 记录结果

### 5. 定位根因

确认根本原因：

```
- 不是表面症状
- 不是巧合
- 有明确证据
```

证据类型：
- 代码逻辑错误
- 数据问题
- 配置问题
- 环境问题

### 6. 提出修复

基于根因提出修复：

```
修复方案：
1. 修改什么？
2. 为什么这样修改？
3. 是否有副作用？
4. 如何验证修复？
```

验证：
- 运行测试
- 检查边界情况
- 确认无回归

## 注意事项

### 禁止

- ❌ 看到错误就猜测原因
- ❌ 直接修改代码
- ❌ 跳过调查步骤
- ❌ 忽略证据

### 必须

- ✅ 先收集信息
- ✅ 提出假设并验证
- ✅ 确认根因后再修复
- ✅ 验证修复有效

## 工具使用

### 查看代码

```bash
read path/to/file.ts
```

### 运行测试

```bash
npm test
npm test -- --filter=specific-test
```

### 搜索错误

```bash
grep -r "error message" src/
grep -r "ERROR" logs/
```

### 查看日志

```bash
cat logs/app.log | tail -100
journalctl -u service-name -n 100
```

## 输出格式

调试完成后，提供：

```markdown
## 调查结果

### 问题
[问题描述]

### 根因
[根本原因]

### 证据
[支持结论的证据]

### 修复
[修复方案]

### 验证
[验证步骤]
```