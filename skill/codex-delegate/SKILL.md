---
name: codex-delegate
description: "Use when user says '用 codex', 'use codex', '委托给 codex', or explicitly requests Codex delegation, OpenAI-model execution, audit trail, billing, or reimbursement tracking."
---

# Codex Delegate

Delegate work from OMP to OpenAI Codex through the configured Codex MCP server. Use this for audit-tracked Codex execution, not for ordinary assistant work.

## Use When

- User explicitly says: "用 codex", "use codex", "委托给 codex", "交给 codex".
- User asks for Codex, OpenAI-model execution, audit trail, billing, or reimbursement tracking.
- A follow-up clearly continues an active Codex thread and a `threadId` is available.

Do not use when the user only wants normal OMP assistance, or when no Codex/audit/OpenAI requirement is present.

## Important Boundaries

- This skill is an instruction package. It does not add a native OMP `/codex` command, global keyword router, or Codex subagent.
- Primary path is MCP: `mcp.call('codex')` and `mcp.call('codex-reply')`.
- Fallback: `codex exec` is only for manual or MCP-unavailable cases.
- Do not promise automatic cross-session `threadId` persistence unless the host runtime provides session storage.

## Workflow

1. Confirm the request should use Codex.
2. Choose a context mode: Smart, Full, or Manual.
3. Build a concise prompt with context, task, expected output format, and working directory.
4. Call Codex via MCP.
5. Save `threadId` if returned.
6. Return Codex output plus model/token/cost notes when available.

## Context Modes

| Mode | Use For | Include |
|---|---|---|
| Smart (default) | Simple refactor, explanation, single-file work | Current file, obvious dependencies, recent conversation summary |
| Full | Complex debugging, architecture, multi-step analysis | Available conversation history and relevant tool results |
| Manual | User names files/ranges or project is large | Only specified files/ranges and task |

Manual range syntax examples:

```text
src/auth.ts
src/auth.ts:10-50
src/auth.ts:10-50,src/user.ts
```

For review tasks, prefer Manual or Smart+Manual scope and explicitly exclude unrelated directories.

## MCP Invocation

Initial delegation:

```javascript
const result = await mcp.call('codex', {
  prompt: buildPrompt(context, task),
  cwd: workingDirectory,
});
const threadId = result.threadId;
saveSessionState('codexThreadId', threadId);
```

Follow-up:

```javascript
const threadId = getSessionState('codexThreadId');
const result = await mcp.call('codex-reply', {
  threadId: threadId,
  prompt: followUpMessage,
});
```

If `saveSessionState`/`getSessionState` are unavailable, keep `threadId` explicitly in the current assistant conversation or another host-provided session store. If no `threadId` is available for a follow-up, start a new `codex` session and tell the user the previous Codex thread is unavailable.

## Prompt Shape

Use a structured prompt:

```text
Context:
- Working directory: ...
- Relevant files: ...
- Recent discussion: ...

Task:
...

Output format:
## 总结
## 问题列表 / 修改建议
## 资源消耗
```

For code review, request findings first with file and line references, then a short summary.

## CLI Fallback

Use CLI only when MCP is unavailable or when manually validating Codex outside OMP.

First call:

```bash
HTTPS_PROXY=http://127.0.0.1:10808 HTTP_PROXY=http://127.0.0.1:10808 \
  timeout 300 codex exec --json -C "$PWD" - < /tmp/codex-prompt.txt
```

Follow-up with an explicit session id:

```bash
HTTPS_PROXY=http://127.0.0.1:10808 HTTP_PROXY=http://127.0.0.1:10808 \
  timeout 300 codex exec resume "$THREAD_ID" - < /tmp/codex-followup.txt
```

Never resume the "last" Codex session implicitly. In multi-window environments it may resume another terminal's session.

## Proxy

MCP calls should inherit proxy settings from `~/.config/mcp/mcp.json`:

```json
{
  "mcpServers": {
    "codex": {
      "type": "stdio",
      "command": "codex",
      "args": ["mcp-server"],
      "env": {
        "HTTPS_PROXY": "http://127.0.0.1:10808",
        "HTTP_PROXY": "http://127.0.0.1:10808"
      }
    }
  }
}
```

For CLI fallback, set `HTTPS_PROXY` and `HTTP_PROXY` inline on the command.

## Reporting Usage and Cost

After Codex execution, report what is actually available:

```text
## 执行结果
[Codex 输出内容]

## 资源消耗
- Thread: [threadId if available]
- 模型: [model if available]
- Token: [token count if available]
- 费用: 请查看 tokensflow 获取实际金额
```

Do not hard-code model prices. Pricing changes and Codex output may not expose the exact input/output split.

## Error Handling

| Problem | Action |
|---|---|
| MCP unavailable | Verify `~/.config/mcp/mcp.json`, then use CLI fallback only if needed |
| Missing `threadId` | Start a new `codex` session and explain that prior state is unavailable |
| Thread invalid | Clear saved `threadId`, start a new session, inform user |
| Context too large | Switch from Full to Smart or Manual mode |
| Timeout | Reduce scope first; increase timeout up to 600s only for complex tasks |
| Proxy/network failure | Check proxy env and MCP config |

## Validation

From the repository root:

```bash
bash skill/codex-delegate/tests/test-mcp-config.sh
bash skill/codex-delegate/tests/test-delegation.sh
bash skill/codex-delegate/tests/test-multiturn.sh
```
