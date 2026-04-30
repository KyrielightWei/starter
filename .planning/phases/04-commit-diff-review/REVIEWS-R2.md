---
phase: 04
review_type: round-2 (post-fix verification)
reviewer: [opencode]
reviewed_at: 2026-04-26
plans_reviewed: [04-01-PLAN.md, 04-02-PLAN.md, 04-03-PLAN.md]
previous_review: REVIEWS.md (2026-04-25)
---

# Cross-AI Plan Review Round 2 — Phase 04: Commit Diff Review

## Summary

All 7 issues from Round 1 have been addressed. Plans are significantly improved with correct APIs, proper scope alignment, and safe module loading. One residual issue remains: `<leader>kp` conflicts with Phase 1 Provider Manager's keymap. Additionally, the `ctrl-tab:toggle-all` binding is semantically incorrect for per-item multi-select. **Overall Risk: LOW** — ready for execution with minor adjustments.

---

## Previous Issues Verification

### HIGH-1: Scope creep (CDRV-05/06 removed?)
**Status: FIXED**

Plan 04-02 header now declares `requirements: [CDRV-01, CDRV-02]`. The objective section explicitly states: *"The full single-vs-two-commit navigation experience (CDRV-05, CDRV-06) will be enhanced in Phase 6."* The success_criteria section adds the note: *"diff.lua provides infrastructure for CDRV-05/CDRV-06 (Phase 6 enhancement)."* This cleanly separates Phase 4's delivery from Phase 6's scope.

### HIGH-2: fzf-lua multi-select API (actions-based pattern?)
**Status: FIXED (partial, see R2-M1 below)**

The plan now uses an `actions` table with `default` handler instead of raw fzf flags. The multi-select is configured via `fzf_opts["--bind"] = "ctrl-tab:toggle-all"`. This is a valid fzf-lua pattern and will work to enable multi-select.

### HIGH-3: Keymap `<leader>kp` (matches AI convention?)
**Status: FIXED for convention, but introduces R2-H1**

Plan 04-03 now uses `<leader>kp` under the `<leader>k` AI namespace, which correctly follows the project's AI keymap convention. However, this exact keymap is **already claimed by Phase 1 Provider Manager**. See R2-H1 below.

### MEDIUM-1: DiffviewOpenEnhanced usage
**Status: FIXED**

Plan 04-02 diff.lua now uses `pcall(vim.cmd, "DiffviewOpenEnhanced " .. range)`. This is the correct command as defined in `lua/plugins/git.lua:391`, preserving the dynamic `git_cmd` setup for worktree support.

### MEDIUM-2: SHA format validation
**Status: FIXED**

Plan 04-02 implements `is_valid_sha()` with pattern `"^%x%x%x%x%x%x%x+$"` (7-40 hex chars). All SHAs are validated in a loop before being passed to `vim.cmd`. Invalid SHAs trigger a bilingual error notification.

### MEDIUM-3: ANSI rendering
**Status: FIXED**

Plan 04-01 now explicitly states *"Do NOT embed ANSI escape codes; use fzf-lua's native highlight system instead."* The plan uses a `highlight` callback function and commits the SHA in brackets `"[sha]"` format for clean parsing. The SHA is embedded as plain text for easy regex extraction (`^%[(%x+)%]`).

### MEDIUM-4: Lazy pcall module loading
**Status: FIXED**

Plan 04-03 now wraps all submodule requires in a `get_modules()` function with individual `pcall` guards. If any submodule fails, the error is isolated and shown as a targeted notification (e.g., `"commit_picker.display module failed to load"`).

---

## New Issues (Round 2)

### R2-H1: Keymap collision with Phase 1 Provider
**Severity: HIGH**
**Affected: 04-03-PLAN.md**

Plan 04-03 registers `<leader>kp` for Commit Picker. However, Phase 1 Provider Manager already uses `<leader>kp` (visible in `lua/ai/init.lua` line 100 keymap pattern). Both cannot share the same keymap — the later registration will overwrite the earlier one (or vice versa depending on load order).

**Suggested fix:** Use `<leader>kC` (capital C for Commit) or `<leader>kd` (diff) for Commit Picker. Update both the plan and the CONTEXT.md D-10 reference. Alternatively, use `<leader>gc` under the git namespace if this feature is meant to be distinct from AI operations.

### R2-M1: `ctrl-tab:toggle-all` binding is semantically wrong
**Severity: MEDIUM**
**Affected: 04-01-PLAN.md**

The plan binds `ctrl-tab:toggle-all`, which selects **all** items in the list at once. For per-item multi-select (where users typically want to pick 1-2 specific commits), the correct binding is `ctrl-space:toggle` (or `ctrl-q:toggle-all` as a secondary option). With `toggle-all`, users cannot easily select exactly 2 commits without first selecting all and then deselecting individuals.

**Suggested fix:** Change `--bind` to:
```lua
["--bind"] = "ctrl-space:toggle,ctrl-a:toggle-all"
```
This allows individual toggling via `ctrl-space` and "select all" via `ctrl-a`.

### R2-M2: fzf-lua `preview` function may be slow for large repos
**Severity: MEDIUM**
**Affected: 04-01-PLAN.md**

The preview function uses `vim.fn.system({"git", "show", sha, "--stat"})` which blocks on every preview cursor movement. On repos with large commits (e.g., dependency updates), this can cause a 1-3s lag as the user navigates the picker.

**Suggested fix:** Add `--stat` with a `--max-count=1` limit, or use `--shortstat` for a lighter preview:
```lua
return vim.fn.system({"git", "show", "--shortstat", "--format=%s", sha})
```

### R2-M3: 04-03 PLAN keymap says "per D-10" but D-10 is about single-select
**Severity: MEDIUM (minor)**
**Affected: 04-03-PLAN.md**

The plan's behavior section states: *"M.setup() registers :AICommitPicker command and <leader>kp keymap per D-10"*. However, D-10 in CONTEXT.md is about *"Single-select mode by default"*, not about the keymap. This is a documentation cross-reference error (harmless but confusing for the executor).

---

## Inter-Plan Consistency

### Dependency chain: CONSISTENT
- 04-01: no dependencies ✓
- 04-02: depends on 04-01 ✓
- 04-03: depends on 04-01, 04-02 ✓

### Interface alignment: CONSISTENT
- `Git.get_unpushed()` → returns `{sha, short_sha, subject, date, refs}[]` → consumed by `Display.show_picker()` and `init.open()` ✓
- `Display.on_select(selected_shas)` → SHA array → consumed by `Selection.set_selected()` → `Diff.open_diff()` ✓
- All SHAs flow as plain 7-40 hex strings; ANSI stripping not needed per the new format ✓

### Requirement coverage: CONSISTENT
All three plans declare `requirements: [CDRV-01, CDRV-02]`, matching Phase 4's scope in ROADMAP.md.

### Cross-reference to CONTEXT.md decisions: ALL COVERED
| Decision | Status |
|----------|--------|
| D-01 through D-17 | All covered across the 3 plans |

---

## Verification Steps Adequacy

### Plan 01 verification: ADEQUATE
- Headless tests check module load and function type
- Could add a test verifying `get_commit_list` returns structured objects, but the done-criteria cover it
- `io.popen` is acceptable here (Phase 2's async suggestion was noted but is nice-to-have, not required)

### Plan 02 verification: ADEQUATE
- Headless test validates `open_diff` function exists
- Done-criteria explicitly check SHA validation, DiffviewOpenEnhanced usage, and fallback behavior
- Could benefit from an integration test mocking `vim.cmd`, but acceptable for plan-level verification

### Plan 03 verification: ADEQUATE
- Headless test validates init.lua loads and exports
- End-to-end verification items (#9, #10) cover the full flow
- ai/init.lua integration test (`require('ai').setup()` with no errors) is appropriate

---

## Completeness Assessment

### ROADMAP Success Criteria
| Criteria | Covered By | Status |
|----------|------------|--------|
| Floating window commit picker (CDRV-01) | Plan 01 display.lua + Plan 03 init.lua | Covered |
| Default to unpushed commits (CDRV-02) | Plan 01 git.lua + Plan 03 open() | Covered |

### Context Decision Coverage: 17/17 (D-01 through D-17)
All decisions from 04-CONTEXT.md are addressed with appropriate implementations or explicit notes.

---

## Risk Assessment

### High Risks
1. **Keymap collision (R2-H1):** `<leader>kp` already used by Phase 1. Would cause one feature to silently override the other.

### Medium Risks
2. **Multi-select binding (R2-M1):** `ctrl-tab:toggle-all` is not the right UX for per-item selection.
3. **Preview performance (R2-M2):** Synchronous `git show` on every cursor movement may feel sluggish.
4. **Cross-reference error (R2-M3):** Minor documentation inconsistency in Plan 03.

### Low Risks
5. **No keymap conflict detection in tests:** No verification step checks for duplicate keymap registrations.
6. **diffview already-open state:** If diffview is already open, calling `DiffviewOpenEnhanced` again may show a warning. Not critical — diffview handles this gracefully.

---

## Recommendations (Priority Order)

1. **Fix keymap collision (R2-H1):** Change `<leader>kp` to `<leader>kC` or `<leader>kd`. This is a blocking issue — two features sharing one keymap will break one of them.

2. **Fix multi-select binding (R2-M1):** Replace `ctrl-tab:toggle-all` with `ctrl-space:toggle` for per-item selection, keeping `ctrl-a:toggle-all` as a convenience:
   ```lua
   ["--bind"] = "ctrl-space:toggle,ctrl-a:toggle-all"
   ```

3. **Lighten preview output (R2-M2):** Use `--shortstat` instead of `--stat` for faster preview rendering.

4. **Fix cross-reference in Plan 03 (R2-M3):** Change `"per D-10"` to the correct context reference (D-10 is about single-select mode, not keymap registration).

---

## Round 2 Verdict

**PLANS CONDITIONALLY APPROVED** — All Round 1 issues are fixed. The remaining issues (R2-H1 keymap collision, R2-M1 multi-select binding) are straightforward fixes. Plans should be updated with these two changes before execution.

Round 1 issues closure summary:
| Issue | Severity | Status |
|-------|----------|--------|
| HIGH-1 Scope creep | HIGH | FIXED |
| HIGH-2 fzf-lua API | HIGH | FIXED |
| HIGH-3 Keymap convention | HIGH | FIXED (new collision introduced) |
| MEDIUM-1 DiffviewOpenEnhanced | MEDIUM | FIXED |
| MEDIUM-2 SHA validation | MEDIUM | FIXED |
| MEDIUM-3 ANSI rendering | MEDIUM | FIXED |
| MEDIUM-4 Lazy loading | MEDIUM | FIXED |
| R2-H1 Keymap collision | HIGH | **OPEN** |
| R2-M1 Multi-select binding | MEDIUM | **OPEN** |
| R2-M2 Preview performance | MEDIUM | OPEN (nice-to-have) |
| R2-M3 Cross-reference | MEDIUM | OPEN (trivial) |
