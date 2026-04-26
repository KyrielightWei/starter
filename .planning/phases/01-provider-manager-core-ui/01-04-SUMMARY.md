---
phase: 01-provider-manager-core-ui
plan: 04
subsystem: ui
tags: [lua, neovim, fzf-lua, provider-management]

dependency_graph:
  requires:
    - phase: 01-provider-manager-core-ui
      provides: "registry.lua base file created in Plan 01"
  provides:
    - Model listing with dynamic fetch + static fallback
    - Default model persistence to Keys config
    - 3-level get_default_model priority chain
  affects:
    - 01-02 (picker uses list_models for Step 2)
    - 01-05 (static models editor)

tech-stack:
  added: []
  patterns: ["pcall-wrapped require() for optional modules", "3-level config priority: user preference > in-memory > static fallback"]

key-files:
  created: []
  modified:
    - lua/ai/provider_manager/registry.lua

key-decisions:
  - "Removed top-level Fetch require — replaced with pcall(require, ...) in list_models per threat model T-01-08"
  - "get_default_model reads from Keys config using active profile (not hardcoded 'default' profile only)"

patterns-established:
  - "Optional dependency loading via pcall(require) for graceful fallback"
  - "Config priority chain: Keys (user preference) > Providers (code default) > static_models (hardcoded fallback)"

requirements-completed: [PMGR-01]

duration: 5min
completed: 2026-04-22
---

# Phase 01 Plan 04: Model Management Functions Summary

**Extended registry.lua with list_models, set_default_model, get_default_model — enabling model listing with dynamic fetch fallback and default model persistence to user preferences**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-22T11:09:00Z
- **Completed:** 2026-04-22T11:14:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- `list_models`: dynamic fetch with pcall-wrapped safety (threat T-01-08), falls back to static_models
- `set_default_model`: writes to Keys config (user preference store at ai_keys.lua) + updates in-memory Providers table
- `get_default_model`: 3-level priority — Keys config (active profile) > Providers.model > static_models[1]
- Cleaned up unused top-level Fetch require

## Task Commits

Each task was committed atomically:

1. **Task 1: Add model management functions to registry.lua** - `8c1cdbe` (feat)

## Files Created/Modified

- `lua/ai/provider_manager/registry.lua` - Added list_models, set_default_model, get_default_model; removed unused Fetch require

## Decisions Made

- `list_models` uses `pcall(require, "ai.fetch_models")` instead of top-level require — this makes the fetch module truly optional, gracefully degrading to static_models if the module is unavailable (aligns with threat model T-01-08)
- `get_default_model` respects the active profile from Keys config (`config.profile`) rather than always hardcoding "default" — this matches the profile-aware pattern used by `M.get_config` in keys.lua

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] list_models top-level Fetch require not pcall-wrapped**
- **Found during:** Task 1 (reading existing code)
- **Issue:** The existing file had `local Fetch = require("ai.fetch_models")` at the top level (from Plan 01). The plan specified `pcall(require, "ai.fetch_models")` for graceful degradation (threat T-01-08). The existing code partially deviated — it used pcall on `Fetch.fetch` but not on the require itself.
- **Fix:** Replaced top-level Fetch require with local `pcall(require, ...)` inside `list_models`, making the fetch module truly optional. Removed unused top-level require.
- **Files modified:** `lua/ai/provider_manager/registry.lua`
- **Verification:** grep confirms no top-level `require("ai.fetch_models")`; function-level pcall present
- **Committed in:** 8c1cdbe (task commit)

**2. [Rule 2 - Missing Critical] get_default_model missing Keys config lookup**
- **Found during:** Task 1 (reading existing code vs plan spec)
- **Issue:** The existing `get_default_model` only checked Providers.model and static_models. The plan specified 3-level priority: Keys config > Providers.model > static_models[1]. Without Keys lookup, the function couldn't return user-set default models persisted in ai_keys.lua.
- **Fix:** Added Keys.read() as first priority, resolving the active profile from `config.profile` and checking provider_config[profile].model with proper fallback chain.
- **Files modified:** `lua/ai/provider_manager/registry.lua`
- **Verification:** grep confirms Keys.read() call in get_default_model with 3-level fallback
- **Committed in:** 8c1cdbe (task commit)

---

**Total deviations:** 2 auto-fixed (1 bug fix, 1 missing critical functionality)
**Impact on plan:** Both fixes essential for correctness — without them, model listing could crash on missing fetch module and user-set defaults would be invisible to get_default_model.

## Issues Encountered

None

## Known Stubs

None — all functions are fully implemented with production-ready logic.

## Threat Flags

No new threat surface introduced beyond what was covered in the plan's threat model (T-01-07, T-01-08).

## Next Phase Readiness

- Model management functions ready for picker consumption (Plan 02 uses list_models for Step 2)
- set_default_model integrates with existing Keys config format (profile-aware)
- Compatible with existing test expectations in `tests/ai/provider_manager/registry_spec.lua`

---

*Phase: 01-provider-manager-core-ui*
*Completed: 2026-04-22*
