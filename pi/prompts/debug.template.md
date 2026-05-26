---
description: Debug the issue by following systematic debugging workflow
argument-hint: "<issue-description>"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Debug                                               ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/prompts/debug.md                              ║
║  调用: /debug <issue>                                                  ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Debug this issue: $@

## Systematic Debugging Process

### 1. Collect Information

- What is the expected behavior?
- What is the actual behavior?
- What are the error messages/logs?
- When did the problem start?
- What changed recently?

### 2. Determine Scope

- Which module?
- Which function?
- Which file?
- Which call path?

### 3. Simplify

- Create minimal reproduction
- Remove unrelated code
- Isolate the environment

### 4. Hypothesize and Verify

For each hypothesis:
- State the hypothesis clearly
- Design verification method
- Execute and record results

### 5. Identify Root Cause

Confirm the root cause with evidence:
- Code logic error
- Data issue
- Configuration issue
- Environment issue

### 6. Propose Fix

Based on root cause:
- What to modify?
- Why this modification?
- Any side effects?
- How to verify the fix?

## Output Format

After debugging:

```markdown
## Debugging Results

### Issue
[Issue description]

### Root Cause
[Root cause with evidence]

### Fix
[Fix proposal]

### Verification
[Steps to verify the fix works]
```