-- lua/ai/keys.lua
-- 自动化 Key Manager（新增 provider 不需要修改本文件）

local Providers = require("ai.providers")

local M = {}

local function keys_path()
  return vim.fn.stdpath("state") .. "/ai_keys.lua"
end

----------------------------------------------------------------------
-- ensure(): 初始化 key 文件（自动包含所有 provider）
----------------------------------------------------------------------
function M.ensure()
  local path = keys_path()

  if vim.fn.filereadable(path) == 0 then
    local lines = { "return {", '  profile = "default",' }

    -- 自动为每个 provider 创建 default key
    for name, def in pairs(Providers) do
      if type(def) == "table" and def.api_key_name then
        table.insert(lines, string.format('  %s = { default = "" },', name))
      end
    end

    table.insert(lines, "}")
    vim.fn.writefile(lines, path)
  end

  return dofile(path)
end

----------------------------------------------------------------------
-- read(): 读取 key 文件
----------------------------------------------------------------------
function M.read()
  local path = keys_path()
  if vim.fn.filereadable(path) == 0 then return nil end
  return dofile(path)
end

----------------------------------------------------------------------
-- write(): 写入 key 文件
----------------------------------------------------------------------
function M.write(tbl)
  local out = { "return {" }

  for provider, profiles in pairs(tbl) do
    if provider ~= "profile" then
      table.insert(out, string.format("  %s = {", provider))
      for profile, key in pairs(profiles) do
        table.insert(out, string.format('    %s = %q,', profile, key))
      end
      table.insert(out, "  },")
    end
  end

  table.insert(out, string.format('  profile = %q,', tbl.profile or "default"))
  table.insert(out, "}")

  vim.fn.writefile(out, keys_path())
end

----------------------------------------------------------------------
-- get_key(provider): 获取当前 profile 下的 key
----------------------------------------------------------------------
function M.get_key(provider)
  local tbl = M.read()
  if not tbl then return "" end

  local profile = tbl.profile or "default"
  local p = tbl[provider]
  if not p then return "" end

  return p[profile] or p["default"] or ""
end

----------------------------------------------------------------------
-- set_key(provider, profile, key): 设置 key
----------------------------------------------------------------------
function M.set_key(provider, profile, key)
  local tbl = M.read() or { profile = "default" }
  tbl[provider] = tbl[provider] or {}
  tbl[provider][profile] = key
  M.write(tbl)
end

return M

