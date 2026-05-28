---
description: Systematic debugging - hypothesis-driven, bisect-based
argument-hint: "<symptom or error message>"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Debug                                               ║
║                                                                        ║
║  安装: cp pi/prompts/debug.template.md ~/.pi/agent/prompts/debug.md    ║
║  调用: /debug <symptom>                                                ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Debug systematically: **$@**

## Method

1. **State the symptom precisely**. What is the input, the observed output, the expected output? If any is unclear, ask before guessing.
2. **Form hypotheses** (at least 2). Rank by likelihood × cheapness-to-test.
3. **Design the cheapest discriminating experiment**. Often: add a single log, run with a known input, bisect git history.
4. **Run the experiment**, **read the output verbatim**, update beliefs.
5. **Repeat** until a single hypothesis stands. Do not implement a fix during this loop.
6. **Once root cause is identified**, propose the smallest fix that addresses it. Explain why your fix maps to the cause.
7. **Add a regression test** before applying the fix. Confirm it fails. Apply fix. Confirm it passes.

## Anti-patterns to avoid

- Speculating without running the experiment ("it might be...")
- Changing multiple things at once ("let me also clean up X")
- Adding defensive code "just in case" without proving the case exists
- Stopping at the first plausible cause when a deeper cause is upstream
- Skipping the regression test ("it's just a one-line fix")

## If stuck

State explicitly: "I have no high-confidence hypothesis." List what you ruled out. Ask for help — do not guess.
