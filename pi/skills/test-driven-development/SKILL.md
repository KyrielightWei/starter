---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code. Write tests first, then implement.
license: MIT
compatibility: Pi coding agent
metadata:
  author: obra
  version: 1.0.0
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Test-Driven Development Skill - 测试驱动开发                          ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/skills/test-driven-development/SKILL.md       ║
║  调用: /skill:test-driven-development                                  ║
╚════════════════════════════════════════════════════════════════════════╝
-->

# Test-Driven Development: 测试驱动开发

## 触发条件

在以下情况使用此技能：
- 实现新功能
- 修复 bug
- 重构代码

**禁止在写测试前写实现代码。**

## TDD 循环

```
┌─────────────────────────────────────────────┐
│                                             │
│  1. 🔴 Red    → 写一个失败的测试             │
│                                             │
│  2. 🟢 Green  → 写最小代码让测试通过         │
│                                             │
│  3. 🔵 Refactor → 重构代码，保持测试通过     │
│                                             │
│  └─────────────────────────────────────────────┘
         ↑
         │ 循环
         ↓
```

## 流程详解

### 1. 🔴 Red: 写失败的测试

**步骤：**

1. 理解需求
2. 设计 API 接口
3. 写测试用例
4. 运行测试确认失败

**测试内容：**

```
- 正常输入
- 边界情况
- 错误处理
- 预期行为
```

**测试文件位置：**

```
tests/module_spec.lua      (Lua)
tests/module.test.ts       (TypeScript)
tests/test_module.py       (Python)
```

### 2. 🟢 Green: 写最小实现

**原则：**

- 只写让测试通过的代码
- 不写额外的功能
- 可以写"丑陋"的代码

**禁止：**

- ❌ 过度设计
- ❌ 添加未测试的功能
- ❌ 优化代码

### 3. 🔵 Refactor: 重构代码

**在测试通过后：**

1. 检查代码重复
2. 优化结构
3. 改善命名
4. 每次小改动后运行测试

**原则：**

- 小步重构
- 每步都运行测试
- 测试必须保持通过

## 测试结构

### 基本格式

```lua
describe("module_name", function()
  describe("function_name", function()
    it("should do X", function()
      -- 测试代码
      assert.are.equal(expected, actual)
    end)

    it("should handle edge case Y", function()
      -- 边界情况测试
    end)

    it("should error on invalid input Z", function()
      -- 错误处理测试
    end)
  end)
end)
```

### TypeScript 格式

```typescript
describe("module_name", () => {
  describe("function_name", () => {
    it("should do X", () => {
      expect(actual).toBe(expected);
    });

    it("should handle edge case Y", () => {
      // 边界情况
    });
  });
});
```

## 测试类型

### 单元测试

```
- 测试单个函数
- 最小依赖
- 快速执行
```

### 集成测试

```
- 测试多个组件交互
- 真实依赖
- 较慢执行
```

### 边界情况

```
- 空输入
- 极值
- 错误类型
- 并发情况
```

## 运行测试

### Lua (plenary)

```bash
nvim --headless -c "PlenaryBustedFile tests/module_spec.lua" -c "q"
nvim --headless -c "PlenaryBustedDirectory tests/" -c "q"
```

### TypeScript

```bash
npm test
npm test -- --watch
npm test -- --filter=test-name
```

### Python

```bash
pytest tests/
pytest -k test_name
pytest --cov=src
```

## 输出格式

完成 TDD 后，提供：

```markdown
## TDD 完成

### 测试文件
[测试文件路径]

### 测试用例
- [x] 正常输入 → [预期结果]
- [x] 边界情况 → [预期结果]
- [x] 错误处理 → [预期结果]

### 实现文件
[实现文件路径]

### 测试状态
所有测试通过 ✓
```

## 注意事项

### 禁止

- ❌ 先写实现，后补测试
- ❌ 测试写得不完整
- ❌ 测试通过后不重构
- ❌ 重构时不运行测试

### 必须

- ✅ 测试先行
- ✅ 测试覆盖所有场景
- ✅ 重构保持测试通过
- ✅ 每步都验证