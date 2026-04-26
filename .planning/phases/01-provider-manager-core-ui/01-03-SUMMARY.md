---
phase: 01-provider-manager-core-ui
plan: 03
subsystem: provider_manager
tags: [integration, keymap, command]
dependency:
  requires: [01-01, 01-02]
  provides: [accessibility]
  affects: [ai/init.lua]
tech-stack:
  added: []
  patterns: [pcall-loading, keymap-delegate, command-registration]
key-files:
  created:
    - lua/ai/provider_manager/init.lua
    - tests/ai/provider_manager/init_spec.lua
  modified:
    - lua/ai/init.lua
decisions:
  - "No <leader>kp conflict — existing keymaps use kc/kn/ke/kq/ks/kk/kS/kt/kd"
  - "Delegated keymap uses pcall guard for resilience when provider_manager not loaded"
  - "setup() loaded via pcall in ai/init.lua setup() following skill_studio pattern"
metrics:
  duration: "~5 minutes"
  completed: "2026-04-22"
---

# Phase 01 Plan 03: Integration + Keymap/Command Summary

**One-liner:** Provider Manager module integrated into ai/init.lua — accessible via `<leader>kp` keymap and `:AIProviderManager` command, loaded via pcall in setup().

## Tasks Completed

| # | Task | Type | Commit | Status |
|---|------|------|--------|--------|
| 1 | Create init.lua orchestrator for Provider Manager | auto+TDD | `0bed11b` | Done |
| 2 | Integrate Provider Manager into ai/init.lua | auto | `7906088` | Done |
| 3 | Human verify full CRUD flow | checkpoint:human-verify | N/A | Awaiting |

## Task Details

### Task 1: Create init.lua orchestrator

**Files created:**
- `lua/ai/provider_manager/init.lua` — Orchestrator with `setup()`, `open()`, `show_help()` exports
- `tests/ai/provider_manager/init_spec.lua` — 5 test cases

**Implementation:**
- `setup()` registers `<leader>kp` keymap (normal mode) and `:AIProviderManager` user command
- Both delegate to `Picker.open()` from plan 02
- Returns module for chaining
- Direct access exports: `M.open = Picker.open`, `M.show_help = Picker.show_help`

**Tests:** 5/5 passing
- Module loads and exports setup()
- setup() returns module for chaining
- open() function accessible
- show_help() function accessible
- Picker accessible via require path

### Task 2: Integrate into ai/init.lua

**Files modified:**
- `lua/ai/init.lua` — Added keymap entry + pcall loading in setup()

**Changes:**
1. Added `<leader>kp` entry to keys table (line 112-117) with pcall guard:
   ```lua
   { "<leader>kp", mode = "n", fn = function()
       local ok, PM = pcall(require, "ai.provider_manager")
       if ok then PM.open() end
     end, desc = "AI Provider Manager" },
   ```
2. Added Provider Manager loading in `setup()` (lines 207-211) after SkillStudio block:
   ```lua
   local ok_pm, ProviderManager = pcall(require, "ai.provider_manager")
   if ok_pm then
     ProviderManager.setup()
   end
   ```

**Conflict check:** No conflict with existing `<leader>k*` bindings (kc, kn, ke, kq, ks, kk, kS, kt, kd).

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None in files created/modified by this plan. (Step 2 model selection stub exists in picker.lua from plan 02 — deferred to Phase 3, documented there.)

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag:module-loading | lua/ai/init.lua | pcall used to safely load provider_manager; if module broken, Neovim startup unaffected (T-01-05 mitigated) |
| threat_flag:keymap | lua/ai/init.lua | Keymap delegates through pcall-guarded function, preventing error if module unloaded (T-01-06 mitigated) |

## Self-Check: PASSED

- [x] `lua/ai/provider_manager/init.lua` exists
- [x] `tests/ai/provider_manager/init_spec.lua` exists
- [x] `lua/ai/init.lua` modified with both changes
- [x] Commits `0bed11b` and `7906088` exist
- [x] All tests pass (5/5 init_spec, 20/20 full suite)
