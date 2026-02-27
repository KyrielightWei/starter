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
-- env_var_map：自动从 providers.lua 生成
-- 不再需要手动维护
----------------------------------------------------------------------
M.env_var_map = {}
for name, def in pairs(Providers) do
  if type(def) == "table" and def.api_key_name then
    M.env_var_map[name] = def.api_key_name
  end
end

----------------------------------------------------------------------
-- get_env_var(provider)
----------------------------------------------------------------------
function M.get_env_var(provider)
  return M.env_var_map[provider] or "OPENAI_API_KEY"
end

return M

