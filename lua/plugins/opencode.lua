-- lua/plugins/opencode.lua
-- OpenCode 本地插件：读取 AI 模块配置，生成 OpenCode 配置，管理终端

local M = {}

-- 配置路径
local function get_config_dir()
  return vim.fn.stdpath("config")
end

local function get_opencode_config_path()
  return get_config_dir() .. "/opencode.json"
end

local function get_opencode_auth_path()
  return get_config_dir() .. "/opencode_auth.json"
end

----------------------------------------------------------------------
-- 读取 AI 模块的 API keys
----------------------------------------------------------------------
local function read_ai_keys()
  local ok, Keys = pcall(require, "ai.keys")
  if not ok then
    return {}
  end

  local keys_data = Keys.read() or {}
  local keys = {}

  local profile = keys_data.profile or "default"
  for provider, profiles in pairs(keys_data) do
    if provider ~= "profile" and type(profiles) == "table" then
      keys[provider] = profiles[profile] or profiles["default"] or ""
    end
  end

  return keys
end

----------------------------------------------------------------------
-- 读取 AI 模块的 providers 配置
----------------------------------------------------------------------
local function read_ai_providers()
  local ok, Providers = pcall(require, "ai.providers")
  if not ok then
    return {}
  end

  local providers = {}
  for name, def in pairs(Providers) do
    if type(def) == "table" and def.endpoint then
      providers[name] = {
        api_key_name = def.api_key_name,
        endpoint = def.endpoint,
        model = def.model,
        static_models = def.static_models or {},
      }
    end
  end

  return providers
end

----------------------------------------------------------------------
-- 动态获取模型列表
----------------------------------------------------------------------
local function get_models_for_provider(provider_name, provider_def)
  local ok, Fetch = pcall(require, "ai.fetch_models")
  if ok then
    local models = Fetch.fetch(provider_name)
    if models and #models > 0 then
      local model_list = {}
      for _, m in ipairs(models) do
        local id = m.id or tostring(m)
        table.insert(model_list, id)
      end
      return model_list
    end
  end

  return provider_def.static_models or {}
end

----------------------------------------------------------------------
-- 生成 OpenCode 配置
----------------------------------------------------------------------
function M.generate_config()
  local providers = read_ai_providers()
  local keys = read_ai_keys()

  local config = {
    ["$schema"] = "https://opencode.ai/config.json",
    model = "glm-5",
    provider = {},
  }

  local auth_config = {}

  for provider_name, provider_def in pairs(providers) do
    local api_key = keys[provider_name] or ""
    
    if api_key and api_key ~= "" then
      auth_config[provider_name] = api_key

      local models = get_models_for_provider(provider_name, provider_def)
      local models_config = {}
      
      for _, model_id in ipairs(models) do
        models_config[model_id] = { name = model_id }
      end

      if vim.tbl_isempty(models_config) and provider_def.model then
        models_config[provider_def.model] = { name = provider_def.model }
      end

      config.provider[provider_name] = {
        npm = "@ai-sdk/openai-compatible",
        name = provider_name:gsub("_", " "):gsub("(%l)(%w*)", function(a, b) return string.upper(a) .. b end),
        options = {
          baseURL = provider_def.endpoint,
        },
        models = models_config,
      }

      if not config.model or config.model == "glm-5" then
        local first_model = next(models_config)
        if first_model then
          config.model = first_model
        end
      end
    end
  end

  return config, auth_config
end

----------------------------------------------------------------------
-- 格式化 JSON
----------------------------------------------------------------------
local function format_json(obj, indent)
  indent = indent or 0
  local spacing = string.rep("  ", indent)
  
  if type(obj) == "table" then
    if next(obj) == nil then
      return "{}"
    end
    
    local is_array = #obj > 0
    local items = {}
    
    if is_array then
      for i, v in ipairs(obj) do
        table.insert(items, spacing .. "  " .. format_json(v, indent + 1))
      end
      return "[\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "]"
    else
      for k, v in pairs(obj) do
        local key = type(k) == "number" and k or string.format("%q", k)
        table.insert(items, spacing .. "  " .. key .. ": " .. format_json(v, indent + 1))
      end
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "}"
    end
  elseif type(obj) == "string" then
    return string.format("%q", obj)
  elseif type(obj) == "number" or type(obj) == "boolean" then
    return tostring(obj)
  elseif obj == nil then
    return "null"
  else
    return tostring(obj)
  end
end

----------------------------------------------------------------------
-- 写入配置文件
----------------------------------------------------------------------
function M.write_config()
  local config, auth_config = M.generate_config()
  
  local config_path = get_opencode_config_path()
  local config_content = format_json(config)
  vim.fn.writefile(vim.split(config_content, "\n"), config_path)

  local auth_path = get_opencode_auth_path()
  local auth_lines = { "{" }
  local first = true
  for provider, key in pairs(auth_config) do
    if not first then
      auth_lines[#auth_lines] = auth_lines[#auth_lines] .. ","
    end
    table.insert(auth_lines, string.format('  "%s": "%s"', provider, key))
    first = false
  end
  table.insert(auth_lines, "}")
  vim.fn.writefile(auth_lines, auth_path)

  vim.notify(string.format("OpenCode 配置已更新:\n- %s\n- %s", config_path, auth_path), vim.log.levels.INFO)
end

----------------------------------------------------------------------
-- OpenCode 终端实例（延迟初始化）
----------------------------------------------------------------------
local opencode_term = nil

local function get_opencode_term()
  if not opencode_term then
    local ok, term_module = pcall(require, "toggleterm.terminal")
    if not ok then
      vim.notify("toggleterm.nvim not installed", vim.log.levels.ERROR)
      return nil
    end

    opencode_term = term_module.Terminal:new({
      cmd = "opencode",
      direction = "float",
      float_opts = {
        border = "curved",
        winblend = 0,
        width = function()
          return math.floor(vim.o.columns * 0.8)
        end,
        height = function()
          return math.floor(vim.o.lines * 0.8)
        end,
      },
      on_open = function(term)
        vim.cmd("startinsert!")
        vim.api.nvim_buf_set_name(term.bufnr, "OpenCode")
      end,
      on_exit = function(term, job, exit_code)
        if exit_code ~= 0 then
          vim.notify("OpenCode exited with code: " .. exit_code, vim.log.levels.WARN)
        end
      end,
    })
  end
  return opencode_term
end

----------------------------------------------------------------------
-- 切换 OpenCode 终端
----------------------------------------------------------------------
function M.toggle()
  if vim.fn.executable("opencode") ~= 1 then
    vim.notify("opencode not found. Install: npm install -g @opencode/cli", vim.log.levels.ERROR)
    return
  end

  local term = get_opencode_term()
  if term then
    term:toggle()
  end
end

----------------------------------------------------------------------
-- 注册命令（立即执行）
----------------------------------------------------------------------
vim.api.nvim_create_user_command("OpenCodeGenerateConfig", function()
  M.write_config()
end, { desc = "Generate OpenCode config from AI module" })

vim.api.nvim_create_user_command("OpenCodeTerminal", function()
  M.toggle()
end, { desc = "Toggle OpenCode Terminal" })

vim.api.nvim_create_user_command("OpenCodeRegenerateConfig", function()
  M.write_config()
end, { desc = "Regenerate OpenCode config" })

return {
  "akinsho/toggleterm.nvim",
  optional = true,
  keys = {
    { "<leader>to", "<cmd>OpenCodeTerminal<CR>", desc = "OpenCode AI Terminal" },
  },
}