---
phase: "03"
reviewers: [qwen, glm5]
reviewed_at: "2026-04-25T08:30:00Z"
models:
  qwen: "bailian_coding/qwen3.6-plus"
  glm5: "bailian_coding/glm-5"
plans_reviewed: ["03-01-PLAN.md", "03-02-PLAN.md"]
---

# Cross-AI Plan Review — Phase 03

## Qwen Review (bailian_coding/qwen3.6-plus)

### Summary

Both plans are tightly scoped, appropriately layered, and directly address PMGR-07/PMGR-08 without scope creep. Plan 01 correctly implements non-blocking async detection aligned with decision D-01/D-03, and Plan 02's backward-compatible UI utility modifications are surgical. However, **Plan 01 has a critical thread-safety gap** (`vim.notify` called from async context without `vim.schedule`), and Plan 02 needs explicit confirmation that cache reads are O(1) memory lookups to guarantee the <500ms panel startup constraint. The wave dependency ordering is sound.

### Strengths
- Thin wrapper design with zero duplication
- Callback injection is surgical, doesn't alter model_switch control flow
- Warning-without-block user autonomy
- `vim.notify` with `replace = true` prevents spam
- Backward-compatible format functions (optional 3rd/4th args)
- Reuses Phase 2 cache directly — no new state stores
- Separate icon/label functions for future theming

### Concerns

| # | Severity | Concern |
|---|----------|---------|
| C-01 | **HIGH** | **`vim.notify` thread safety**: Called from `vim.system()` async context without `vim.schedule()` — will cause Neovim errors |
| C-02 | **MEDIUM** | **Race condition on rapid switching**: 3 async checks fire in quick succession, callbacks return out of order, stale warnings possible |
| C-03 | **MEDIUM** | **Cache read performance in picker loops**: If reads are disk I/O, providers with 50+ models cause UI stutter |
| C-04 | **MEDIUM** | **Unicode icon rendering in FZF-lua**: Icons may render inconsistently or be stripped; no ASCII fallback |
| C-05 | **MEDIUM** | **Status staleness during picker open**: Picker only reads cache at open time, misses async updates |
| C-06 | **LOW** | No fault tolerance for require/detector failures |
| C-07 | **LOW** | No cache warm-up on startup |
| C-08 | **LOW** | Color hint implementation unspecified in FZF-lua |
| C-09 | **LOW** | No "checking..." intermediate state |

### Suggestions
1. Wrap `vim.notify` in `vim.schedule()` — critical fix
2. Add `current_provider/model` guard to discard stale check results
3. Verify Phase 2 exports programmatic APIs (not just vim commands)
4. If cache is disk-backed, batch-load once at `M.open()` time
5. Add ASCII fallbacks for icon compatibility
6. Add "checking..." intermediate state with ⏳ icon

### Risk Assessment: MEDIUM

---

## GLM-5 Review (bailian_coding/glm-5)

### PLAN 01 Summary

Establishes the core integration layer for auto-detection with a thin wrapper module. The async-on-switch approach correctly implements D-01, D-03. However, **callback timing creates a UX gap where switch completes before warning**, and there's insufficient attention to Neovim coroutine safety (`vim.schedule`).

### PLAN 02 Summary

Extends UI layer with backward-compatible inline status indicators. Correct wave dependency, synchronous reads acceptable for N < 10. **No refresh mechanism when background detection updates cache** — stale icons.

### Strengths
- Thin wrapper reuses Phase 2 infrastructure
- Non-blocking, respects user autonomy
- Clear integration point with specific line numbers
- Backward-compatible API preserves existing callers
- Icon consistency with Phase 2 results.lua
- Synchronous cache reads O(1) for typical picker sizes

### Concerns

| # | Severity | Concern |
|---|----------|---------|
| C-10 | **HIGH** | **`vim.notify` without `vim.schedule`**: "E5560: vim.notify must not be called in a lua loop callback" |
| C-11 | **MEDIUM** | **Callback timing UX gap**: User may be 3-4 keystrokes into using new model before seeing warning |
| C-12 | **MEDIUM** | **Circular dependency risk**: status.lua → detector.lua, verify detector doesn't import back |
| C-13 | **MEDIUM** | **Picker stale data**: After switch, immediately opened picker shows outdated icon |
| C-14 | **MEDIUM** | **nil vs "unchecked" distinction**: Undefined behavior for nil cache entries |
| C-15 | **LOW** | Multiple rapid switches — notification queue confusion |
| C-16 | **LOW** | Test specification missing for TDD claim |
| C-17 | **LOW** | Icon customization — no user override mechanism |
| C-18 | **LOW** | fzf-lua ANSI coloring compatibility |

### Suggestions
1. Wrap `vim.notify` in `vim.schedule_wrap()`
2. Consider immediate provisional status "⏳ 检测中..." at switch time
3. Verify circular dependency chain
4. Add cache-update subscription hook for picker refresh
5. Explicit nil-handling with fallback to "unchecked"
6. Specify concrete test cases

### Risk Assessment: MEDIUM (reduces to LOW with suggested fixes)

---

## Consensus Summary

### Agreed Strengths (mentioned by both)
- ✅ Thin wrapper architecture — reuses Phase 2 cache/detector, zero duplication
- ✅ Non-blocking async design — respects D-01/D-03, user keeps control
- ✅ Surgical callback injection at specific lines — minimal disruption
- ✅ Backward-compatible API — optional status args, no breaking changes
- ✅ Icon consistency with Phase 2 results.lua
- ✅ Correct wave sequencing (Plan 01 → Plan 02)

### Agreed Concerns (both reviewers raised)
| Priority | Concern | Severity Both | Impact |
|----------|---------|---------------|--------|
| **1** | **`vim.notify` NOT wrapped in `vim.schedule`** | HIGH (both) | Runtime crash in async context |
| **2** | **Picker stale data** — async detection completes while picker open, icons outdated | MEDIUM (both) | User sees confusing/old status |
| **3** | **Rapid switching race condition** — stale warnings after rapid A→B→C switches | MEDIUM (both) | Warning for wrong model |
| **4** | **No "checking..." intermediate state** — active detection shows as "未检测" | LOW+ (both) | User doesn't know detection is running |
| **5** | **nil vs "unchecked" handling unspecified** | — | Defensive coding gap |
| **6** | **TDD test case specifications missing** | LOW (both) | Executor lacks clear test targets |

### Unique Concerns
- **Qwen only**: Unicode icon rendering in FZF-lua + ASCII fallback plan
- **Qwen only**: Cache warm-up on startup (vim.defer_fn)
- **GLM-5 only**: Circular dependency verification (status.lua ↔ detector.lua → cycle?)
- **GLM-5 only**: Callback timing UX gap (warning fires after switch, user may miss it)

### Divergent Views
- **Cache performance**: Qwen concerned about disk I/O risk; GLM-5 states "cache.lua reads are O(1) table lookups" — these conflict, executor should verify Phase 2 cache.lua implementation
- **Risk ceiling**: Both rate MEDIUM, but GLM-5 explicitly states risk drops to LOW with fixes; Qwen holds MEDIUM even with the vim.schedule fix (due to cache perf concern)

---

## Recommended Actions Before Execution

1. **MANDATORY**: Add `vim.schedule()` wrap around all async callbacks that touch UI in Plan 01
2. **ADD**: Race guard — check current provider/model before firing stale warnings
3. **ADD**: "检测中..." intermediate state in status.lua
4. **CLARIFY**: Explicit nil → "unchecked" fallback in `get_cached_status`
5. **VERIFY**: Phase 2 `cache.lua` — memory vs disk reads to validate performance concern
6. **ADD**: ASCII fallbacks for icon rendering compatibility
7. **DOCUMENT**: Circular dependency check before implementation
