---
phase: 03-provider-manager-auto-detection-status
plan: 02
wave: 2
completed: 2026-04-25
---

## 03-02: Inline Status Indicators in UI Pickers

### Objective
Add inline status indicators to Provider Manager picker and model picker UI, sourced from Phase 2 cache, with backward-compatible format functions and ASCII fallbacks.

### What Was Built
- **ui_util.lua extensions**:
  - ICONS table extended with status_available (✓), status_unavailable (✗), status_timeout (⏱), status_error (⚠), status_unchecked (○)
  - ASCII fallbacks: [ok], [--], [..], [!!], [  ]
  - get_status_icon(status): Returns Unicode icon for status enum, defaults to unchecked
  - get_status_label(status): Returns color hint strings (success/error/warn/comment)
  - format_provider_display(name, def, status): Optional 3rd arg, backward compatible
  - format_model_display(model_id, is_default, metadata, status): Optional 4th arg, backward compatible
- **picker.lua integration**:
  - Provider picker: reads cached status for each provider's default model, passes to format function
  - Model picker: reads cached status for each provider+model, passes to format function
  - Status sourced from cache.lua (memory-backed _memory_cache, O(1) lookup)
  - Unchecked entries render identically to pre-phase (no icon prefix)

### Key Files Created/Modified
- `lua/ai/provider_manager/ui_util.lua` (modified — added status icons, labels, updated format functions)
- `lua/ai/provider_manager/picker.lua` (modified — added Status import, wired get_cached_status into display loops)
- `tests/ai/provider_manager/ui_util_spec.lua` (new — comprehensive tests for icons, labels, format backward compatibility)

### Review Findings Addressed
- C-04: Unicode icons have ASCII fallbacks for font compatibility
- C-14: Nil-safe handling in format functions — nil status produces identical output to pre-phase
- D-05: Status icons displayed in picker lists
- D-06: Icon mapping per design spec (✓/✗/⏱/⚠/○)
- D-07: Status sourced from cache.lua, not live checks
- D-08: Picker integration priority — picker display primary, model_switch complementary
- D-11: No new keymaps added

### Self-Check: PASSED
- All 5 status icons present in ICONS table with ASCII fallbacks
- get_status_icon returns correct icon for each enum, defaults to unchecked for unknown
- get_status_label returns correct color hints
- format_provider_display backward compatible: nil status → identical output
- format_model_display backward compatible: nil metadata + nil status → no crash
- picker.lua calls Status.get_cached_status for each provider and model entry
- Both pickers load without errors (EXIT:0 verified)
- Tests cover all status enums, format with/without status, nil handling
