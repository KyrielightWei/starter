-- lua/ai/keys.lua
-- API Key 和 Base URL 管理器
--
-- ============================================================================
-- Key 文件格式 (~/.local/state/nvim/ai_keys.lua)
-- ============================================================================
--
-- return {
--   profile = "default",
--   bailian_coding = {
--     default = {
--       api_key = "sk-xxx",
--       base_url = "https://coding.dashscope.aliyuncs.com/v1",      -- OpenAI 风格
--       base_url_claude = "https://coding.dashscope.aliyuncs.com/v1", -- Claude Code 风格 (可选)
--     },
--     work = {
--       api_key = "sk-yyy",
--       base_url = "https://...",
--     },
--   },
-- }
--
-- 说明：
-- - api_key: API 密钥
-- - base_url: OpenAI 兼容风格的 endpoint (OpenCode/Avante 使用)
-- - base_url_claude: Claude Code 专用 endpoint (可选，不填则使用 base_url)
--
-- ============================================================================

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
    local lines = {
      "return {",
      '  profile = "default",',
    }

    for name, def in pairs(Providers) do
      if type(def) == "table" and def.api_key_name then
        local endpoint = def.endpoint or ""
        endpoint = endpoint:gsub("{(%w+_BASE_ENDPOINT)}", "")
        
        table.insert(lines, string.format("  %s = {", name))
        table.insert(lines, '    default = {')
        table.insert(lines, '      api_key = "",')
        table.insert(lines, string.format('      base_url = %q,', endpoint))
        table.insert(lines, '      base_url_claude = "",  -- Claude Code 专用 (可选)')
        table.insert(lines, "    },")
        table.insert(lines, "  },")
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
      for profile, config in pairs(profiles) do
        if type(config) == "table" then
          table.insert(out, string.format("    %s = {", profile))
          table.insert(out, string.format('      api_key = %q,', config.api_key or ""))
          table.insert(out, string.format('      base_url = %q,', config.base_url or ""))
          table.insert(out, string.format('      base_url_claude = %q,', config.base_url_claude or ""))
          table.insert(out, "    },")
        elseif type(config) == "string" then
          -- 向后兼容旧格式
          table.insert(out, string.format('    %s = { api_key = %q, base_url = "", base_url_claude = "" },', profile, config))
        end
      end
      table.insert(out, "  },")
    end
  end

  table.insert(out, string.format('  profile = %q,', tbl.profile or "default"))
  table.insert(out, "}")

  vim.fn.writefile(out, keys_path())
end

----------------------------------------------------------------------
-- get_config(provider): 获取当前 profile 下的完整配置
-- @return table: { api_key, base_url, base_url_claude }
----------------------------------------------------------------------
function M.get_config(provider)
  local tbl = M.read()
  if not tbl then
    return { api_key = "", base_url = "", base_url_claude = "" }
  end

  local profile = tbl.profile or "default"
  local p = tbl[provider]
  if not p then
    return { api_key = "", base_url = "", base_url_claude = "" }
  end

  local config = p[profile] or p["default"]
  if not config then
    return { api_key = "", base_url = "", base_url_claude = "" }
  end

  -- 兼容旧格式 (直接是字符串)
  if type(config) == "string" then
    return { api_key = config, base_url = "", base_url_claude = "" }
  end

  return {
    api_key = config.api_key or "",
    base_url = config.base_url or "",
    base_url_claude = config.base_url_claude or "",
  }
end

----------------------------------------------------------------------
-- get_key(provider): 获取当前 profile 下的 api_key
----------------------------------------------------------------------
function M.get_key(provider)
  return M.get_config(provider).api_key
end

----------------------------------------------------------------------
-- get_base_url(provider): 获取 OpenAI 风格的 base_url
----------------------------------------------------------------------
function M.get_base_url(provider)
  local config = M.get_config(provider)
  
  -- 优先使用 key 文件中的配置
  if config.base_url and config.base_url ~= "" then
    return config.base_url
  end
  
  -- 回退到 providers.lua 中的默认值
  local def = Providers.get(provider)
  if def and def.endpoint then
    local endpoint = def.endpoint
    endpoint = endpoint:gsub("{(%w+_BASE_ENDPOINT)}", function(var)
      return os.getenv(var) or ""
    end)
    return endpoint
  end
  
  return ""
end

----------------------------------------------------------------------
-- get_base_url_claude(provider): 获取 Claude Code 专用的 base_url
----------------------------------------------------------------------
function M.get_base_url_claude(provider)
  local config = M.get_config(provider)
  
  -- 如果有专门的 Claude URL，使用它
  if config.base_url_claude and config.base_url_claude ~= "" then
    return config.base_url_claude
  end
  
  -- 否则回退到通用 base_url
  return M.get_base_url(provider)
end

----------------------------------------------------------------------
-- set_key(provider, profile, key): 设置 api_key (向后兼容)
----------------------------------------------------------------------
function M.set_key(provider, profile, key)
  local tbl = M.read() or { profile = "default" }
  tbl[provider] = tbl[provider] or {}
  
  if type(tbl[provider][profile]) == "table" then
    tbl[provider][profile].api_key = key
  else
    tbl[provider][profile] = {
      api_key = key,
      base_url = "",
      base_url_claude = "",
    }
  end
  
  M.write(tbl)
end

----------------------------------------------------------------------
-- set_config(provider, profile, config): 设置完整配置
----------------------------------------------------------------------
function M.set_config(provider, profile, config)
  local tbl = M.read() or { profile = "default" }
  tbl[provider] = tbl[provider] or {}
  tbl[provider][profile] = {
    api_key = config.api_key or "",
    base_url = config.base_url or "",
    base_url_claude = config.base_url_claude or "",
  }
  M.write(tbl)
end

----------------------------------------------------------------------
-- edit(): 打开 key 文件编辑
----------------------------------------------------------------------
function M.edit()
  M.ensure()
  local path = keys_path()
  vim.cmd("edit " .. path)
end

return M