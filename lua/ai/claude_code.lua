-- lua/ai/claude_code.lua
-- Claude Code CLI 集成：配置生成、终端集成、上下文传递

local M = {}

local Providers = require("ai.providers")
local Keys = require("ai.keys")

-- 判断 table 是否为纯数组（所有 key 为连续整数）
local function tbl_is_array(t)
  if type(t) ~= "table" then
    return false
  end
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then
      return false
    end
  end
  return i > 0
end

local function format_json(obj, indent)
  indent = indent or 0
  local spacing = string.rep("  ", indent)

  if type(obj) == "table" then
    if next(obj) == nil then
      return "{}"
    end

    local items = {}

    if tbl_is_array(obj) then
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

local function get_config_dir()
  return vim.fn.expand("~/.claude")
end

local function get_settings_path()
  return get_config_dir() .. "/settings.json"
end

local function get_api_key_path()
  return get_config_dir() .. "/api_key.txt"
end

local function get_template_path()
  return vim.fn.stdpath("config") .. "/claude_code.template.jsonc"
end

local function get_ccstatusline_template_path()
  return vim.fn.stdpath("config") .. "/ccstatusline.template.jsonc"
end

local function get_ccstatusline_settings_path()
  return vim.fn.expand("~/.config/ccstatusline/settings.json")
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
  -- 匹配: , 后面跟着空白和 } 或 ]
  clean = clean:gsub(",%s*([}%]])", "%1")

  return clean
end

local function read_template()
  local template_path = get_template_path()
  local warnings = {}

  if vim.fn.filereadable(template_path) == 0 then
    return {}, warnings
  end

  local content = table.concat(vim.fn.readfile(template_path), "\n")
  local clean_content = strip_jsonc_comments(content)

  local ok, config = pcall(vim.json.decode, clean_content)
  if not ok then
    table.insert(warnings, "Claude Code 模板解析错误: " .. tostring(config))
    return {}, warnings
  end

  local result = {}
  for k, v in pairs(config or {}) do
    if k:sub(1, 1) ~= "$" or k == "$schema" then
      result[k] = v
    end
  end

  return result, warnings
end

local function ensure_config_dir()
  local dir = get_config_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

local function read_ccstatusline_template()
  local template_path = get_ccstatusline_template_path()

  if vim.fn.filereadable(template_path) == 0 then
    return nil
  end

  local content = table.concat(vim.fn.readfile(template_path), "\n")
  local clean_content = strip_jsonc_comments(content)

  local ok, config = pcall(vim.json.decode, clean_content)
  if not ok then
    return nil
  end

  return config
end

local function write_ccstatusline_settings()
  local template = read_ccstatusline_template()
  if not template then
    return false, "ccstatusline template not found"
  end

  local settings_path = get_ccstatusline_settings_path()
  local settings_dir = vim.fn.fnamemodify(settings_path, ":h")

  if vim.fn.isdirectory(settings_dir) == 0 then
    vim.fn.mkdir(settings_dir, "p")
  end

  local content = format_json(template)
  local lines = vim.split(content, "\n")
  vim.fn.writefile(lines, settings_path)

  return true
end

local function get_default_settings()
  local SystemPrompt = require("ai.system_prompt")

  return {
    ["$schema"] = "https://json.schemastore.org/claude-code-settings.json",
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

-- ccstatusline 默认配置（仅在 existing 中不存在时使用）
local function get_default_statusline()
  return {
    type = "command",
    command = "npx -y ccstatusline@latest",
    padding = 0,
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
    -- 如果两个都是数组，直接覆盖
    if tbl_is_array(value) and tbl_is_array(result[key]) then
      result[key] = vim.deepcopy(value)
    elseif type(value) == "table" and type(result[key]) == "table" then
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
  local config = Keys.get_config(provider_name)
  local endpoint = ""
  local using_fallback = false

  -- 优先使用 base_url_claude
  if config.base_url_claude and config.base_url_claude ~= "" then
    endpoint = config.base_url_claude
  elseif config.base_url and config.base_url ~= "" then
    -- 回退到 base_url
    endpoint = config.base_url
    using_fallback = true
  else
    -- 最后回退到 providers.lua 默认值
    endpoint = Keys.get_base_url(provider_name)
    using_fallback = true
  end

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

  -- 告警：base_url_claude 未配置
  if using_fallback then
    vim.notify(
      string.format(
        "⚠️  Claude Code: base_url_claude 未配置，使用 %s\n建议在 :AIEditKeys 中设置专用的 base_url_claude",
        endpoint ~= "" and endpoint or "默认值"
      ),
      vim.log.levels.WARN
    )
  end

  return settings
end

function M.generate_settings(opts)
  opts = opts or {}

  local default_settings = get_default_settings()
  local template_settings, template_warnings = read_template()
  local provider_settings = build_provider_settings()

  -- 显示模板警告
  if #template_warnings > 0 then
    vim.notify(table.concat(template_warnings, "\n"), vim.log.levels.WARN)
  end

  -- 合并顺序：默认 -> 模板 -> provider (key文件)
  local settings = merge_settings(default_settings, template_settings)
  settings = merge_settings(settings, provider_settings)

  if opts.model then
    settings.model = opts.model
  end

  return settings
end

-- build_final_settings(): 构建最终写入的配置（existing + generated + statusLine seed）
local function build_final_settings(opts)
  local generated = M.generate_settings(opts)
  local existing = read_settings() or {}
  local final = merge_settings(existing, generated)

  -- statusLine: 仅在 existing 和 template 都没有时，使用默认值（seed）
  -- 用户可以通过模板覆盖，或直接编辑 settings.json（不会被生成器覆盖）
  if not final.statusLine then
    final.statusLine = get_default_statusline()
  end

  return final
end

function M.write_settings(opts)
  opts = opts or {}

  -- 读取 switcher 分配的组件
  local Switcher = require("ai.components.switcher")
  local Registry = require("ai.components.registry")
  local comp_name = Switcher.get_active("claude")

  -- Guard: component not assigned
  if not comp_name or not Registry.is_registered(comp_name) then
    local assignments = Switcher.get_all()
    local lines = {
      "❌ Claude Code: 未分配组件",
      "",
      "  当前分配:",
    }
    for tool, comp in pairs(assignments) do
      table.insert(lines, string.format("    %s → %s", tool, comp))
    end
    table.insert(lines, "")
    table.insert(lines, "  修复选项:")
    table.insert(lines, "    1. 运行组件选择器为 Claude Code 分配一个组件")
    table.insert(lines, string.format("    2. 运行 :ClaudeCodeGenerateConfig 在分配组件后重试"))
    table.insert(lines, "")
    if comp_name then
      table.insert(lines, string.format("  已分配: %s (但未在注册表中找到)", comp_name))
      table.insert(lines, "  提示: 该组件可能未部署或未注册")
    else
      table.insert(lines, "  提示: Claude Code 还没有被分配到任何组件")
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR)
    return false
  end

  -- 动态加载组件
  local Component = require("ai.components." .. comp_name)

  -- 检查组件是否已安装
  if not Component.is_installed() then
    local lines = {
      string.format("❌ 组件 '%s' 未安装 (Claude Code 分配)", comp_name),
      "",
      "  快速修复:",
      string.format("    运行 :%sDeployTools (部署到工具)", comp_name:upper()),
      string.format("    或切换为其他已安装的组件"),
      "",
      string.format("  当前分配: claude → %s", comp_name),
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR)
    return false
  end

  ensure_config_dir()

  local final = build_final_settings(opts)
  local path = get_settings_path()

  local content = format_json(final)
  local lines = vim.split(content, "\n")
  vim.fn.writefile(lines, path)

  -- 同步 ccstatusline 配置
  local ccstatusline_ok, ccstatusline_err = write_ccstatusline_settings()

  -- 检测组件状态并通知
  local comp_status = Component.get_status()
  local notify_lines2 = { "✅ Claude Code settings written to: " .. path }

  if ccstatusline_ok then
    table.insert(notify_lines2, "✅ ccstatusline config synced to: " .. get_ccstatusline_settings_path())
  elseif ccstatusline_err then
    table.insert(notify_lines2, "⚠️  ccstatusline: " .. ccstatusline_err)
  end

  vim.list_extend(notify_lines2, { "" })
  if Component.format_notification then
    vim.list_extend(notify_lines2, Component.format_notification(comp_status))
  end

  vim.notify(table.concat(notify_lines2, "\n"), vim.log.levels.INFO)

  return true
end

function M.edit_settings()
  local path = get_settings_path()

  if vim.fn.filereadable(path) == 0 then
    M.write_settings()
  end

  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

function M.edit_template()
  local template_path = get_template_path()

  if vim.fn.filereadable(template_path) == 0 then
    local default_template = [[{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  // Claude Code 配置模板
  // 修改后运行 :ClaudeCodeGenerateConfig 生成最终配置
  //
  // 合并顺序：existing settings -> 默认配置 -> 模板配置 -> key文件配置
  // 模板配置会覆盖默认值，但不会删除 existing 中的额外字段
  //
  // statusLine 和 model 属于「用户管理字段」：
  //   - 不在默认配置中，不会被生成器覆盖
  //   - 首次生成时自动添加 statusLine 默认值
  //   - 可以直接编辑 settings.json 或在此模板中设置

  // 示例：覆盖权限配置
  // "permissions": {
  //   "allow": ["Read", "Write", "Edit", "Bash"],
  //   "deny": ["Bash(rm -rf /*)"],
  //   "ask": ["Bash(sudo *)"]
  // },

  // 示例：禁用沙盒
  // "sandbox": {
  //   "enabled": false
  // },

  // 环境变量（合并到 settings.json 的 env 字段，与 key 文件配置合并）
  "env": {
    "XDG_STATE_HOME": "/tmp/claude-state"
  },

  // 自定义 ccstatusline 状态栏（取消注释并修改即可覆盖默认配置）
  // 默认值：{ "type": "command", "command": "npx -y ccstatusline@latest", "padding": 0 }
  // "statusLine": {
  //   "type": "command",
  //   "command": "npx -y ccstatusline@latest --widgets model,cost,tokens,context",
  //   "padding": 0
  // },

  // 示例：设置模型（直接编辑 settings.json 中的 model 也不会被覆盖）
  // "model": "opus[1m]",

  // 示例：添加环境变量
  // "env": {
  //   "MY_CUSTOM_VAR": "value"
  // }
}]]
    vim.fn.writefile(vim.split(default_template, "\n"), template_path)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(template_path))
end

function M.edit_ccstatusline_template()
  local template_path = get_ccstatusline_template_path()

  if vim.fn.filereadable(template_path) == 0 then
    -- 如果模板不存在，从现有配置复制
    local existing_path = get_ccstatusline_settings_path()
    if vim.fn.filereadable(existing_path) == 1 then
      local content = table.concat(vim.fn.readfile(existing_path), "\n")
      -- 添加注释头
      local template_content = [[{
  "$schema": "https://json.schemastore.org/ccstatusline.json",

  // ccstatusline 状态栏配置
  // 修改后运行 :ClaudeCodeGenerateConfig 同步到 ~/.config/ccstatusline/settings.json
  //
  // 文档: https://github.com/nick-field/ccstatusline

]]
      -- 移除现有的 schema 并添加内容
      local ok, config = pcall(vim.json.decode, content)
      if ok and config then
        config["$schema"] = "https://json.schemastore.org/ccstatusline.json"
        -- 移除开头的 "{\n"（format_json 输出格式：第一行是 {，第二行开始是内容）
        local json_str = format_json(config)
        local first_nl = json_str:find("\n")
        if first_nl then
          template_content = template_content .. json_str:sub(first_nl + 1)
        else
          template_content = template_content .. json_str
        end
      end
      vim.fn.writefile(vim.split(template_content, "\n"), template_path)
    end
  end

  vim.cmd("edit " .. vim.fn.fnameescape(template_path))
end

function M.preview_settings()
  -- 预览最终合并结果（与实际写入一致）
  local final = build_final_settings()
  local content = format_json(final)
  local lines = vim.split(content, "\n")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "json")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_name(buf, "Claude Code Settings Preview")

  vim.api.nvim_win_set_buf(0, buf)
  vim.notify("Preview mode (final merged result): q to close", vim.log.levels.INFO)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { silent = true })
end

function M.toggle_terminal(opts)
  local Terminal = require("ai.terminal")
  Terminal.create_preset("claude", opts)
end

function M.open_with_context(opts)
  opts = opts or {}
  local Terminal = require("ai.terminal")
  Terminal.create_preset_with_context("claude", opts)
end

function M.check_installation()
  if vim.fn.executable("claude") == 1 then
    return true, "Claude Code is installed"
  end

  return false, "Claude Code is not installed. Install with: npm install -g @anthropic-ai/claude-code"
end

----------------------------------------------------------------------
-- check_dependencies(): 检测环境依赖，返回状态列表（不执行安装）
----------------------------------------------------------------------
function M.check_dependencies()
  local deps = {}

  -- Node.js
  local node_installed = vim.fn.executable("node") == 1
  table.insert(deps, {
    name = "Node.js",
    installed = node_installed,
    install_hint = "https://nodejs.org/ 或: curl -fsSL https://fnm.vercel.app/install | bash",
  })

  -- npm
  local npm_installed = vim.fn.executable("npm") == 1
  table.insert(deps, {
    name = "npm",
    installed = npm_installed,
    install_hint = "随 Node.js 一起安装",
  })

  -- npx
  local npx_installed = vim.fn.executable("npx") == 1
  table.insert(deps, {
    name = "npx",
    installed = npx_installed,
    install_hint = "随 Node.js 一起安装",
  })

  -- Claude Code CLI
  local claude_installed = vim.fn.executable("claude") == 1
  table.insert(deps, {
    name = "Claude Code CLI",
    installed = claude_installed,
    install_hint = "npm install -g @anthropic-ai/claude-code",
  })

  -- ccstatusline（通过 npx 按需运行，仅需 npx 可用）
  table.insert(deps, {
    name = "ccstatusline",
    installed = npx_installed,
    install_hint = "需要 npm/npx (通过 npx -y ccstatusline@latest 按需运行)",
  })

  -- 动态检查 switcher 分配的组件依赖
  local Switcher = require("ai.components.switcher")
  local Registry = require("ai.components.registry")
  local active_comp = Switcher.get_active("claude")
  if active_comp and Registry.is_registered(active_comp) then
    local ok, Component = pcall(require, "ai.components." .. active_comp)
    if ok then
      table.insert(deps, {
        name = string.format("%s 组件", active_comp:upper()),
        installed = Component.is_installed(),
        install_hint = Component.install_hint and Component.install_hint() or ("运行 :" .. active_comp:upper() .. "DeployTools"),
      })
    end
  end

  return deps
end

----------------------------------------------------------------------
-- get_active_component_status(): 动态获取 switcher 分配组件的安装状态
----------------------------------------------------------------------
function M.get_active_component_status()
  local Switcher = require("ai.components.switcher")
  local comp_name = Switcher.get_active("claude")
  if not comp_name then
    return nil
  end
  local ok, Component = pcall(require, "ai.components." .. comp_name)
  if not ok then
    return nil
  end
  return Component.get_status()
end

function M.get_status()
  local installed, message = M.check_installation()
  local config_exists = vim.fn.filereadable(get_settings_path()) == 1
  local comp = M.get_active_component_status()
  local deps = M.check_dependencies()
  local missing_deps = vim.tbl_filter(function(d)
    return not d.installed
  end, deps)

  return {
    installed = installed,
    message = message,
    config_exists = config_exists,
    config_path = get_settings_path(),
    component = comp,
    missing_deps = missing_deps,
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
