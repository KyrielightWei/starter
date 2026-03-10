-- lua/ai/claude_code.lua
-- Claude Code CLI 集成：配置生成、终端集成、上下文传递

local M = {}

local Providers = require("ai.providers")
local Keys = require("ai.keys")

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
    -- JSON 字符串转义
    local escaped = obj
      :gsub("\\", "\\\\")
      :gsub('"', '\\"')
      :gsub("\n", "\\n")
      :gsub("\r", "\\r")
      :gsub("\t", "\\t")
    return '"' .. escaped .. '"'
  elseif type(obj) == "number" or type(obj) == "boolean" then
    return tostring(obj)
  elseif obj == nil then
    return "null"
  else
    return tostring(obj)
  end
end

local function get_config_dir()
  return vim.fn.expand("~/.claude")
end

local function get_settings_path()
  return get_config_dir() .. "/settings.json"
end

local function get_api_key_path()
  return get_config_dir() .. "/api_key.txt"
end

local function ensure_config_dir()
  local dir = get_config_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

local function get_default_settings()
  local SystemPrompt = require("ai.system_prompt")
  
  return {
    append_system_prompt = SystemPrompt.for_tool("claude_code"),
    env = {
      DISABLE_TELEMETRY = "1",
      DISABLE_ERROR_REPORTING = "1",
      DISABLE_PROMPT_CACHING = "1",
      DISABLE_BUG_COMMAND = "1",
      CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1",
    },
    permissions = {
      deny = {
        "Read(~/.claude/settings.json)",
        "Read(/etc/passwd)",
        "Read(/etc/pwd.db)",
        "Read(/etc/spwd.db)",
        "Bash(su *)",
        "Bash(mount *)",
        "Bash(umount *)",
        "Bash(ngrok *)",
        "Bash(frps *)",
        "Bash(frpc *)",
        "Bash(lt *)",
        "Bash(localtunnel *)",
        "Bash(nc *)",
        "Bash(netcat *)",
        "Bash(rm -rf /*)",
        "Bash(rm -rf /)",
      },
      allow = {
        "Read",
        "Write",
        "Edit",
        "Glob",
        "Grep",
        "Bash",
      },
      ask = {
        "Read(./**/*.pem)",
        "Read(./**/*.key)",
        "Read(./**/*id_rsa*)",
        "Bash(sudo *)",
        "Bash(chmod *)",
        "Bash(chown *)",
        "Bash(curl *)",
        "Bash(wget *)",
        "Bash(ssh *)",
        "Bash(scp *)",
        "Bash(rsync *)",
        "Bash(mv *)",
        "Bash(rm *)",
      },
    },
    disableBypassPermissionsMode = "disable",
    cleanupPeriodDays = 14,
    sandbox = {
      enabled = true,
      autoAllowBashIfSandboxed = true,
      allowUnsandboxedCommands = false,
      network = {
        allowLocalBinding = false,
      },
    },
  }
end

local function read_settings()
  local path = get_settings_path()
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local content = table.concat(vim.fn.readfile(path), "\n")
  local ok, settings = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end

  return settings
end

local function merge_settings(base, override)
  local result = vim.deepcopy(base)

  for key, value in pairs(override) do
    if type(value) == "table" and type(result[key]) == "table" then
      result[key] = merge_settings(result[key], value)
    else
      result[key] = value
    end
  end

  return result
end

local function build_provider_settings()
  local provider_name = Providers.default_provider
  local provider_def = Providers.get(provider_name)
  
  if not provider_def then
    return {}
  end

  local api_key = Keys.get_key(provider_name) or ""
  -- 使用 Claude Code 专用的 base_url（如果配置了的话）
  local endpoint = Keys.get_base_url_claude(provider_name)
  
  local model = Providers.default_model

  local env = {}

  if api_key ~= "" then
    env["ANTHROPIC_AUTH_TOKEN"] = api_key
  end

  if endpoint ~= "" then
    env["ANTHROPIC_BASE_URL"] = endpoint
  end

  env["ANTHROPIC_MODEL"] = model
  env["ANTHROPIC_SMALL_FAST_MODEL"] = model
  env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = model
  env["ANTHROPIC_DEFAULT_OPUS_MODEL"] = model
  env["ANTHROPIC_DEFAULT_SONNET_MODEL"] = model

  local settings = {}
  if vim.tbl_count(env) > 0 then
    settings.env = env
  end

  return settings
end

function M.generate_settings(opts)
  opts = opts or {}

  local Resolver = require("ai.config_resolver")
  local default_settings = get_default_settings()
  local provider_settings = build_provider_settings()
  local existing_settings = read_settings() or {}

  local settings = merge_settings(default_settings, existing_settings)
  settings = merge_settings(settings, provider_settings)

  if opts.model then
    settings.model = opts.model
  end

  return settings
end

function M.write_settings(opts)
  opts = opts or {}

  ensure_config_dir()

  local settings = M.generate_settings(opts)
  local path = get_settings_path()

  local content = format_json(settings)
  local lines = vim.split(content, "\n")
  vim.fn.writefile(lines, path)

  vim.notify("Claude Code settings written to: " .. path, vim.log.levels.INFO)

  return true
end

function M.edit_settings()
  local path = get_settings_path()

  if vim.fn.filereadable(path) == 0 then
    M.write_settings()
  end

  vim.cmd("edit " .. path)
end

function M.preview_settings()
  local settings = M.generate_settings()
  local content = format_json(settings)
  local lines = vim.split(content, "\n")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "json")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_name(buf, "Claude Code Settings Preview")

  vim.api.nvim_win_set_buf(0, buf)
  vim.notify("Preview mode: q to close", vim.log.levels.INFO)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
end

function M.toggle_terminal(opts)
  local Terminal = require("ai.terminal")
  Terminal.toggle("claude", opts)
end

function M.open_with_context(opts)
  opts = opts or {}
  local Terminal = require("ai.terminal")
  Terminal.toggle_with_context("claude", opts)
end

function M.check_installation()
  if vim.fn.executable("claude") == 1 then
    return true, "Claude Code is installed"
  end

  return false, "Claude Code is not installed. Install with: npm install -g @anthropic-ai/claude-code"
end

function M.get_status()
  local installed, message = M.check_installation()
  local config_exists = vim.fn.filereadable(get_settings_path()) == 1

  return {
    installed = installed,
    message = message,
    config_exists = config_exists,
    config_path = get_settings_path(),
  }
end

function M.setup(opts)
  opts = opts or {}

  if opts.auto_generate_config then
    M.write_settings(opts)
  end

  return M
end

return M