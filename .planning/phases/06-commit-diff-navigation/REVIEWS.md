# Phase 06: Commit Diff Navigation — Plan Review

**Reviewed:** 2026-04-26
**Plans Reviewed:** 06-01-PLAN.md (Wave 1), 06-02-PLAN.md (Wave 2)
**Context:** 06-CONTEXT.md (D-18~D-38), ROADMAP.md (CDRV-05, CDRV-06)
**Reviewer:** Plan Review Specialist

---

## Summary

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Completeness | MEDIUM — Gap found | Both plans cover CDRV-05 (single commit) but CDRV-06 (two-commit range) navigation is underspecified |
| Correctness | MEDIUM — Issues found | Keymap conflict with existing `<leader>kn`; navigation logic contradicts D-29 |
| Dependencies | HIGH — OK | Wave 2 correctly depends on Wave 1; all imports valid |
| Quality | MEDIUM — Gaps | Tasks well-scoped but verification inadequate; no test plan |
| Risks | MEDIUM — Notable | Diffview close+reopen race condition; commit list staleness |
| Consistency | MEDIUM — Mixed | Follows most conventions; conflicts with ai/init.lua keymap pattern |
| Scope Creep | HIGH — OK | No v2 feature creep detected |

---

## Detailed Findings

### 1. Completeness

#### C-01: CDRV-06 (two-commit range nav) is underspecified — MEDIUM

**File:** 06-01-PLAN.md, Task 1

**Finding:** CDRV-06 states "用户选择两个 Commit 时，显示这两个 Commit 之间的 Diff". The plans implement navigation as cycling through *individual* commits (sha^..sha). D-29 in CONTEXT.md explicitly says: *"For two-commit mode: fixed range (sha1..sha2), navigation not applicable"*. 

This creates a logic gap: if a user opens a range diff (sha1..sha2) via selecting two commits from the picker, what should `<leader>kn` / `<leader>kN` do? The plans only implement sha^..sha cycling. D-29 says navigation is "not applicable" for range mode, but the plans don't implement any behavior for this case — the navigation module will attempt to cycle regardless, producing incorrect single-commit diffs instead of the expected range.

**Recommendation:** The navigation module should detect view mode. If the current selection is 2 SHAs (range mode), cycling should be disabled with an informative notification: "范围模式下不支持逐条导航". This should be explicit in the task.

---

#### C-02: No test plan for either wave — MEDIUM

**File:** Both 06-01-PLAN.md and 06-02-PLAN.md

**Finding:** Neither plan includes a test file creation task. Phase 5 plans included plenary.nvim specs; Phase 4 also had tests. The plans contain `<verification>` sections but only use headless Lua load checks (syntax-level), not functional unit tests.

**Recommendation:** Add a test task for `tests/commit_picker/navigation_spec.lua` covering: position advancement, boundary conditions, SHA validation, empty commit list handling, and selection update on cycle.

---

#### C-03: `nav_status` mentioned in ROADMAP but not in plans — LOW

**File:** ROADMAP.md line 162

**Finding:** ROADMAP.md describes Plan 02 as "Integration + status (keymap registration, nav_status indicator)". Neither plan mentions implementing a `nav_status` function or lualine component. D-34 in CONTEXT.md mentions: *"If lualine has a commit_picker component, show current commit position there"*.

**Recommendation:** Either add a simple `M.nav_status()` function returning a string like `"3/93"` for potential lualine integration, or update ROADMAP.md to remove "status" from the plan description.

---

### 2. Correctness

#### H-01: Critical keymap conflict — `<leader>kn` already bound in ai/init.lua — HIGH

**File:** 06-02-PLAN.md, Task 1 step 1; compared against `lua/ai/init.lua:102`

**Finding:** `lua/ai/init.lua` line 102 already registers `<leader>kn` for `call("chat_new")` — "AI New Chat":

```lua
{ "<leader>kn", mode = "n", fn = call("chat_new"), desc = "AI New Chat", icon = "✨" },
```

Plan 02 proposes to add a *second* `<leader>kn` entry in the same `keys` table for "AI Next Commit". In Lua, duplicate table keys silently overwrite — the later entry would replace the chat_new binding. This breaks an existing AI core feature.

**Impact:** User loses `<leader>kn` for AI New Chat — this is a core interaction keymap per the ai module design.

**Recommendation:** Choose a non-conflicting keymap. Options:
- `<leader>kj` (j = jump/jun, next commit) — needs conflict check
- `<leader>k>` / `<leader>k<` — intuitive forward/back
- `<leader>k<Down>` / `<leader>k<Up>` — uses arrow keys
- `<leader>k.` / `<leader>k,` — period/comma for next/prev

**Action Required:** Verify candidate keymaps against the full `keys` table in ai/init.lua before finalizing.

---

#### C-04: Navigation cycling logic defaults to single-commit mode even for range selection — MEDIUM

**File:** 06-01-PLAN.md, Task 1 step 3-4

**Finding:** Both `cycle_next()` and `cycle_prev()` are described as opening `DiffviewOpenEnhanced sha^..sha`. This hardcodes single-commit mode. However, D-19 says *"Navigation keeps the same commit list from the picker session"*, implying it should respect the original selection mode (1 SHA or 2 SHAs).

The plan does not distinguish between:
- User selected 1 SHA → should cycle sha^..sha (correct)
- User selected 2 SHAs → should cycle as a fixed range, not decompose to single commits (not handled)

**Recommendation:** The navigation module should store `view_mode = "single" | "range"` and use it to determine the diff format during cycling.

---

#### C-05: `load_commits()` logic mismatch with D-30 — LOW

**File:** 06-01-PLAN.md, Task 1 step 2

**Finding:** D-30 says *"Store current commit list + current index in selection.lua (extend existing module)"*. Plan 01 instead creates a dedicated `navigation.lua` with its own module-local `commit_list`. This is a valid architectural choice and arguably cleaner than extending selection.lua, but it contradicts the locked decision D-30.

**Recommendation:** Either update D-30 to reflect the module-per-concern approach (navigation.lua owns its state), or implement as selection.lua extension per D-30. Given that navigation.lua is cleaner, recommend updating the decision rather than changing the plan.

---

### 3. Dependencies

#### D-01: Wave 2 dependency chain is correct — INFO

**File:** 06-02-PLAN.md header: `depends_on: ["06-01"]`

**Finding:** Wave 2 correctly declares dependency on Wave 1. The imports in Wave 2 (Navigation.cycle_next, Navigation.is_loaded, etc.) depend on exports defined in Wave 1.

**Status:** OK.

---

#### D-02: `Nav.load_commits()` auto-load in ai/init.lua has a variable scope bug — MEDIUM

**File:** 06-02-PLAN.md, Task 1 step 1, keymap callback for `<leader>kn`

**Finding:** The proposed callback code:
```lua
local ok2, CP = pcall(require, "commit_picker.init")
if ok2 then
  local Git = require("commit_picker.git")
  Commits = Git.get_commits_for_mode()  -- BUG: `Commits` is a global (no `local`)
```

`Commits` is assigned without `local`, creating a global variable. This is a Lua anti-per the AGENTS.md coding standards.

**Recommendation:** Change to `local commits = Git.get_commits_for_mode()`.

---

#### D-03: `Nav.cycle_next()` called during auto-load — questionable — LOW

**File:** 06-02-PLAN.md, Task 1 step 1, `<leader>kn` auto-load path

**Finding:** When the user presses `<leader>kn` without having opened the picker first, the callback auto-loads commits then calls `Nav.cycle_next()`. But `cycle_next()` is designed as "move to next position" — if the user hasn't viewed the *current* commit yet, calling `cycle_next()` on first load means they skip the first commit (position 1) and go directly to position 2.

**Recommendation:** On first load, the behavior should be: load commits, set position to 1, open the diff for the *current* (first) commit. NOT cycle to next. The auto-load path should probably call a new function like `Nav.open_first()` or reuse `M.load_commits()` + `Diff.open_diff({first_sha})`.

---

### 4. Quality

#### Q-01: Verification inadequate — no functional tests — MEDIUM

**File:** Both plans, `<verify>` sections

**Finding:** The only verification is:
```
nvim --headless -c "lua require('commit_picker.navigation')" -c "q" 2>&1 | grep -i error || echo "OK: module loads"
```

This only confirms the module parses without syntax errors. It does not verify:
- cycle_next advances position correctly
- Boundary conditions at position 1 and last position
- SHA validation prevents invalid input
- Diffview close+reopen works
- Selection is updated correctly
- Notification format matches D-33

**Recommendation:** Add a plenary.nvim test file or at minimum more sophisticated headless verification that exercises the cycling functions with mock data.

---

#### Q-02: Task scoping is reasonable but could be finer-grained — INFO

**Finding:** Wave 1 has 1 task (create navigation.lua with 7 exports). Wave 2 has 1 task (register keymaps + integrate). Each task is well-defined with clear inputs/outputs, but splitting Wave 1 into sub-tasks (state management, cycling logic, diffview integration) would improve parallel execution and failure isolation.

**Status:** Acceptable for a single-module phase.

---

#### Q-03: Threat model is present but lightweight — LOW

**File:** Both plans, `<threat_model>` sections

**Finding:** Each plan has a small STRIDE table with 2-3 entries. This is adequate for a local IDE feature. T-06-01 correctly identifies SHA spoofing and plans to validate via `is_valid_sha()`. No high-severity threats identified.

**Status:** Acceptable.

---

### 5. Risks

#### R-01: Diffview close+reopen race condition — MEDIUM

**File:** 06-01-PLAN.md, Task 1 steps 3-4 (D-27 research)

**Finding:** Plans correctly identify that diffview.nvim has no in-place range update API and use close+reopen. However, `pcall(vim.cmd, "DiffviewClose")` followed immediately by `vim.cmd("DiffviewOpenEnhanced ...")` may have a race condition:

1. `DiffviewClose` may return before diffview has fully cleaned up its buffers
2. `DiffviewOpenEnhanced` may then fail or create a corrupted view
3. This is particularly likely when cycling rapidly (user holding `<leader>kn`)

**Recommendation:** Add a small `vim.defer_fn()` delay (e.g., 50-100ms) between close and reopen, OR use a synchronization mechanism like checking that no diffview buffers remain before reopening. At minimum, wrap the reopen in its own pcall and show an error notification if it fails.

---

#### R-02: Commit list staleness during navigation — LOW

**File:** D-19 context

**Finding:** The commit list is loaded once via `Git.get_commits_for_mode()`. If a new commit is added (or the branch is rebased) while the user is navigating, the list becomes stale. Navigation would operate on SHAs that may no longer exist or have moved.

**Recommendation:** This is acceptable for v1. The mitigation is already in place: SHA validation via `is_valid_sha()` before passing to DiffviewOpenEnhanced. If diffview fails with an invalid SHA, the error will be caught by the pcall in DiffviewOpenEnhanced.

---

#### R-03: Missing `close_if_open()` pattern — LOW

**File:** 06-01-PLAN.md, Task 1 notes

**Finding:** The plan mentions using `pcall(vim.cmd, "DiffviewClose")` but the existing `diff.lua` has a specific pattern for checking if diffview is open (lines 42-53 in diff.lua — iterating `nvim_list_bufs()` checking for "diffview" in bufname). For cycling, we *want* to close if open, but we should also handle the case where diffview is NOT open gracefully (which pcall covers). The plan is correct here.

**Status:** Acceptable.

---

### 6. Consistency

#### S-01: Module pattern follows AGENTS.md conventions — INFO

**Finding:** `local M = {}`, `function M.xxx()`, `return M` — all consistent with AGENTS.md. 2-space indent, double quotes, pcall for optional modules. The plan correctly references these patterns.

**Status:** OK.

---

#### S-02: Chinese notification messages follow project convention — INFO

**Finding:** Plans use Chinese messages like "已是最后一条提交", "没有可导航的提交" — consistent with the Chinese message convention established in Phase 4 (diff.lua: "请先选择 commit", "无效的 SHA 格式").

**Status:** OK.

---

#### S-03: `keys` table pattern in ai/init.lua is consistent with Phase 4/5 — INFO

**Finding:** The plan's proposed `<leader>kC`-adjacent keymap registration matches the existing pattern used for Commit Picker (Phase 4) and Provider Manager (Phase 1).

**Status:** OK — aside from the `<leader>kn` conflict (H-01).

---

#### S-04: Plan 02 modifies `lua/ai/init.lua` keys table directly — inconsistent with Phase 4 approach — LOW

**Finding:** Phase 4 added `<leader>kC` directly to the `keys` table in ai/init.lua. Phase 6 plans do the same. However, a cleaner approach for future scalability would be to add a `setup_navigation_keys()` function in navigation.lua that ai/init.lua calls, keeping keymap logic localized. This is an architectural preference, not a bug.

**Status:** Acceptable for v1.

---

### 7. Scope Creep

#### SC-01: No v2 feature creep detected — INFO

**Finding:** Plans stay strictly within CDRV-05/CDRV-06 scope. No inline comments (CDRV-07), no review summaries (CDRV-08~11), no commit search/filtering. Deferred ideas in CONTEXT.md are correctly excluded.

**Status:** OK. Plans are properly scoped.

---

## Decision Alignment Summary

| Decision | Plan Compliance | Note |
|----------|----------------|-------|
| D-18: Next/prev via keymaps | OK | Implemented |
| D-19: Same commit list from picker | OK | load_commits() stores list |
| D-20: End-of-list notification | OK | "已是最后一条提交" / "已是第一条提交" |
| D-21: No wrap-around | OK | Stops at boundaries |
| D-22: `<leader>kn` = next | CONFLICT | Conflicts with existing AI New Chat |
| D-23: `<leader>kN` = prev | Check | Must avoid conflict with `<leader>kn` |
| D-24: Keymaps active when diffview active | Partial | Plan allows cycling even after diffview closed |
| D-25: No conflict with existing keymaps | FAIL | `<leader>kn` is bound to chat_new |
| D-26: Close+reopen for navigation | OK | Matches D-27 research findings |
| D-27: Investigate programmatic range | OK | Plans use close+reopen |
| D-28: Single commit = sha^..sha | OK | Implemented |
| D-29: Two-commit mode = no navigation | NOT IMPLEMENTED | Plans don't detect range mode to disable cycling |
| D-30: Store in selection.lua | DEVIATION | Plans use navigation.lua (cleaner, but contradicts D-30) |
| D-33: Show vim.notify with position | OK | Matches format |
| D-34: Lualine component | DEFERRED | Not implemented (acceptable) |
| D-35: Chinese message convention | OK | Consistent |
| D-36: Uses same commit list as picker | OK | Implemented |
| D-37: since_base navigation | OK | load_commits() calls get_commits_for_mode() |
| D-38: last_n navigation | OK | load_commits() calls get_commits_for_mode() |

---

## Priority Actions Before Execution

### Must Fix (HIGH)

1. **H-01 — Keymap conflict:** `<leader>kn` is already bound to "AI New Chat" in ai/init.lua:102. Must choose a different keymap for next/prev navigation before executing.

### Should Fix (MEDIUM)

2. **C-01/C-04 — Range mode detection:** Navigation should detect when the selection is 2 SHAs (range mode) and disable cycling with an informative notification, per D-29.
3. **C-02 — Add test plan:** Create `tests/commit_picker/navigation_spec.lua` with functional tests.
4. **R-01 — Race condition mitigation:** Add defer or retry logic between DiffviewClose and DiffviewOpenEnhanced during cycling.
5. **D-02 — Global variable bug:** Fix `Commits = Git.get_commits_for_mode()` to `local commits` in the auto-load callback.
6. **D-03 — Auto-load behavior:** On first load via `<leader>kn`, should open the current (first) commit, not cycle to the second.
7. **C-03 — nav_status:** Either implement or remove "status" from ROADMAP.md plan description.

### Optional (LOW)

8. **C-05 — D-30 deviation:** Update D-30 to document the navigation.lua module-per-concern approach.
9. **Q-02 — Finer task granularity:** Split Wave 1 into sub-tasks for better execution tracking.
10. **R-02 — Commit list staleness:** Acceptable for v1; document as known limitation.
11. **S-04 — Keymap localization:** Consider moving navigation keymaps to navigation.lua for cleaner separation.

---

*Review complete. 1 HIGH, 6 MEDIUM, 5 LOW/INFO findings.*
