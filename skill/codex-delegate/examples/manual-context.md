# 示例 3: 手动指定上下文

## 场景
用户想要精确控制传递给 Codex 的文件和范围。

## 对话流程

**用户:**
```
委托给 codex 优化这些文件：src/auth.ts:10-50, src/user.ts
```

**OMP 处理:**
1. 检测到关键词 "委托给 codex"
2. 解析文件列表:
   - `src/auth.ts:10-50` → 第 10-50 行
   - `src/user.ts` → 整个文件
3. 加载指定内容:
   ```typescript
   // src/auth.ts 第 10-50 行
   export function login(username: string, password: string) {
     // ... 函数实现
   }
   
   // src/user.ts 完整内容
   export class User {
     // ... 类定义
   }
   ```
4. 构建 prompt（手动模式）:
   ```
   Context:
   - src/auth.ts (lines 10-50): login function
   - src/user.ts: User class definition
   
   Task:
   优化这些文件的性能和代码质量
   
   Output Format:
   提供优化建议和重构后的代码
   ```
5. 调用 `codex` 工具
6. 显示结果

## 关键点
- 使用 `--files` 参数指定文件
- 支持行范围: `file:start-end`
- 只加载用户指定的内容
- 适合大型项目或敏感文件

## 其他手动模式示例

**指定多个文件:**
```
用 codex 审查这些文件：src/api.ts, src/db.ts, src/utils.ts
```

**指定行范围:**
```
交给 codex 重构：src/legacy.ts:100-200
```

**混合使用:**
```
用 codex 优化：src/core.ts, src/helper.ts:50-100, src/config.ts
```
