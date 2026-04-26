-- tests/ai/provider_manager/status_spec.lua
-- Unit tests for status.lua — thread-safe status checker with stale guards

local function get_project_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
end

-- Ensure project is at the front of runtimepath
local project_root = get_project_root()
if project_root and #project_root > 0 then
  vim.opt.runtimepath:prepend(project_root)
end

-- Clear any previously cached modules
package.loaded["ai.provider_manager.cache"] = nil
package.loaded["ai.provider_manager.detector"] = nil
package.loaded["ai.state"] = nil
package.loaded["ai.provider_manager.status"] = nil

----------------------------------------------------------------------
-- Test-friendly stubs — defined BEFORE requiring status
----------------------------------------------------------------------
local _cache_data = {}

local cache_stub = {}
function cache_stub.get(p, m)
  return _cache_data[p] and _cache_data[p][m]
end
function cache_stub.set(p, m, r)
  if not _cache_data[p] then _cache_data[p] = {} end
  _cache_data[p][m] = r
end
function cache_stub.is_valid(p, m)
  return _cache_data[p] and _cache_data[p][m] ~= nil
end
function cache_stub.clear()
  _cache_data = {}
end

local _detector_calls = {}
local detector_stub = {}
function detector_stub.check_provider_model(provider, model, callback)
  table.insert(_detector_calls, { provider = provider, model = model, callback = callback })
  -- Don't invoke callback immediately — test controls timing
end

local _batch_called = false
function detector_stub.check_all_providers(callback)
  _batch_called = true
  -- Simulate async callback
  vim.schedule(function()
    callback({
      { provider = "test", model = "test-model", status = "available" },
    })
  end)
end

-- Track vim.schedule_wrap calls
local _schedule_wrap_calls = 0
local _schedule_wrap_args = {}
local _state_current = { provider = nil, model = nil }

local state_stub = {}
function state_stub.get()
  return { provider = _state_current.provider, model = _state_current.model }
end
function state_stub.set(provider, model)
  _state_current.provider = provider
  _state_current.model = model
end
function state_stub.clear()
  _state_current = { provider = nil, model = nil }
end

local orig_schedule_wrap = vim.schedule_wrap
vim.schedule_wrap = function(fn)
  _schedule_wrap_calls = _schedule_wrap_calls + 1
  table.insert(_schedule_wrap_args, fn)
  -- In tests, execute immediately (we can't test real deferred scheduling here)
  return orig_schedule_wrap(fn)
end

----------------------------------------------------------------------
-- Install stubs BEFORE requiring status
----------------------------------------------------------------------
package.loaded["ai.provider_manager.cache"] = cache_stub
package.loaded["ai.provider_manager.detector"] = detector_stub
package.loaded["ai.state"] = state_stub

-- Now require status — it will pick up stubs
local Status = require("ai.provider_manager.status")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function reset_state()
  _cache_data = {}
  _detector_calls = {}
  _batch_called = false
  _schedule_wrap_calls = 0
  _schedule_wrap_args = {}
  _state_current = { provider = nil, model = nil }
  -- Note: vim.schedule_wrap wrapper is NOT reset here — it's applied once at module load
  -- and must stay active for all tests to count calls. See WR-04 fix discussion.
end

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------
describe("ai.provider_manager.status", function()
  before_each(function()
    reset_state()
  end)

  describe("get_cached_status() — nil and empty inputs (C-14)", function()
    it("returns 'unchecked' for nil provider", function()
      local result = Status.get_cached_status(nil, "some-model")
      assert.are.equal("unchecked", result)
    end)

    it("returns 'unchecked' for nil model", function()
      local result = Status.get_cached_status("test-provider", nil)
      assert.are.equal("unchecked", result)
    end)

    it("returns 'unchecked' for empty provider string", function()
      local result = Status.get_cached_status("", "some-model")
      assert.are.equal("unchecked", result)
    end)

    it("returns 'unchecked' for empty model string", function()
      local result = Status.get_cached_status("test-provider", "")
      assert.are.equal("unchecked", result)
    end)
  end)

  describe("get_cached_status() — cache behavior", function()
    it("returns 'unchecked' when cache is invalid", function()
      -- is_valid returns false by default (no data)
      local result = Status.get_cached_status("test-prov", "test-model")
      assert.are.equal("unchecked", result)
    end)

    it("returns cached status when cache is valid", function()
      -- Populate cache with a valid entry
      _cache_data["test-prov"] = {
        ["test-model"] = { status = "available", timestamp = os.time() }
      }
      local result = Status.get_cached_status("test-prov", "test-model")
      assert.are.equal("available", result)
    end)

    it("returns cached 'unavailable' status", function()
      _cache_data["bad-prov"] = {
        ["bad-model"] = { status = "unavailable", timestamp = os.time() }
      }
      local result = Status.get_cached_status("bad-prov", "bad-model")
      assert.are.equal("unavailable", result)
    end)

    it("returns cached 'timeout' status", function()
      _cache_data["slow-prov"] = {
        ["slow-model"] = { status = "timeout", timestamp = os.time() }
      }
      local result = Status.get_cached_status("slow-prov", "slow-model")
      assert.are.equal("timeout", result)
    end)

    it("returns cached 'error' status", function()
      _cache_data["err-prov"] = {
        ["err-model"] = { status = "error", timestamp = os.time() }
      }
      local result = Status.get_cached_status("err-prov", "err-model")
      assert.are.equal("error", result)
    end)

    it("returns 'unchecked' when cache.get returns nil but is_valid somehow true", function()
      -- Edge case: is_valid returns true but get returns nil (defensive coding)
      -- Simulate by adding entry then removing it (is_valid checks non-nil, get would return nil if removed)
      -- In our stub, is_valid and get use same data, so we need to trick it
      -- For this test: override is_valid to return true but get to return nil
      local orig_is_valid = cache_stub.is_valid
      local orig_get = cache_stub.get
      cache_stub.is_valid = function() return true end
      cache_stub.get = function() return nil end

      local result = Status.get_cached_status("ghost-prov", "ghost-model")
      assert.are.equal("unchecked", result)

      -- Restore
      cache_stub.is_valid = orig_is_valid
      cache_stub.get = orig_get
    end)
  end)

  describe("get_cached_status_with_pending()", function()
    it("returns same status as get_cached_status", function()
      _cache_data["test-prov"] = {
        ["test-model"] = { status = "available", timestamp = os.time() }
      }
      local status, is_checking = Status.get_cached_status_with_pending("test-prov", "test-model")
      assert.are.equal("available", status)
      assert.is_false(is_checking)
    end)

    it("returns 'unchecked', false when no cache entry", function()
      local status, is_checking = Status.get_cached_status_with_pending(nil, "model")
      assert.are.equal("unchecked", status)
      assert.is_false(is_checking)
    end)
  end)

  describe("trigger_async_check() — basic behavior", function()
    it("calls Detector.check_provider_model with correct args", function()
      Status.trigger_async_check("my-prov", "my-model", function() end)

      assert.is_true(#_detector_calls >= 1)
      local call = _detector_calls[#_detector_calls]
      assert.are.equal("my-prov", call.provider)
      assert.are.equal("my-model", call.model)
    end)

    it("uses vim.schedule_wrap (verifiable by call count)", function()
      local before = _schedule_wrap_calls
      Status.trigger_async_check("test-prov", "test-model", function() end)
      assert.is_true(_schedule_wrap_calls > before)
    end)

    it("fires check even with nil on_complete", function()
      local before = #_detector_calls
      Status.trigger_async_check("test-prov", "test-model", nil)
      assert.is_true(#_detector_calls > before)
    end)
  end)

  describe("trigger_async_check() — stale guard (C-02, C-11)", function()
    it("invokes on_complete when State matches captured provider+model", function()
      -- Set state to match what we're checking
      _state_current = { provider = "active-prov", model = "active-model" }

      local completed = false
      Status.trigger_async_check("active-prov", "active-model", function(result)
        completed = true
      end)

      -- Simulate detector callback completing
      local call = _detector_calls[#_detector_calls]
      call.callback({ status = "available" })

      assert.is_true(completed)
    end)

    it("discards callback when State has different provider", function()
      -- Set state to a DIFFERENT provider (user switched away)
      _state_current = { provider = "other-prov", model = "active-model" }

      local completed = false
      Status.trigger_async_check("active-prov", "active-model", function(result)
        completed = true
      end)

      -- Simulate detector callback completing
      local call = _detector_calls[#_detector_calls]
      call.callback({ status = "available" })

      assert.is_false(completed) -- Stale guard should prevent callback
    end)

    it("discards callback when State has different model", function()
      -- Set state to a DIFFERENT model
      _state_current = { provider = "active-prov", model = "other-model" }

      local completed = false
      Status.trigger_async_check("active-prov", "active-model", function(result)
        completed = true
      end)

      local call = _detector_calls[#_detector_calls]
      call.callback({ status = "available" })

      assert.is_false(completed)
    end)

    it("discards callback when State.get() returns nil", function()
      _state_current = { provider = nil, model = nil }

      local completed = false
      Status.trigger_async_check("active-prov", "active-model", function(result)
        completed = true
      end)

      local call = _detector_calls[#_detector_calls]
      call.callback({ status = "available" })

      assert.is_false(completed)
    end)
  end)

  describe("check_all_batch()", function()
    it("calls Detector.check_all_providers", function()
      Status.check_all_batch(function() end)

      -- check_all_providers should have been called
      assert.is_true(_batch_called)
    end)

    it("invokes callback with results", function()
      local results_received = false
      Status.check_all_batch(function(results)
        results_received = true
        assert.is_true(#results > 0)
      end)

      -- Wait for vim.schedule to fire
      vim.wait(1000, function() return results_received end, 50, false)
      assert.is_true(results_received)
    end)
  end)
end)
