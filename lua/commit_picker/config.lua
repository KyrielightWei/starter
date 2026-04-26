-- lua/commit_picker/config.lua
-- Commit picker configuration: read/write/validate with atomic writes and caching

local M = {}

----------------------------------------------------------------------
-- Constants and defaults
----------------------------------------------------------------------
local DEFAULT_CONFIG = {
  mode = "unpushed",
  count = 20,
  base_commit = nil,
}

local ALLOWED_MODES = {
  unpushed = true,
  last_n = true,
  since_base = true,
}

local MAX_COUNT = 500
local MIN_COUNT = 1

----------------------------------------------------------------------
-- Cached state
----------------------------------------------------------------------
local cached_config = nil
local cached_mtime = nil

----------------------------------------------------------------------
-- Deep copy helper (IN-04 fix: defined early for use below)
----------------------------------------------------------------------
local function deep_copy(t)
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = v
  end
  return copy
end

----------------------------------------------------------------------
-- M.get_config_path()
-- Returns the absolute path to the config file
----------------------------------------------------------------------
function M.get_config_path()
  return vim.fn.expand("~/.config/nvim/commit_picker_config.lua")
end

----------------------------------------------------------------------
-- M.config_file_exists()
-- Returns true if config file exists on disk
----------------------------------------------------------------------
function M.config_file_exists()
  local path = M.get_config_path()
  return vim.fn.filereadable(path) == 1
end

----------------------------------------------------------------------
-- Validate a git SHA exists in the repository
-- Returns true if valid format AND exists in git history
----------------------------------------------------------------------
local function validate_sha_exists(sha)
  if not sha or type(sha) ~= "string" then
    return false
  end

  -- Format check: 7-40 hex characters (regex enforces minimum 7 chars)
  if not sha:match("^%x%x%x%x%x%x%x[%x]*$") then
    return false
  end

  -- Max length check (regex enforces minimum, but not maximum)
  if #sha > 40 then
    return false
  end

  -- Verify exists in git history via git cat-file
  local ok, result = pcall(function()
    return vim.system({ "git", "cat-file", "-t", sha }):wait()
  end)

  if not ok then
    return false
  end

  return result.code == 0
end

----------------------------------------------------------------------
-- M.validate_config(config)
-- Validates config table against schema
-- Returns { ok = true } or { ok = false, error = "message" }
----------------------------------------------------------------------
function M.validate_config(config)
  if type(config) ~= "table" then
    return { ok = false, error = "配置必须是表类型" }
  end

  -- Validate mode
  if config.mode ~= nil then
    if type(config.mode) ~= "string" then
      return { ok = false, error = "mode 必须是字符串" }
    end
    if not ALLOWED_MODES[config.mode] then
      return { ok = false, error = string.format(
        "无效模式 '%s'，允许的模式: unpushed, last_n, since_base", config.mode
      )}
    end
  end

  -- Validate count
  if config.count ~= nil then
    if type(config.count) ~= "number" then
      return { ok = false, error = "count 必须是数字" }
    end
    if config.count < MIN_COUNT then
      return { ok = false, error = string.format("count 必须大于等于 %d", MIN_COUNT) }
    end
    if config.count > MAX_COUNT then
      return { ok = false, error = string.format("count 不能超过 %d", MAX_COUNT) }
    end
    if config.count ~= math.floor(config.count) then
      return { ok = false, error = "count 必须是整数" }
    end
  end

  -- Validate base_commit
  if config.base_commit ~= nil then
    if type(config.base_commit) ~= "string" then
      return { ok = false, error = "base_commit 必须是字符串或 nil" }
    end

    -- Format check
    if not config.base_commit:match("^%x%x%x%x%x%x%x[%x]*$") then
      return { ok = false, error = "base_commit 必须是有效的 git SHA (7-40 位十六进制字符)" }
    end

    -- Length check
    if #config.base_commit < 7 or #config.base_commit > 40 then
      return { ok = false, error = "base_commit 长度必须在 7-40 位之间" }
    end

    -- Verify exists in git history
    if not validate_sha_exists(config.base_commit) then
      return { ok = false, error = string.format(
        "基础提交不存在于 git 历史中: %s", config.base_commit:sub(1, 7)
      )}
    end
  end

  return { ok = true }
end

----------------------------------------------------------------------
-- M.invalidate_cache()
-- Clears cached config (called after external changes)
----------------------------------------------------------------------
function M.invalidate_cache()
  cached_config = nil
  cached_mtime = nil
end

----------------------------------------------------------------------
-- Merge raw config with defaults
-- NOTE: This provides type coercion and fallback only — not full validation.
-- validate_config() should be called separately for user input (IN-03 fix).
----------------------------------------------------------------------
local function merge_with_defaults(raw)
  local config = {}
  config.mode = type(raw.mode) == "string" and raw.mode or DEFAULT_CONFIG.mode
  config.count = type(raw.count) == "number" and raw.count or DEFAULT_CONFIG.count

  -- Clamp count to valid range
  config.count = math.max(MIN_COUNT, math.min(MAX_COUNT, config.count))

  -- Fallback mode if invalid
  if not ALLOWED_MODES[config.mode] then
    config.mode = DEFAULT_CONFIG.mode
  end

  -- Accept base_commit if format looks reasonable (full validation in validate_config)
  if raw.base_commit ~= nil and type(raw.base_commit) == "string"
     and raw.base_commit:match("^%x%x%x%x%x%x%x[%x]*$") then
    config.base_commit = raw.base_commit
  end

  return config
end

----------------------------------------------------------------------
-- M.get_config()
-- Reads config file, returns merged with defaults, caches result
-- Cache keyed by file mtime for automatic staleness detection
----------------------------------------------------------------------
function M.get_config()
  local path = M.get_config_path()

  -- Check file stat for cache staleness
  local stat = vim.loop.fs_stat(path)

  -- Return cached config if mtime unchanged
  if stat and cached_mtime and stat.mtime.sec == cached_mtime.sec and stat.mtime.nsec == cached_mtime.nsec then
    return cached_config
  end

  -- File doesn't exist — return defaults (no caching for missing file)
  if not stat then
    return deep_copy(DEFAULT_CONFIG)
  end

  -- Parse config file using pcall(dofile) — safe for user-owned files
  local ok, raw = pcall(dofile, path)

  if not ok or type(raw) ~= "table" then
    vim.notify("commit_picker 配置文件格式错误，使用默认设置", vim.log.levels.WARN)
    return deep_copy(DEFAULT_CONFIG)
  end

  -- Merge with defaults and validate fields
  local config = merge_with_defaults(raw)

  -- Update cache
  cached_config = config
  cached_mtime = { sec = stat.mtime.sec, nsec = stat.mtime.nsec }

  return config
end

----------------------------------------------------------------------
-- Atomic write helper: write to .tmp, then os.rename with cross-device fallback
-- Uses synchronous os.rename for headless compatibility (IN-02 fix)
----------------------------------------------------------------------
local function atomic_write(path, content)
  local tmp_path = path .. ".tmp"

  -- Write to temp file
  local f = io.open(tmp_path, "w")
  if not f then
    return false, "无法写入临时文件"
  end
  f:write(content)
  f:close()

  -- Try os.rename first (works on same filesystem)
  -- os.rename returns (true) or (nil, nil) on success, (nil, error_string) on failure
  local success, err = os.rename(tmp_path, path)
  if success or (success == nil and err == nil) then
    return true
  end

  -- Fallback: cross-device — read temp and write directly
  local tmp_f = io.open(tmp_path, "r")
  if not tmp_f then
    os.remove(tmp_path)
    return false, "无法读取临时文件"
  end
  local data = tmp_f:read("*all")
  tmp_f:close()

  local final_f = io.open(path, "w")
  if not final_f then
    os.remove(tmp_path)
    return false, "无法写入目标文件"
  end
  final_f:write(data)
  final_f:close()
  os.remove(tmp_path)

  return true
end

----------------------------------------------------------------------
-- M.save_config(new_config)
-- Atomic write via .tmp → rename with cross-device fallback
-- Validates before saving, invalidates cache on success
----------------------------------------------------------------------
function M.save_config(new_config)
  if type(new_config) ~= "table" then
    return false, "配置必须是表类型"
  end

  -- Validate before saving
  local validation = M.validate_config(new_config)
  if not validation.ok then
    return false, validation.error
  end

  -- Serialize to Lua table format
  local lines = {}
  table.insert(lines, "-- Commit picker configuration")
  table.insert(lines, string.format("mode = %q,", new_config.mode or "unpushed"))
  table.insert(lines, string.format("count = %d,", new_config.count or 20))

  if new_config.base_commit then
    table.insert(lines, string.format("base_commit = %q,", new_config.base_commit))
  else
    table.insert(lines, "base_commit = nil,")
  end

  local content = "return {\n  " .. table.concat(lines, "\n  ") .. "\n}\n"

  -- Atomic write
  local path = M.get_config_path()
  local ok, err = atomic_write(path, content)
  if not ok then
    return false, err
  end

  -- Invalidate cache so next get_config() reads fresh data
  M.invalidate_cache()

  return true
end

----------------------------------------------------------------------
-- M.reset_to_defaults()
-- Writes default config file
----------------------------------------------------------------------
function M.reset_to_defaults()
  local ok, err = M.save_config(deep_copy(DEFAULT_CONFIG))
  if not ok then
    return false, err
  end
  return true
end

-- Backward compatibility: expose on M for test access
M._deep_copy = deep_copy

return M
