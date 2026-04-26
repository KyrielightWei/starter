-- lua/ai/provider_manager/cache.lua
-- Detection result caching with TTL-based invalidation
-- Stores results at vim.fn.stdpath("state")/ai_detection_cache.lua
-- CR-02 FIX: Uses vim.json.decode instead of dofile() to prevent
-- arbitrary code execution via tampered cache files
-- WR-03 FIX: In-memory cache layer to reduce disk I/O during batch checks

local M = {}

local TTL_BY_STATUS = {
  available   = 300,
  timeout     = 60,
  error       = 30,
  unavailable = 120,
}

local DEFAULT_TTL = 60

-- In-memory cache layer to avoid repeated disk I/O during batch checks
local _memory_cache = nil

----------------------------------------------------------------------
-- Path helpers
----------------------------------------------------------------------
local function cache_dir()
  return vim.fn.stdpath("state")
end

local function cache_file()
  local dir = cache_dir()
  vim.fn.mkdir(dir, "p")
  return dir .. "/ai_detection_cache.lua"
end

----------------------------------------------------------------------
-- Private: Load cache from disk using safe JSON deserialization
-- CR-02 FIX: Replaced pcall(dofile, path) — dofile runs arbitrary code
----------------------------------------------------------------------
local function load_cache()
  local path = cache_file()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end

  local lines = vim.fn.readfile(path)
  if not lines or #lines == 0 then
    return {}
  end
  local content = table.concat(lines, "\n")
  local ok, data = pcall(vim.json.decode, content, { luanil = { object = true, array = true } })
  if not ok or type(data) ~= "table" then
    vim.notify("Cache file corrupted, resetting", vim.log.levels.WARN)
    return {}
  end

  return data
end

----------------------------------------------------------------------
-- Private: Write cache to disk as JSON
----------------------------------------------------------------------
local function save_cache(data)
  local path = cache_file()
  local dir = cache_dir()
  vim.fn.mkdir(dir, "p")

  local content = vim.json.encode(data)
  vim.fn.writefile(vim.split(content, "\n"), path)
end

----------------------------------------------------------------------
-- Private: Get cache data (from memory or disk)
----------------------------------------------------------------------
local function get_cache_data()
  if _memory_cache then
    return _memory_cache
  end
  _memory_cache = load_cache()
  return _memory_cache
end

----------------------------------------------------------------------
-- Cache get/set/invalidate/is_valid/get_all/clear
----------------------------------------------------------------------

function M.get(provider, model)
  local data = get_cache_data()
  if data[provider] then
    return data[provider][model]
  end
  return nil
end

function M.set(provider, model, result)
  local data = get_cache_data()

  if not data[provider] then
    data[provider] = {}
  end

  data[provider][model] = {
    status        = result.status or "error",
    response_time = result.response_time or 0,
    error_msg     = result.error_msg or "",
    timestamp     = result.timestamp or os.time(),
  }

  save_cache(data)
end

function M.is_valid(provider, model)
  local entry = M.get(provider, model)
  if not entry then
    return false
  end

  local now = os.time()
  local ttl = TTL_BY_STATUS[entry.status] or DEFAULT_TTL

  return (now - entry.timestamp) < ttl
end

function M.invalidate(provider, model)
  local data = get_cache_data()

  if data[provider] then
    data[provider][model] = nil
    if not next(data[provider]) then
      data[provider] = nil
    end
    save_cache(data)
  end
end

function M.get_all()
  return get_cache_data()
end

function M.clear()
  _memory_cache = nil
  local path = cache_file()
  if vim.fn.filereadable(path) == 1 then
    os.remove(path)
  end
end

return M
