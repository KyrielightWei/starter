---
phase: 03-provider-manager-auto-detection-status
plan: 01
wave: 1
completed: 2026-04-25
---

## 03-01: Status Checker API + Async Auto-Detection Integration

### Objective
Create status checker API module and integrate async auto-detection into model switching flow, with vim.schedule thread safety and stale callback guards.

### What Was Built
- **status.lua**: New thin wrapper module over cache.lua, detector.lua, and state.lua
  - `get_cached_status(provider, model)`: Returns cached status string or "unchecked" (nil-safe)
  - `get_cached_status_with_pending(provider, model)`: Returns (status, is_checking) tuple
  - `trigger_async_check(provider, model, on_complete)`: Fire-and-forget async detection with vim.schedule_wrap + stale guard
  - `check_all_batch(callback)`: Batch detection delegate with vim.schedule_wrap
- **model_switch.lua integration**: Auto-detection triggered immediately before callback fires, warning shown on non-available status without blocking switch
- **init.lua exports**: get_cached_status, trigger_async_check, check_all_batch exposed via provider_manager subsystem

### Key Files Created/Modified
- `lua/ai/provider_manager/status.lua` (new)
- `tests/ai/provider_manager/status_spec.lua` (new)
- `lua/ai/model_switch.lua` (modified — added Status.trigger_async_check call + vim.schedule-wrapped warning)
- `lua/ai/provider_manager/init.lua` (modified — added Status require + exports)

### Review Findings Addressed
- C-01/C-10: All async callbacks touching UI wrapped in vim.schedule() or vim.schedule_wrap()
- C-02/C-11: Stale guard in trigger_async_check compares captured provider+model against State.get()
- C-14: Nil/empty input guard returns "unchecked" immediately
- C-12: Circular dependency verified — status.lua imports cache/detector/state, none import back
- D-01: Detection is async — callback fires immediately, not after detection
- D-03: On failure/unavailability, show warning via vim.notify — does NOT prevent switch
- D-09: User retains control — no auto-revert, no blocking
- D-11: No new keymaps added

### Self-Check: PASSED
- All 4 exported functions present and tested
- vim.schedule_wrap used in both trigger_async_check and check_all_batch
- Stale guard prevents wrong warnings after rapid switching
- Nil-safe cache access with defensive fallback
- Circular dependency verified: clean DAG
- model_switch.lua callback fires regardless of detection result
- Warning notification uses { replace = true } to prevent buildup
