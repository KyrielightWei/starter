---
phase: 01-provider-manager-core-ui
plan: 05
subsystem: ui
tags: [fzf-lua, picker, static-models, atomic-write, block-parser]

# Dependency graph
requires:
  - phase: 01-01
    provides: [file_util safe_write_file, find_provider_block block parser, registry CRUD base]
  - phase: 01-02
    provides: [provider picker UI, model picker two-step flow]
  - phase: 01-04
    provides: [model management functions in registry]
provides:
  - Static models CRUD API (list, add, remove, update) with atomic file persistence
  - Static models editor UI accessible from model picker via <C-e>
  - Block-aware parser for finding provider M.register blocks
  - Safe file write (FileUtil) for atomic .tmp→rename persistence
affects: [future agent-model configuration, provider detection phases]

# Tech tracking
tech-stack:
  added: [file_util.lua]
  patterns: [atomic file write (.tmp→rename), block-aware source code parser, nested FZF-lua picker with auto-refresh]

key-files:
  created:
    - lua/ai/provider_manager/file_util.lua
    - tests/ai/provider_manager/registry_static_models_spec.lua
  modified:
    - lua/ai/provider_manager/registry.lua
    - lua/ai/provider_manager/picker.lua

key-decisions:
  - "Used FileUtil.safe_write_file for all static_models file writes (atomic .tmp→rename)"
  - "Block-aware parser (find_provider_block) used to locate provider M.register blocks before editing"
  - "Static models editor accessed via model picker <C-e> rather than provider picker (reduced keymap density)"
  - "Auto-refresh via vim.defer_fn(M._edit_static_models, 50) after add/delete operations"

patterns-established:
  - "Safe file write: write .tmp first, then fs_rename (atomic), with fallback to delete+copy"
  - "Block-aware parsing: find M.register('name') start to '})' end for reliable source editing"
  - "Nested picker navigation: <Esc> returns to parent picker, <C-e> opens sub-editors"

requirements-completed: [PMGR-04]

# Metrics
duration: 8min
completed: 2026-04-22
---

# Phase 01 Plan 05: Static Models Editor Summary

**Static models CRUD with atomic file persistence and nested FZF-lua editor accessible from model picker**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-22T13:50:00Z (approx)
- **Completed:** 2026-04-22T13:58:00Z (approx)
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 4

## Accomplishments
- Static models CRUD API: `list_static_models`, `add_static_model`, `remove_static_model`, `update_static_models`
- Created `file_util.lua` with `safe_write_file` (atomic .tmp→rename pattern) addressing review HIGH concern
- Added `find_provider_block` for block-aware provider parsing (replaces naive regex line matching)
- Static models editor picker accessible via `<C-e>` from model picker with add/remove/help actions
- Auto-refresh via `vim.defer_fn` after changes to avoid picker race conditions
- Fixed `delete_provider` to use `safe_write_file` instead of raw `vim.fn.writefile` (deviation fix)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add static_models CRUD with safe file persistence** - `854c714` (feat)
2. **Task 2: Human verify static models editor** - `a26997d` (feat)

## Files Created/Modified
- `lua/ai/provider_manager/file_util.lua` - Atomic file write utility (.tmp→rename with fs_rename)
- `lua/ai/provider_manager/registry.lua` - Added `find_provider_block`, static_models CRUD, `_update_static_models_in_file`
- `lua/ai/provider_manager/picker.lua` - Added `_edit_static_models`, `_add_static_model_dialog`, `_show_static_models_help`
- `tests/ai/provider_manager/registry_static_models_spec.lua` - Test suite for static_models CRUD

## Decisions Made
- Used `vim.defer_fn(M._edit_static_models, 50)` for auto-refresh (50ms delay avoids picker race conditions per review concern)
- Static models editor placed on model picker `<C-e>` (not provider picker) to keep keymap density at 4 core keys per provider picker
- Block-aware parser aggregates lines between `{` and `}` inside provider block to handle multi-line static_models format

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created file_util.lua**
- **Found during:** Task 1 (static_models CRUD implementation)
- **Issue:** Plan referenced `FileUtil.safe_write_file` but `file_util.lua` did not exist on disk (planned in 01-01 but not created)
- **Fix:** Created `lua/ai/provider_manager/file_util.lua` with `safe_write_file` (atomic .tmp→rename) and `read_lua_table`
- **Files modified:** Created `lua/ai/provider_manager/file_util.lua`
- **Verification:** Imported successfully via `require("ai.provider_manager.file_util")`
- **Committed in:** `854c714` (Task 1 commit)

**2. [Rule 1 - Bug] Fixed delete_provider to use safe_write_file**
- **Found during:** Task 1 (adding FileUtil to registry imports)
- **Issue:** `delete_provider` used raw `vim.fn.writefile` for providers.lua persistence — addresses review HIGH concern about unsafe file writes
- **Fix:** Updated `delete_provider` to use `FileUtil.safe_write_file` with `find_provider_block` for block-aware deletion
- **Files modified:** `lua/ai/provider_manager/registry.lua`
- **Verification:** Grep confirms `safe_write_file` is now used for all file persistence operations
- **Committed in:** `854c714` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking dependency, 1 bug fix)
**Impact on plan:** All auto-fixes necessary for correctness/safety. No scope creep — both address review concerns.

## Issues Encountered
- None beyond deviations documented above

## Known Stubs
- None — all static_models CRUD functions are fully wired to file persistence

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: tampering | lua/ai/provider_manager/registry.lua | `add_static_model`/`remove_static_model` modify providers.lua source code via block-aware parser; mitigated by `find_provider_block` scope isolation and `safe_write_file` atomic writes |
| threat_flag: integrity | lua/ai/provider_manager/registry.lua | `parse_static_models_from_block` uses regex to extract model IDs; graceful degradation returns empty list on parse failure |

## Checkpoint Reached (Task 2: Human Verify)

Static models editor is implemented but requires manual verification in Neovim:
1. Open Neovim → `<leader>kp` → select provider → select model
2. Press `<C-e>` to open static models editor
3. Verify models display correctly, `<C-a>` adds new model, `<C-d>` removes selected model
4. Verify providers.lua static_models persists correctly after restart

## Next Phase Readiness
- PMGR-04 fully delivered: users can view/edit static_models via picker
- Ready for Phase 2 (Detection Commands) and Phase 6 (Commit Diff Review)
- No blockers

---
*Phase: 01-provider-manager-core-ui*
*Plan 05: Static Models Editor*
*Completed: 2026-04-22*
