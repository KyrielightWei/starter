---
merge_commit: 3025b7e
reviewers: [opencode]
reviewed_at: 2026-04-17T15:10:00+08:00
files_reviewed:
  - lua/ai/providers.lua
  - lua/ai/opencode.lua
  - lua/ai/config_resolver.lua
  - lua/ai/ecc.lua
  - lua/ai/init.lua
  - opencode.template.jsonc
  - ECC_GUIDE.md
---

# Cross-AI Code Review — Merge 3025b7e

## Context

A merge was performed between two branches:
- **Local branch (4d77db7)**: Fix for OpenCode config (auto-prefix provider name in model config)
- **Remote branch (b9937f4)**: Features for ECC installation and default model switch

---

## OpenCode Review

# Cross-AI Code Review Report

## Summary

This merge combines changes from two branches:
- **Local**: Fix for OpenCode config (provider prefix handling)
- **Remote**: ECC installation features and default model switch

I've identified several **critical logical conflicts** and potential issues that need attention.

---

## 🔴 HIGH Severity Issues

### 1. Logical Conflict: Model Format Inconsistency

**Location**: `lua/ai/opencode.lua` (lines 182-191 removed), `lua/ai/providers.lua`, `opencode.template.jsonc`

**Problem**: The `ensure_provider_prefix()` function was removed, but model format expectations are now inconsistent:

```lua
-- providers.lua
M.default_model = "qwen3.6-plus"  -- NO provider prefix

-- opencode.template.jsonc
"model": "bailian_coding/qwen3.6-plus",  -- WITH provider prefix
```

**Impact**:
- Users writing `"model": "glm-5"` in template will no longer get auto-prefixed
- The warning about missing provider prefix was also removed
- `generate_config()` no longer normalizes model names

**Risk**: OpenCode may fail to find models if format mismatch occurs.

**Recommendation**: Either:
1. Keep `ensure_provider_prefix()` for backward compatibility
2. Document clearly that models MUST include provider prefix
3. Update `providers.lua` default to use full format: `M.default_model = "bailian_coding/qwen3.6-plus"`

---

### 2. Breaking Change: Config Directory Migration

**Location**: `lua/ai/opencode.lua` (line 8-10), `lua/ai/config_resolver.lua` (lines 269-270)

**Problem**: Config directory changed from `~/.config/opencode/` to `~/.opencode/`:

```lua
-- Before
local xdg_config = os.getenv("XDG_CONFIG_HOME") or vim.fn.expand("~/.config")
return xdg_config .. "/opencode"

-- After
return vim.fn.expand("~/.opencode")
```

**Impact**:
- Existing API keys in `~/.config/opencode/api_key_*.txt` will NOT be found
- Users must manually migrate their keys
- No migration path provided

**Recommendation**:
```lua
local function get_opencode_config_dir()
  local new_dir = vim.fn.expand("~/.opencode")
  local old_dir = (os.getenv("XDG_CONFIG_HOME") or vim.fn.expand("~/.config")) .. "/opencode"
  
  -- Auto-migrate if old dir exists and new doesn't
  if vim.fn.isdirectory(old_dir) == 1 and vim.fn.isdirectory(new_dir) ~= 1 then
    vim.notify("Migrating OpenCode config from " .. old_dir .. " to " .. new_dir, vim.log.levels.WARN)
    -- Migration logic here
  end
  
  return new_dir
end
```

---

### 3. API Endpoint Change Without Migration

**Location**: `lua/ai/providers.lua` (line 95)

**Problem**:
```lua
-- Before
endpoint = "https://coding-intl.dashscope.aliyuncs.com/v1",

-- After  
endpoint = "https://coding.dashscope.aliyuncs.com/v1",
```

**Impact**: Users relying on the international endpoint (`coding-intl`) will be silently switched to domestic endpoint.

**Recommendation**: Add both endpoints or provide a migration notice:
```lua
M.register("bailian_coding", {
  api_key_name = "BAILIAN_CODING_API_KEY",
  endpoint = "https://coding.dashscope.aliyuncs.com/v1",
  -- Alternative for international users
  -- endpoint_intl = "https://coding-intl.dashscope.aliyuncs.com/v1",
  ...
})
```

---

## 🟡 MEDIUM Severity Issues

### 4. Dead Code: Coroutine Function Never Used

**Location**: `lua/ai/ecc.lua` (lines 100-132)

**Problem**: `run_cmd()` uses coroutines but is never called:

```lua
local function run_cmd(cmd, opts)
  -- ...
  local co = coroutine.running()
  -- ...
  if co then
    coroutine.yield()  -- This is never properly managed
  end
  -- ...
end
```

All actual usage is through `run_cmd_sync()` which is synchronous.

**Impact**: Dead code, potential confusion for maintainers.

**Recommendation**: Remove unused `run_cmd()` or properly implement async installation with coroutines.

---

### 5. Blocking UI During ECC Installation

**Location**: `lua/ai/ecc.lua` (lines 276-298)

**Problem**: `install_async()` claims to be async but actually blocks:

```lua
function M.install_async(opts, callback)
  -- ...
  vim.defer_fn(function()
    local ok, msg = M.install(opts, update)  -- This calls run_cmd_sync!
    -- ...
  end, 100)
end
```

`M.install()` → `run_cmd_sync()` → `vim.fn.systemlist()` which **blocks Neovim**.

**Impact**: UI freezes for 2-5 minutes during installation, making the "async" claim misleading.

**Recommendation**: Use `vim.fn.jobstart()` with callbacks for truly async installation, or remove the async wrapper and document that installation blocks.

---

### 6. Incomplete Error Recovery

**Location**: `lua/ai/ecc.lua` (line 219)

**Problem**: Temp directory cleanup only happens on success:

```lua
-- 运行安装脚本
ok, msg = run_install(target, profile, on_progress)
if not ok then
  return false, msg  -- Returns early WITHOUT cleanup
end

-- 清理临时目录
vim.fn.delete(ECC_TEMP_DIR, "rf")
```

**Impact**: Failed installations leave `/tmp/ecc-install/` behind.

**Recommendation**:
```lua
-- Always cleanup
local function cleanup()
  if vim.fn.isdirectory(ECC_TEMP_DIR) == 1 then
    vim.fn.delete(ECC_TEMP_DIR, "rf")
  end
end

-- In install function, use pcall or finally pattern
local ok, msg = xpcall(function()
  -- installation steps
end, function(err)
  cleanup()
  return err
end)
cleanup()
```

---

### 7. Missing Variable Usage

**Location**: `lua/ai/opencode.lua` (line 394)

**Problem**:
```lua
local keys, profile = read_ai_keys()
```

These variables are declared but never used in the function.

**Recommendation**: Either use them or remove the declaration.

---

## 🟢 LOW Severity Issues

### 8. Inconsistent Timeout Values

**Location**: `lua/ai/ecc.lua`

**Problem**: Various timeout values with no documentation:
- `run_cmd`: 120000ms (2 min)
- `run_cmd_sync`: 300000ms (5 min) default
- `clone_repo`: 120000ms
- `install_deps`: 180000ms (3 min)
- `run_install`: 120000ms

**Recommendation**: Define constants with comments:
```lua
local TIMEOUT = {
  GIT_CLONE = 120000,  -- 2 minutes
  NPM_INSTALL = 180000, -- 3 minutes
  SCRIPT_RUN = 120000,  -- 2 minutes
}
```

---

### 9. Silent Model Switch

**Location**: `lua/ai/providers.lua`, `opencode.template.jsonc`

**Problem**: Default model changed from `glm-5` to `qwen3.6-plus` without user notification.

**Recommendation**: Add migration notice or allow users to opt-out:
```lua
if was_using_glm5 then
  vim.notify("Default model changed to qwen3.6-plus. To revert, update your config.", vim.log.levels.INFO)
end
```

---

### 10. ECC Installation Prompts During Config Generation

**Location**: `lua/ai/opencode.lua` (line 412-413)

**Problem**: `Ecc.ensure_installed()` is called synchronously during `write_config()`:

```lua
function M.write_config()
  local Ecc = require("ai.ecc")
  local ecc_installed = Ecc.ensure_installed({ target = "opencode", profile = "developer" })
  -- ...
```

**Impact**: Users generating config may be interrupted with installation prompts.

**Recommendation**: Make this optional or move to a separate command:
```lua
function M.write_config(opts)
  opts = opts or {}
  if opts.check_ecc ~= false then
    local ecc_installed = Ecc.ensure_installed({ target = "opencode", profile = "developer" })
  end
  -- ...
```

---

## Edge Cases Not Handled

### 11. Missing Validation for Model Format in Template

The template comment says:
```jsonc
// 默认模型 (格式: provider/model)
"model": "bailian_coding/qwen3.6-plus",
```

But there's no validation in `validate_template()` to enforce this format.

**Recommendation**:
```lua
if config.model and not config.model:match("^[%w_]+/.+$") then
  table.insert(warnings, "model should be in 'provider/model' format")
end
```

---

### 12. Race Condition in Async Installation

**Location**: `lua/ai/ecc.lua` (lines 381-397)

**Problem**: When installing to both Claude and OpenCode, the callback chain doesn't wait for first installation to complete:
```lua
M.install_async({
  target = "claude",
  -- ...
}, function(ok, msg)
  if ok then
    -- This runs while previous install might still be running
    M.install_async({ target = "opencode", ... })
  end
end)
```

Since `install_async` is already async (via `defer_fn`), this creates nested async calls.

---

## Security Review

### ✅ Good: Input Validation

The `run_install` function properly validates inputs:
```lua
if not VALID_TARGETS[target] then
  return false, "无效的安装目标: " .. tostring(target)
end
if not VALID_PROFILES[profile] then
  return false, "无效的安装 profile: " .. tostring(profile)
end
```

### ✅ Good: No Shell Injection

Using `vim.fn.jobstart()` and `vim.fn.systemlist()` instead of `os.execute()`.

### ⚠️ Warning: No Signature Verification

Git clone doesn't verify commit signatures:
```lua
local cmd = string.format("git clone %s %s --depth=1", ECC_REPO, ECC_TEMP_DIR)
```

**Recommendation**: Consider adding GPG verification for releases.

---

## Recommendations Summary

| Priority | Issue | Action |
|----------|-------|--------|
| **HIGH** | Model format inconsistency | Restore `ensure_provider_prefix()` or document requirement |
| **HIGH** | Config directory migration | Add auto-migration logic |
| **HIGH** | Endpoint change | Add migration notice or support both |
| **MEDIUM** | Dead coroutine code | Remove or properly implement |
| **MEDIUM** | Blocking UI | Use true async or document blocking |
| **MEDIUM** | Incomplete cleanup | Add finally/try-catch pattern |
| **MEDIUM** | Unused variables | Remove `keys, profile = read_ai_keys()` |
| **LOW** | Timeout inconsistency | Define constants |
| **LOW** | Silent model switch | Add user notification |
| **LOW** | ECC prompt during config | Make optional |

---

## Test Cases Needed

Before merging, verify:

1. **Model format migration**: User has `"model": "glm-5"` in template → what happens?
2. **Config directory migration**: User has keys in `~/.config/opencode/` → migration path?
3. **International endpoint users**: Are they affected by endpoint change?
4. **Fresh install**: ECC installation works without blocking UI?
5. **Failed installation**: Does cleanup happen correctly?
6. **Template with invalid model format**: Is validation working?

---

## Consensus Summary

Since only OpenCode was available for this review (Claude CLI skipped due to current runtime environment), there is no multi-reviewer consensus. However, the identified issues are critical and should be addressed:

### Top Priority Concerns (HIGH Severity)

1. **Model Format Inconsistency** — The removal of `ensure_provider_prefix()` creates a logical conflict between:
   - `providers.lua` using plain model names
   - Template expecting `provider/model` format
   - No auto-prefixing for backward compatibility

2. **Config Directory Migration** — Users with existing keys in `~/.config/opencode/` will lose access to them

3. **Endpoint Change** — Silent switch from international to domestic endpoint could break existing workflows

### Recommended Actions

| Action | Priority |
|--------|----------|
| Restore `ensure_provider_prefix()` or enforce provider/model format | HIGH |
| Add auto-migration for config directory | HIGH |
| Provide endpoint migration notice | HIGH |
| Remove unused `run_cmd()` coroutine code | MEDIUM |
| Fix `install_async()` to be truly async or document blocking behavior | MEDIUM |
| Add cleanup on installation failure | MEDIUM |
| Remove unused `keys, profile` variables | MEDIUM |

---

## Next Steps

1. Address HIGH severity issues before pushing to production
2. Consider adding migration guide for affected users
3. Run test cases to verify fixes work correctly
4. Update documentation to clarify model format requirements