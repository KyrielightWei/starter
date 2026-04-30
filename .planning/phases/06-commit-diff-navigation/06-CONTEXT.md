# Phase 06: Commit Diff Navigation - Context

**Gathered:** 2026-04-26
**Status:** Ready for planning — auto-resolved (user delegated decisions)
**Auto-resolved:** Yes — user answered "未解答" (unanswered), deferring all design decisions to the agent

<domain>
## Phase Boundary

Phase 06 adds commit-to-commit navigation *during* diff review. After Phase 4/5, users can select commits from a picker and view the diff. Phase 6 lets them navigate through the commit list sequentially without reopening the picker each time.

**What this phase delivers:**
- `<leader>kn` / `<leader>kN` keymaps for next/previous commit navigation (while diffview is open or after closing)
- Navigation state: remember current position in the commit list, move forward/backward
- Visual feedback: show which commit is currently being reviewed
- Works with Phase 5 config modes (unpushed, last_n, since_base)

This phase depends on Phase 4 (picker + diff foundation) and Phase 5 (config).
Phase 6 does NOT add: inline comments, review summaries, or code editing — those are v2 requirements (CDRV-07~11).

</domain>

<decisions>
## Implementation Decisions

### Navigation Workflow
- **D-18:** After selecting commits in picker and viewing diff, user can navigate to next/previous commit via keymaps
- **D-19:** Navigation keeps the same commit list from the picker session — no re-fetching
- **D-20:** At the end of the list (last/first commit), show notification: "已是最后/最早 commit"
- **D-21:** Navigation wraps around disabled — stops at boundaries, no loop

### Keymaps (under `<leader>k` AI namespace)
- **D-22:** `<leader>kf` — Navigate to next commit (f = forward)
- **D-23:** `<leader>kb` — Navigate to previous commit (b = backward)
- **D-22a:** ~~`<leader>kn`~~ → REMOVED due to conflict with "AI New Chat" (H-01 fix)
- **D-23a:** ~~`<leader>kN`~~ → REMOVED due to conflict with "AI New Chat" (H-01 fix)
- **D-24:** Keymaps only active when diffview is open or when commit_picker session is active
- **D-25:** No conflict with existing keymaps — `<leader>kf` and `<leader>kb` not currently used in ai/init.lua

### Diff Update Behavior (D-27 research resolved)
- **D-26:** Navigation closes current diffview and opens a new one with updated range (reuses DiffviewOpenEnhanced)
- **D-26a:** RACE CONDITION FIX: Added vim.defer_fn(50ms) between DiffviewClose and DiffviewOpenEnhanced (R-01 fix)
- **D-27:** diffview.nvim has no in-place range update API — investigated and confirmed close+reopen is required
- **D-28:** For single-commit mode: navigating shows sha^..sha for each commit (same as Phase 4 behavior)
- **D-29:** For two-commit mode: navigation disabled with "范围模式下不支持逐条导航" notification (C-01 fix)

### Navigation State
- **D-30:** Store current commit list + current index in `navigation.lua` (module-local state, NOT selection.lua) — DEV from original D-30: dedicated module is cleaner than extending selection.lua
- **D-31:** When picker is opened, store the full commit list, not just selected SHAs
- **D-32:** When navigation is complete (user closes picker or switches context), clear stored list

### Visual Feedback
- **D-33:** Show vim.notify() on navigation: "3/93 → abc1234 feat: add auth" (current/total + subject)
- **D-34:** If lualine has a commit_picker component, show current commit position there
- **D-35:** the agent's Discretion on exact notification format — use existing Chinese message convention

### Config Integration (Phase 5)
- **D-36:** Navigation uses the same commit list that was fetched for the picker (respects Phase 5 config)
- **D-37:** If config mode is "since_base", navigation goes from HEAD backward to base_commit
- **D-38:** If config mode is "last_n", navigation goes through N commits from HEAD backward

### the agent's Discretion
- Diffview API investigation: whether programmatic range change is available vs close+reopen
- Navigation state storage pattern (selection.lua extension vs new navigation.lua module)
- Lualine component implementation details
- Error recovery for edge cases (commit deleted, rebase during navigation)
- Test file structure follows Phase 5 patterns (plenary.nvim specs)

### Folded Todos
None

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Standards
- `.planning/ROADMAP.md` — Phase 06 goal, requirements (CDRV-05, CDRV-06), success criteria
- `.planning/REQUIREMENTS.md` — CDRV-05, CDRV-06 requirement definitions
- `AGENTS.md` — Coding conventions, module patterns, testing guidelines

### Code References
- `lua/commit_picker/diff.lua` — Existing diff integration (DiffviewOpenEnhanced, SHA validation)
- `lua/commit_picker/init.lua` — Picker entry point (get_modules, mode routing)
- `lua/commit_picker/selection.lua` — Selection state (extend with navigation list)
- `lua/commit_picker/config.lua` — Config module (Phase 5, provides commit list context)
- `lua/commit_picker/git.lua` — Git operations (commit fetching, needs navigation helpers)
- `lua/ai/init.lua` — Keymap registration (`<leader>k` namespace)
- `lua/plugins/git.lua` — diffview.nvim configuration (DiffviewOpenEnhanced definition)

### External Dependencies
- `sindrets/diffview.nvim` — Diff display plugin (check API for programmatic range change)
- `git` CLI >= 2.31 (per STACK.md)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **diff.lua**: `M.open_diff(shas)` already handles 1-SHA (sha^..sha) and 2-SHA (sha1..sha2) ranges
- **selection.lua**: Simple module-local state — easy to extend with `commit_list` and `current_index`
- **git.lua**: `vim.system()` pattern established; `get_commit_list()` returns structured commits
- **init.lua**: `get_modules()` with pcall guards — pattern for navigation module loading
- **display.lua**: fzf-lua picker with colored SHA, multi-select, preview caching

### Established Patterns
- Keymaps registered in `ai/init.lua` keys table (static) + `commit_picker/init.lua:setup()` (dynamic for commands)
- Error messages in Chinese (bilingual approach from Phase 4)
- Atomic file writes (Phase 5 config module)
- Plenary.nvim test specs (20/20 passing in Phase 5)
- Module structure: `lua/commit_picker/` directory

### Integration Points
- Navigation state needs to be accessible from both picker (when commits are selected) and keymaps (when navigating)
- Navigation keymaps must check if diffview is open before acting
- Selection module needs backward compatibility — existing `get_selected()`/`set_selected()` must still work

</code_context>

<specifics>
## Specific Ideas

- Navigation notification format: `"3/93 → abc1234 feat: add auth"` — position + SHA + subject
- Keymaps: `<leader>kn` next, `<leader>kN` previous — intuitive vim-style convention
- Navigation list persisted only for current picker session, not across restarts
- When user picks commits from picker, the full list (not just selection) is stored for navigation
</specifics>

<deferred>
## Deferred Ideas

- Inline comments on diff lines (v2: CDRV-07)
- Review summary generation (v2: CDRV-08~11)
- Commit search/filtering within navigation list (mentioned in Phase 4 deferred, belongs here or later)
- Interactive rebase integration (mentioned in Phase 4 deferred, out of scope)

### Reviewed Todos (not folded)
None

</deferred>

---

*Phase: 06-commit-diff-navigation*
*Context gathered: 2026-04-26*
*Decisions auto-resolved: user delegated to agent*
