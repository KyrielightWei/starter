# Phase 04: Commit Diff Review - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 04 delivers a commit picker and diff review capability for GSD workflow. Users can:
- Open a floating window commit picker defaulting to unpushed commits
- Select commits and view their diffs using diffview.nvim
- Review changes across multiple commits in a GSD workflow

This phase is independent of the Provider Manager stream (Phases 1-3).
Phase 5 (configuration) and Phase 6 (navigation) build on this foundation.

</domain>

<decisions>
## Implementation Decisions

### Commit Display
- **D-01:** Use fzf-lua as picker (consistent with Phase 1 Provider Manager pattern)
- **D-02:** Commit list defaults to unpushed commits (origin/HEAD..HEAD range)
- **D-03:** Single commit selection shows diff against parent; two commits shows diff between them
- **D-04:** Commit format: `[short_sha] subject (date, branch_info)` — compact but informative
- **D-05:** Use colored short SHA for visual scanning (matching git log --color pattern)

### Diff Display
- **D-06:** Use diffview.nvim for diff visualization (already installed per STACK.md)
- **D-07:** Diff opens in current tab, replacing current buffer view (non-intrusive)
- **D-08:** Support both single-commit diff (git show) and range diff (git diff commit1..commit2)
- **D-09:** Diff view uses existing diffview.nvim configuration from git.lua plugin spec

### Picker Interaction
- **D-10:** Single-select mode by default (user picks one commit to review)
- **D-11:** Multi-select enabled via fzf-lua's built-in multi-select (ctrl+tab) for range diff
- **D-12:** Picker window centered, 60% width, 40% height (consistent with Phase 1)
- **D-13:** <CR> opens diff for selected commit(s)
- **D-14:** <Esc> closes picker without action

### Error & Empty States
- **D-15:** When no unpushed commits exist, show informative message: "No unpushed commits. Showing recent commits instead." and fallback to last 20 commits
- **D-16:** When git command fails, show error notification with command output for debugging
- **D-17:** When diffview.nvim not configured, show warning and suggest `:DiffviewOpen` as fallback

### the agent's Discretion
- Test file structure and naming conventions follow Phase 1 patterns
- Module organization (lua/commit_picker/ directory) for clean separation
- Error messages in Chinese (matching project's bilingual approach)

### Folded Todos
None

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Standards
- `.planning/ROADMAP.md` — Phase 04 goal, requirements (CDRV-01, CDRV-02), success criteria
- `.planning/REQUIREMENTS.md` — CDRV-01, CDRV-02 requirement definitions
- `lua/ai/provider_manager/picker.lua` — Reference implementation for fzf-lua picker pattern
- `lua/plugins/git.lua` — diffview.nvim plugin configuration and custom settings

### External Dependencies
- `sindrets/diffview.nvim` — Diff display plugin (already installed)
- `ibhagwan/fzf-lua` — Fuzzy finder (already installed)
- `git` CLI >= 2.31 (per STACK.md)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **fzf-lua integration**: Phase 1 picker.lua demonstrates fzf-lua.fzf_exec pattern with custom actions
- **diffview.nvim config**: git.lua plugin spec already configures diffview with custom settings (LSP disabled in diff buffers, worktree support)
- **UI patterns**: Phase 1 ui_util.lua provides notify_with_icon, floating_input utilities
- **State management**: ai.state module pattern for persistent configuration

### Established Patterns
- **Module structure**: lua/ai/provider_manager/ directory pattern (registry, validator, picker, display)
- **Error handling**: vim.notify with appropriate log levels (INFO, WARN, ERROR)
- **Key patterns**: <leader>k prefix for AI-related commands
- **Command naming**: AI prefix for user commands (AIProviderManager, AICheckProvider, etc.)

### Integration Points
- New lua/commit_picker/ directory alongside lua/ai/ (or within it?)
- Keymap registration in init.lua or separate setup function
- User command registration for :CommitDiffReview or similar

</code_context>

<specifics>
## Specific Ideas

- Picker should feel similar to Phase 1 Provider Manager for consistency
- Use same icon style (softer Unicode symbols, not large emoji)
- Commit dates formatted relative ("2 hours ago") for readability
- Multi-select via fzf-lua's native ctrl+tab binding (no custom keymap needed)
- Diff view should leverage existing diffview.nvim configuration

</specifics>

<deferred>
## Deferred Ideas

- Commit search/filtering (belongs in Phase 5 or separate phase)
- Commit message editing (out of scope — new capability)
- Interactive rebase integration (belongs in Phase 6 or separate phase)

### Reviewed Todos (not folded)
None

</deferred>

---

*Phase: 04-commit-diff-review*
*Context updated: 2026-04-25*
