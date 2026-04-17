-- lua/ai/opencode.lua
-- OpenCode 配置生成模块

local M = {}

-- OpenCode CLI 配置目录 (~/.opencode/)
-- OpenCode 使用 ~/.opencode/ 作为全局配置目录，而不是 ~/.config/opencode/
local function get_opencode_config_dir()
  return vim.fn.expand("~/.opencode")
end

-- Neovim 配置目录 (存放模板)
local function get_nvim_config_dir()
  return vim.fn.stdpath("config")
end

local function get_opencode_config_path()
  return get_opencode_config_dir() .. "/opencode.json"
end

local function get_opencode_template_path()
  return get_nvim_config_dir() .. "/opencode.template.jsonc"
end

local function get_opencode_tui_path()
  return get_opencode_config_dir() .. "/tui.json"
end

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
      local config = profiles[profile] or profiles["default"]
      -- 兼容新旧格式
      if type(config) == "table" then
        keys[provider] = config.api_key or ""
      elseif type(config) == "string" then
        keys[provider] = config
      else
        keys[provider] = ""
      end
    end
  end

  return keys, profile
end

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

  local clean = table.concat(result)
  -- 去除尾随逗号 (JSON 不允许)
  clean = clean:gsub(",%s*([}%]])", "%1")
  return clean
end

local function validate_template(config)
  local errors = {}
  local warnings = {}

  local valid_keys = {
    ["$schema"] = true,
    model = true,
    small_model = true,
    provider = true,
    autoupdate = true,
    default_agent = true,
    share = true,
    permission = true,
    tools = true,
    command = true,
    formatter = true,
    watcher = true,
    compaction = true,
    server = true,
    instructions = true,
    enabled_providers = true,
    disabled_providers = true,
    experimental = true,
    mcp = true,
    plugin = true,
  }

  for key, _ in pairs(config) do
    if not valid_keys[key] then
      table.insert(warnings, string.format("未知配置项: %s", key))
    end
  end

  if config.model and type(config.model) ~= "string" then
    table.insert(errors, "model 必须是字符串")
  elseif config.model and not config.model:find("/") then
    table.insert(
      warnings,
      string.format(
        "model '%s' 缺少 provider 前缀，建议使用 'provider/model' 格式（生成时会自动补全）",
        config.model
      )
    )
  end

  if config.share and not vim.tbl_contains({ "manual", "auto", "disabled" }, config.share) then
    table.insert(errors, "share 必须是 'manual', 'auto' 或 'disabled'")
  end

  if config.autoupdate ~= nil and type(config.autoupdate) ~= "boolean" and config.autoupdate ~= "notify" then
    table.insert(errors, "autoupdate 必须是 boolean 或 'notify'")
  end

  if config.permission then
    local valid_perms = { edit = true, bash = true, write = true }
    for perm, value in pairs(config.permission) do
      if not valid_perms[perm] then
        table.insert(warnings, string.format("permission 中未知权限: %s", perm))
      end
      if value ~= "ask" and value ~= "allow" then
        table.insert(errors, string.format("permission.%s 必须是 'ask' 或 'allow'", perm))
      end
    end
  end

  if config.provider and type(config.provider) ~= "table" then
    table.insert(errors, "provider 必须是对象")
  end

  if config.watcher and config.watcher.ignore then
    if type(config.watcher.ignore) ~= "table" then
      table.insert(errors, "watcher.ignore 必须是数组")
    end
  end

  return errors, warnings
end

local function read_template_config()
  local template_path = get_opencode_template_path()
  local errors = {}
  local warnings = {}

  if vim.fn.filereadable(template_path) == 0 then
    table.insert(warnings, "OpenCode 模板文件不存在: " .. template_path)
    table.insert(warnings, "将使用默认配置，运行 :OpenCodeEditTemplate 创建模板")
    return {}, errors, warnings
  end

  local content = table.concat(vim.fn.readfile(template_path), "\n")
  local clean_content = strip_jsonc_comments(content)

  local ok, config = pcall(vim.json.decode, clean_content)
  if not ok then
    local err_msg = tostring(config)
    table.insert(errors, "JSON 解析错误: " .. err_msg)
    return {}, errors, warnings
  end

  local validation_errors, validation_warnings = validate_template(config or {})
  vim.list_extend(errors, validation_errors)
  vim.list_extend(warnings, validation_warnings)

  return config or {}, errors, warnings
end

local function build_provider_config(keys, profile)
  local providers = read_ai_providers()
  local provider_config = {}
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

      local endpoint = provider_def.endpoint
      endpoint = endpoint:gsub("{(%w+_BASE_ENDPOINT)}", function(var)
        return os.getenv(var) or ""
      end)

      provider_config[provider_name] = {
        npm = "@ai-sdk/openai-compatible",
        name = provider_name:gsub("_", " "):gsub("(%l)(%w*)", function(a, b)
          return string.upper(a) .. b
        end),
        options = {
          baseURL = endpoint,
          apiKey = api_key,
        },
        models = models_config,
      }
    end
  end

  return provider_config, auth_config
end

local function deep_merge(base, override)
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
      local sorted_keys = {}
      for k in pairs(obj) do
        table.insert(sorted_keys, k)
      end
      table.sort(sorted_keys)

      for _, k in ipairs(sorted_keys) do
        local v = obj[k]
        local key = type(k) == "number" and k or string.format("%q", k)
        table.insert(items, spacing .. "  " .. key .. ": " .. format_json(v, indent + 1))
      end
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "}"
    end
  elseif type(obj) == "string" then
    local escaped = obj:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return '"' .. escaped .. '"'
  elseif type(obj) == "number" or type(obj) == "boolean" then
    return tostring(obj)
  elseif obj == nil then
    return "null"
  else
    return tostring(obj)
  end
end

local function show_validation_result(errors, warnings, show_success)
  local lines = {}

  if #errors > 0 then
    table.insert(lines, "❌ 发现错误:")
    for _, err in ipairs(errors) do
      table.insert(lines, "  • " .. err)
    end
  end

  if #warnings > 0 then
    table.insert(lines, "⚠️  警告:")
    for _, warn in ipairs(warnings) do
      table.insert(lines, "  • " .. warn)
    end
  end

  if #errors == 0 and #warnings == 0 and show_success then
    table.insert(lines, "✅ 模板配置有效")
  end

  if #lines > 0 then
    vim.notify(table.concat(lines, "\n"), #errors > 0 and vim.log.levels.ERROR or vim.log.levels.INFO)
  end

  return #errors == 0
end

function M.validate_template()
  local _, errors, warnings = read_template_config()
  return show_validation_result(errors, warnings, true)
end

function M.generate_config()
  local template_config, errors, warnings = read_template_config()

  if #errors > 0 then
    show_validation_result(errors, warnings, false)
    return nil, nil, false
  end

  if #warnings > 0 then
    show_validation_result(errors, warnings, false)
  end

  local Resolver = require("ai.config_resolver")
  local dynamic_providers, auth_config = Resolver.build_provider_config()

  local base_config = Resolver.get_defaults()

  local config = deep_merge(base_config, template_config)

  if not config.provider then
    config.provider = {}
  end
  config.provider = deep_merge(config.provider, dynamic_providers)

  -- 确保 model/small_model 使用 provider/model 格式
  local function ensure_provider_prefix(model_value)
    if not model_value or type(model_value) ~= "string" then
      return model_value
    end
    if model_value:find("/") then
      return model_value
    end
    -- 优先检查默认 provider
    local default = Providers.default_provider
    local default_def = Providers.get(default)
    if default_def then
      if default_def.model == model_value then
        return default .. "/" .. model_value
      end
      for _, m in ipairs(default_def.static_models or {}) do
        if m == model_value then
          return default .. "/" .. model_value
        end
      end
    end
    -- 再遍历其他 provider
    for provider_name, _ in pairs(config.provider or {}) do
      if provider_name ~= default then
        local provider_def = Providers.get(provider_name)
        if provider_def then
          if provider_def.model == model_value then
            return provider_name .. "/" .. model_value
          end
          for _, m in ipairs(provider_def.static_models or {}) do
            if m == model_value then
              return provider_name .. "/" .. model_value
            end
          end
        end
      end
    end
    -- 回退：使用默认 provider
    return default .. "/" .. model_value
  end

  config.model = ensure_provider_prefix(config.model)
  if config.small_model then
    config.small_model = ensure_provider_prefix(config.small_model)
  end

  return config, auth_config, true
end

function M.write_config()
  -- 检查并安装 ECC (同时为 Claude Code 和 OpenCode 安装)
  local Ecc = require("ai.ecc")
  local ecc_installed = Ecc.ensure_installed({ target = "opencode", profile = "developer" })

  local config, auth_config, ok = M.generate_config()
  if not ok then
    vim.notify("配置生成失败，请修复模板错误后重试", vim.log.levels.ERROR)
    return false
  end

  -- 确保 OpenCode 配置目录存在
  local opencode_dir = get_opencode_config_dir()
  if vim.fn.isdirectory(opencode_dir) == 0 then
    vim.fn.mkdir(opencode_dir, "p")
  end

  -- 写入 instructions.md 文件
  local instructions_md_path = opencode_dir .. "/instructions.md"
  local SystemPrompt = require("ai.system_prompt")
  local instructions_content = SystemPrompt.for_tool("opencode")
  vim.fn.writefile(vim.split(instructions_content, "\n"), instructions_md_path)

  -- 设置 build agent 的 system prompt (使用 {file:...} 引用)
  config.agent = config.agent or {}
  config.agent.build = config.agent.build or {}
  config.agent.build.prompt = "{file:" .. instructions_md_path .. "}"

  -- 写入 API key 文件 (每个 provider 一个文件)
  for provider, key in pairs(auth_config) do
    if key and key ~= "" then
      local key_file = opencode_dir .. "/api_key_" .. provider .. ".txt"
      vim.fn.writefile({ key }, key_file)
    end
  end

  -- 写入 opencode.json（OpenCode 官方配置）
  local config_path = get_opencode_config_path()
  local config_content = format_json(config)
  vim.fn.writefile(vim.split(config_content, "\n"), config_path)

  -- 打印配置结果
  local ecc = Ecc.get_status()
  local notify_lines = { "✅ OpenCode 配置生成成功", "" }
  vim.list_extend(notify_lines, Ecc.format_notification(ecc))

  if ecc then
    table.insert(notify_lines, "  Rules: ~/.claude/rules/")
    table.insert(notify_lines, "  Agents: ~/.claude/agents/")
    table.insert(notify_lines, "  Commands: ~/.opencode/commands/")
  end

  vim.notify(table.concat(notify_lines, "\n"), vim.log.levels.INFO)

  return true
end

function M.edit_template()
  local template_path = get_opencode_template_path()

  if vim.fn.filereadable(template_path) == 0 then
    local default_template = [[{
  "$schema": "https://opencode.ai/config.json",

  // OpenCode 配置模板
  // 修改后运行 :OpenCodeGenerateConfig 生成最终配置

  // 默认模型 (格式: provider/model)
  "model": "bailian_coding/glm-5",

  // 自动更新
  "autoupdate": true,

  // 会话共享
  "share": "manual",

  // 权限配置
  "permission": {},

  // 文件监视器配置
  "watcher": {
    "ignore": [
      "node_modules/**",
      "dist/**",
      ".git/**",
      "*.log"
    ]
  },

  // 上下文压缩配置
  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 10000
  }
}]]
    vim.fn.writefile(vim.split(default_template, "\n"), template_path)
    vim.notify("已创建默认模板文件", vim.log.levels.INFO)
  end

  vim.cmd("edit " .. template_path)

  vim.api.nvim_buf_set_option(0, "filetype", "jsonc")
  vim.api.nvim_buf_set_option(0, "commentstring", "// %s")
end

function M.preview_config()
  local config, _, ok = M.generate_config()
  if not ok then
    return
  end

  local preview = format_json(config)
  local lines = vim.split(preview, "\n")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "json")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_name(buf, "OpenCode Config Preview")

  vim.api.nvim_win_set_buf(0, buf)
  vim.notify("预览模式: q 退出", vim.log.levels.INFO)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
end

function M.toggle_terminal(opts)
  local Terminal = require("ai.terminal")
  Terminal.create_preset("opencode", opts)
end

function M.open_with_context(opts)
  opts = opts or {}
  local Terminal = require("ai.terminal")
  Terminal.create_preset_with_context("opencode", opts)
end

function M.check_installation()
  if vim.fn.executable("opencode") == 1 then
    return true, "OpenCode is installed"
  end
  return false, "OpenCode not found. Install: npm install -g @opencode/cli"
end

function M.get_status()
  local installed, message = M.check_installation()
  local config_exists = vim.fn.filereadable(get_opencode_config_path()) == 1
  local template_exists = vim.fn.filereadable(get_opencode_template_path()) == 1

  return {
    installed = installed,
    message = message,
    config_exists = config_exists,
    template_exists = template_exists,
    config_path = get_opencode_config_path(),
    template_path = get_opencode_template_path(),
  }
end

return M
