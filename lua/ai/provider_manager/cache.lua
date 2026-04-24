-- lua/ai/provider_manager/cache.lua
-- Detection result caching with TTL-based invalidation
-- Stores results at vim.fn.stdpath("state")/ai_detection_cache.lua

local M = {}

local TTL_BY_STATUS = {
  available   = 300,
  timeout     = 60,
  error       = 30,
  unavailable = 120,
}

local DEFAULT_TTL = 60

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
-- Private: Load cache from disk
----------------------------------------------------------------------
local function load_cache()
  local path = cache_file()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end

  local ok, data = pcall(dofile, path)
  if not ok or type(data) ~= "table" then
    return {}
  end

  return data
end

----------------------------------------------------------------------
-- Private: Write cache to disk
----------------------------------------------------------------------
local function save_cache(data)
  local path = cache_file()
  local dir = cache_dir()
  vim.fn.mkdir(dir, "p")

  local serialized = { "return {" }
  for provider, models in pairs(data) do
    table.insert(serialized, string.format("  [%q] = {", provider))
    for model, entry in pairs(models) do
      table.insert(serialized, string.format("    [%q] = {", model))
      table.insert(serialized, string.format("      status = %q,", entry.status or ""))
      table.insert(serialized, string.format("      response_time = %s,", entry.response_time or 0))
      table.insert(serialized, string.format("      error_msg = %q,", entry.error_msg or ""))
      table.insert(serialized, string.format("      timestamp = %s,", entry.timestamp or 0))
      table.insert(serialized, "    },")
    end
    table.insert(serialized, "  },")
  end
  table.insert(serialized, "}")

  vim.fn.writefile(serialized, path)
end

----------------------------------------------------------------------
-- Cache get/set/invalidate/is_valid/get_all/clear
----------------------------------------------------------------------

function M.get(provider, model)
  local data = load_cache()
  if data[provider] and data[provider][model] then
    return data[provider][model]
  end
  return nil
end

function M.set(provider, model, result)
  local data = load_cache()

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
  local data = load_cache()

  if data[provider] then
    data[provider][model] = nil
    if not next(data[provider]) then
      data[provider] = nil
    end
    save_cache(data)
  end
end

function M.get_all()
  return load_cache()
end

function M.clear()
  local path = cache_file()
  if vim.fn.filereadable(path) == 1 then
    os.remove(path)
  end
end

return M
