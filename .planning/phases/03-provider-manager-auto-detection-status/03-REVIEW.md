---
status: issues_found
phase: 03-provider-manager-auto-detection-status
depth: deep
files_reviewed: 7
review_date: 2026-04-25
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
severity:
  critical: 1
  warning: 4
  info: 3
  total: 8
---

# Phase 03 Code Review Report

**Depth:** deep (cross-file analysis including import graphs and call chains)
**Files Reviewed:** 7
**Phase:** 03-provider-manager-auto-detection-status

## Files in Scope

| File | Type | Lines |
|------|------|-------|
| `lua/ai/provider_manager/status.lua` | Created | 74 |
| `lua/ai/provider_manager/ui_util.lua` | Modified | +58 lines |
| `lua/ai/provider_manager/picker.lua` | Modified | +12 lines |
| `lua/ai/provider_manager/init.lua` | Modified | +5 lines |
| `lua/ai/model_switch.lua` | Modified | +19 lines |
| `tests/ai/provider_manager/status_spec.lua` | Created | 317 |
| `tests/ai/provider_manager/ui_util_spec.lua` | Created | 201 |

---

## CRITICAL — Must Fix Before Ship

### CR-01: model_switch.lua — `require` inside nested fzf callback causes repeated module load

**File:** `lua/ai/model_switch.lua:84`
**Severity:** Critical
**Category:** Performance / Potential Memory Leak

```lua
-- Line 84: Inside fzf.fzf_exec action callback (fires on EVERY model selection)
local Status = require("ai.provider_manager.status")
Status.trigger_async_check(provider, model, function(result)
```

**Issue:** The `require("ai.provider_manager.status")` is placed inside the fzf `default` action callback, which fires every time a user selects a model. While Lua's `require` caches modules in `package.loaded`, the `status.lua` module's top-level imports (cache, detector, state) execute during first load, and the `state.lua` module runs `setup_backward_compat()` which sets `_G.AI_MODEL` metatable. If for any reason the cache is cleared (e.g., test harness, hot-reload), the metatable would be re-applied, potentially causing duplicate deprecation warnings or state corruption.

More importantly, this pattern is inconsistent with the existing codebase where `require` is done at module level. The `status.lua` import should be at the top of `model_switch.lua`.

**Fix:** Move `local Status = require("ai.provider_manager.status")` to the top of `model_switch.lua` with the other requires (lines 5-7).

**Impact when unfixed:** Low in production (require is cached), but represents a code quality anti-pattern and could cause issues if `package.loaded` is manipulated (e.g., during hot-reload or testing).

---

## WARNING — Should Fix

### WR-01: status.lua — `trigger_async_check` stale guard runs inside `vim.schedule_wrap`, but `State.get()` returns a copy — race condition possible

**File:** `lua/ai/provider_manager/status.lua:50-54`
**Severity:** Warning
**Category:** Race Condition

```lua
Detector.check_provider_model(provider, model, vim.schedule_wrap(function(result)
  local current = State.get()
  if not current or current.provider ~= captured_provider or current.model ~= captured_model then
    return
  end
```

**Issue:** `State.get()` returns a `{provider, model}` copy (see `state.lua:24-27`). The stale guard compares against captured values from the original call. The race window: if user switches model between the time `Detector.check_provider_model` fires and when the schedule_wrap callback executes, the stale guard will correctly discard. However, if user switches model rapidly and multiple checks are in-flight, each callback's stale guard uses its own captured values — which is correct behavior.

The real concern: `State.get()` returns a shallow copy. If `ai.state` internals change (unlikely), the comparison logic could break. The guard is functionally correct with current implementation but should have a comment noting the dependency on `State.get()` returning a simple `{provider, model}` table.

**Current risk:** Low — implementation is correct, but coupling to State.get()'s return shape is implicit.

### WR-02: ui_util.lua — ASCII fallbacks defined but never used

**File:** `lua/ai/provider_manager/ui_util.lua:32-36`
**Severity:** Warning
**Category:** Dead Code

The `fallback_available`, `fallback_unavailable`, `fallback_timeout`, `fallback_error`, `fallback_unchecked` icons are defined in the ICONS table but `get_status_icon()` returns only the Unicode icons. The ASCII fallbacks are never referenced.

**Impact:** These icons are in the table but inaccessible through the current API. Either they should be used (e.g., detect if font supports Unicode, fall back if not) or removed to avoid confusion.

**Recommendation:** Either:
1. Add a `get_status_icon(status, use_ascii)` parameter for explicit fallback selection, or
2. Add automatic fallback detection (check if Neovim's GUI font supports Unicode), or
3. Remove the fallback entries and document that Unicode is required (acceptable for Neovim users)

### WR-03: picker.lua — Status read at picker-open time means stale display during async detection

**File:** `lua/ai/provider_manager/picker.lua:40, 157`
**Severity:** Warning
**Category:** UX Staleness

Status is read once when picker opens. If async detection completes while picker is still open (e.g., user opened picker right after switching model), the displayed status won't update until picker is closed and reopened.

**Note:** This is a known and accepted tradeoff per the PLAN.md (addresses C-05, C-13). fzf-lua doesn't support reactive list updates. Not a code defect, but worth documenting.

### WR-04: status_spec.lua — Test stub for `vim.schedule_wrap` mutates Neovim global, risks test pollution

**File:** `tests/ai/provider_manager/status_spec.lua:75-81`
**Severity:** Warning
**Category:** Test Quality

```lua
local orig_schedule_wrap = vim.schedule_wrap
vim.schedule_wrap = function(fn)
  _schedule_wrap_calls = _schedule_wrap_calls + 1
  table.insert(_schedule_wrap_args, fn)
  return orig_schedule_wrap(fn)
end
```

The test wraps `vim.schedule_wrap` globally and increments call counters. However, `reset_state()` in `before_each` does NOT restore `vim.schedule_wrap` to the original. If any other test (or future test file) also wraps this global, tests could accumulate counters or the wrapping could be inconsistent.

**Fix:** Add `vim.schedule_wrap = orig_schedule_wrap` to `reset_state()`.

---

## INFO — Nice to Have

### IF-01: model_switch.lua — Auto-detection `require` placed after model selection, callback may fire before `require` completes

**File:** `lua/ai/model_switch.lua:84-100`
**Severity:** Info
**Category:** Code Organization

The `Status.trigger_async_check` call and its callback are placed BEFORE the `if callback then callback(...) end` block. This is correct per D-01 (detection is async, callback fires immediately). However, the notification formatting logic (lines 87-94) is a good candidate for extraction into a helper function like `Status.format_warning(provider, model, result)` to avoid bloating model_switch.lua.

### IF-02: ui_util_spec.lua — Comprehensive but missing edge case for `format_provider_display` with long endpoint truncation + status

**File:** `tests/ai/provider_manager/ui_util_spec.lua`
**Severity:** Info
**Category:** Test Coverage

No test case verifies that a provider with a >40 character endpoint that ALSO has a status icon renders correctly (i.e., icon prepended to the truncated base string). This is a low-risk combination since both features are independent string operations.

### IF-03: init.lua — Status require is at top but detector's detection callbacks don't use vim.schedule_wrap

**File:** `lua/ai/provider_manager/init.lua:68-75`
**Severity:** Info
**Category:** Consistency

The `cmd_check_provider` function at line 69 calls `Detector.check_provider_model` with a plain callback (not wrapped in `vim.schedule_wrap`). This is pre-existing code (not from Phase 3), but it's worth noting that `Detector.check_provider_model` internally may invoke the callback synchronously (cache hit via `vim.schedule`) or asynchronously (HTTP response). The callback in init.lua calls `Results.show_single_result` which may interact with the UI — this could benefit from `vim.schedule_wrap` for consistency with the new Phase 3 safety standards.

---

## Import Graph Analysis

```
model_switch.lua
  └── ai.provider_manager.status (NEW)
        ├── ai.provider_manager.cache
        ├── ai.provider_manager.detector
        └── ai.state
  └── ai.providers
  └── ai.fetch_models
  └── ai.util

picker.lua
  └── ai.provider_manager.status (NEW)
  └── ai.provider_manager.ui_util
  └── ai.provider_manager.registry
  └── ai.provider_manager.validator
  └── ai.util

init.lua
  └── ai.provider_manager.status (NEW - exports only)
  └── ai.provider_manager.picker
  └── ai.provider_manager.detector
  └── ai.provider_manager.results
  └── ai.provider_manager.cache
  └── ai.provider_manager.registry
  └── ai.state
```

No circular dependencies detected. The import graph is a clean DAG.

## Security Review

No new security issues introduced. Status module reads from cache (local file), detector (outbound HTTP — already sanitized by `sanitize_error` in detector.lua), and state (in-memory). No PII or credentials leaked in new display code. ASCII fallback entries are inert strings.

## Summary

| Severity | Count | Action |
|----------|-------|--------|
| Critical | 1 | Fix CR-01 before shipping (move require to module level) |
| Warning | 4 | Addressed or documented trade-offs |
| Info | 3 | Improvement suggestions |

**Overall assessment:** Phase 3 changes are well-structured with good separation of concerns. The status module is a thin, correct wrapper with proper thread safety and stale guards. The main concern (CR-01) is a code organization issue rather than a runtime bug. The ASCII fallback dead code (WR-02) should be cleaned up or activated.
