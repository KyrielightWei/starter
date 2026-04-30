---
phase: 05-commit-picker-configuration
reviewed: 2026-04-26T08:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lua/commit_picker/config.lua
  - lua/commit_picker/settings.lua
  - lua/commit_picker/git.lua
  - lua/commit_picker/init.lua
  - lua/commit_picker/display.lua
  - tests/commit_picker/config_spec.lua
findings:
  critical: 0
  warning: 3
  info: 6
  total: 9
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-04-26T08:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed 6 Lua files implementing commit picker configuration: config module with atomic writes and mtime caching, fzf-lua settings picker UI, mode routing in git.lua, display highlighting, and plenary.nvim test suite. The code is generally well-structured with good error handling, safe config parsing via `pcall(dofile)`, and proper module patterns consistent with AGENTS.md conventions. No critical security or correctness bugs were found. Three warnings address a nil-deref risk in init.lua, an unused variable in settings.lua, and inconsistent return value semantics in git.lua. Six info items cover redundant validation, dead code, duplicated logic, and minor naming inconsistencies.

## Warnings

### WR-01: Potential nil deref when accessing fallback config

**File:** `lua/commit_picker/init.lua:83`
**Issue:** After `pcall(require, "commit_picker.config")`, if the require fails (ok=false), the code accesses `Config.get_config().count` directly. Since `Config` would be nil or undefined when `ok` is false, this causes a nil index error that crashes the picker open flow.

```lua
-- Line 82-83: current code
local config_ok, Config = pcall(require, "commit_picker.config")
local count = config_ok and Config.get_config().count or 20
```

When `config_ok` is false, `Config` is the error message (a string from pcall), not a module. Calling `Config.get_config()` on a string throws "attempt to index a string value."

**Fix:**
```lua
local config_ok, Config = pcall(require, "commit_picker.config")
local count = 20
if config_ok and type(Config) == "table" and type(Config.get_config) == "function" then
  local cfg = Config.get_config()
  if cfg and type(cfg.count) == "number" then
    count = cfg.count
  end
end
```

### WR-02: Unused variable `fzf` in settings.lua open()

**File:** `lua/commit_picker/settings.lua:31`
**Issue:** Variable `fzf` is captured by `pcall(require, "fzf-lua")` at line 31 but is never used within the `M.open()` function. The actual fzf-lua usage happens in `M._render_picker()` and other sub-functions which do their own `pcall(require, "fzf-lua")`. This triggers linter warnings (luacheck/selene) and is dead code.

```lua
-- Line 31: fzf captured but never used
local ok, fzf = pcall(require, "fzf-lua")
if not ok then
  vim.notify("[commit_picker] fzf-lua not installed", vim.log.levels.ERROR)
  return
end
```

**Fix:**
```lua
local ok = pcall(require, "fzf-lua")
if not ok then
  vim.notify("[commit_picker] fzf-lua not installed", vim.log.levels.ERROR)
  return
end
```

### WR-03: Inconsistent second return value from get_commits_for_mode

**File:** `lua/commit_picker/git.lua:191`
**Issue:** `get_commits_for_mode()` sometimes returns a second value (base_commit SHA string at line 180) and sometimes returns `nil` (line 191). This inconsistency makes the API contract unclear. Callers in `init.lua:72` handle it (`local commits, base_commit = Git.get_commits_for_mode()`), but the implicit contract should be documented. Additionally, line 186 attempts to call `config.base_commit:sub(1, 7)` without verifying `config.base_commit` is non-nil in all code paths that reach it (though the code path at lines 174-191 does guard this, the fallthrough to line 193 has no such guarantee for unknown modes).

```lua
-- Line 174-191: since_base path
if config.mode == "since_base" and config.base_commit then
  -- ...
  return commits, config.base_commit  -- returns SHA or nil
end

-- Line 193-195: default fallback — no second return value
local count = config.count or 20
return M.get_commit_list(nil, nil, { count = count })  -- missing second value
```

**Fix:** Make return semantics explicit. Either always return two values, or document that the second value is only meaningful in since_base mode. Add nil guard for base_commit access in the fallback:

```lua
-- Line 185: add nil guard before :sub()
local short = config.base_commit and config.base_commit:sub(1, 7) or "unknown"
```

## Info

### IN-01: Redundant length check after regex validation

**File:** `lua/commit_picker/config.lua:57-64`
**Issue:** The regex `%x%x%x%x%x%x%x[%x]*` already requires at least 7 hex characters. The subsequent length check (`#sha < 7`) is mathematically guaranteed to always pass if the regex matched. Same pattern appears at lines 123-129 for base_commit validation.

```lua
-- Lines 57-64: regex already enforces minimum 7 chars
if not sha:match("^%x%x%x%x%x%x%x[%x]*$") then
  return false
end
-- Length check is redundant:
if #sha < 7 or #sha > 40 then
  return false
end
```

**Fix:** Remove the redundant length check or add a comment explaining the defense-in-depth rationale.

### IN-02: Dead code in atomic_write

**File:** `lua/commit_picker/config.lua:268`
**Issue:** The `return true` at line 268 is unreachable. Both branches of the conditional at lines 241-245 return before reaching this line:
- Success path (line 241-243): returns `true`
- Failure path (line 245-266): returns `true` or `false, err`
- Line 268: never reached

**Fix:** Remove the dead `return true` at line 268.

### IN-03: Duplicated validation logic in merge_with_defaults

**File:** `lua/commit_picker/config.lua:155-182`
**Issue:** `merge_with_defaults()` duplicates validation logic already present in `validate_config()`: mode whitelist check (line 164 vs line 93), base_commit format validation (lines 171-178 vs lines 117-137). The two functions use slightly different strategies — `validate_config` rejects with error, `merge_with_defaults` silently corrects with warning. This is intentional (read-time vs save-time), but the duplicated regex and logic increases maintenance burden and risk of drift.

**Fix:** Consider extracting shared validation helpers:
```lua
local function is_valid_mode(mode)
  return type(mode) == "string" and ALLOWED_MODES[mode]
end

local function is_valid_sha_format(sha)
  return type(sha) == "string"
    and sha:match("^%x%x%x%x%x%x%x[%x]*$")
    and #sha >= 7 and #sha <= 40
end
```

### IN-04: Public `_deep_copy` with underscore prefix naming inconsistency

**File:** `lua/commit_picker/config.lua:329`
**Issue:** `_deep_copy` is exported as a public module member (`M._deep_copy`) but uses the leading underscore convention typically reserved for private/internal functions. The AGENTS.md conventions use `local function` for private helpers. This is likely intentional to expose it for tests, but conflicts with the module's own pattern of using `local function` for private helpers (e.g., `merge_with_defaults`, `validate_sha_exists`).

**Fix:** Either keep it as a `local function` and use a different testing strategy, or rename to `M.deep_copy` without the underscore prefix and document it as a public utility.

### IN-05: Base commit git existence check not in settings picker

**File:** `lua/commit_picker/settings.lua:264-324`
**Issue:** `_select_base_commit()` lets users pick from the last 100 commits via fzf-lua picker. While these commits are guaranteed to exist (fetched from git log), the picker doesn't verify the SHA format before setting `pending.base_commit`. The validation happens later in `_save_and_close()` via `Config.validate_config()`, but a user could theoretically craft a scenario where an invalid SHA bypasses validation if save is skipped.

**Severity:** Info only — current implementation is safe because validation happens before write.

**Fix:** No change needed currently. Document the validation chain: select → validate on save → atomic write.

### IN-06: Test writes invalid SHA format as base_commit

**File:** `tests/commit_picker/config_spec.lua:88`
**Issue:** The test at line 88 writes `"HEAD"` as `base_commit`:
```lua
f:write('return {\n  mode = "since_base",\n  count = 10,\n  base_commit = "HEAD",\n}\n')
```
This is invalid per the SHA format validation (not a hex string). However, the test is checking that `save_config({ base_commit = nil })` correctly sets base_commit to nil, so the initial file content with "HEAD" is bypassed by the invalidate+save cycle. This is not a bug but could be misleading — using a valid-format SHA would be clearer.

**Fix:** Replace `"HEAD"` with a valid-format SHA like `"abcdef1234567890abcdef1234567890abcdef12"` in the test setup, or add a comment explaining why the invalid SHA is intentional (it gets overwritten by the valid save_config call).

---

_Reviewed: 2026-04-26T08:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
