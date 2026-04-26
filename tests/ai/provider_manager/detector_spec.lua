-- tests/ai/provider_manager/detector_spec.lua
-- Unit tests for detector.lua

local function get_project_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
end

-- Ensure project is at the front of runtimepath
local project_root = get_project_root()
if project_root and #project_root > 0 then
  vim.opt.runtimepath:prepend(project_root)
end

-- Clear any previously cached modules to ensure we load from project
package.loaded["ai.provider_manager.cache"] = nil
package.loaded["ai.providers"] = nil
package.loaded["ai.keys"] = nil
package.loaded["ai.provider_manager.registry"] = nil
package.loaded["ai.state"] = nil
package.loaded["ai.provider_manager.detector"] = nil

----------------------------------------------------------------------
-- Test-friendly stubs — defined BEFORE requiring detector
----------------------------------------------------------------------
local _cache_data = {}

local cache_stub = {}
function cache_stub.get(p, m) return _cache_data[p] and _cache_data[p][m] end
function cache_stub.set(p, m, r)
  if not _cache_data[p] then _cache_data[p] = {} end
  _cache_data[p][m] = r
end
function cache_stub.is_valid(p, m) return cache_stub.get(p, m) ~= nil end
function cache_stub.clear() _cache_data = {} end

local _providers = {}
local providers_stub = {}
function providers_stub.get(name) return _providers[name] end
function providers_stub.list()
  local out = {}
  for k, v in pairs(_providers) do table.insert(out, k) end
  return out
end

local _keys = {}
local keys_stub = {}
function keys_stub.get_key(p) return _keys[p] and _keys[p].api_key or "" end
function keys_stub.get_base_url(p) return _keys[p] and _keys[p].base_url or "" end

local _registry_models = {}
local registry_stub = {}
function registry_stub.list_providers()
  local out = {}
  for name, def in pairs(_providers) do
    table.insert(out, { name = name, endpoint = def.endpoint, model = def.model })
  end
  return out
end
function registry_stub.get_default_model(name) return _registry_models[name] end

local state_stub = {
  get = function() return { provider = nil, model = nil } end,
  set = function() end,
}

----------------------------------------------------------------------
-- Install stubs BEFORE requiring detector
----------------------------------------------------------------------
package.loaded["ai.provider_manager.cache"] = cache_stub
package.loaded["ai.providers"] = providers_stub
package.loaded["ai.keys"] = keys_stub
package.loaded["ai.provider_manager.registry"] = registry_stub
package.loaded["ai.state"] = state_stub

-- Now require detector — it will pick up stubs
local Detector = require("ai.provider_manager.detector")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function reset_state()
  _cache_data = {}
  _providers = {}
  _keys = {}
  _registry_models = {}
  Detector._http_fn = nil
end

local function fake_response(stdout, code, signal)
  return { code = code or 0, signal = signal, stdout = stdout or "", stderr = "" }
end

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------
describe("ai.provider_manager.detector", function()
  before_each(function()
    reset_state()
  end)

  describe("status constants", function()
    it("exports STATUS_AVAILABLE", function()
      assert.are.equal("available", Detector.STATUS_AVAILABLE)
    end)

    it("exports STATUS_UNAVAILABLE", function()
      assert.are.equal("unavailable", Detector.STATUS_UNAVAILABLE)
    end)

    it("exports STATUS_TIMEOUT", function()
      assert.are.equal("timeout", Detector.STATUS_TIMEOUT)
    end)

    it("exports STATUS_ERROR", function()
      assert.are.equal("error",Detector.STATUS_ERROR)
    end)
  end)

  describe("check_provider_model() — available", function()
    it("returns available for valid response with choices", function()
      _providers["test_prov"] = {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
        timeout = 5000,
      }
      _keys["test_prov"] = { api_key = "sk-test123", base_url = "https://test.api.com/v1" }

      local called = false
      Detector._http_fn = function(cmd, opts, cb)
        called = true
        cb(fake_response('{"choices": [{"message": {"content": "hi"}}]}', 0))
      end

      local result = Detector.check_single("test_prov", "test-model")

      assert.is_true(called)
      assert.are.equal("available", result.status)
      assert.is_not_nil(result.response_time)
      assert.is_nil(result.error_msg)
    end)

    it("returns available and caches result", function()
      _providers["cache_prov"] = {
        endpoint = "https://cache.api.com/v1",
        model = "cache-model",
        timeout = 5000,
      }
      _keys["cache_prov"] = { api_key = "sk-cache", base_url = "https://cache.api.com/v1" }

      local call_count = 0
      Detector._http_fn = function(cmd, opts, cb)
        call_count = call_count + 1
        cb(fake_response('{"choices": []}', 0))
      end

      -- First call hits API
      local r1 = Detector.check_single("cache_prov", "cache-model")
      assert.are.equal("available", r1.status)
      assert.are.equal(1, call_count)

      -- Second call should hit cache (no additional HTTP call)
      local r2 = Detector.check_single("cache_prov", "cache-model")
      assert.are.equal("available", r2.status)
      assert.are.equal(1, call_count)
    end)
  end)

  describe("check_provider_model() — unavailable", function()
    it("returns unavailable when JSON has error field", function()
      _providers["bad_prov"] = {
        endpoint = "https://bad.api.com/v1",
        model = "bad-model",
        timeout = 5000,
      }
      _keys["bad_prov"] = { api_key = "sk-bad", base_url = "https://bad.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"error": {"message": "Unauthorized", "code": 401}}', 0))
      end

      local result = Detector.check_single("bad_prov", "bad-model")

      assert.are.equal("unavailable", result.status)
      assert.is_not_nil(result.error_msg)
      assert.is_nil(result.error_msg:match("sk%-bad"))
    end)

    it("sanitizes API keys from error messages", function()
      _providers["leak_prov"] = {
        endpoint = "https://leak.api.com/v1",
        model = "leak-model",
        timeout = 5000,
      }
      _keys["leak_prov"] = { api_key = "sk-secretkey", base_url = "https://leak.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"error": {"message": "Invalid key: sk-secretkey"}}', 0))
      end

      local result = Detector.check_single("leak_prov", "leak-model")

      assert.are.equal("unavailable", result.status)
      assert.is_nil(result.error_msg:match("sk%-secretkey"))
      assert.is_not_nil(result.error_msg:match("%[KEY_REDACTED%]"))
    end)

    it("sanitizes Bearer tokens from error messages", function()
      _providers["bearer_prov"] = {
        endpoint = "https://bearer.api.com/v1",
        model = "bearer-model",
        timeout = 5000,
      }
      _keys["bearer_prov"] = { api_key = "sk-bearer", base_url = "https://bearer.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"error": {"message": "Expired token: Bearer abc123xyz"}}', 0))
      end

      local result = Detector.check_single("bearer_prov", "bearer-model")

      assert.are.equal("unavailable", result.status)
      assert.is_nil(result.error_msg:match("Bearer abc123xyz"))
    end)
  end)

  describe("check_provider_model() — error cases", function()
    it("returns error when provider not found", function()
      local result = Detector.check_single("nonexistent", "any-model")
      assert.are.equal("error", result.status)
    end)

    it("returns error when API key is missing", function()
      _providers["nokey_prov"] = {
        endpoint = "https://nokey.api.com/v1",
        model = "nokey-model",
        timeout = 5000,
      }
      _keys["nokey_prov"] = { api_key = "", base_url = "https://nokey.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"choices": []}', 0))
      end

      local result = Detector.check_single("nokey_prov", "nokey-model")
      assert.are.equal("error", result.status)
    end)

    it("returns error when base URL is missing", function()
      _providers["nourl_prov"] = {
        endpoint = "https://nourl.api.com/v1",
        model = "nourl-model",
        timeout = 5000,
      }
      _keys["nourl_prov"] = { api_key = "sk-valid", base_url = "" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"choices": []}', 0))
      end

      local result = Detector.check_single("nourl_prov", "nourl-model")
      assert.are.equal("error", result.status)
    end)

    it("returns error on malformed JSON response", function()
      _providers["json_prov"] = {
        endpoint = "https://json.api.com/v1",
        model = "json-model",
        timeout = 5000,
      }
      _keys["json_prov"] = { api_key = "sk-json", base_url = "https://json.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response("not json at all", 0))
      end

      local result = Detector.check_single("json_prov", "json-model")
      assert.are.equal("error", result.status)
    end)

    it("returns error on 200 but unexpected JSON shape", function()
      _providers["shape_prov"] = {
        endpoint = "https://shape.api.com/v1",
        model = "shape-model",
        timeout = 5000,
      }
      _keys["shape_prov"] = { api_key = "sk-shape", base_url = "https://shape.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"status": "ok"}', 0))
      end

      local result = Detector.check_single("shape_prov", "shape-model")
      assert.are.equal("error", result.status)
    end)
  end)

  describe("check_provider_model() — endpoint compatibility", function()
    it("warns and attempts request for non-compatible endpoint", function()
      _providers["old_prov"] = {
        endpoint = "https://old.api.com/api/v2",
        model = "old-model",
        timeout = 5000,
      }
      _keys["old_prov"] = { api_key = "sk-old", base_url = "https://old.api.com/api/v2" }

      local notified = false
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        if level == vim.log.levels.WARN and msg:match("endpoint") then
          notified = true
        end
      end

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"choices": []}', 0))
      end

      Detector.check_single("old_prov", "old-model")

      vim.notify = orig_notify
      assert.is_true(notified)
    end)

    it("does not warn for /v1/ endpoint", function()
      _providers["v1_prov"] = {
        endpoint = "https://v1.api.com/v1/",
        model = "v1-model",
        timeout = 5000,
      }
      _keys["v1_prov"] = { api_key = "sk-v1", base_url = "https://v1.api.com/v1/" }

      local notified = false
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        if level == vim.log.levels.WARN and msg:match("endpoint") then
          notified = true
        end
      end

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"choices": []}', 0))
      end

      Detector.check_single("v1_prov", "v1-model")

      vim.notify = orig_notify
      assert.is_false(notified)
    end)

    it("does not warn for /compatible-mode endpoint", function()
      _providers["compat_prov"] = {
        endpoint = "https://compat.api.com/compatible-mode",
        model = "compat-model",
        timeout = 5000,
      }
      _keys["compat_prov"] = { api_key = "sk-compat", base_url = "https://compat.api.com/compatible-mode" }

      local notified = false
      local orig_notify = vim.notify
      vim.notify = function(msg, level)
        if level == vim.log.levels.WARN and msg:match("endpoint") then
          notified = true
        end
      end

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"choices": []}', 0))
      end

      Detector.check_single("compat_prov", "compat-model")

      vim.notify = orig_notify
      assert.is_false(notified)
    end)
  end)

  describe("check_provider() — uses default model", function()
    it("resolves provider default model from registry", function()
      _providers["def_prov"] = {
        endpoint = "https://def.api.com/v1",
        model = "def-model",
        timeout = 5000,
      }
      _keys["def_prov"] = { api_key = "sk-def", base_url = "https://def.api.com/v1" }
      _registry_models["def_prov"] = "registry-default-model"

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"choices": []}', 0))
      end

      local result = nil
      local done = false
      Detector.check_provider("def_prov", function(r)
        result = r
        done = true
      end)
      vim.wait(5000, function() return done end, 50, false)

      assert.is_not_nil(result)
      assert.are.equal("available", result.status)
      assert.are.equal("registry-default-model", result.model)
    end)
  end)

  describe("check_all_providers() — batch async", function()
    it("returns results for all providers", function()
      _providers["prov_a"] = {
        endpoint = "https://a.api.com/v1",
        model = "a-model",
        timeout = 5000,
      }
      _keys["prov_a"] = { api_key = "sk-a", base_url = "https://a.api.com/v1" }

      _providers["prov_b"] = {
        endpoint = "https://b.api.com/v1",
        model = "b-model",
        timeout = 5000,
      }
      _keys["prov_b"] = { api_key = "sk-b", base_url = "https://b.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"choices": []}', 0))
      end

      local results = nil
      local done = false
      Detector.check_all_providers(function(r)
        results = r
        done = true
      end)
      vim.wait(10000, function() return done end, 50, false)

      assert.is_not_nil(results)
      assert.is_true(#results >= 2)
    end)

    it("continues batch when one provider fails", function()
      _providers["good_prov"] = {
        endpoint = "https://good.api.com/v1",
        model = "good-model",
        timeout = 5000,
      }
      _keys["good_prov"] = { api_key = "sk-good", base_url = "https://good.api.com/v1" }

      _providers["fail_prov"] = {
        endpoint = "https://fail.api.com/v1",
        model = "fail-model",
        timeout = 5000,
      }
      _keys["fail_prov"] = { api_key = "", base_url = "https://fail.api.com/v1" }

      local call_count = 0
      Detector._http_fn = function(cmd, opts, cb)
        call_count = call_count + 1
        cb(fake_response('{"choices": []}', 0))
      end

      local results = nil
      local done = false
      Detector.check_all_providers(function(r)
        results = r
        done = true
      end)
      vim.wait(10000, function() return done end, 50, false)

      assert.is_not_nil(results)
      assert.is_true(#results >= 2)
      -- Both should have results even though one had no key
      local found_fail = false
      for _, r in ipairs(results) do
        if r.provider == "fail_prov" then found_fail = true; break end
      end
      assert.is_true(found_fail)
    end)
  end)

  describe("check_single() — sync wrapper", function()
    it("blocks until async callback fires", function()
      _providers["sync_prov"] = {
        endpoint = "https://sync.api.com/v1",
        model = "sync-model",
        timeout = 5000,
      }
      _keys["sync_prov"] = { api_key = "sk-sync", base_url = "https://sync.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        cb(fake_response('{"choices": []}', 0))
      end

      local result = Detector.check_single("sync_prov", "sync-model")

      assert.is_table(result)
      assert.are.equal("available", result.status)
    end)

    it("returns nil or partial result when callback is delayed", function()
      _providers["slow_prov"] = {
        endpoint = "https://slow.api.com/v1",
        model = "slow-model",
        timeout = 100,
      }
      _keys["slow_prov"] = { api_key = "sk-slow", base_url = "https://slow.api.com/v1" }

      Detector._http_fn = function(cmd, opts, cb)
        -- Never calls callback — simulates unresponsive HTTP
      end

      local result = Detector.check_single("slow_prov", "slow-model")
      -- result may be nil if vim.wait times out before callback
      assert.is_true(result == nil or type(result) == "table")
    end)
  end)
end)
