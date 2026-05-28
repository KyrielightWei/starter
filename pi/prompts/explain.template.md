---
description: Explain code to onboard a new reader
argument-hint: "<file-or-symbol-or-flow>"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Explain                                             ║
║                                                                        ║
║  安装: cp pi/prompts/explain.template.md ~/.pi/agent/prompts/explain.md
║  调用: /explain <file or symbol or flow>                               ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Explain **$1** as if onboarding a new engineer who has read the project README but never opened this code.

## Structure

1. **One-sentence summary** — what role does this play?
2. **Why it exists** — what problem does it solve, what was the trade-off?
3. **Entry points** — where does control flow start?
4. **Key abstractions** — name the 3-5 concepts that matter; explain each in one paragraph.
5. **Data flow** — trace a representative request/event end-to-end.
6. **Gotchas** — invariants, hidden coupling, surprising decisions (read git blame if needed).
7. **Where to go next** — for adding a feature / fixing a bug / removing this.

## Rules

- Cite file paths with `file:line` so the reader can jump.
- Don't repeat what the code already says; explain the **why** and **how it fits**.
- If you discover something the code doesn't say (a constraint from a comment, commit message, or shape of tests), surface it.
- If you find something genuinely confusing, say "this is confusing because X" — don't paper over it.
- For large modules, ask first: do they want the architecture view, or a specific function's behavior?
