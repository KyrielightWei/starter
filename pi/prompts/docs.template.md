---
description: Generate or update documentation for code
argument-hint: "<file-or-symbol>"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Docs                                                ║
║                                                                        ║
║  安装: cp pi/prompts/docs.template.md ~/.pi/agent/prompts/docs.md      ║
║  调用: /docs <file-or-symbol>                                          ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Write or update documentation for **$1**.

## Steps

1. **Read** the code. Do not document from filename guesses.
2. **Detect doc style**: project's existing docs (TSDoc/JSDoc/Sphinx/rustdoc/godoc/Markdown). Match it exactly.
3. **Write for the reader who will use this**, not the reader who reads it cover-to-cover:
   - **What it does** (one sentence)
   - **When to use it / when NOT to use it** (often more useful than what)
   - **Parameters / returns / errors** (every public param, every thrown error)
   - **Example** (real, runnable, copy-pasteable)
4. **Skip the obvious**. If the name says it, don't repeat in prose.
5. **Mark stability** if applicable: `@experimental`, `@deprecated`, internal-only.

## Rules

- Do not invent behavior. If something is unclear from the code, **ask** or **read more** — do not guess.
- Examples must be runnable. Don't write `// ... rest of code` placeholders.
- Don't use marketing language ("powerful", "robust", "elegant"). State facts.
- Don't document what changed in this version — that's the changelog's job.
- Update related docs (README sections, CHANGELOG, type-doc index) if behavior changed.
