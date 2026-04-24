-- lua/ai/provider_manager/detector.lua
-- Provider/Model detection logic — single sync and batch async
-- Uses vim.system() for non-blocking async HTTP (NOT io.popen)

local M = {}

local Cache = require("ai.provider_manager.cache")
local Providers = require("ai.providers")
local Keys = require("ai.keys")
local Registry = require("ai.provider_manager.registry")
local State = require("ai.state")

----------------------------------------------------------------------
-- Status constants
----------------------------------------------------------------------
M.STATUS_AVAILABLE = "available"
M.STATUS_UNAVAILABLE = "unavailable"
M.STATUS_TIMEOUT = "timeout"
M.STATUS_ERROR = "error"

----------------------------------------------------------------------
-- Injectable HTTP function for testability
-- Defaults to vim.system (Neovim 0.10+)
----------------------------------------------------------------------
M._http_fn = nil

local function http_fn()
  return M._http_fn or vim.system
end

----------------------------------------------------------------------
-- Private: Sanitize error messages (remove API keys and Bearer tokens)
----------------------------------------------------------------------
local function sanitize_error(msg)
  if not msg or msg == "" then return msg end
  msg = msg:gsub("sk%-[A-Za-z0-9]+", "[KEY_REDACTED]")
  msg = msg:gsub("Bearer [^ ]+", "Bearer [REDACTED]")
  return msg
end

----------------------------------------------------------------------
-- Private: Check if endpoint is OpenAI-compatible
-- Returns true if endpoint contains /v1/ or ends with /compatible-mode
----------------------------------------------------------------------
local function is_endpoint_compatible(endpoint)
  if not endpoint then return false end
  return endpoint:match("/v1/") or endpoint:match("/v1$") or endpoint:match("/compatible%-mode$")
end

----------------------------------------------------------------------
-- Private: Build the detection URL
----------------------------------------------------------------------
local function build_url(base_url)
  if base_url:match("/v1$") or base_url:match("/v1/$") then
    return base_url .. "/chat/completions"
  end
  return base_url .. "/v1/chat/completions"
end

----------------------------------------------------------------------
-- Private: Make async HTTP request via vim.system
----------------------------------------------------------------------
local function do_request(base_url, api_key, model, timeout_ms, callback)
  local url = build_url(base_url)
  local timeout_sec = math.max(1, math.floor(timeout_ms / 1000))

  local body = vim.json.encode({
    model = model,
    messages = { { role = "user", content = "hi" } },
    max_tokens = 1,
  })

  local cmd = {
    "curl", "-s", "-m", tostring(timeout_sec),
    "-X", "POST",
    "-H", "Content-Type: application/json",
    "-H", "Authorization: Bearer " .. api_key,
    "-d", body,
    url,
  }

  http_fn()(cmd, { timeout = timeout_ms }, function(obj)
    callback(obj)
  end)
end

----------------------------------------------------------------------
-- Private: Parse HTTP response and determine status
----------------------------------------------------------------------
local function parse_response(stdout, start_time)
  local response_time = math.floor((vim.loop.now() - start_time))
  local result = { response_time = response_time }

  -- Attempt JSON parse
  local ok, json = pcall(vim.json.decode, stdout)
  if not ok or type(json) ~= "table" then
    result.status = M.STATUS_ERROR
    result.error_msg = "Response is not valid JSON"
    return result
  end

  -- Check for API error
  if json.error then
    local err_msg = ""
    if type(json.error) == "table" then
      err_msg = json.error.message or json.error.code or vim.json.encode(json.error)
    elseif type(json.error) == "string" then
      err_msg = json.error
    end
    result.status = M.STATUS_UNAVAILABLE
    result.error_msg = sanitize_error(err_msg)
    return result
  end

  -- Check for successful response
  if json.choices then
    result.status = M.STATUS_AVAILABLE
    return result
  end

  -- Unexpected shape
  result.status = M.STATUS_ERROR
  result.error_msg = "Unexpected response shape (no choices or error field)"
  return result
end

----------------------------------------------------------------------
-- Private: Core async check for a specific provider/model
----------------------------------------------------------------------
local function check_provider_model_async(provider_name, model_id, callback)
  -- Step 1: Check cache
  if Cache.is_valid(provider_name, model_id) then
    local cached = Cache.get(provider_name, model_id)
    callback(cached)
    return
  end

  -- Step 2: Get provider config
  local def = Providers.get(provider_name)
  if not def then
    callback({
      status = M.STATUS_ERROR,
      response_time = 0,
      error_msg = "Provider not found in registry: " .. provider_name,
    })
    return
  end

  -- Step 3: Get API key
  local api_key = Keys.get_key(provider_name)
  if not api_key or api_key == "" then
    callback({
      status = M.STATUS_ERROR,
      response_time = 0,
      error_msg = "API key not configured for: " .. provider_name,
    })
    return
  end

  -- Step 4: Get base URL
  local base_url = Keys.get_base_url(provider_name)
  if not base_url or base_url == "" then
    callback({
      status = M.STATUS_ERROR,
      response_time = 0,
      error_msg = "Base URL not configured for: " .. provider_name,
    })
    return
  end

  -- Step 5: Endpoint compatibility check
  if not is_endpoint_compatible(base_url) then
    vim.notify("Provider " .. provider_name .. " endpoint may not be OpenAI-compatible: " .. base_url, vim.log.levels.WARN)
  end

  -- Step 6: Make request
  local timeout = def.timeout or 30000
  local start_time = vim.loop.now()

  do_request(base_url, api_key, model_id, timeout, function(obj)
    local result
    if obj.code == nil and obj.signal == nil then
      -- vim.system callback not properly invoked (test path)
      -- obj is the response directly
      result = parse_response(obj.stdout or obj, start_time)
    elseif obj.code ~= 0 then
      -- curl exit code non-zero (network error, timeout, etc.)
      if obj.signal and obj.signal.name == "sigterm" then
        result = {
          status = M.STATUS_TIMEOUT,
          response_time = math.floor(vim.loop.now() - start_time),
          error_msg = "Request timed out",
        }
      else
        local err = sanitize_error(obj.stderr or "curl error")
        result = {
          status = M.STATUS_UNAVAILABLE,
          response_time = math.floor(vim.loop.now() - start_time),
          error_msg = err ~= "" and err or "Connection failed",
        }
      end
    else
      -- curl succeeded, parse response body
      result = parse_response(obj.stdout, start_time)
    end

    -- Step 9: Cache if available
    if result.status == M.STATUS_AVAILABLE then
      result.provider = provider_name
      result.model = model_id
      result.timestamp = os.time()
      Cache.set(provider_name, model_id, result)
    end

    callback(result)
  end)
end

----------------------------------------------------------------------
-- check_provider_model(provider_name, model_id, callback)
-- Async: checks a specific provider/model pair
----------------------------------------------------------------------
function M.check_provider_model(provider_name, model_id, callback)
  check_provider_model_async(provider_name, model_id, callback)
end

----------------------------------------------------------------------
-- check_provider(provider_name, callback)
-- Checks provider's default model from registry
----------------------------------------------------------------------
function M.check_provider(provider_name, callback)
  local model = Registry.get_default_model(provider_name)
  if not model then
    local def = Providers.get(provider_name)
    model = def and def.model or "unknown"
  end

  M.check_provider_model(provider_name, model, function(result)
    result.model = model
    callback(result)
  end)
end

----------------------------------------------------------------------
-- check_single(provider_name, model_id)
-- Synchronous wrapper — uses vim.wait() to block until callback fires
----------------------------------------------------------------------
function M.check_single(provider_name, model_id)
  local result = nil
  local done = false

  check_provider_model_async(provider_name, model_id, function(r)
    result = r
    done = true
  end)

  local def = Providers.get(provider_name)
  local timeout = def and def.timeout or 30000

  vim.wait(timeout, function() return done end, 50, false)

  return result
end

----------------------------------------------------------------------
-- check_all_providers(callback)
-- Async batch check with max 3 concurrent, progress notifications
----------------------------------------------------------------------
function M.check_all_providers(callback)
  local providers = Registry.list_providers()
  if not providers or #providers == 0 then
    callback({})
    return
  end

  local total = #providers
  local completed = 0
  local active = 0
  local current = 1
  local results = {}
  local max_concurrent = 3

  local function update_progress()
    vim.notify("检测中: " .. completed .. "/" .. total, vim.log.levels.INFO, { replace = true })
  end

  update_progress()

  local function run_next()
    if current > total then return end

    -- Fill up to max_concurrent
    while active < max_concurrent and current <= total do
      local p = providers[current]
      current = current + 1
      active = active + 1

      local model = Registry.get_default_model(p.name)
      if not model then
        local def = Providers.get(p.name)
        model = def and def.model or "unknown"
      end

      M.check_provider_model(p.name, model, function(result)
        result.provider = p.name
        result.model = model
        table.insert(results, result)
        active = active - 1
        completed = completed + 1
        update_progress()

        -- Kick off next in queue
        run_next()

        -- All done?
        if completed == total then
          vim.notify("检测完成: " .. completed .. "/" .. total, vim.log.levels.INFO)
          callback(results)
        end
      end)
    end
  end

  run_next()
end

return M
