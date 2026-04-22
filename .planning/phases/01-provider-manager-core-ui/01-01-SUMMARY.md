---
phase: 01-provider-manager-core-ui
plan: 01
subsystem: provider_manager
tags: [tdd, crud, validation, file-persistence]
dependency:
  requires: []
  provides: [PMGR-01, PMGR-02, PMGR-03]
  affects: [01-UI-SPEC.md, lua/ai/init.lua (future)]
tech-stack:
  added: []
  patterns: [skill-studio-subsystem, tdd-with-plenary, fzf-lua-action-args]
key-files:
  created:
    - lua/ai/provider_manager/validator.lua
    - lua/ai/provider_manager/registry.lua
    - tests/ai/provider_manager/validator_spec.lua
    - tests/ai/provider_manager/registry_spec.lua
  modified:
    - tests/ai/provider_manager/ (directory created)
decisions:
  - "Validator error messages split into leading-letter check and full-format check for better UX"
  - "Keys cleanup done inline (read → remove → write) rather than separate Keys.cleanup() function"
  - "Lua string pattern uses single-quoted outer strings to avoid escape sequence issues with embedded quotes"
metrics:
  duration_minutes: ~10
  completed_date: "2026-04-22"
---

# Phase 01 Plan 01: Registry and Validator Modules Summary

**One-liner:** Provider name validation and CRUD registry with file persistence, implemented TDD-style with 15 passing tests.

## Objective

Create the foundation layer for managing Provider configurations: input validation (validator.lua) and CRUD operations with file persistence (registry.lua). Addresses review concerns — delete_provider() writes modified providers.lua file, find_provider_line() uses dynamic path, list_providers() iterates via Providers.list() API.

## Tasks Completed

### Task 1: Create validator.lua with input validation [COMMITTED]

Create `lua/ai/provider_manager/validator.lua` with `validate_provider_name()` function.

**Implementation:** Validates provider names against:
- Empty/nil check: returns "Provider name cannot be empty"
- Leading letter check: returns "Provider name must start with a letter..."
- Full format regex: returns "Provider name must be lowercase with dashes/underscores, starting with a letter"
- Duplicate check against Providers registry: returns "Provider already exists: {name}"

**Tests:** 7 test cases all passing (validator_spec.lua)

### Task 2: Create registry.lua with CRUD operations and file persistence [COMMITTED]

Create `lua/ai/provider_manager/registry.lua` implementing full CRUD API.

**Implementation:**
- `list_providers()`: Uses `Providers.list()` API (not pairs(Providers)), returns `{name, display, endpoint, model}` table
- `find_provider_line(name)`: Uses `vim.fn.stdpath("config")` for dynamic path resolution
- `add_provider(name)`: Validates input via Validator before opening providers.lua for user config entry
- `delete_provider(name)`: Removes from memory, cleans Keys entry, persists deletion to providers.lua file

**Tests:** 8 test cases all passing (registry_spec.lua)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Lua pattern escape sequences in registry.lua**
- **Found during:** Task 2 implementation
- **Issue:** Plan code used `"['\"]"` escaped quote syntax in Lua patterns, causing `invalid escape sequence` Lua error at runtime
- **Fix:** Changed to single-quoted outer strings `'M%.register%([\'"]' .. name .. '[\'"]'` which correctly embed quote characters in Lua patterns
- **Files modified:** `lua/ai/provider_manager/registry.lua`
- **Commit:** `e564f94`

**2. [Rule 2 - Missing functionality] Validator error messages split for better diagnostics**
- **Found during:** Task 1 TDD phase
- **Issue:** Plan spec had two error tests ("uppercase" and "starts with number") both matching the same regex `^[a-z][a-z0-9_-]*$`, but plan required different error messages ("must be lowercase" vs "must start with letter")
- **Fix:** Split validation into two checks — first `^[a-z]` for leading letter (different error message), then full `^[a-z][a-z0-9_-]*$` for format
- **Files modified:** `lua/ai/provider_manager/validator.lua`
- **Commit:** `bef189d`

**3. [Rule 2 - Missing critical functionality] add_provider() missing input validation**
- **Found during:** Task 2 implementation
- **Issue:** Existing registry.lua `add_provider()` did not call `Validator.validate_provider_name()` — any name (including invalid) would open providers.lua
- **Fix:** Added Validator import and validation check before opening file
- **Files modified:** `lua/ai/provider_manager/registry.lua`
- **Commit:** `e564f94`

**4. [Rule 2 - Missing critical functionality] delete_provider() missing file persistence and Keys cleanup**
- **Found during:** Task 2 implementation
- **Issue:** Existing registry.lua `delete_provider()` only removed from in-memory Providers table with a notification telling users to manually edit providers.lua. No Keys cleanup. This was a review HIGH concern that was not addressed in the pre-existing code.
- **Fix:** Implemented full file persistence (read providers.lua → skip targeted M.register() block → writefile), plus Keys.read/Keys.write to remove the provider's key entry
- **Files modified:** `lua/ai/provider_manager/registry.lua`
- **Commit:** `e564f94`

**5. [Rule 2 - Missing data fields] list_providers() missing endpoint and model in result**
- **Found during:** Task 2 implementation
- **Issue:** Existing `list_providers()` only returned `{name, display}` — plan required `{name, display, endpoint, model}`
- **Fix:** Added endpoint and model fields to returned table
- **Files modified:** `lua/ai/provider_manager/registry.lua`
- **Commit:** `e564f94`

## Authentication Gates

None encountered.

## Known Stubs

None. All functions are fully implemented with real data sources wired.

## Threat Flags

No new security-relevant surface introduced beyond what plan specified.

## Tests

| Spec File | Tests | Passed | Failed |
|-----------|-------|--------|--------|
| validator_spec.lua | 7 | 7 | 0 |
| registry_spec.lua | 8 | 8 | 0 |
| **Total** | **15** | **15** | **0** |

## Verification Checklist

- [x] validator.lua exists at lua/ai/provider_manager/validator.lua
- [x] validate_provider_name() function exported
- [x] All 7 validator test cases pass
- [x] Validator rejects empty, uppercase, duplicate, and invalid format names
- [x] registry.lua exists at lua/ai/provider_manager/registry.lua
- [x] list_providers() uses Providers.list() API (not pairs(Providers))
- [x] find_provider_line() uses vim.fn.stdpath("config") for dynamic path
- [x] delete_provider() removes from file via vim.fn.writefile (not just memory)
- [x] delete_provider() also cleans Keys entry
- [x] All 8 registry test cases pass
- [x] Review HIGH concerns addressed: file persistence, dynamic path, Providers.list()

## Self-Check: PASSED
