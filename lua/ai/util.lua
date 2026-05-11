-- lua/ai/util.lua
-- 通用工具函数（自动读取 providers.lua，不需要手动维护）

local Providers = require("ai.providers")

local M = {}

----------------------------------------------------------------------
-- merge_table：浅合并（你当前 avante.lua 使用的版本）
----------------------------------------------------------------------
function M.merge_table(a, b)
  a = a or {}
  for k, v in pairs(b or {}) do
    a[k] = v
  end
  return a
end

----------------------------------------------------------------------
-- beautify_model_item：用于 ModelSwitch 的展示
----------------------------------------------------------------------
function M.beautify_model_item(m)
  local id = m.id or tostring(m)
  local owner = m.owned_by or m.owner or "unknown"
  local created = m.created or m.create_time or m.created_at

  local created_str = "unknown"
  if type(created) == "number" then
    created_str = os.date("%Y-%m-%d %H:%M:%S", created)
  elseif type(created) == "string" and tonumber(created) then
    created_str = os.date("%Y-%m-%d %H:%M:%S", tonumber(created))
  end

  return string.format("%s  —  %s  —  %s", id, created_str, owner), id
end

----------------------------------------------------------------------
-- get_env_var(provider)
-- Look up api_key_name from Providers at call time (not cached at load)
----------------------------------------------------------------------
function M.get_env_var(provider)
  local def = Providers.get(provider)
  if def and def.api_key_name then
    return def.api_key_name
  end
  return "OPENAI_API_KEY"
end

return M
