---
description: Draft a pull request description from branch commits
argument-hint: "[base-branch]"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - PR                                                  ║
║                                                                        ║
║  安装: cp pi/prompts/pr.template.md ~/.pi/agent/prompts/pr.md          ║
║  调用: /pr [base-branch]   (默认 main)                                 ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Draft a PR description comparing the current branch to **$1** (default `main` if empty).

## Steps

1. `git fetch origin` first.
2. `BASE=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo main)`
3. Inspect: `git log --oneline ${BASE:-main}..HEAD` and `git diff ${BASE:-main}...HEAD --stat`.
4. Group commits by intent (feature / fix / refactor / docs / test / chore).
5. Output the PR description in this exact shape:

```markdown
## Summary

<2-4 sentences: what changes, why, user impact>

## Changes

- **<area>**: <one-line change>
- **<area>**: <one-line change>

## How to Verify

- [ ] <reviewer step 1>
- [ ] <reviewer step 2>

## Risks

<edge cases, known limitations, follow-ups deferred>

## Related

<links: issues, design docs, related PRs — do not invent>
```

## Rules

- "Summary" is the only required section.
- Do not list every commit; consolidate by topic.
- Risks section is honest: empty section is allowed, fake reassurance is not.
- Do not push or open the PR unless I ask.
