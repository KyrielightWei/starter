-- lua/ai/fetch_models.lua
-- 动态模型拉取（独立模块，可复用到任何 AI 插件）

local Providers = require("ai.providers")
local Keys = require("ai.keys")

local M = {}

----------------------------------------------------------------------
-- fetch(provider_name)
-- 返回：models, tried_urls, succeeded_urls, failed_urls
----------------------------------------------------------------------
function M.fetch(provider_name)
  local def = Providers.get(provider_name)
  if not def or not def.endpoint then
    return nil, {}, {}, {}
  end

  local endpoint = def.endpoint
  local api_key = Keys.get_key(provider_name)

  local candidates = {
    endpoint .. "/v1/models",
    endpoint .. "/models",
    endpoint .. "/api/models",
    endpoint .. "/chat/models",
  }

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

    -- 构建完整的命令字符串
    local cmd = ""
    for i, part in ipairs(cmd_parts) do
      if i > 1 then cmd = cmd .. " " end
      cmd = cmd .. string.format("%q", part)
    end

    local fh = io.popen(cmd)
    if fh then
      local out = fh:read("*a")
      fh:close()

      if out and out:match("%S") then
        local ok, json = pcall(vim.fn.json_decode, out)
        if ok and type(json) == "table" then
          -- OpenAI 格式：{ data = { {id=...}, ... } }
          if json.data and type(json.data) == "table" then
            for _, v in ipairs(json.data) do
              if v.id then table.insert(collected, v) end
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

  -- 打印日志
  if #uniq > 0 then
    -- 拉取成功：打印模型数量和成功的链接
    local success_url = succ[1] or "unknown"
    vim.notify(string.format("✅ 成功从 %s 拉取到 %d 个模型 (URL: %s)",
      provider_name, #uniq, success_url), vim.log.levels.INFO)
  else
    -- 拉取失败：打印告警信息
    if #fail > 0 then
      local failed_urls = table.concat(fail, ", ")
      vim.notify(string.format("⚠️  %s 模型列表拉取失败，尝试的URL: %s",
        provider_name, failed_urls), vim.log.levels.WARN)
    else
      vim.notify(string.format("⚠️  %s 模型列表拉取失败，未尝试任何URL",
        provider_name), vim.log.levels.WARN)
    end
  end

  return uniq, tried, succ, fail
end

return M

