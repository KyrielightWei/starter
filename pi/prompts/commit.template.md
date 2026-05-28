---
description: Generate a conventional commit message from staged changes
argument-hint: "[scope-hint]"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Commit                                              ║
║                                                                        ║
║  安装: cp pi/prompts/commit.template.md ~/.pi/agent/prompts/commit.md  ║
║  调用: /commit [scope-hint]                                            ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Generate a conventional commit message for the **currently staged** changes.

## Steps

1. Run `git diff --cached --stat` then `git diff --cached`. Read carefully.
2. If nothing is staged, stop and tell me — do not stage on your behalf.
3. Detect the change nature:
   - `feat`: new user-visible behavior
   - `fix`: corrects wrong behavior
   - `refactor`: no behavior change, only structure
   - `docs` / `test` / `chore` / `perf` / `ci`: literal
4. Pick a scope (one short noun for the affected module). Hint from user: **$1**
5. Draft message:
   ```
   <type>(<scope>): <imperative summary, <72 chars>

   [Optional body: WHY, not WHAT. WHAT is in the diff.]
   [Optional footer: Refs #123, BREAKING CHANGE: ...]
   ```
6. Show me the draft. **Do not commit** unless I confirm.

## Rules

- Imperative mood (`add`, not `added`)
- No trailing period in the subject line
- Body explains motivation, not file-by-file enumeration
- Mark breaking changes explicitly in footer or with `!`: `feat(api)!: drop v1 endpoint`
- Do not invent issue numbers or co-author tags
