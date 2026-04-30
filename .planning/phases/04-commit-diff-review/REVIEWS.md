---
phase: 04
reviewers: [opencode]
reviewed_at: 2026-04-25
plans_reviewed: [04-01-PLAN.md, 04-02-PLAN.md, 04-03-PLAN.md]
---

# Cross-AI Plan Review — Phase 04: Commit Diff Review

## Summary

The three plans are well-structured with clear module boundaries and good threat modeling. The architecture (git → display → selection → diff) is sound and follows existing project patterns. However, there is a significant scope mismatch: Plans 02 and 03 implement requirements (CDRV-05, CDRV-06) that belong to Phase 6 in ROADMAP.md. Additionally, there are technical inaccuracies in fzf-lua multi-select configuration and diffview.nvim API usage that need correction before execution.

**Overall Risk: MEDIUM** — scope ambiguity and two medium-severity API issues could cause rework.

---

## Plan 01 Review (git.lua + display.lua)

### Strengths

- **Good module separation**: `git.lua` for data, `display.lua` for UI — clean and testable
- **Fallback behavior (D-15)**: Well-designed graceful degradation from unpushed to recent commits
- **Error handling pattern (D-16)**: Using `pcall` + capturing command output for debugging
- **Follows project conventions**: `local M = {}`, 2-space indent, `pcall` for optional deps
- **Threat model covers injection risk**: Static git commands without user interpolation

### Concerns

- **[HIGH] fzf-lua multi-select configuration is incorrect**: Plan specifies `fzf_opts = { ["--multi"] = "" }` with ctrl+tab binding. fzf-lua does not support raw `--multi` in `fzf_opts` in all versions. The correct approach is to use `fzf_opts["--bind"] = "ctrl-tab:toggle-all"` or consult the fzf-lua API — see `lua/ai/provider_manager/picker.lua` which uses `actions` tables, not raw fzf flags. The `--multi` flag may conflict with fzf-lua's default single-select behavior and the custom `actions` system.
- **[MEDIUM] `io.popen` blocking**: Plan uses `io.popen` (same as `fetch_models.lua`) for git commands. On repos with 10K+ commits, even with `--max-count=20`, git log may take >1s to traverse refs. Consider `vim.system()` (Neovim 0.10+) for async execution to avoid UI freezes, matching the async pattern used in provider detection (Phase 2 Detector).
- **[MEDIUM] ANSI escape codes in fzf-lua**: Embedding raw `\27[33m` ANSI codes in display strings may not render correctly in fzf-lua. fzf-lua uses its own highlight system (`highlight_callback` or `file_icons`). The picker.lua pattern at `lua/ai/provider_manager/picker.lua` uses Lua text formatting (icons, strings) rather than ANSI escapes. Recommend using string-based visual cues (e.g., `* abc1234`) or fzf-lua's native highlights instead.
- **[LOW] `display.close()` is underspecified**: The `close()` function is declared but no implementation detail is provided. What exactly should it close? fzf-lua windows are managed by the library. If this is a no-op, remove it to avoid confusion.
- **[LOW] No handling for detached HEAD**: `origin/HEAD..HEAD` range will fail in detached HEAD state. Should detect and use `origin/HEAD...HEAD` (three-dot) or fallback.
- **[LOW] git.lua interface mismatch**: `get_commit_list(base, head, opts)` uses `base..head` range, but the fallback description says "nil base/head uses HEAD with count limit." The interface is inconsistent — callers pass `"origin/HEAD", "HEAD"` but the plan says `base..head` implies `git log origin/HEAD..HEAD`, which is correct. However, the opts `{count = 20}` only applies when base/head are nil — this edge case is under-documented.

### Suggestions

1. Replace `io.popen` with `vim.system()` for async git log execution (Neovim 0.10+ available per STACK.md)
2. Use `fzf-lua`'s native highlight system for SHA coloring instead of raw ANSI escapes
3. Add detached HEAD detection before `get_unpushed()`
4. Clarify `display.close()` purpose or remove it

---

## Plan 02 Review (selection.lua + diff.lua)

### Strengths

- **Minimal selection state**: Module-local state without persistence is correct for ephemeral selection
- **Truncation to 2 SHAs**: Smart handling of fzf-lua returning more than 2 selected items
- **SHA validation in threat model**: Threat T-04-05 correctly identifies injection via vim.cmd and proposes format validation
- **Graceful diffview fallback (D-17)**: Checks `require("diffview")` before attempting to open

### Concerns

- **[HIGH] Scope creep — CDRV-05 and CDRV-06 belong to Phase 6**: The plan header declares `requirements: [CDRV-05, CDRV-06]` but these are Phase 6 requirements per ROADMAP.md. Phase 4's scope is "User can open a floating window commit picker" (CDRV-01) and "Picker defaults to unpushed commits" (CDRV-02). The diff capability is required for Phase 4's user workflow, but the full single-vs-two-commit behavior (CDRV-05, CDRV-06) is Phase 6's goal. This creates a documentation inconsistency and risks double-implementation.
- **[MEDIUM] Uses `vim.cmd("DiffviewOpen")` instead of `DiffviewOpenEnhanced`**: The existing `git.lua` plugin spec defines `DiffviewOpenEnhanced` which dynamically sets `git_cmd` for worktree support (line 391-394 of `lua/plugins/git.lua`). Using the raw `DiffviewOpen` command bypasses this custom worktree handling, which breaks D-09 ("Diff view uses existing diffview.nvim configuration"). Should use `vim.cmd("DiffviewOpenEnhanced " .. range)` or call `update_diffview_git_cmd()` before `DiffviewOpen`.
- **[MEDIUM] SHA format validation not implemented**: Threat T-04-05 proposes validating SHAs as 7-40 hex chars, but the implementation plan in diff.lua does not include this validation. The `open_diff` function passes SHAs directly to `vim.cmd`. Malformed SHAs could cause unexpected git behavior.
- **[LOW] Range order matters**: `sha1..sha2` is directional — if user selects sha2 then sha1, the diff will be reversed. Plans don't address whether order in multi-select matches commit chronological order (fzf-lua returns selection order, not sorted order). This could confuse users.
- **[LOW] No diffview close handling**: If diffview is already open, calling `DiffviewOpen` again may produce unexpected behavior. Should check and close existing diffview first, or leverage diffview's own state management.

### Suggestions

1. Change requirement header to `[CDRV-01, CDRV-02]` (align with Phase 4 scope), move full diff navigation details to Phase 6 plan
2. Use `DiffviewOpenEnhanced` instead of `DiffviewOpen` to preserve worktree support
3. Add SHA format validation: `sha:match("^%x%x%x%x%x%x%x+$")` before passing to vim.cmd
4. Clarify selection order semantics (chronological vs user-selection order)

---

## Plan 03 Review (init.lua + ai/init.lua integration)

### Strengths

- **Clear module wiring**: Full data flow (git → display → selection → diff) in a single `on_select` callback
- **Safe AI module integration**: Using `pcall` to require `commit_picker` prevents breaking AI setup
- **Bilingual notifications**: Matches project convention
- **Follows existing patterns**: `vim.keymap.set`, `vim.api.nvim_create_user_command`, opts table — consistent with `ai/provider_manager/init.lua`

### Concerns

- **[HIGH] `<leader>gd` keymap conflicts with existing convention**: The `<leader>k` prefix is reserved for AI-related commands (line 29 of `lua/ai/init.lua`). Provider Manager uses `<leader>kp`. Placing commit picker at `<leader>gd` (git diff prefix) is inconsistent with the project's `<leader>k` convention for AI module features. Since commit_picker is part of the AI module ecosystem, it should use `<leader>kc` (commit) or similar under the `<leader>k` prefix. Alternatively, if `<leader>g` is the git namespace, this should be outside the AI module entirely and registered separately.
- **[MEDIUM] Fallback info notification only shown when `ahead == 0`**: In `M.open()`, the info notification "没有未推送的提交" is only shown when `ab.ahead == 0`. But `get_ahead_behind()` might fail (pcall), and if it succeeds with `ahead > 0` but `get_unpushed` returned empty (e.g., remote ref issue), the silence is confusing. The notification logic should always show the info message when fallback triggers, regardless of ahead count.
- **[MEDIUM] Eager requires at module top**: Plan loads all 4 submodules (`Git`, `Display`, `Selection`, `Diff`) at the top of `init.lua`. If any submodule has a missing dependency (e.g., fzf-lua not installed), the entire module fails to load. Provider Manager pattern uses lazy `pcall` requires inside functions. Consider lazy-loading or at least wrapping in `pcall` pairs.
- **[LOW] No completion for :AICommitPicker**: Provider Manager commands have `complete = provider_complet`. Adding commit picker command completion (e.g., `--count N`, `--base <sha>`) would be nice even if these are Phase 5 features — at least stub them.
- **[LOW] ai/init.lua insertion point underspecified**: Plan says "after the existing backend adapter setup and before setup_commands and setup_keymaps." Looking at `lua/ai/init.lua`, the `setup()` function has: backend loading → SkillStudio → Provider Manager. The correct insertion point is after Provider Manager setup (line 209), before the `return M`. Should reference specific line numbers.

### Suggestions

1. Reconsider keymap placement: use `<leader>kc` under AI namespace, or clarify that commit picker is a standalone git tool (not AI-related)
2. Always show fallback notification when unpushed returns empty
3. Use lazy `pcall` requires for submodules instead of eager loading
4. Specify exact line in `ai/init.lua` for insertion (after line 209)

---

## Plan Dependency Analysis

### Dependencies Graph

```
04-01 (git.lua, display.lua) → no dependencies
04-02 (selection.lua, diff.lua) → depends on 04-01
04-03 (init.lua, ai/init.lua) → depends on 04-01, 04-02
```

**Verdict: Correct ordering.** Wave 1 builds the data/UX layer, Wave 2 adds state/diff engine, Wave 3 wires everything together. No circular dependencies.

### Missing Prerequisites

- **[MEDIUM] fzf-lua availability check not in Plan 01**: Plan 01 assumes fzf-lua is installed (it is per STACK.md) but does not add a `pcall(require, "fzf-lua")` guard in `display.lua`. The provider_manager/picker.lua has this guard (line 19-22). Should mirror this pattern for consistency.
- **[LOW] diffview.nvim lazy-load behavior**: diffview.nvim is configured with `cmd` lazy-loading. Calling `require("diffview")` in diff.lua may trigger the plugin load. This is fine but worth noting — if diffview takes time to initialize, the picker→diff transition may feel slow.

### Cross-Plan Interface Compatibility

- **Interface match**: Plan 01 exports `get_unpushed()` returning `{sha, short_sha, subject, date, refs}`; Plan 02 consumes SHAs only; Plan 03 wires both. No interface mismatch.
- **Potential issue**: Plan 01's `display.lua` passes `selected_shas` to `on_select`, which Plan 03 uses as `selected_shas` input to `Selection.set_selected()`. The SHA parsing from display strings (with ANSI codes stripped) in Plan 01 must produce clean 7-40 hex strings that Plan 02's `diff.lua` can pass to `vim.cmd` safely.

---

## Completeness Assessment

### ROADMAP Success Criteria Coverage

| Criteria | Phase 4 from ROADMAP | Covered By | Status |
|----------|----------------------|------------|--------|
| User can open floating window commit picker | CDRV-01 | Plan 01 (display.lua) + Plan 03 (init.lua) | ✓ Covered |
| Picker defaults to unpushed commits | CDRV-02 | Plan 01 (git.lua) + Plan 03 (open()) | ✓ Covered |

**Note:** Phase 6 requirements (CDRV-05, CDRV-06) are also implemented across Plans 02-03, creating scope duplication. The plans over-deliver but this is not a completeness gap — rather a scope alignment issue.

### CONTEXT.md Decision Coverage

| Decision | Covered By | Status |
|----------|------------|--------|
| D-01: fzf-lua picker | Plan 01 display.lua | ✓ |
| D-02: origin/HEAD..HEAD default | Plan 01 get_unpushed | ✓ |
| D-03: single vs two-commit diff | Plan 02 diff.lua | ✓ (Phase 6 scope) |
| D-04: commit format | Plan 01 display.lua | ✓ |
| D-05: colored short SHA | Plan 01 display.lua | ⚠ (ANSI approach questionable) |
| D-06: diffview.nvim | Plan 02 diff.lua | ✓ |
| D-07: current tab | Plan 02 diff.lua | ✓ |
| D-08: sha^..sha / sha1..sha2 | Plan 02 diff.lua | ✓ |
| D-09: existing diffview config | Plan 02 diff.lua | ⚠ (not using Enhanced) |
| D-10: single-select default | Plan 01 display.lua | ✓ |
| D-11: multi-select ctrl+tab | Plan 01 display.lua | ⚠ (API incorrect) |
| D-12: 60%w, 40%h | Plan 01 display.lua | ✓ |
| D-13: <CR> opens diff | Plan 03 on_select | ✓ |
| D-14: <Esc> closes picker | Plan 01 display.lua (fzf-lua default) | ✓ |
| D-15: fallback to 20 commits | Plan 01 git.lua + Plan 03 open() | ✓ |
| D-16: error notification with output | Plan 01 git.lua | ✓ |
| D-17: diffview unavailable warning | Plan 02 diff.lua | ✓ |

---

## Risk Assessment

### High Risks

1. **Scope duplication with Phase 6**: Plans 02-03 implement CDRV-05/06 which are Phase 6 requirements. This creates confusion about what Phase 4 actually delivers vs. Phase 6, and risks double-implementation if Phase 6 plans repeat the same diff logic.
2. **fzf-lua multi-select API mismatch**: The `--multi` flag approach may not work as expected with fzf-lua's action system. If multi-select doesn't work, users lose the range diff capability entirely.
3. **Keymap namespace conflict**: `<leader>gd` breaks the project's `<leader>k` AI convention, causing inconsistency in the user experience.

### Medium Risks

4. **DiffviewEnhanced not used**: Worktree support will not function for commit diffs, which the project explicitly supports in git.lua.
5. **No SHA validation in diff.lua**: Injection risk from malformed SHAs (mitigated by threat registration but not implemented).
6. **ANSI escape codes may not render in fzf-lua**: Visual degradation of the commit picker display.
7. **Eager module loading**: If any submodule fails, entire module is unusable.

### Low Risks

8. **detached HEAD state**: Edge case where `origin/HEAD..HEAD` fails.
9. **Diffview already open**: No graceful handling of re-opening.
10. **Selection order semantics**: User may not understand diff direction in two-commit mode.

---

## Consensus with Self

### Agreed Strengths
- Clean 3-wave architecture with correct dependency ordering
- Good error handling patterns matching project conventions
- Comprehensive threat modeling with mitigations
- Follows established patterns (pcall, vim.notify, local M = {})

### Agreed Concerns
- Scope misalignment with Phase 6 requirements (CDRV-05, CDRV-06)
- fzf-lua multi-select API usage needs correction
- Missing DiffviewOpenEnhanced for worktree support
- Keymap namespace inconsistency

### Divergent Views
- None — single reviewer assessment.

---

## Recommendations (Priority Order)

1. **Fix scope alignment**: Move CDRV-05/CDRV-06 implementation notes to Phase 6 plans. In Phase 4, implement the diff as an "enabler" (the infrastructure) without claiming the user-facing navigation experience as Phase 4's deliverable. Change Plan 02 header to `requirements: [CDRV-01, CDRV-02]` and add a note: "diff.lua provides infrastructure for CDRV-05/CDRV-06 implemented in Phase 6."

2. **Fix fzf-lua multi-select**: Replace `fzf_opts = { ["--multi"] = "" }` with fzf-lua's native multi-select API. See `:h fzf-lua.fzf_exec` or inspect existing provider_manager/picker.lua for the correct action pattern.

3. **Use DiffviewOpenEnhanced**: Change `vim.cmd("DiffviewOpen " .. range)` to `vim.cmd("DiffviewOpenEnhanced " .. range)` to preserve worktree support.

4. **Add SHA validation**: In `diff.lua`, validate SHA format before passing to `vim.cmd`:
   ```lua
   local function is_valid_sha(sha)
     return sha and sha:match("^%x%x%x%x%x%x%x+$")
   end
   ```

5. **Align keymap with AI convention**: Change `<leader>gd` to `<leader>kc` (commit) or `<leader>kC`. Update the key group in `ai/init.lua` if needed. Or, if commit picker is meant to be a standalone tool (not AI-related), register it outside the AI module with a `<leader>g` prefix and own setup function.

6. **Lazy-load submodules**: Wrap requires in `init.lua` with `pcall` at the function level, not module level.

7. **Add fzf-lua guard in display.lua**: Mirror provider_manager pattern:
   ```lua
   local ok, fzf = pcall(require, "fzf-lua")
   if not ok then
     vim.notify("fzf-lua not installed", vim.log.levels.ERROR)
     return
   end
   ```
