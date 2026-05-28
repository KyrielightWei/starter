-- lua/ai/config_resolver.lua
-- 配置解析器：支持多层配置合并、动态引用、热更新

local Providers = require("ai.providers")
local Keys = require("ai.keys")
local JsonUtil = require("ai.json_util")

local M = {}

local cache = {
  config = nil,
  last_modified = 0,
}

local deep_merge = JsonUtil.deep_merge
local strip_jsonc_comments = JsonUtil.strip_jsonc_comments

-- ${file:...} 引用允许的根目录白名单
-- 防止任意文件读取（例如 /etc/passwd、~/.ssh/id_rsa）
local function is_file_path_allowed(path)
  local expanded = vim.fn.expand(path)
  local abs = vim.fn.fnamemodify(expanded, ":p")
  local home = vim.fn.expand("~")
  local allowed_prefixes = {
    home .. "/.config/",
    home .. "/.local/state/",
    home .. "/.claude/",
    home .. "/.opencode/",
    vim.fn.stdpath("config") .. "/",
    vim.fn.stdpath("state") .. "/",
    vim.fn.stdpath("data") .. "/",
    vim.fn.getcwd() .. "/",
  }
  for _, prefix in ipairs(allowed_prefixes) do
    if abs:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

local function get_env_var(provider)
  local def = Providers.get(provider)
  return def and def.api_key_name or "OPENAI_API_KEY"
end

function M.get_provider_field(provider_name, field)
  local def = Providers.get(provider_name)
  if not def then
    return nil
  end

  if field == "model" then
    return def.model
  elseif field == "endpoint" then
    return def.endpoint
  elseif field == "api_key" then
    return Keys.get_key(provider_name)
  end
  return def[field]
end

function M.get_api_key(provider_name)
  return Keys.get_key(provider_name)
end

local function resolve_refs(value, context)
  context = context or {}

  if type(value) == "string" then
    return value:gsub("%${([^}]+)}", function(ref)
      local ref_type, ref_key = ref:match("^(%w+):(.+)$")

      if ref_type == "env" then
        return os.getenv(ref_key) or ""
      elseif ref_type == "provider" then
        local provider, field = ref_key:match("^([^:]+):(.+)$")
        if provider and field then
          return M.get_provider_field(provider, field) or ""
        end
      elseif ref_type == "key" then
        return M.get_api_key(ref_key) or ""
      elseif ref_type == "file" then
        if not is_file_path_allowed(ref_key) then
          vim.notify(string.format("${file:%s} 路径未在白名单内，已拒绝", ref_key), vim.log.levels.WARN)
          return ""
        end
        local expanded = vim.fn.expand(ref_key)
        if vim.fn.filereadable(expanded) == 1 then
          return table.concat(vim.fn.readfile(expanded), "\n")
        end
      elseif ref_type == "exec" then
        -- Security: ${exec:...} is disabled to prevent command injection
        -- If you need dynamic values, use ${env:...} or ${file:...} instead
        vim.notify("${exec:...} is disabled for security", vim.log.levels.WARN)
        return ""
      end

      return ""
    end)
  elseif type(value) == "table" then
    local result = {}
    for k, v in pairs(value) do
      -- 跳过以 "$" 开头的元数据 key（如 $schema）；非字符串 key（数组下标）直接保留
      if type(k) ~= "string" or k:sub(1, 1) ~= "$" then
        result[k] = resolve_refs(v, context)
      end
    end
    return result
  end

  return value
end

local function get_config_dir()
  return vim.fn.stdpath("config")
end

local function get_template_path()
  return get_config_dir() .. "/opencode.template.jsonc"
end

local function get_project_config_path()
  local root = vim.fn.getcwd()
  return root .. "/.opencode.json"
end

function M.get_defaults()
  -- OpenCode needs full model format: provider/model
  -- Use tool-specific default for OpenCode, fallback to global default
  local Registry = require("ai.provider_manager.registry")
  local provider, model = Registry.get_effective_default("opencode")

  -- For providers like zenmux that include provider prefix in model names (e.g., "anthropic/claude-opus-4.6")
  -- the format should be: zenmux/anthropic/claude-opus-4.6
  -- For providers with simple model names (e.g., "glm-5"), format is: bailian_coding/glm-5
  local default_model = provider .. "/" .. model

  return {
    ["$schema"] = "https://opencode.ai/config.json",
    model = default_model,
    small_model = default_model,
    autoupdate = true,
    share = "manual",
    permission = {
      edit = "ask",
      bash = "ask",
      write = "ask",
    },
    watcher = {
      ignore = {
        "node_modules/**",
        "dist/**",
        ".git/**",
        "*.log",
      },
    },
    compaction = {
      auto = true,
      prune = true,
      reserved = 10000,
    },
  }
end

function M.read_template()
  local template_path = get_template_path()

  if vim.fn.filereadable(template_path) == 0 then
    return {}
  end

  local content = table.concat(vim.fn.readfile(template_path), "\n")
  local clean_content = strip_jsonc_comments(content)

  local ok, config = pcall(vim.json.decode, clean_content)
  if not ok then
    vim.notify("模板解析错误: " .. tostring(config), vim.log.levels.WARN)
    return {}
  end

  local result = {}
  for k, v in pairs(config or {}) do
    if k:sub(1, 1) ~= "$" or k == "$schema" then
      result[k] = v
    end
  end

  return result
end

function M.read_project_config()
  local project_path = get_project_config_path()

  if vim.fn.filereadable(project_path) == 0 then
    return {}
  end

  local content = table.concat(vim.fn.readfile(project_path), "\n")
  local ok, config = pcall(vim.json.decode, content)
  if not ok then
    return {}
  end

  return config or {}
end

function M.build_provider_config()
  local provider_config = {}
  local auth_config = {}

  -- FIX: Use Providers.list() API instead of pairs(Providers)
  for _, provider_name in ipairs(Providers.list()) do
    local provider_def = Providers.get(provider_name)
    if provider_def and provider_def.endpoint then
      local api_key = Keys.get_key(provider_name)

      if api_key and api_key ~= "" then
        auth_config[provider_name] = api_key

        local models = provider_def.static_models or {}
        if provider_def.model then
          local found = false
          for _, m in ipairs(models) do
            if m == provider_def.model then
              found = true
            end
          end
          if not found then
            table.insert(models, provider_def.model)
          end
        end

        local models_config = {}
        for _, model_id in ipairs(models) do
          models_config[model_id] = { name = model_id }

          -- Add model info if available (per D-09)
          if provider_def.model_info and provider_def.model_info[model_id] then
            local info = provider_def.model_info[model_id]
            if info.description then
              models_config[model_id].description = info.description
            end
            if info.limit then
              models_config[model_id].limit = info.limit
            end
          end
        end

        -- 使用 key 文件中的 base_url (OpenAI 风格)
        local endpoint = Keys.get_base_url(provider_name)

        -- Determine API key format based on ai_keys.lua content:
        -- Format 1: {env:VAR_NAME} if api_key starts with "${env:"
        -- Format 2: {file:...} if api_key is actual value (default)

        local api_key_value
        if api_key:sub(1, 6) == "${env:" and api_key:sub(-1) == "}" then
          -- Environment variable reference: ${env:VAR_NAME} → {env:VAR_NAME}
          -- Extract VAR_NAME from "${env:VAR_NAME}"
          local env_var = api_key:sub(7, -2) -- Remove "${env:" prefix and "}" suffix
          api_key_value = "{env:" .. env_var .. "}"
        else
          -- Actual API key: write to file and use {file:...}
          local xdg_config = os.getenv("XDG_CONFIG_HOME") or vim.fn.expand("~/.config")
          local api_key_path = xdg_config .. "/opencode/api_key_" .. provider_name .. ".txt"
          api_key_value = "{file:" .. api_key_path .. "}"
        end

        provider_config[provider_name] = {
          npm = "@ai-sdk/openai-compatible",
          name = provider_name:gsub("_", " "):gsub("(%l)(%w*)", function(a, b)
            return string.upper(a) .. b
          end),
          options = {
            baseURL = endpoint,
            apiKey = api_key_value,
          },
          models = models_config,
        }
      end
    end
  end

  return provider_config, auth_config
end

function M.resolve(opts)
  opts = opts or {}

  if not opts.force and cache.config and os.time() - cache.last_modified < 5 then
    return cache.config
  end

  local config = M.get_defaults()

  local template_config = M.read_template()
  config = deep_merge(config, template_config)

  local project_config = M.read_project_config()
  config = deep_merge(config, project_config)

  config = resolve_refs(config)

  local dynamic_providers, auth_config = M.build_provider_config()
  if not config.provider then
    config.provider = {}
  end
  config.provider = deep_merge(config.provider, dynamic_providers)

  cache.config = config
  cache.last_modified = os.time()

  return config, auth_config
end

function M.invalidate_cache()
  cache.config = nil
  cache.last_modified = 0
end

function M.get(path, default)
  local config = M.resolve()
  local parts = vim.split(path, ".", { plain = true })
  local current = config

  for _, part in ipairs(parts) do
    if type(current) ~= "table" then
      return default
    end
    current = current[part]
  end

  return current ~= nil and current or default
end

function M.set(path, value)
  local config = M.resolve()
  local parts = vim.split(path, ".", { plain = true })
  local current = config

  for i = 1, #parts - 1 do
    local part = parts[i]
    if type(current[part]) ~= "table" then
      current[part] = {}
    end
    current = current[part]
  end

  current[parts[#parts]] = value
  cache.config = config

  return true
end

M.deep_merge = deep_merge

return M
