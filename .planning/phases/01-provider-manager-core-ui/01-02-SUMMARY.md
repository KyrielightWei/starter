---
phase: "01-provider-manager-core-ui"
plan: "02"
subsystem: "provider_manager"
tags: [fzf-lua, picker, crud]
dependency_graph:
  requires: [Registry.list_providers, Validator.validate_provider_name, Registry.find_provider_line]
  provides: [Picker.open, Picker.show_help, Picker.add_provider_dialog, Picker.delete_provider_dialog, Picker.edit_provider]
  affects: [user_experience]
tech_stack:
  added:
    - fzf-lua (existing dependency)
    - vim.ui.input (Neovim core API)
  patterns:
    - FZF-lua picker with custom actions (ctrl-a/d/e/?)
    - Empty state early return (no placeholder injection)
    - Closure capture before async callback (vim.ui.input)
    - Dynamic provider file path via vim.fn.stdpath
key_files:
  created:
    - lua/ai/provider_manager/picker.lua
    - lua/ai/provider_manager/registry.lua (blocking dependency, Rule 3)
    - lua/ai/provider_manager/validator.lua (blocking dependency, Rule 3)
    - tests/ai/provider_manager/picker_spec.lua
decisions:
  - "Use fzf_exec (not fzf_contents) per glm-5 review and model_switch.lua consistency"
  - "Empty state returns early with vim.notify, no placeholder item added to name_map"
  - "Ctrl-D and Ctrl-E capture name in closure before vim.ui.input async callback per qwen review"
  - "Step 2 model selection deferred to Phase 3 (auto-detection)"
  - "Registry and validator created as blocking dependencies (Deviation Rule 3) since Plan 01 not yet executed"
metrics:
  duration_minutes: 5
  completed_date: "2026-04-22"
  tests: 4 passed, 0 failed
---

# Phase 01 Plan 02: Provider Manager FZF Picker UI Summary

## One-liner

FZF-lua picker UI with CRUD actions (add/delete/edit/help) for Provider Manager, using fzf_exec API with empty-state guard and closure-captured async callbacks.

## Tasks Completed

| Task | Type | Status | Commit | Files Created |
|------|------|--------|--------|---------------|
| 1 | auto (TDD) | Done | a8b9f87 | picker.lua, registry.lua, validator.lua, picker_spec.lua |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing registry.lua and validator.lua**
- **Found during:** Task 1 (picker implementation)
- **Issue:** Plan 01-02 depends on lua/ai/provider_manager/registry.lua and validator.lua from Plan 01-01, which had not been executed yet. Picker cannot load without these requires.
- **Fix:** Created minimal implementations of both modules before implementing picker:
  - `validator.lua`: Input validation with kebab-case regex and duplicate check
  - `registry.lua`: CRUD operations — `list_providers()`, `add_provider()`, `delete_provider()`, `find_provider_line()`
- **Files modified:** lua/ai/provider_manager/validator.lua, lua/ai/provider_manager/registry.lua

**None - plan executed exactly as written beyond the blocking dependencies.**

## Authentication Gates

None.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| fzf_exec over fzf_contents | Matches model_switch.lua pattern; consistent with glm-5 review | Adopted |
| Empty state early return | No placeholder added to name_map (avoids name_map lookup bug per review) | Adopted |
| Closure capture for async | name captured in local variable before vim.ui.input callback (per qwen review) | Adopted |
| Step 2 deferred | Auto-detection belongs to Phase 3, not Phase 1 Core UI | Documented as TODO |

## Test Results

```
Success  ||  Provider Manager Picker module loads
Success  ||  Provider Manager Picker registry integration
Success  ||  Provider Manager Picker picker validates provider display format
Success  ||  Provider Manager Picker picker handles empty provider list gracefully
Success: 4
Errors : 0
```

## Known Stubs

- **Step 2 model selection** (`picker.lua` line 53): TODO annotation — model selection picker deferred to Phase 3. Provider selection is complete; model selection will chain to `M.select()` from model_switch.lua.

## Verification Against Plan Done Criteria

- [x] picker.lua exists at lua/ai/provider_manager/picker.lua
- [x] open() function displays provider list via fzf.fzf_exec
- [x] Empty state: returns early if no providers (no placeholder in name_map)
- [x] Ctrl-A triggers add with validation
- [x] Ctrl-D captures name BEFORE async callback (closure fix)
- [x] Ctrl-E opens providers.lua at correct line
- [x] Ctrl-/ shows help window
- [x] Basic tests pass (4/4)

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag:T-01-03-mitigated | picker.lua | Delete confirmation dialog (y/n) required before deletion |
| threat_flag:T-01-05-mitigated | picker.lua | name_map[display] validated before CRUD operations; early-return if missing |

---

*Plan 02 executed: 2026-04-22*
*Commit: a8b9f87*
