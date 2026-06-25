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
--       -- 格式1：直接写 API key（会导出到 api_key_*.txt 文件）
--       api_key = "sk-xxx",
--
--       -- 格式2：环境变量引用（推荐，更安全）
--       -- api_key = "${env:BAILIAN_CODING_API_KEY}",
--
--       -- 格式3：空字符串（需要手动配置）
--       -- api_key = "",
--
--       base_url = "https://coding.dashscope.aliyuncs.com/v1",
--       base_url_claude = "",  -- Claude Code 专用 (可选)
--     },
--   },
-- }
--
-- 说明：
-- - api_key: API 密钥
--   - 直接值：会导出到 ~/.config/opencode/api_key_<provider>.txt
--   - ${env:VAR_NAME}：生成 {env:VAR_NAME}，从环境变量读取（推荐）
--   - 空字符串：需要手动配置
-- - base_url: API endpoint (可选，不填则使用 providers.lua 默认值)
-- - base_url_claude: Claude Code 专用 endpoint (可选)
--
-- 推荐：使用环境变量格式以避免 API key 写入文件
-- ============================================================================

local Providers = require("ai.providers")

local M = {}

-- 缓存：减少重复文件读取，带 mtime 校验
local read_cache = nil
-- #8 修复: 使用 sec + nsec 提高精度
local read_cache_mtime_sec = 0
local read_cache_mtime_nsec = 0

local function invalidate_cache()
  read_cache = nil
  read_cache_mtime_sec = 0
  read_cache_mtime_nsec = 0
end

local function keys_path()
  return vim.fn.stdpath("state") .. "/ai_keys.lua"
end

--- 安全加载 Lua 文件（sandboxed，禁止访问全局变量）
--- 解析失败时会通过 vim.notify 上报详细错误，避免静默失败。
---@param path string 文件路径
---@return table|nil
local function safe_load_lua(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local content = vim.fn.readfile(path)
  if #content == 0 then
    return nil
  end
  local code = table.concat(content, "\n")
  local func, load_err = load(code, "keys", "t", {})
  if not func then
    vim.notify(string.format("ai_keys.lua 加载失败 (%s): %s", path, load_err), vim.log.levels.ERROR)
    return nil
  end
  local ok, result = pcall(func)
  if not ok then
    vim.notify(string.format("ai_keys.lua 执行失败 (%s): %s", path, tostring(result)), vim.log.levels.ERROR)
    return nil
  end
  if type(result) ~= "table" then
    vim.notify(
      string.format("ai_keys.lua 必须 return 一个 table，实际类型: %s", type(result)),
      vim.log.levels.ERROR
    )
    return nil
  end
  return result
end

--- 验证 provider/profile 名称是否安全（仅允许字母数字、下划线、连字符）
---@param name string
---@return boolean
local function is_safe_name(name)
  return type(name) == "string" and name:match("^[%w_-]+$") ~= nil
end

----------------------------------------------------------------------
-- ensure(): 初始化 key 文件（自动包含所有 provider）
----------------------------------------------------------------------
function M.ensure()
  local path = keys_path()

  if vim.fn.filereadable(path) == 0 then
    local lines = {
      "return {",
      "  -- 全局默认配置（所有工具的 fallback）",
      "  global_default = {",
      '    provider = "bailian_coding",',
      '    model = "qwen3.6-plus",',
      "  },",
      "",
      "  -- 工具级别配置（覆盖全局默认）",
      "  tool_default = {",
      "    -- opencode = {",
      '    --   provider = "zenmux",',
      '    --   model = "anthropic/claude-opus-4.7",',
      "    -- },",
      "    -- claude_code = {",
      '    --   provider = "zenmux",',
      '    --   model = "anthropic/claude-sonnet-4.6",',
      "    -- },",
      "  },",
      "",
      '  profile = "default",',
    }

    local provider_names = {}
    for _, name in ipairs(Providers.list()) do
      table.insert(provider_names, name)
    end
    table.sort(provider_names)

    for _, name in ipairs(provider_names) do
      local def = Providers.get(name)
      if def and def.api_key_name and is_safe_name(name) then
        local endpoint = def.endpoint or ""
        endpoint = endpoint:gsub("{(%w+_BASE_ENDPOINT)}", "")

        table.insert(lines, string.format("  %s = {", name))
        table.insert(lines, "    default = {")
        table.insert(lines, '      api_key = "",')
        table.insert(lines, string.format("      base_url = %q,", endpoint))
        table.insert(lines, '      base_url_claude = "",  -- Claude Code 专用 (可选)')
        table.insert(lines, "    },")
        table.insert(lines, "  },")
      end
    end

    table.insert(lines, "}")
    vim.fn.writefile(lines, path)
  else
    -- Migration: add global_default and tool_default to existing files if missing
    local tbl = safe_load_lua(path)
    if tbl then
      if not tbl.global_default then
        tbl.global_default = {
          provider = "bailian_coding",
          model = "qwen3.6-plus",
        }
      end
      if not tbl.tool_default then
        tbl.tool_default = {}
      end
      M.write(tbl)
    end
  end

  return safe_load_lua(path)
end

----------------------------------------------------------------------
-- read(): 读取 key 文件
----------------------------------------------------------------------
function M.read()
  local path = keys_path()
  -- 校验文件 mtime，外部修改后自动失效缓存
  -- #8 修复: 使用 sec + nsec 提高精度
  if read_cache then
    local stat = vim.uv.fs_stat(path)
    if stat and stat.mtime.sec == read_cache_mtime_sec and stat.mtime.nsec == read_cache_mtime_nsec then
      return read_cache
    end
  end
  read_cache = safe_load_lua(path)
  local stat = vim.uv.fs_stat(path)
  read_cache_mtime_sec = stat and stat.mtime.sec or 0
  read_cache_mtime_nsec = stat and stat.mtime.nsec or 0
  return read_cache
end

----------------------------------------------------------------------
-- write(): 写入 key 文件
----------------------------------------------------------------------
function M.write(tbl)
  local out = { "return {" }

  -- 写入 global_default（如果存在）
  if tbl.global_default then
    table.insert(out, "  -- 全局默认配置（所有工具的 fallback）")
    table.insert(out, "  global_default = {")
    table.insert(out, string.format("    provider = %q,", tbl.global_default.provider or ""))
    table.insert(out, string.format("    model = %q,", tbl.global_default.model or ""))
    table.insert(out, "  },")
    table.insert(out, "")
  end

  -- 写入 tool_default（如果存在）
  if tbl.tool_default and next(tbl.tool_default) then
    table.insert(out, "  -- 工具级别配置（覆盖全局默认）")
    table.insert(out, "  tool_default = {")
    for tool_name, tool_config in pairs(tbl.tool_default) do
      if is_safe_name(tool_name) and tool_config.provider then
        table.insert(out, string.format("    %s = {", tool_name))
        table.insert(out, string.format("      provider = %q,", tool_config.provider))
        table.insert(out, string.format("      model = %q,", tool_config.model))
        table.insert(out, "    },")
      end
    end
    table.insert(out, "  },")
    table.insert(out, "")
  elseif tbl.tool_default then
    -- Empty tool_default table
    table.insert(out, "  -- 工具级别配置（覆盖全局默认）")
    table.insert(out, "  tool_default = {},")
    table.insert(out, "")
  end

  for provider, profiles in pairs(tbl) do
    if
      provider ~= "profile"
      and provider ~= "global_default"
      and provider ~= "tool_default"
      and is_safe_name(provider)
    then
      table.insert(out, string.format("  %s = {", provider))
      for profile, config in pairs(profiles) do
        if is_safe_name(profile) then
          if type(config) == "table" then
            table.insert(out, string.format("    %s = {", profile))
            table.insert(out, string.format("      api_key = %q,", config.api_key or ""))
            table.insert(out, string.format("      base_url = %q,", config.base_url or ""))
            table.insert(out, string.format("      base_url_claude = %q,", config.base_url_claude or ""))
            table.insert(out, "    },")
          elseif type(config) == "string" then
            -- 向后兼容旧格式
            table.insert(
              out,
              string.format('    %s = { api_key = %q, base_url = "", base_url_claude = "" },', profile, config)
            )
          end
        end
      end
      table.insert(out, "  },")
    end
  end

  table.insert(out, string.format("  profile = %q,", tbl.profile or "default"))
  table.insert(out, "}")

  vim.fn.writefile(out, keys_path())

  -- 失效内部缓存
  invalidate_cache()

  -- Invalidate caches after writing
  -- This ensures subsequent reads get fresh values
  local ok, Resolver = pcall(require, "ai.config_resolver")
  if ok and Resolver.invalidate_cache then
    Resolver.invalidate_cache()
  end

  local ok2, Fetch = pcall(require, "ai.fetch_models")
  if ok2 and Fetch.clear_cache then
    Fetch.clear_cache()
  end
end

----------------------------------------------------------------------
-- get_global_default(): 获取全局默认 provider 和 model
----------------------------------------------------------------------
function M.get_global_default()
  local tbl = M.read()
  if not tbl then
    return Providers.DEFAULT_PROVIDER, Providers.DEFAULT_MODEL
  end

  if tbl.global_default and tbl.global_default.provider then
    return tbl.global_default.provider, tbl.global_default.model
  end

  -- Fallback: 常量值
  return Providers.DEFAULT_PROVIDER, Providers.DEFAULT_MODEL
end

----------------------------------------------------------------------
-- set_global_default(provider, model): 设置全局默认 provider 和 model
----------------------------------------------------------------------
function M.set_global_default(provider, model)
  local tbl = M.read() or { profile = "default", tool_default = {} }

  tbl.global_default = {
    provider = provider,
    model = model,
  }

  M.write(tbl)
end

----------------------------------------------------------------------
-- get_tool_default(tool_name): 获取工具级别的默认配置
-- @param tool_name string: "opencode" or "claude_code"
-- @return provider, model: 工具级别配置，如果没有则返回 nil, nil
----------------------------------------------------------------------
function M.get_tool_default(tool_name)
  local tbl = M.read()
  if not tbl or not tbl.tool_default then
    return nil, nil
  end

  local tool_config = tbl.tool_default[tool_name]
  if tool_config and tool_config.provider then
    return tool_config.provider, tool_config.model
  end

  return nil, nil
end

----------------------------------------------------------------------
-- set_tool_default(tool_name, provider, model): 设置工具级别默认配置
-- @param tool_name string: "opencode" or "claude_code"
-- @param provider string: provider name
-- @param model string: model name
----------------------------------------------------------------------
function M.set_tool_default(tool_name, provider, model)
  if not is_safe_name(tool_name) then
    vim.notify("Invalid tool name: " .. tool_name, vim.log.levels.ERROR)
    return
  end

  local tbl = M.read() or { profile = "default" }

  if not tbl.tool_default then
    tbl.tool_default = {}
  end

  tbl.tool_default[tool_name] = {
    provider = provider,
    model = model,
  }

  M.write(tbl)
end

----------------------------------------------------------------------
-- clear_tool_default(tool_name): 清除工具级别配置（回退到全局默认）
----------------------------------------------------------------------
function M.clear_tool_default(tool_name)
  local tbl = M.read()
  if not tbl or not tbl.tool_default then
    return
  end

  tbl.tool_default[tool_name] = nil
  M.write(tbl)
end

----------------------------------------------------------------------
-- get_effective_default(tool_name): 获取工具的有效默认配置
-- 优先级：tool_default > global_default > 硬编码 fallback
-- @param tool_name string: "opencode" or "claude_code" (可选)
-- @return provider, model
----------------------------------------------------------------------
function M.get_effective_default(tool_name)
  -- Level 1: 工具级别配置
  if tool_name then
    local tool_provider, tool_model = M.get_tool_default(tool_name)
    if tool_provider and tool_model then
      return tool_provider, tool_model
    end
  end

  -- Level 2: 全局默认
  local global_provider, global_model = M.get_global_default()
  if global_provider and global_model then
    return global_provider, global_model
  end

  -- Level 3: 常量 fallback
  return Providers.DEFAULT_PROVIDER, Providers.DEFAULT_MODEL
end

----------------------------------------------------------------------
-- resolve_env_ref(value): 解析环境变量引用
-- 支持 ${env:VAR_NAME} 格式，如 ${env:BAILIAN_CODING_API_KEY}
----------------------------------------------------------------------
local function resolve_env_ref(value)
  if type(value) ~= "string" then
    return value
  end

  return value:gsub("%${env:(%w+)}", function(var_name)
    return os.getenv(var_name) or ""
  end)
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
    return { api_key = resolve_env_ref(config), base_url = "", base_url_claude = "" }
  end

  return {
    api_key = resolve_env_ref(config.api_key) or "",
    base_url = resolve_env_ref(config.base_url) or "",
    base_url_claude = resolve_env_ref(config.base_url_claude) or "",
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
  if not is_safe_name(provider) or not is_safe_name(profile) then
    vim.notify("Invalid provider or profile name", vim.log.levels.ERROR)
    return
  end
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
  if not is_safe_name(provider) or not is_safe_name(profile) then
    vim.notify("Invalid provider or profile name", vim.log.levels.ERROR)
    return
  end
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
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

return M
