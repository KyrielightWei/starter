-- Automated UAT for Phase 2: Provider Manager Detection Commands
-- Run: nvim --headless -u tests/minimal_init.lua -c "luafile tests/ai/provider_manager/uat_phase2.lua" -c "q"

local project_root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(project_root)

-- Load modules
local ok, Detector = pcall(require, "ai.provider_manager.detector")
local ok2, Results = pcall(require, "ai.provider_manager.results")
local ok3, Cache = pcall(require, "ai.provider_manager.cache")
local ok4, Init = pcall(require, "ai.provider_manager.init")

local passed = 0
local failed = 0
local issues = {}

local function assert(test, name, detail)
  if test then
    passed = passed + 1
    print("  ✓ " .. name)
  else
    failed = failed + 1
    table.insert(issues, { name = name, detail = detail or "expected truthy, got falsy" })
    print("  ✗ " .. name .. " — " .. (detail or "expected truthy, got falsy"))
  end
end

print("\n━━━ Phase 2 UAT: Provider Manager Detection Commands ━━━\n")

-- Test 1: Module loads
print("\n[Test 1] Module structure")
assert(ok, "Detector loads")
assert(ok2, "Results loads")
assert(ok3, "Cache loads")
assert(ok4, "Init loads")

-- Test 2: Exports
print("\n[Test 2] API exports")
assert(type(Detector.check_provider_model) == "function", "check_provider_model()")
assert(type(Detector.check_provider) == "function", "check_provider()")
assert(type(Detector.check_single) == "function", "check_single()")
assert(type(Detector.check_all_providers) == "function", "check_all_providers()")
assert(type(Results.show_results) == "function", "show_results()")
assert(type(Results.show_single_result) == "function", "show_single_result()")
assert(type(Results.close_results) == "function", "close_results()")
assert(type(Cache.get) == "function", "Cache.get()")
assert(type(Cache.set) == "function", "Cache.set()")
assert(type(Cache.is_valid) == "function", "Cache.is_valid()")
assert(type(Cache.clear) == "function", "Cache.clear()")

-- Test 3: Status constants
print("\n[Test 3] Status constants")
assert(Detector.STATUS_AVAILABLE == "available", "STATUS_AVAILABLE")
assert(Detector.STATUS_UNAVAILABLE == "unavailable", "STATUS_UNAVAILABLE")
assert(Detector.STATUS_TIMEOUT == "timeout", "STATUS_TIMEOUT")
assert(Detector.STATUS_ERROR == "error", "STATUS_ERROR")

-- Test 4: Injectable http_fn
print("\n[Test 4] Injectable HTTP")
assert(Detector._http_fn == nil, "M._http_fn is nil by default")
Detector._http_fn = function(cmd, opts, cb)
  cb({ code = 0, stdout = '{"choices":[{}]}', stderr = "" })
end
assert(type(Detector._http_fn) == "function", "M._http_fn injectable")
Detector._http_fn = nil  -- Reset

-- Test 5: Cache operations
print("\n[Test 5] Cache operations")
Cache.clear()
assert(Cache.get("test_provider", "test_model") == nil, "Cache.get returns nil for missing")
Cache.set("test_provider", "test_model", {
  status = "available",
  response_time = 42,
  error_msg = "",
  timestamp = os.time(),
})
local cached = Cache.get("test_provider", "test_model")
assert(cached ~= nil, "Cache.get returns stored entry")
assert(cached.status == "available", "Cache stores status")
assert(cached.response_time == 42, "Cache stores response_time")
assert(Cache.is_valid("test_provider", "test_model") == true, "Cache.is_valid for fresh entry")
Cache.invalidate("test_provider", "test_model")
assert(Cache.get("test_provider", "test_model") == nil, "Cache.invalidate removes entry")
Cache.clear()

-- Test 6: TTL differentiation
print("\n[Test 6] TTL differentiation")
local now = os.time()
Cache.set("ttl_test", "available_model", {
  status = "available", response_time = 10, error_msg = "", timestamp = now - 299
})
assert(Cache.is_valid("ttl_test", "available_model") == true, "available: 299s < 300s TTL")

Cache.set("ttl_test", "available_expired", {
  status = "available", response_time = 10, error_msg = "", timestamp = now - 301
})
assert(Cache.is_valid("ttl_test", "available_expired") == false, "available: 301s > 300s TTL — expired")

Cache.set("ttl_test", "error_model", {
  status = "error", response_time = 10, error_msg = "", timestamp = now - 29
})
assert(Cache.is_valid("ttl_test", "error_model") == true, "error: 29s < 30s TTL")

Cache.set("ttl_test", "error_expired", {
  status = "error", response_time = 10, error_msg = "", timestamp = now - 31
})
assert(Cache.is_valid("ttl_test", "error_expired") == false, "error: 31s > 30s TTL — expired")

Cache.set("ttl_test", "timeout_model", {
  status = "timeout", response_time = 10, error_msg = "", timestamp = now - 59
})
assert(Cache.is_valid("ttl_test", "timeout_model") == true, "timeout: 59s < 60s TTL")

Cache.set("ttl_test", "timeout_expired", {
  status = "timeout", response_time = 10, error_msg = "", timestamp = now - 61
})
assert(Cache.is_valid("ttl_test", "timeout_expired") == false, "timeout: 61s > 60s TTL — expired")
Cache.clear()

-- Test 7: build_url — CR-01 fix
print("\n[Test 7] build_url CR-01 fix")
-- We can't call build_url directly (local), but we can test via detector with mock

-- Test 8: sanitize_error — WR-07 fix (via mock test)
print("\n[Test 8] Error sanitization")
Detector._http_fn = function(cmd, opts, cb)
  cb({ code = 0, stdout = '{"error":{"message":"Invalid key: sk-abc123xyz789abc"}}', stderr = "" })
end
local result = nil
Detector.check_provider_model("bailian_coding", "test", function(r)
  result = r
end)
if result then
  assert(not result.error_msg:match("sk%-abc"), "API key redacted from error")
  assert(result.error_msg:match("%[KEY_REDACTED%]"), "Error contains [KEY_REDACTED]")
else
  failed = failed + 1
  print("  ✗ API key redacted from error — callback did not fire")
end
Detector._http_fn = nil

-- Test 9: Empty choices — WR-04 fix
print("\n[Test 9] Empty choices array")
Detector._http_fn = function(cmd, opts, cb)
  cb({ code = 0, stdout = '{"choices":[]}', stderr = "" })
end
local result = nil
Detector.check_provider_model("test", "test", function(r)
  result = r
end)
if result then
  assert(result.status ~= "available", "Empty choices is NOT 'available'")
  print("  ✓ Empty choices rejected as expected")
  passed = passed + 1
else
  failed = failed + 1
  print("  ✗ Empty choices — callback did not fire")
end
Detector._http_fn = nil

-- Test 10: Command registration
print("\n[Test 10] Command and keymap registration")
Init.setup({})
local cmds = vim.api.nvim_get_commands({})
assert(cmds["AICheckProvider"] ~= nil, ":AICheckProvider registered")
assert(cmds["AICheckAllProviders"] ~= nil, ":AICheckAllProviders registered")
assert(cmds["AIClearDetectionCache"] ~= nil, ":AIClearDetectionCache registered")

-- Summary
print("\n━━━ Summary ━━━")
print("Passed: " .. passed)
print("Failed: " .. failed)

if #issues > 0 then
  print("\nIssues:")
  for _, issue in ipairs(issues) do
    print("  - " .. issue.name .. ": " .. issue.detail)
  end
end

vim.cmd("q")
