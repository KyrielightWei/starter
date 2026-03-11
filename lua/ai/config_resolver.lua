-- lua/ai/config_resolver.lua
-- 配置解析器：支持多层配置合并、动态引用、热更新

local Providers = require("ai.providers")
local Keys = require("ai.keys")

local M = {}

local cache = {
  config = nil,
  last_modified = 0,
}

local function deep_merge(base, override)
  if type(base) ~= "table" or type(override) ~= "table" then
    return override
  end

  local result = vim.deepcopy(base)
  for key, value in pairs(override) do
    if type(value) == "table" and type(result[key]) == "table" then
      result[key] = deep_merge(result[key], value)
    else
      result[key] = value
    end
  end
  return result
end

local function strip_jsonc_comments(content)
  local result = {}
  local in_string = false
  local escape_next = false
  local i = 1

  while i <= #content do
    local char = content:sub(i, i)

    if escape_next then
      table.insert(result, char)
      escape_next = false
      i = i + 1
    elseif char == "\\" and in_string then
      table.insert(result, char)
      escape_next = true
      i = i + 1
    elseif char == '"' then
      table.insert(result, char)
      in_string = not in_string
      i = i + 1
    elseif not in_string then
      if char == "/" and i < #content then
        local next_char = content:sub(i + 1, i + 1)
        if next_char == "/" then
          while i <= #content and content:sub(i, i) ~= "\n" do
            i = i + 1
          end
        elseif next_char == "*" then
          i = i + 2
          while i <= #content do
            if content:sub(i, i) == "*" and i < #content and content:sub(i + 1, i + 1) == "/" then
              i = i + 2
              break
            end
            i = i + 1
          end
        else
          table.insert(result, char)
          i = i + 1
        end
      else
        table.insert(result, char)
        i = i + 1
      end
    else
      table.insert(result, char)
      i = i + 1
    end
  end

  return table.concat(result)
end

local function get_env_var(provider)
  local def = Providers.get(provider)
  return def and def.api_key_name or "OPENAI_API_KEY"
end

function M.get_provider_field(provider_name, field)
  local def = Providers.get(provider_name)
  if not def then return nil end

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
        local expanded = vim.fn.expand(ref_key)
        if vim.fn.filereadable(expanded) == 1 then
          return table.concat(vim.fn.readfile(expanded), "\n")
        end
      elseif ref_type == "exec" then
        local result = vim.fn.system(ref_key)
        if vim.v.shell_error == 0 then
          return vim.trim(result)
        end
      end

      return ""
    end)
  elseif type(value) == "table" then
    local result = {}
    for k, v in pairs(value) do
      if k:sub(1, 1) ~= "$" then
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
  return {
    ["$schema"] = "https://opencode.ai/config.json",
    model = Providers.default_model,
    small_model = Providers.default_model,
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

  for provider_name, provider_def in pairs(Providers) do
    if type(provider_def) == "table" and provider_def.endpoint then
      local api_key = Keys.get_key(provider_name)

      if api_key and api_key ~= "" then
        auth_config[provider_name] = api_key

        local models = provider_def.static_models or {}
        if provider_def.model then
          local found = false
          for _, m in ipairs(models) do
            if m == provider_def.model then found = true end
          end
          if not found then
            table.insert(models, provider_def.model)
          end
        end

        local models_config = {}
        for _, model_id in ipairs(models) do
          models_config[model_id] = { name = model_id }
        end

        -- 使用 key 文件中的 base_url (OpenAI 风格)
        local endpoint = Keys.get_base_url(provider_name)

        provider_config[provider_name] = {
          npm = "@ai-sdk/openai-compatible",
          name = provider_name:gsub("_", " "):gsub("(%l)(%w*)", function(a, b)
            return string.upper(a) .. b
          end),
          options = {
            baseURL = endpoint,
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
  local parts = vim.split(path, ".")
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
  local parts = vim.split(path, ".")
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