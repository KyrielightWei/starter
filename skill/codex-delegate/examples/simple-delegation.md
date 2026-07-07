# 示例 1: 简单任务委托

## 场景
用户在 OMP 中编辑文件，想要用 Codex 重构一个函数。

## 对话流程

**用户:**
```
用 codex 帮我重构这个 login 函数，改用 JWT token
```

**OMP 处理:**
1. 检测到关键词 "用 codex" → 激活 codex-delegate skill
2. 识别当前编辑文件: `src/auth.ts`
3. 提取上下文:
   - 当前文件内容
   - 相关文件: `src/user.ts`, `src/db.ts`
   - 最近 3 轮对话摘要
4. 构建 prompt:
   ```
   Context:
   - Current file: src/auth.ts (editing)
   - Related files: src/user.ts, src/db.ts
   - Recent discussion: User wants to add JWT authentication
   
   Task:
   Refactor the login function to use JWT tokens instead of session cookies
   
   Output Format:
   Provide refactored code with explanation of changes
   ```
5. 调用 MCP 工具:
   ```javascript
   const result = await mcp.call('codex', {
     prompt: buildPrompt(context, task),
     cwd: process.cwd(),
     env: {
       HTTPS_PROXY: process.env.HTTPS_PROXY || '',
       HTTP_PROXY: process.env.HTTP_PROXY || ''
     }
   });
   ```
6. 保存 threadId:
   ```javascript
   saveSessionState('codexThreadId', result.threadId);
   ```
7. 显示结果给用户

## 关键点
- 自动提取上下文（智能模式）
- 保存 threadId 用于后续对话
- Codex 自动生成审计日志
