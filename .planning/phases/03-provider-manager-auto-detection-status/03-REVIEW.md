---
status: issues_found
phase: 03-provider-manager-auto-detection-status
depth: deep
files_reviewed: 7
review_date: 2026-04-25
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
severity:
  critical: 0
  warning: 3
  info: 4
  total: 7
---

# Phase 03 Code Review Report (Re-review after fixes)

**Depth:** deep (cross-file analysis including import graphs and call chains)
**Files Reviewed:** 7
**Phase:** 03-provider-manager-auto-detection-status

## Files in Scope

| File | Type | Lines |
|------|------|-------|
| `lua/ai/provider_manager/status.lua` | Created | 74 |
| `lua/ai/provider_manager/ui_util.lua` | Modified | +68 lines |
| `lua/ai/provider_manager/picker.lua` | Modified | +12 lines |
| `lua/ai/provider_manager/init.lua` | Modified | +5 lines |
| `lua/ai/model_switch.lua` | Modified | +18 lines |
| `tests/ai/provider_manager/status_spec.lua` | Created | 319 |
| `tests/ai/provider_manager/ui_util_spec.lua` | Created | 201 |

---

## Previous Issues Status

| ID | Severity | Status | Notes |
|----|----------|--------|-------|
| CR-01 | Critical | **FIXED** | `require("ai.provider_manager.status")` moved to module level in model_switch.lua (line 8). ✅ |
| WR-01 | Warning | **ACCEPTED** | Stale guard coupling — correct implementation, low risk. No action needed. |
| WR-02 | Warning | **PARTIALLY FIXED** | Added `use_ascii` parameter to `get_status_icon()`. ASCII fallbacks now accessible but callers in picker.lua still use Unicode default. ✅ |
| WR-03 | Warning | **ACCEPTED** | Picker staleness during async detection — known fzf-lua limitation. No action needed. |
| WR-04 | Warning | **DOCUMENTED** | Added clarifying comment in `reset_state()`. |

---

## WARNING — Should Fix

### WR-05: ui_util_spec.lua — Missing tests for `use_ascii` parameter in get_status_icon

**File:** `tests/ai/provider_manager/ui_util_spec.lua`
**Severity:** Warning
**Category:** Test Coverage

The `use_ascii` parameter was added in WR-02 fix but the test file does not cover this new code path. All existing tests call `get_status_icon(status)` without the second argument, so the ASCII fallback branch is untested.

**Fix:** Add tests:
```lua
it("returns ASCII fallback when use_ascii is true", function()
  assert.are.equal("[ok]", UIUtil.get_status_icon("available", true))
  assert.are.equal("[--]", UIUtil.get_status_icon("unavailable", true))
  assert.are.equal("[..]", UIUtil.get_status_icon("timeout", true))
  assert.are.equal("[!!]", UIUtil.get_status_icon("error", true))
  assert.are.equal("[  ]", UIUtil.get_status_icon("unchecked", true))
end)

it("returns ASCII fallback for unknown status when use_ascii is true", function()
  assert.are.equal("[  ]", UIUtil.get_status_icon("unknown", true))
end)
```

### WR-06: model_switch.lua — Unused variable in Fetch.fetch result

**File:** `lua/ai/model_switch.lua:39`
**Severity:** Warning
**Category:** Code Quality

```lua
local models_raw, tried, succ, fail = Fetch.fetch(provider)
```

The variables `tried`, `succ`, and `fail` are never used. This was pre-existing code, but it's worth noting. In Luacheck this would trigger "unused variable" warnings.

**Fix:** Use `_` placeholder for unused values:
```lua
local models_raw, _, _, _ = Fetch.fetch(provider)
```

### WR-07: init.lua — Detector.check_provider_model callback not wrapped in vim.schedule_wrap

**File:** `lua/ai/provider_manager/init.lua:69`
**Severity:** Warning
**Category:** Thread Safety Consistency

```lua
Detector.check_provider_model(provider, model, function(result)
  if result then
    Results.show_single_result(result, "Detection Result: " .. provider .. "/" .. model)
```

The `cmd_check_provider` callback calls `Results.show_single_result` which may interact with the UI. Unlike the new Phase 3 code (which wraps all UI callbacks in `vim.schedule_wrap`), this pre-existing callback is not wrapped. While `Detector.check_provider_model` internally handles cache hits via `vim.schedule`, HTTP responses come through `vim.system` callbacks which already run in the main thread.

**Risk:** Low — `vim.system` callbacks are already on the main thread. The inconsistency is cosmetic but represents a deviation from the Phase 3 safety standard.

**Recommendation:** Wrap in `vim.schedule_wrap` for consistency:
```lua
Detector.check_provider_model(provider, model, vim.schedule_wrap(function(result)
  ...
end))
```

---

## INFO — Nice to Have

### IF-01: status_spec.lua — Missing test for get_cached_status with both nil provider and nil model

**File:** `tests/ai/provider_manager/status_spec.lua`
**Severity:** Info
**Category:** Test Coverage

Tests cover nil provider OR nil model individually, but not both simultaneously:
```lua
it("returns 'unchecked' when both provider and model are nil", function()
  assert.are.equal("unchecked", Status.get_cached_status(nil, nil))
end)
```

### IF-02: picker.lua — Local require of Registry inside loop is redundant

**File:** `lua/ai/provider_manager/picker.lua`
**Severity:** Info
**Category:** Code Style

Registry is already imported at the top of the file (line 8), so the `Status.get_cached_status(p.name, default_model)` call inside the loop (line 40) is fine. No issue here — just noting that the import graph is clean.

### IF-03: ui_util.lua — get_status_label unused in picker display

**File:** `lua/ai/provider_manager/ui_util.lua`
**Severity:** Info
**Category:** Dead Code Risk

`get_status_label()` is defined but never called by any consumer in the current codebase. It was designed for future color/hint assignment but is currently dead code. Not an issue — it's a prepared API — but worth tracking.

### IF-04: ui_util_spec.lua — format_model_display trailing space in expected output

**File:** `tests/ai/provider_manager/ui_util_spec.lua`
**Severity:** Info
**Category:** Test Brittleness

The test for `format_model_display` without context_length expects `"★ gpt-4 "` with a trailing space:
```lua
assert.are.equal("★ gpt-4 ", result)
```

This trailing space comes from the format string `"%s %s %s"` where context is empty. While technically correct, it's an implementation detail that could change without functional impact. Tests anchored to exact strings are brittle.

---

## Import Graph Analysis (Clean DAG)

```
ai/model_switch.lua
  └── ai/provider_manager/status (line 8) — FIXED: module level
  └── ai/providers
  └── ai/fetch_models
  └── ai/util

ai/provider_manager/init.lua
  └── ai/provider_manager/status (line 13) — exported at lines 178-180
  └── ai/provider_manager/picker
  └── ai/provider_manager/detector
  └── ai/provider_manager/results
  └── ai/provider_manager/cache
  └── ai/provider_manager/registry
  └── ai/state

ai/provider_manager/picker.lua
  └── ai/provider_manager/status (line 12) — used in open() and _select_model()
  └── ai/provider_manager/ui_util
  └── ai/provider_manager/registry
  └── ai/provider_manager/validator
  └── ai/util

ai/provider_manager/ui_util.lua
  └── (no internal dependencies)

ai/provider_manager/status.lua
  └── ai/provider_manager/cache
  └── ai/provider_manager/detector
  └── ai/state
```

**No circular dependencies.** Import graph is a clean DAG.

## Security Review

No new security issues. The `use_ascii` parameter addition is safe (simple conditional branch). The `require` move to module level (CR-01 fix) is strictly better. No credentials, API keys, or sensitive data in display paths.

## Summary

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 0 | ✅ CR-01 fixed |
| Warning | 3 | WR-05 (new), WR-06 (pre-existing), WR-07 (consistency) |
| Info | 4 | Test coverage edge cases and style notes |

**Overall assessment:** The CR-01 fix resolved the most important issue. The remaining warnings are minor: WR-05 is test coverage for new code, WR-06 is pre-existing unused variables, and WR-07 is consistency with the new thread-safety standard. Phase 3 code quality has improved meaningfully since the first review.
