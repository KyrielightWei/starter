-- lua/ai/provider_manager/status.lua
-- Status checker API module — thread-safe async auto-detection with stale guards
-- Wraps detector.lua and cache.lua to provide a clean public API
-- Addresses cross-AI review findings: vim.schedule() thread safety (C-01, C-10),
-- stale callback guard (C-02, C-11), nil-safe cache access (C-14)

local M = {}

local Cache = require("ai.provider_manager.cache")
local Detector = require("ai.provider_manager.detector")
local State = require("ai.state")

----------------------------------------------------------------------
-- get_cached_status(provider, model)
-- Returns cached status string or "unchecked"
-- Nil-safe: returns "unchecked" for nil/empty inputs (C-14)
----------------------------------------------------------------------
function M.get_cached_status(provider, model)
  if not provider or provider == "" or not model or model == "" then
    return "unchecked"
  end
  if not Cache.is_valid(provider, model) then
    return "unchecked"
  end
  local entry = Cache.get(provider, model)
  return entry and entry.status or "unchecked"
end

----------------------------------------------------------------------
-- get_cached_status_with_pending(provider, model)
-- Same as get_cached_status but returns additional is_checking boolean
-- is_checking = true if detection is currently in flight
-- Reserved for future cache-aware tracking when detector exposes in-flight status
----------------------------------------------------------------------
function M.get_cached_status_with_pending(provider, model)
  local status = M.get_cached_status(provider, model)
  return status, false -- is_checking = false (reserved for future in-flight tracking)
end

----------------------------------------------------------------------
-- trigger_async_check(provider, model, on_complete)
-- Fires async detection in background, invokes on_complete(result) when done
-- vim.schedule_wrap ensures thread safety (C-01, C-10)
-- Stale guard discards callback if user switched to different provider/model (C-02, C-11)
----------------------------------------------------------------------
function M.trigger_async_check(provider, model, on_complete)
  local captured_provider = provider
  local captured_model = model

  Detector.check_provider_model(provider, model, vim.schedule_wrap(function(result)
    -- Stale guard: check if user is still on this provider+model
    local current = State.get()
    if not current or current.provider ~= captured_provider or current.model ~= captured_model then
      return -- Discard stale callback
    end
    if on_complete then
      on_complete(result)
    end
  end))
end

----------------------------------------------------------------------
-- check_all_batch(callback)
-- Calls Detector.check_all_providers with vim.schedule_wrap safety
----------------------------------------------------------------------
function M.check_all_batch(callback)
  Detector.check_all_providers(vim.schedule_wrap(function(results)
    if callback then
      callback(results)
    end
  end))
end

return M
