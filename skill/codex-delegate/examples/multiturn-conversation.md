# 示例 2: 多轮对话

## 场景
用户先用 Codex 分析 bug，然后继续追问修复方案。

## 对话流程

**第一轮 - 分析 bug:**

**用户:**
```
用 codex 分析这个 bug，为什么用户登录后 session 会丢失？
```

**OMP 处理:**
1. 检测到 "用 codex"
2. 提取当前文件和错误日志
3. 调用 `codex` 工具（新会话）
4. 保存 threadId: `thread-abc123`
5. 显示 Codex 的分析结果

**Codex 响应:**
```
根据代码分析，问题在于 session 过期时间设置过短（5分钟），
且没有在刷新 token 时延长 session。

建议修复:
1. 将 session 过期时间改为 30 分钟
2. 在每次 API 调用时刷新 session
3. 添加 session 续期逻辑
```

---

**第二轮 - 追问修复:**

**用户:**
```
那如何修复呢？
```

**OMP 处理:**
1. 检测到这是后续问题
2. 加载保存的 threadId: `thread-abc123`
3. 调用 `codex-reply` 工具:
   ```javascript
   const result = await mcp.call('codex-reply', {
     threadId: 'thread-abc123',
     prompt: '那如何修复呢？'
   });
   ```
4. 显示修复方案

**Codex 响应:**
```
修复方案:

1. 修改 src/auth.ts 中的 session 配置:
   ```typescript
   const sessionConfig = {
     expiresIn: '30m',  // 改为 30 分钟
     rolling: true,      // 启用滚动过期
   };
   ```

2. 添加中间件刷新 session:
   ```typescript
   app.use((req, res, next) => {
     if (req.session) {
       req.session.touch(); // 刷新 session
     }
     next();
   });
   ```

3. 在前端添加 token 刷新逻辑...
```

## 关键点
- 使用 `codex-reply` 继续对话
- threadId 保持会话上下文
- Codex 记住之前的分析结果
