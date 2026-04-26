---
phase: 02-provider-manager-detection-commands
plan: 02
subsystem: ai-integration
tags: [neovim, lua, vim.system, async-http, provider-detection, tdd]

# Dependency graph
requires:
  - phase: 02-01
    provides: cache.lua, results.lua, Wave 1 infrastructure
provides:
  - detector.lua with vim.system()-based async HTTP provider/model detection
  - :AICheckProvider, :AICheckAllProviders, :AIClearDetectionCache commands
  - <leader>kP (check current) and <leader>kA (check all) keymaps
  - Injectable M._http_fn for testability
  - Recursive run_next() queue with max 3 concurrent batch checks
  - Cache-first detection with status-based TTL
  - API key/URL sanitization in error messages
affects:
  - 02-03 (future UI enhancements)
  - Wave 3 (future features)

# Tech tracking
tech-stack:
  added: [vim.system async HTTP, run_next recursive queue pattern]
  patterns:
    - "vim.system() + injectable _http_fn for testable async HTTP"
    - "Sync wrapper via vim.wait() wrapping async callback"
    - "recursive run_next() queue for bounded concurrency"
    - "package.loaded stub injection for unit testing Lua requires"
    - "Error sanitization via gsub redaction"

key-files:
  created:
    - lua/ai/provider_manager/detector.lua
    - tests/ai/provider_manager/detector_spec.lua
  modified:
    - lua/ai/provider_manager/init.lua

key-decisions:
  - "Used vim.system() instead of io.popen for non-blocking async HTTP (unanimous review fix)"
  - "Extended is_endpoint_compatible to also match /v1$ (without trailing slash) for real-world endpoints"
  - "Prepended project root to runtimepath in test file to ensure project detector loads instead of installed version"
  - "check_all_providers uses simple recursive run_next() + active counter (not io.popen + vim.loop semaphore)"
  - "{replace=true} on vim.notify to prevent notification coalescing during batch progress"
  - "Cache only on 'available' status to avoid caching transient failures"

patterns-established:
  - "detector.lua: injectable M._http_fn pattern for testable async HTTP"
  - "check_single(): sync wrapper using vim.wait(timeout, predicate, 50, false)"
  - "check_all_providers(): recursive run_next() with active/max_concurrent control flow"
  - "Test stub injection: clear package.loaded, install stubs, then require module"

requirements-completed: [PMGR-05, PMGR-06]

# Metrics
duration: 25min
completed: 2026-04-25
---

# Phase 02 Plan 02: Provider/Model Detection Commands Summary

**vim.system()-based async provider/model detection with sync wrapper, batch concurrency, cache, and command/keymap wiring**

## Performance

- **Duration:** 25 min
- **Started:** 2026-04-25T~10:00
- **Completed:** 2026-04-25T~10:25
- **Tasks:** 2 (detector.lua TDD + init.lua wiring)
- **Files modified:** 2 (detector.lua created, init.lua extended)

## Accomplishments
- Created detector.lua with vim.system() async HTTP, cache-first flow, endpoint compatibility checks, and error message sanitization
- Wired :AICheckProvider, :AICheckAllProviders, :AIClearDetectionCache user commands with tab completion and provider validation
- Added <leader>kP (check current provider) and <leader>kA (check all providers) keymaps
- 22 detector unit tests pass (available, unavailable, error, timeout, cache, batch, endpoint compatibility cases)
- All 91 provider_manager tests pass across 8 test files

## Task Commits

Each task was committed atomically:

1. **Task 1: Create detector.lua — TDD** - `pending` (feat + test)
   - Red/Green: wrote 22 test cases in detector_spec.lua, then implemented detector.lua
   - Key: injectable M._http_fn, vim.system() async HTTP, run_next() batch queue, status constants, endpoint compatibility, error sanitization

2. **Task 2: Wire detection commands and keymaps in init.lua** - `pending` (feat)
   - Added :AICheckProvider with nargs="*" and completion, :AICheckAllProviders, :AIClearDetectionCache
   - Added <leader>kP and <leader>kA keymaps, provider_exists validation, Results.show integration

## Files Created/Modified
- `lua/ai/provider_manager/detector.lua` - Core detection: async HTTP via vim.system(), sync wrapper via vim.wait(), batch queue with max 3 concurrent
- `tests/ai/provider_manager/detector_spec.lua` - 22 unit tests with package.loaded stub injection
- `lua/ai/provider_manager/init.lua` - Extended with detection commands, keymaps, check_provider/check_all exports

## Decisions Made
- Extended `is_endpoint_compatible()` to also match `/v1$` (not just `/v1/`) since many real endpoints like `https://api.openai.com/v1` lack trailing slash
- Prepended project root to runtimepath in test file to ensure `require()` loads the project detector rather than installed `~/.config/nvim/` version
- Cache only stores "available" results (not errors/timeouts/unavailable) to avoid caching transient failures
- Provider validation before check uses `Registry.list_providers()` to confirm provider exists

## Deviations from Plan

### Auto-fixed Issues

**1. [Test infrastructure] Runtimepath module resolution mismatch**
- **Found during:** Task 1 (initial test run — 18 failures)
- **Issue:** `require("ai.provider_manager.detector")` loaded from `~/.config/nvim/` instead of project, bypassing package.loaded stub injection
- **Fix:** Prepended project root to `vim.opt.runtimepath` at the top of test file before clearing package.loaded, ensuring project files resolve first
- **Files modified:** tests/ai/provider_manager/detector_spec.lua
- **Verification:** All 22 tests pass after fix
- **Committed in:** Task 1 commit

**2. [Edge case] Endpoint compatibility too narrow — missed `/v1$` pattern**
- **Found during:** Task 1 test — "does not warn for /v1/ endpoint" failed because test base_url was `https://v1.api.com/v1` (no trailing slash)
- **Issue:** `is_endpoint_compatible()` only checked for `/v1/` but many real APIs end with `/v1` without trailing slash
- **Fix:** Extended pattern to also match `/v1$` in addition to `/v1/` and `/compatible-mode$`
- **Files modified:** lua/ai/provider_manager/detector.lua
- **Verification:** Test passes; both `/v1` and `/v1/` endpoints now recognized as compatible
- **Committed in:** Task 1 commit

---

**Total deviations:** 2 auto-fixed (1 test infrastructure, 1 edge case)
**Impact on plan:** Both fixes improve correctness and test reliability. No scope creep.

## Issues Encountered
- Initial test run had 18/22 failures due to `package.loaded` stubs not being picked up by the detector's `require` calls — detector was resolving to installed version (runtimepath ordering issue)
- Fixed by prepending project root to runtimepath in test file before clearing package.loaded

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Detection core complete: detector.lua exports all required functions
- Commands and keymaps wired: all 3 user commands and 2 keymaps functional
- Ready for Wave 3 (UI enhancements, additional features)
- Detector is fully testable via injectable `M._http_fn`

---
*Phase: 02-provider-manager-detection-commands*
*Plan: 02*
*Completed: 2026-04-25*
