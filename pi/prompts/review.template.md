---
description: Review staged git changes for bugs, security issues, and performance problems
argument-hint: "[focus]"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Code Review                                         ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/prompts/review.md                             ║
║  调用: /review [focus]                                                 ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Review the staged changes (`git diff --cached`).

Focus on:
$@

## Checklist

- [ ] Bugs and logic errors
- [ ] Security vulnerabilities
- [ ] Error handling gaps
- [ ] Performance concerns
- [ ] Code style consistency
- [ ] Documentation clarity