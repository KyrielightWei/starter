# Phase 04: Commit Diff Review - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 04-commit-diff-review
**Areas discussed:** Commit Display, Diff Display, Picker Interaction, Error & Empty States

---

## Commit Display

| Option | Description | Selected |
|--------|-------------|----------|
| fzf-lua picker | Reuse Phase 1 pattern for consistency | ✓ |
| Telescope picker | Alternative fuzzy finder | |
| Custom floating window | Full control over UI | |

**User's choice:** fzf-lua picker (consistent with Phase 1)
**Notes:** Commit format: `[short_sha] subject (date, branch_info)` with colored short SHA

---

## Diff Display

| Option | Description | Selected |
|--------|-------------|----------|
| diffview.nvim | Already installed, configured | ✓ |
| codediff.nvim | VSCode-style diff (also installed) | |
| vimdiff | Built-in, minimal setup | |

**User's choice:** diffview.nvim (already installed per STACK.md)
**Notes:** Opens in current tab, supports single-commit and range diff

---

## Picker Interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Single-select default | User picks one commit at a time | ✓ |
| Multi-select only | User must select 2+ commits | |
| Toggle mode | Switch between single/multi | |

**User's choice:** Single-select by default, multi-select via fzf-lua's ctrl+tab
**Notes:** <CR> opens diff, <Esc> closes picker. Window 60% width, 40% height, centered.

---

## Error & Empty States

| Option | Description | Selected |
|--------|-------------|----------|
| Fallback to recent commits | When no unpushed, show last 20 | ✓ |
| Show empty message only | "No unpushed commits" | |
| Auto-push prompt | Ask if user wants to push | |

**User's choice:** Fallback to recent commits with informative message
**Notes:** Git command failures show error notification with command output for debugging

---

## the agent's Discretion

- Test file structure follows Phase 1 patterns
- Module organization in lua/commit_picker/ directory
- Error messages in Chinese (bilingual approach)

## Deferred Ideas

- Commit search/filtering (Phase 5 or separate)
- Commit message editing (new capability)
- Interactive rebase integration (Phase 6 or separate)
