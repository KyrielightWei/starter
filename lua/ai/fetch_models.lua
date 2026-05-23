-- lua/ai/fetch_models.lua
-- 动态模型拉取（独立模块，可复用到任何 AI 插件）
-- 提供同步和异步两种 API

local Providers = require("ai.providers")
local Keys = require("ai.keys")

local M = {}

-- 模型列表缓存（5分钟有效期）
local model_cache = {}
local cache_ttl = 300 -- seconds

----------------------------------------------------------------------
-- clear_cache(): 清除所有缓存
----------------------------------------------------------------------
function M.clear_cache()
  model_cache = {}
end

----------------------------------------------------------------------
-- fetch_async(provider_name, callback)
-- 异步获取模型列表（不阻塞 UI）
-- callback(models) - models 是模型数组，失败时为空数组
----------------------------------------------------------------------
function M.fetch_async(provider_name, callback)
  local def = Providers.get(provider_name)
  if not def or not def.endpoint then
    if callback then
      callback({})
    end
    return
  end

  -- 检查缓存
  local cached = model_cache[provider_name]
  if cached and cached.timestamp and os.time() - cached.timestamp < cache_ttl then
    if callback then
      callback(cached.models)
    end
    return
  end

  local endpoint = def.endpoint
  local api_key = Keys.get_key(provider_name)

  -- 检查 endpoint 是否已包含 /v1
  local has_v1 = endpoint:match("/v1/?$")

  local candidates
  if has_v1 then
    candidates = {
      endpoint .. "/models",
      endpoint .. "/api/models",
    }
  else
    candidates = {
      endpoint .. "/v1/models",
      endpoint .. "/models",
    }
  end

  local headers = {}
  if api_key and api_key ~= "" then
    headers = {
      "Authorization: Bearer " .. api_key,
      "Content-Type: application/json",
    }
  else
    headers = { "Content-Type: application/json" }
  end

  local function try_url(idx, collected)
    if idx > #candidates then
      -- 所有 URL 都失败了，返回 collected（可能为空）
      if #collected > 0 then
        model_cache[provider_name] = {
          models = collected,
          timestamp = os.time(),
          url = candidates[1],
        }
      end
      if callback then
        callback(collected)
      end
      return
    end

    local url = candidates[idx]
    local cmd_parts = { "curl", "-s", "-m", "5" } -- 5秒超时
    for _, header in ipairs(headers) do
      if header and header ~= "" then
        table.insert(cmd_parts, "-H")
        table.insert(cmd_parts, header)
      end
    end
    table.insert(cmd_parts, url)

    vim.system(cmd_parts, { text = true }, function(result)
      if result.code == 0 and result.stdout and result.stdout:match("%S") then
        local ok_json, json = pcall(vim.fn.json_decode, result.stdout)
        if ok_json and type(json) == "table" then
          -- OpenAI 格式：{ data = { {id=...}, ... } }
          if json.data and type(json.data) == "table" then
            for _, v in ipairs(json.data) do
              if v.id then
                table.insert(collected, v)
              end
            end
          -- 数组格式：[{id=...}, ...]
          elseif type(json[1]) == "table" and json[1].id then
            for _, v in ipairs(json) do
              table.insert(collected, v)
            end
          -- 字典格式
          else
            for _, v in pairs(json) do
              if type(v) == "table" and v.id then
                table.insert(collected, v)
              end
            end
          end
        end
      end

      -- 去重
      local seen, uniq = {}, {}
      for _, m in ipairs(collected) do
        local id = m.id or tostring(m)
        if not seen[id] then
          seen[id] = true
          table.insert(uniq, m)
        end
      end

      -- 成功则停止，失败则继续尝试下一个 URL
      if #uniq > 0 then
        model_cache[provider_name] = {
          models = uniq,
          timestamp = os.time(),
          url = url,
        }
        if callback then
          callback(uniq)
        end
      else
        try_url(idx + 1, collected)
      end
    end)
  end

  -- 开始尝试第一个 URL
  try_url(1, {})
end

----------------------------------------------------------------------
-- fetch(provider_name)
-- 同步获取模型列表（会阻塞 UI，最多 3 秒）
-- 返回：models, tried_urls, succeeded_urls, failed_urls
-- ⚠️ 已弃用：推荐使用 fetch_async() 以避免阻塞 UI
----------------------------------------------------------------------
function M.fetch(provider_name)
  local def = Providers.get(provider_name)
  if not def or not def.endpoint then
    return nil, {}, {}, {}
  end

  -- 检查缓存
  local cached = model_cache[provider_name]
  if cached and cached.timestamp and os.time() - cached.timestamp < cache_ttl then
    -- 缓存有效，直接返回（静默，不打印日志）
    return cached.models, {}, { cached.url }, {}
  end

  local endpoint = def.endpoint
  local api_key = Keys.get_key(provider_name)

  -- 检查 endpoint 是否已包含 /v1，避免重复拼接
  local has_v1 = endpoint:match("/v1/?$")

  local candidates
  if has_v1 then
    -- endpoint 已有 /v1，直接拼接 /models
    candidates = {
      endpoint .. "/models",
      endpoint .. "/api/models",
      endpoint .. "/chat/models",
    }
  else
    -- endpoint 没有 /v1，优先尝试 /v1/models
    candidates = {
      endpoint .. "/v1/models",
      endpoint .. "/models",
      endpoint .. "/api/models",
      endpoint .. "/chat/models",
    }
  end

  local headers = {}
  if api_key and api_key ~= "" then
    headers = {
      "Authorization: Bearer " .. api_key,
      "Content-Type: application/json",
    }
  else
    headers = { "Content-Type: application/json" }
  end

  local tried, succ, fail = {}, {}, {}
  local collected = {}

  -- Progress notification ID (used for replace)
  local progress_id = "fetch_models_" .. provider_name

  -- Show progress notification once before trying URLs
  vim.notify(
    string.format("⏳ 正在从 %s 拉取模型列表...", provider_name),
    vim.log.levels.INFO,
    { title = "Model Fetch", replace = progress_id }
  )

  for _, url in ipairs(candidates) do
    table.insert(tried, url)

    -- 动态构建curl命令，只包含非空的headers
    local cmd_parts = { "curl", "-s" }
    for _, header in ipairs(headers) do
      if header and header ~= "" then
        table.insert(cmd_parts, "-H")
        table.insert(cmd_parts, header)
      end
    end
    table.insert(cmd_parts, url)

    -- Use vim.system (async, non-blocking) with vim.wait to preserve sync API
    local result = nil
    local done = false

    local ok, proc = pcall(vim.system, cmd_parts, { text = true }, function(obj)
      result = obj
      done = true
    end)

    if ok and proc then
      -- Wait up to 3 seconds with progress updates
      local wait_ms = 3000
      local elapsed = 0
      vim.wait(wait_ms, function()
        elapsed = elapsed + 100
        -- Update progress every 500ms
        if elapsed % 500 == 0 then
          local seconds = elapsed / 1000
          vim.notify(
            string.format("⏳ 正在拉取 %s 模型列表... (%.1fs)", provider_name, seconds),
            vim.log.levels.INFO,
            { title = "Model Fetch", replace = progress_id }
          )
        end
        return done
      end, 100) -- check every 100ms

      if result and result.code == 0 and result.stdout and result.stdout:match("%S") then
        local out = result.stdout
        local ok_json, json = pcall(vim.fn.json_decode, out)
        if ok_json and type(json) == "table" then
          -- OpenAI 格式：{ data = { {id=...}, ... } }
          if json.data and type(json.data) == "table" then
            for _, v in ipairs(json.data) do
              if v.id then
                table.insert(collected, v)
              end
            end

          -- 数组格式：[{id=...}, ...]
          elseif type(json[1]) == "table" and json[1].id then
            for _, v in ipairs(json) do
              table.insert(collected, v)
            end

          -- 字典格式：{ model1={id=...}, model2={id=...} }
          else
            for _, v in pairs(json) do
              if type(v) == "table" and v.id then
                table.insert(collected, v)
              end
            end
          end

          if #collected > 0 then
            table.insert(succ, url)
            -- Success! Break out of loop, don't try other URLs
            break
          else
            table.insert(fail, url)
          end
        else
          table.insert(fail, url)
        end
      else
        table.insert(fail, url)
      end
    else
      table.insert(fail, url)
    end
  end

  -- 去重
  local seen, uniq = {}, {}
  for _, m in ipairs(collected) do
    local id = m.id or tostring(m)
    if not seen[id] then
      seen[id] = true
      table.insert(uniq, m)
    end
  end

  -- 成功时保存到缓存
  if #uniq > 0 and #succ > 0 then
    model_cache[provider_name] = {
      models = uniq,
      timestamp = os.time(),
      url = succ[1],
    }
  end

  -- 打印日志（替换进度通知）
  if #uniq > 0 then
    -- 拉取成功：打印模型数量和成功的链接
    local success_url = succ[1] or "unknown"
    vim.notify(
      string.format("✅ 成功从 %s 拉取到 %d 个模型", provider_name, #uniq),
      vim.log.levels.INFO,
      { title = "Model Fetch", replace = progress_id }
    )
  else
    -- 拉取失败：打印告警信息
    if #fail > 0 then
      local failed_urls = table.concat(fail, ", ")
      vim.notify(
        string.format("⚠️  %s 模型列表拉取失败\n尝试的URL: %s", provider_name, failed_urls),
        vim.log.levels.WARN,
        { title = "Model Fetch", replace = progress_id }
      )
    else
      vim.notify(
        string.format("⚠️  %s 模型列表拉取失败，未尝试任何URL", provider_name),
        vim.log.levels.WARN,
        { title = "Model Fetch", replace = progress_id }
      )
    end
  end

  return uniq, tried, succ, fail
end

return M
