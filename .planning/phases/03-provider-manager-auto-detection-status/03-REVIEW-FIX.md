---
status: partial
padphase: 03
iteration: 1
fix_scope: critical_warning
findings_in_scope: 5
fixed: 3
skipped: 2
skipped_detail:
  WR-01: "Acceptable risk — stale guard implementation is correct with current State.get() behavior. Coupling to return shape is low-risk; documented but no code change needed."
  WR-03: "Known tradeoff per PLAN.md (addresses C-05, C-13). fzf-lua doesn't support reactive list updates. No fix required — accepted design decision."
---

## Phase 03 Code Review Fix Report

### Fixes Applied

#### FIX-01: CR-01 — Move require to module level in model_switch.lua (FIXED)

**File:** `lua/ai/model_switch.lua`

Moved `local Status = require("ai.provider_manager.status")` from inside the nested fzf callback (line 84) to the module-level imports (line 8). This eliminates the anti-pattern of requiring modules inside UI callbacks and ensures consistent module loading behavior.

**Before:**
```lua
function M.select(callback)
  ...
  fzf.fzf_exec(..., {
    actions = {
      ["default"] = function(sel)
        local Status = require("ai.provider_manager.status")  -- inside callback
        Status.trigger_async_check(provider, model, ...)
```

**After:**
```lua
local Status = require("ai.provider_manager.status")  -- at module level

function M.select(callback)
  ...
  Status.trigger_async_check(provider, model, ...)  -- direct call
```

**Commit:** Atomic

#### FIX-02: WR-02 — Activate ASCII fallbacks in get_status_icon (FIXED)

**File:** `lua/ai/provider_manager/ui_util.lua`

Added `use_ascii` optional boolean parameter to `M.get_status_icon(status, use_ascii)`. When `true`, returns ASCII fallback icons (`[ok]`, `[--]`, `[..]`, `[!!]`, `[  ]`) instead of Unicode icons. When `false` or nil (default), returns Unicode icons (current behavior).

This activates the previously dead-code ASCII fallback entries in the ICONS table.

**Before:**
```lua
function M.get_status_icon(status)
  local icon_map = {
    available   = ICONS.status_available,
    ...
  }
  return icon_map[status] or ICONS.status_unchecked
end
```

**After:**
```lua
function M.get_status_icon(status, use_ascii)
  if use_ascii then
    local ascii = {
      available   = ICONS.fallback_available,
      ...
    }
    return ascii[status] or ICONS.fallback_unchecked
  end
  -- Unicode path (unchanged behavior)
  ...
end
```

Backward compatible: all existing callers pass no second argument, so they continue to get Unicode icons.

#### FIX-03: WR-04 — Document test wrapper behavior in status_spec.lua (FIXED)

**File:** `tests/ai/provider_manager/status_spec.lua`

Added clarifying comment to `reset_state()` explaining why `vim.schedule_wrap` is NOT restored: the wrapper must stay active across all tests to count calls. Restoring it would break the "uses vim.schedule_wrap" verification test on subsequent test runs.

**Action:** Added inline comment documenting the design decision.

### Skipped Findings

| Finding | Reason |
|---------|--------|
| WR-01 | Acceptable risk. Stale guard is functionally correct with current `State.get()` implementation. Coupling to return shape is implicit but low-risk since `State.get()` is stable API. |
| WR-03 | Known and documented tradeoff. fzf-lua doesn't support reactive list updates. Users can re-open picker for fresh status. Accepted per PLAN.md. |

### Summary

- **Fixed:** 3 (CR-01, WR-02, WR-04)
- **Skipped:** 2 (WR-01, WR-03 — documented trade-offs)
- **Status:** partial — remaining findings are accepted design decisions, not code defects
