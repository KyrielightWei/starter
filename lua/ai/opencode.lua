-- lua/ai/opencode.lua
-- OpenCode 配置生成模块

local M = {}

-- OpenCode CLI 配置目录
-- 官方推荐: ~/.config/opencode/ (遵循 XDG Base Directory 规范)
-- 兼容旧版: ~/.opencode/ (自动迁移)
local function get_opencode_config_dir()
  -- XDG 规范优先
  local xdg_config = os.getenv("XDG_CONFIG_HOME") or vim.fn.expand("~/.config")
  local new_dir = xdg_config .. "/opencode"
  local old_dir = vim.fn.expand("~/.opencode")

  -- 自动迁移：如果旧目录存在且新目录不存在，迁移配置
  if vim.fn.isdirectory(old_dir) == 1 and vim.fn.isdirectory(new_dir) ~= 1 then
    -- 检查旧目录中是否有配置文件
    local old_config = old_dir .. "/opencode.json"
    local old_keys = {}
    for _, f in ipairs(vim.fn.glob(old_dir .. "/api_key_*.txt", false, true) or {}) do
      table.insert(old_keys, f)
    end

    if vim.fn.filereadable(old_config) == 1 or #old_keys > 0 then
      vim.notify("正在迁移 OpenCode 配置从 ~/.opencode/ 到 ~/.config/opencode/", vim.log.levels.WARN)

      -- 创建新目录
      vim.fn.mkdir(new_dir, "p")

      -- 迁移配置文件
      if vim.fn.filereadable(old_config) == 1 then
        vim.fn.rename(old_config, new_dir .. "/opencode.json")
      end

      -- 迁移 API key 文件
      for _, key_file in ipairs(old_keys) do
        local filename = vim.fn.fnamemodify(key_file, ":t")
        vim.fn.rename(key_file, new_dir .. "/" .. filename)
      end

      vim.notify("✅ 配置迁移完成", vim.log.levels.INFO)
    end
  end

  return new_dir
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
  -- FIX: Use Providers.list() API instead of pairs(Providers) to avoid
  -- iterating over module functions (list, get, register, etc.)
  for _, name in ipairs(Providers.list()) do
    local def = Providers.get(name)
    if def and def.endpoint then
      providers[name] = {
        api_key_name = def.api_key_name,
        endpoint = def.endpoint,
        model = def.model,
        static_models = def.static_models or {},
        model_info = def.model_info or {},
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
    agent = true, -- 新增：支持 agent 配置
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
  elseif config.model then
    -- 检查模型格式：必须是 provider/model 格式
    if not config.model:match("^[%w_-]+/.+$") then
      table.insert(
        errors,
        string.format(
          "model '%s' 必须使用 'provider/model' 格式，例如 'bailian_coding/qwen3.6-plus'",
          config.model
        )
      )
    end
  end

  if config.share and not vim.tbl_contains({ "manual", "auto", "disabled" }, config.share) then
    table.insert(errors, "share 必须是 'manual', 'auto' 或 'disabled'")
  end

  if config.autoupdate ~= nil and type(config.autoupdate) ~= "boolean" and config.autoupdate ~= "notify" then
    table.insert(errors, "autoupdate 必须是 boolean 或 'notify'")
  end

  -- Permission validation - 支持嵌套 permission 对象
  if config.permission then
    -- 支持的权限类型（扩展列表）
    local valid_perms = {
      read = true,
      edit = true,
      write = true,
      bash = true,
      external_directory = true,
      task = true,
      skill = true,
      doom_loop = true,
    }

    for perm, value in pairs(config.permission) do
      -- 检查权限类型
      if not valid_perms[perm] then
        table.insert(warnings, string.format("permission 中未知权限: %s", perm))
      end

      -- 检查权限值格式
      if type(value) == "string" then
        -- 简单格式: "read": "ask" 或 "edit": "allow"
        if value ~= "ask" and value ~= "allow" and value ~= "deny" then
          table.insert(errors, string.format("permission.%s 必须是 'ask', 'allow' 或 'deny'", perm))
        end
      elseif type(value) == "table" then
        -- 嵌套格式: "bash": { "git status*": "allow", "rm *": "ask" }
        for pattern, action in pairs(value) do
          if action ~= "ask" and action ~= "allow" and action ~= "deny" then
            table.insert(
              errors,
              string.format("permission.%s['%s'] 必须是 'ask', 'allow' 或 'deny'", perm, pattern)
            )
          end
        end
      else
        table.insert(errors, string.format("permission.%s 必须是字符串或对象", perm))
      end
    end
  end

  -- Agent validation - 支持 agent 权限覆盖
  if config.agent then
    if type(config.agent) ~= "table" then
      table.insert(errors, "agent 必须是对象")
    else
      for agent_name, agent_config in pairs(config.agent) do
        if type(agent_config) ~= "table" then
          table.insert(errors, string.format("agent.%s 必须是对象", agent_name))
        elseif agent_config.permission then
          -- 递归检查 agent.permission（使用相同的逻辑）
          for perm, value in pairs(agent_config.permission) do
            if type(value) == "string" then
              if value ~= "ask" and value ~= "allow" and value ~= "deny" then
                table.insert(
                  errors,
                  string.format("agent.%s.permission.%s 必须是 'ask', 'allow' 或 'deny'", agent_name, perm)
                )
              end
            elseif type(value) == "table" then
              for pattern, action in pairs(value) do
                if action ~= "ask" and action ~= "allow" and action ~= "deny" then
                  table.insert(
                    errors,
                    string.format(
                      "agent.%s.permission.%s['%s'] 必须是 'ask', 'allow' 或 'deny'",
                      agent_name,
                      perm,
                      pattern
                    )
                  )
                end
              end
            end
          end
        end
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

local function read_template_config(version)
  version = version or "default"
  local errors = {}
  local warnings = {}

  -- Try new template version path first
  local TemplateVersion = require("ai.template_version")
  local template_path = TemplateVersion.get_template_path("opencode", version)

  if vim.fn.filereadable(template_path) == 0 then
    -- Fallback to legacy path
    local legacy_path = get_opencode_template_path()
    if vim.fn.filereadable(legacy_path) == 1 then
      template_path = legacy_path
    else
      table.insert(warnings, "OpenCode 模板文件不存在: " .. template_path)
      table.insert(warnings, "将使用默认配置，运行 :AITemplateCreate opencode default 创建模板")
      return {}, errors, warnings
    end
  end

  local content = table.concat(vim.fn.readfile(template_path), "\n")
  local clean_content = strip_jsonc_comments(content)

  -- Security validation
  local secure_ok, security_warnings = TemplateVersion.validate_security(content)
  if not secure_ok then
    vim.list_extend(warnings, security_warnings)
  end

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
      local model_info = provider_def.model_info or {}

      for _, model_id in ipairs(models) do
        local info = model_info[model_id] or {}
        models_config[model_id] = {
          name = model_id,
          limit = info.limit or { context = 0, output = 0 },
          description = info.description,
        }
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

function M.generate_config(version_override)
  local State = require("ai.state")
  local version = version_override or State.get_template_version("opencode")

  local template_config, errors, warnings = read_template_config(version)

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

  return config, auth_config, true
end

function M.write_config(version_override)
  -- Backup before writing
  local Backup = require("ai.config_backup")
  Backup.backup("opencode")

  -- Generate config
  local config, auth_config, ok = M.generate_config(version_override)
  if not ok then
    vim.notify("配置生成失败，请修复模板错误后重试", vim.log.levels.ERROR)
    return false
  end

  -- 写入配置
  local opencode_dir = get_opencode_config_dir()
  if vim.fn.isdirectory(opencode_dir) == 0 then
    vim.fn.mkdir(opencode_dir, "p")
  end

  -- 写入 instructions.md
  local instructions_md_path = opencode_dir .. "/instructions.md"
  local SystemPrompt = require("ai.system_prompt")
  local instructions_content = SystemPrompt.for_tool("opencode")
  vim.fn.writefile(vim.split(instructions_content, "\n"), instructions_md_path)

  config.agent = config.agent or {}
  config.agent.build = config.agent.build or {}
  config.agent.build.prompt = "{file:" .. instructions_md_path .. "}"

  -- 写入 API key 文件
  for provider, key in pairs(auth_config) do
    if key and key ~= "" and key:sub(1, 6) ~= "${env:" then
      local key_file = opencode_dir .. "/api_key_" .. provider .. ".txt"
      vim.fn.writefile({ key }, key_file)
      -- Security: Set restrictive permissions on API key files
      -- chmod 600 = 384 in decimal (LuaJIT doesn't support 0o600)
      vim.uv.fs_chmod(key_file, 384)
    end
  end

  -- 写入 opencode.json
  local config_path = get_opencode_config_path()
  local config_content = format_json(config)
  vim.fn.writefile(vim.split(config_content, "\n"), config_path)

  -- 生成 TUI 配置
  local ok_tui, TuiConfig = pcall(require, "ai.opencode_tui")
  if ok_tui then
    TuiConfig.generate_tui_config()
  end

  -- Show backup info
  Backup.show_overwrite_warning("opencode")

  vim.notify("✅ OpenCode 配置生成成功", vim.log.levels.INFO)
  return true
end

----------------------------------------------------------------------
-- restore_backup(backup_num): 从备份恢复配置
-- @param backup_num number: 备份编号 (1 或 2)
----------------------------------------------------------------------
function M.restore_backup(backup_num)
  local Backup = require("ai.config_backup")
  local ok, result = Backup.restore("opencode", backup_num)
  if ok then
    vim.notify(result, vim.log.levels.INFO)
  else
    vim.notify(result, vim.log.levels.ERROR)
  end
end

function M.edit_template()
  local template_path = get_opencode_template_path()

  if vim.fn.filereadable(template_path) == 0 then
    local default_template = [[{
  "$schema": "https://opencode.ai/config.json",

  // OpenCode 配置模板
  // 修改后运行 :OpenCodeGenerateConfig 生成最终配置

  // 默认模型 (必须使用 provider/model 格式)
  "model": "bailian_coding/qwen3.6-plus",

  // 自动更新
  "autoupdate": true,

  // 会话共享
  "share": "manual",

  // 权限配置 - 安全优先
  "permission": {
    "read": {
      "*": "allow",
      "*.env": "ask",
      "*.env.*": "ask",
      ".env*": "ask",
      "*credentials*": "ask",
      "*secret*": "ask",
      "*password*": "ask",
      "*token*": "ask",
      "*key*.pem": "ask",
      "*key*.key": "ask"
    },
    "edit": {
      "*": "allow",
      "*.lock": "ask"
    },
    "bash": {
      "*": "allow",
      "ls *": "allow",
      "cat *": "allow",
      "head *": "allow",
      "tail *": "allow",
      "find *": "allow",
      "stat *": "allow",
      "du *": "allow",
      "df *": "allow",
      "wc *": "allow",
      "which *": "allow",
      "whereis *": "allow",
      "uname *": "allow",
      "date *": "allow",
      "echo *": "allow",
      "grep *": "allow",
      "rg *": "allow",
      "ag *": "allow",
      "ack *": "allow",
      "git status*": "allow",
      "git log*": "allow",
      "git diff*": "allow",
      "git show*": "allow",
      "git branch*": "allow",
      "git tag*": "allow",
      "git remote*": "allow",
      "git fetch*": "allow",
      "git rev-parse*": "allow",
      "git ls-files*": "allow",
      "git describe*": "allow",
      "git reflog*": "allow",
      "npm run build*": "allow",
      "npm run test*": "allow",
      "npm run lint*": "allow",
      "yarn run*": "allow",
      "pnpm run*": "allow",
      "make*": "allow",
      "cargo build*": "allow",
      "cargo test*": "allow",
      "cargo check*": "allow",
      "go build*": "allow",
      "go test*": "allow",
      "go vet*": "allow",
      "python -m pytest*": "allow",
      "pytest*": "allow",
      "npm install*": "allow",
      "npm ci*": "allow",
      "yarn install*": "allow",
      "pnpm install*": "allow",
      "cargo install*": "allow",
      "go get*": "allow",
      "pip install*": "allow",
      "pip3 install*": "allow",
      "stylua*": "allow",
      "prettier*": "allow",
      "eslint*": "allow",
      "rustfmt*": "allow",
      "gofmt*": "allow",
      "goimports*": "allow",
      "git pull*": "ask",
      "git merge*": "ask",
      "rm *": "ask",
      "rm -rf *": "ask",
      "rm -r *": "ask",
      "unlink *": "ask",
      "delete *": "ask",
      "mv * /dev/null": "ask",
      "trash *": "ask",
      "git push*": "ask",
      "git push -f*": "ask",
      "git push --force*": "ask",
      "git push --force-with-lease*": "ask",
      "git reset --hard*": "ask",
      "git reset --hard": "ask",
      "git checkout -f*": "ask",
      "git clean*": "ask",
      "git clean -f*": "ask",
      "git clean -fd*": "ask",
      "chmod *": "ask",
      "chown *": "ask",
      "chgrp *": "ask",
      "sudo *": "ask",
      "apt-get *": "ask",
      "yum *": "ask",
      "brew *": "ask",
      "systemctl *": "ask",
      "service *": "ask"
    },
    "external_directory": "ask",
    "doom_loop": "ask",
    "task": "ask",
    "skill": "allow"
  },

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

  vim.cmd("edit " .. vim.fn.fnameescape(template_path))

  vim.api.nvim_set_option_value("filetype", "jsonc", { buf = 0 })
  vim.api.nvim_set_option_value("commentstring", "// %s", { buf = 0 })
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
  vim.api.nvim_set_option_value("filetype", "json", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
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
