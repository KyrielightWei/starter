# Plan: 05 — Commit Picker Configuration

## Goal
Users can customize the commit picker display range and boundaries

## Requirements
- CDRV-03: User can configure how many commits appear in the picker
- CDRV-04: User can set a base commit as the review boundary

## Success Criteria
1. User can configure how many commits appear in the picker (counting from newest backward)
2. User can set a base commit as the review boundary to limit displayed commits

## Approach

### Architecture
Config module (read/write/validate) → Settings picker UI (fzf-lua actions) → Integration (wire into git.lua, init.lua mode routing)

### Config Schema
```lua
return {
  mode = "unpushed",       -- "unpushed" | "last_n" | "since_base"
  count = 20,              -- Used when mode == "last_n"
  base_commit = nil,       -- Full SHA, used when mode == "since_base"
}
```

### File: `~/.config/nvim/commit_picker_config.lua`
- Lua table format (return { ... })
- Created with defaults on first load if missing
- Atomic writes via `vim.uv.fs_rename` with cross-device fallback
- Safe parsing: `pcall(dofile)` + schema validation, no `loadstring()` sandboxing

## Implementation Waves

### Wave 1: Config Module (`lua/commit_picker/config.lua`)
**Goal:** Read/write/validate commit picker configuration

**Tasks:**
1. Create `lua/commit_picker/config.lua` with:
   - `M.get_config()` — reads config file, returns merged with defaults, caches result
   - `M.save_config(new_config)` — atomic write via .tmp → rename with cross-device fallback
   - `M.get_config_path()` — returns `~/.config/nvim/commit_picker_config.lua`
   - `M.validate_config(config)` — validates mode in allowed list, count > 0, base_commit valid SHA or nil
   - `M.reset_to_defaults()` — writes default config
   - `M.invalidate_cache()` — clears cached config (called after external changes)
   - `M.config_file_exists()` — returns boolean (useful for UI state)

2. Schema validation rules:
   - `mode`: must be one of `"unpushed"`, `"last_n"`, `"since_base"`
   - `count`: integer > 0, reasonable max (clamp to 500 if exceeded)
   - `base_commit`: nil or valid git SHA (7-40 hex chars); optionally verify exists in repo via `git cat-file -t <sha>`
   - Unknown fields: ignored (forward-compatible)

3. Defaults: `{ mode = "unpushed", count = 20, base_commit = nil }`

4. Cache behavior:
   - Cache config after first read
   - Invalidate on save() or when triggered by config.watcher (if integrated later)
   - Cache keyed by file mtime for automatic staleness detection:
     ```lua
     local stat = vim.loop.fs_stat(path)
     if stat and cached_mtime and stat.mtime.sec == cached_mtime.sec then
       return cached_config
     end
     ```

5. Safe config parsing:
   - Read file content as string
   - Use `pcall(dofile, path)` to safely parse the Lua table
   - If dofile fails (corrupted file), return defaults with warning
   - After parsing, validate every field against schema before returning
   - Do NOT use `loadstring()` — Lua 5.1 does not support sandboxing

6. File structure:
   - All validation is inline in `config.lua` — no external validator dependency
   - The Provider Manager's `validator.lua` only validates provider names, which is unrelated to commit_picker config schema

7. Verification:
   - Module loads without errors: `nvim --headless -c "lua require('commit_picker.config')" -c "q"`
   - `get_config()` returns defaults when config file missing
   - `save_config()` creates valid Lua file that can be read back
   - Invalid configs rejected by validate with descriptive error messages
   - Cache invalidation works correctly
   - `base_commit` SHA is verified to exist in git history (via `git cat-file -t`)

### Test Specs (Wave 1.5)
Create `tests/commit_picker/config_spec.lua` with plenary.nvim specs:
- `get_config()` returns defaults when file missing
- `save_config()` writes parseable file that can be read back
- `validate_config()` rejects invalid mode, negative count, non-hex SHA
- `validate_config()` rejects valid-format SHA not in git history
- `reset_to_defaults()` writes known-good config
- `config_file_exists()` returns correct boolean

### Wave 2: Settings Panel UI (`lua/commit_picker/settings.lua`)
**Goal:** fzf-lua picker for editing commit picker settings

**Tasks:**
1. Create `lua/commit_picker/settings.lua` with:
   - `M.open()` — fzf-lua picker showing current settings as editable items
   - Mode selector: picker to choose unpushed / last N / since base
   - Count setter: floating input dialog for count value
   - Base commit setter:
     - When mode is "since_base", prompt user to pick a commit (reuse display.lua's picker temporarily or use fzf-lua with git log)
     - Store full SHA for stability across rebases/amendments
   - Save action: persist changes via config.save_config()

2. Picker display format (reuses Provider Manager picker pattern):
   ```
   ◦ Mode: unpushed [▶ change]
   ◦ Count: 20 [▶ change]
   ◦ Base: none [▶ set]        -- shown as SHA when set
   ◦ [Save]                    -- action row
   ```

3. Keymaps:
   - `<CR>`: edit selected setting
   - `<C-s>`: save and exit
   - `<C-r>`: reset to defaults
   - `<C-?>`: show help

4. Mode selection flow:
   - Open fzf-lua picker with options: "unpushed", "last_n (recent N commits)", "since_base (from base commit)"
   - Selection updates in-memory config, marks as changed

5. Count input flow:
   - Show floating input dialog (reuse ui_util.input_dialog pattern if available, or vim.ui.input)
   - Validate integer > 0 and <= 500
   - Update in-memory config, mark as changed

6. Base commit selection flow:
   - Fetch recent commits (last 100 from HEAD) via git.lua
   - Show in fzf-lua picker with commit hash + subject
   - Selected commit's full SHA stored in config.base_commit
   - Clear option available (set to nil)

7. File structure:
   - No separate validator/file_util/ui_util needed in commit_picker/ — all config validation is inline in config.lua
   - The Provider Manager's validator only handles provider names; commit_picker uses a completely different schema
   - Settings UI uses fzf-lua patterns from both provider_manager/picker.lua and commit_picker/display.lua

8. Verification:
   - `:AICommitConfig` opens settings picker
   - Mode change persists after save
   - Count change reflected in picker
   - Base commit stored as full SHA
   - Reset to defaults clears all customizations

### Wave 3: Integration (modify existing files)
**Goal:** Wire configuration into Phase 4 picker, implement mode routing

**Tasks:**
1. Modify `lua/commit_picker/git.lua`:
   - Add `M.get_commit_range()` function that reads config and returns appropriate git args:
     - `unpushed` → `origin/HEAD..HEAD` (same as current get_unpushed)
     - `last_n` → last N commits from HEAD (uses existing get_commit_list with config.count)
     - `since_base` → `base_commit..HEAD` (uses existing get_commit_list)
   - Add `M.get_commits_for_mode()` — high-level function that handles mode routing and fallback
   - Keep existing functions for backward compatibility

2. Modify `lua/commit_picker/init.lua`:
   - Load config on `M.open()` instead of hardcoded unpushed logic
   - Route to appropriate git function based on config.mode
   - Fallback chain:
     - If configured mode fails (e.g., base_commit invalid, no remote for unpushed), fall back to last N (config.count)
     - Show warning message on fallback with diagnostic info: include ahead/behind counts for unpushed mode, base SHA for since_base mode
     - Example: `string.format("未找到远程提交 (ahead %d, behind %d)，回退到最近 %d 条", ab.ahead, ab.behind, count)`
     - Example: `string.format("基础提交不可用 (%s)，回退到最近 %d 条", base_commit:sub(1,7), count)`
   - Add `:AICommitConfig` user command in `setup()` function (registered alongside existing `:AICommitPicker` command)
   - **No change needed to `ai/init.lua` for the command** — `commit_picker/init.lua:setup()` is called by `ai/init.lua:219-222` which handles all command registration

3. Modify `lua/commit_picker/display.lua`:
   - Accept additional option: `opts.base_commit` (full SHA string) for highlighting
   - Interface: `show_picker(commits, { on_select = ..., base_commit = "full_sha" })`
   - When `base_commit` is provided, iterate commits to find matching SHA
   - Prefix the matching commit line with marker: `★ base | abc1234 feat: ...`
   - Use a different ANSI color (e.g., yellow `\27[38;5;220m`) for the base commit marker

4. Keymap registration (`lua/ai/init.lua` or `lua/commit_picker/init.lua`):
   - Check existing keymaps: commit picker is `<leader>kC`
   - Config command: `:AICommitConfig` (standalone user command)
   - No new keymap needed — config accessible via command or potentially as action within picker (`<C-c>` to open config from picker)

5. Fallback behavior details:
   - `unpushed` mode fallback: if no remote or `origin/HEAD` doesn't exist, warn and fallback to `last_n`
   - `since_base` mode fallback: if `base_commit` not found in history or invalid SHA, warn and fallback to `last_n`
   - `last_n` mode: no fallback needed (always works unless repo empty)
   - All fallbacks update display with warning message

6. Verification:
   - `:AICommitPicker` respects configured mode
   - Mode switching works: unpushed → last N → since base
   - Invalid base_commit triggers fallback with warning
   - `<leader>kC` still opens picker, `:AICommitConfig` opens settings
   - Base commit highlighted in picker display when mode is "since_base"

## Threat Model

| Threat | Mitigation |
|--------|-----------|
| T-05-01: Config file tampering (arbitrary Lua code execution) | Use safe parsing: `pcall(dofile)` + field validation, no `loadstring` |
| T-05-02: Path traversal in config path | Config path is fixed constant, not user-provided |
| T-05-03: Invalid SHA injection into git commands | Validate base_commit is 7-40 hex chars AND exists in git history before passing to git |
| T-05-04: Count overflow (e.g., 999999) | Clamp count to reasonable range (1-500) |
| T-05-05: Config file corruption (syntax error) | Catch parse errors with pcall(dofile), return defaults, warn user |
| T-05-06: Race condition on config write | Atomic writes via `vim.uv.fs_rename` with cross-device fallback chain |

## Verification Strategy

### Automated Checks
1. `config.lua` exports all required functions: get_config, save_config, get_config_path, validate_config, reset_to_defaults, invalidate_cache, config_file_exists
2. Default config loads when file missing
3. Config saves as valid Lua (can be read back and parsed via pcall(dofile))
4. Invalid configs rejected (bad mode, negative count, invalid SHA, not-in-history SHA) with descriptive errors
5. Mode routing in `init.lua` calls correct git function
6. `:AICommitConfig` command registered in `commit_picker/init.lua:setup()` (not in ai/init.lua)
7. Fallback handles missing remote, invalid base, and parse errors
8. Atomic write works: .tmp file renamed to final path with cross-device fallback
9. Cache invalidation works: get_config() after save() returns new values
10. `tests/commit_picker/config_spec.lua` specs pass via plenary.nvim

### Manual Checks
1. Open `:AICommitConfig`, change mode to "last_n", set count to 50, save
2. Open `<leader>kC`, verify 50 commits shown
3. Change mode to "since_base", set base commit via picker
4. Verify picker shows commits only since base
5. Verify base commit highlighted with marker in picker display
6. Reset to defaults, verify unpushed is default again
7. Delete config file, verify defaults load on next open
8. Write invalid config file manually, verify error message and fallback to defaults

## Dependencies
- Phase 4 (commit_picker/ modules) — must exist and load
- fzf-lua — already a dependency for display.lua
- git >= 2.31 — already enforced by project
- No new external dependencies
- Config validation is fully inline in `config.lua` — no dependency on provider_manager's validator

## Implementation Notes

### Config Parsing Safety (HIGH-02 fix)
Use `pcall(dofile, path)` + field validation for user-owned config files:
1. Try `pcall(dofile, path)` — safe for user-owned files in `~/.config/nvim/`
2. If dofile fails (corrupted/malicious content), return defaults and warn user
3. After parsing, validate every field against schema before returning
4. Do NOT use `loadstring()` — Lua 5.1 has no sandbox, it grants full environment access

Example:
```lua
local ok, raw = pcall(dofile, path)
if not ok or type(raw) ~= "table" then
  vim.notify("配置文件格式错误，使用默认设置", vim.log.levels.WARN)
  return DEFAULT_CONFIG
end

local config = {}
config.mode = type(raw.mode) == "string" and raw.mode or "unpushed"
config.count = type(raw.count) == "number" and math.max(1, math.min(500, raw.count)) or 20
config.base_commit = (type(raw.base_commit) == "string"
  and raw.base_commit:match("^%x%x%x%x%x%x%x[%x]*$")) or nil
return config
```

### File Atomic Write Pattern (HIGH-01 fix)
Use `vim.uv.fs_rename` which has a proper fallback chain built-in:
```lua
local function atomic_write(path, content)
  local tmp_path = path .. ".tmp"

  -- Write to temp file
  local f = io.open(tmp_path, "w")
  if not f then
    return false, "无法写入临时文件"
  end
  f:write(content)
  f:close()

  -- Rename: vim.uv.fs_rename handles cross-device fallback
  local done = false
  vim.uv.fs_rename(tmp_path, path, function(err)
    if err then
      -- Fallback: read temp and write directly (cross-device rename fails)
      local tmp_f = io.open(tmp_path, "r")
      if tmp_f then
        local data = tmp_f:read("*all")
        tmp_f:close()
        local final_f = io.open(path, "w")
        if final_f then
          final_f:write(data)
          final_f:close()
          os.remove(tmp_path)
        end
      end
    end
    done = true
  end)

  -- Spin wait for async callback (or use vim.wait)
  while not done do end

  return true
end
```

**Correctness note:** `os.rename()` returns `nil` on success and `"rename error"` on failure. The truthiness check must be `if ok == nil` (success) not `if not ok` (which treats nil as false). Using `vim.uv.fs_rename` with callback is safer and handles cross-device moves automatically.

### Mode Routing Logic (in git.lua)
```lua
function M.get_commits_for_mode()
  local config = require("commit_picker.config").get_config()

  if config.mode == "unpushed" then
    local ok, commits = pcall(M.get_unpushed)
    if ok and #commits > 0 then return commits end
    -- fallback with diagnostic info
    local ab = Git.get_ahead_behind()
    vim.notify(string.format("未找到远程提交 (ahead %d, behind %d)，回退到最近 %d 条",
      ab.ahead, ab.behind, config.count), vim.log.levels.WARN)
    return M.get_commit_list(nil, nil, { count = config.count })
  end

  if config.mode == "last_n" then
    return M.get_commit_list(nil, nil, { count = config.count })
  end

  if config.mode == "since_base" and config.base_commit then
    local ok, commits = pcall(M.get_commit_list, config.base_commit, "HEAD")
    if ok then return commits end
    -- fallback with diagnostic info
    vim.notify(string.format("基础提交不可用 (%s)，回退到最近 %d 条",
      config.base_commit:sub(1, 7), config.count), vim.log.levels.WARN)
    return M.get_commit_list(nil, nil, { count = config.count })
  end

  -- default fallback
  return M.get_commit_list(nil, nil, { count = config.count })
end
```

### Error Messages (Chinese, per commit_picker convention)
- 配置文件加载失败: 无法加载配置文件，使用默认设置
- 配置保存成功: 提交选择器配置已保存
- 配置已重置: 已恢复默认设置
- 模式切换警告: 回退到最近 N 条提交
- Base commit 无效: 基础提交不可用，已回退
