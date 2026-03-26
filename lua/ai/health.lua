-- lua/ai/health.lua
-- Health check module for AI configuration
-- Implements :checkhealth ai

local M = {}

----------------------------------------------------------------------
-- Helper: Check if command exists
----------------------------------------------------------------------
local function command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

----------------------------------------------------------------------
-- Helper: Validate API key format (basic checks)
----------------------------------------------------------------------
local function validate_api_key(provider, key)
  if not key or key == "" then
    return false, "empty"
  end

  -- Provider-specific format checks
  if provider == "openai" then
    if not key:match("^sk%-") then
      return false, "invalid format (should start with 'sk-')"
    end
  elseif provider == "deepseek" then
    if not key:match("^sk%-") then
      return false, "invalid format (should start with 'sk-')"
    end
  elseif provider == "bailian_coding" or provider == "bailian" then
    if #key < 20 then
      return false, "too short"
    end
  end

  return true, "valid"
end

----------------------------------------------------------------------
-- Check OpenCode installation and configuration
----------------------------------------------------------------------
local function check_opencode()
  vim.health.start("ai.opencode")

  -- Check installation
  local installed = command_exists("opencode")
  if installed then
    vim.health.ok("OpenCode CLI installed")
  else
    vim.health.warn("OpenCode CLI not found in PATH")
    vim.health.info("Install with: npm install -g @anthropic-ai/opencode")
  end

  -- Check config file
  local config_path = vim.fn.expand("~/.config/opencode/opencode.json")
  if vim.fn.filereadable(config_path) == 1 then
    vim.health.ok("OpenCode config exists: " .. config_path)

    -- Check if config has required fields
    local ok, content = pcall(vim.fn.readfile, config_path)
    if ok then
      local json_str = table.concat(content, "\n")
      local ok2, config = pcall(vim.json.decode, json_str)
      if ok2 and config then
        if config.model then
          vim.health.ok("Default model: " .. config.model)
        else
          vim.health.warn("No default model set in config")
        end

        if config.provider and next(config.provider) then
          local provider_count = 0
          for _ in pairs(config.provider) do
            provider_count = provider_count + 1
          end
          vim.health.ok("Providers configured: " .. provider_count)
        else
          vim.health.warn("No providers configured")
        end
      end
    end
  else
    vim.health.warn("OpenCode config not found")
    vim.health.info("Run :OpenCodeGenerateConfig to create it")
  end

  -- Check ECC integration for OpenCode
  local Ecc = require("ai.ecc")
  if Ecc.is_installed() then
    vim.health.ok("ECC installed (shared with Claude Code)")
  else
    vim.health.info("ECC not installed: " .. Ecc.install_hint())
  end

  -- Check template
  local template_path = vim.fn.stdpath("config") .. "/opencode.template.jsonc"
  if vim.fn.filereadable(template_path) == 1 then
    vim.health.ok("OpenCode template exists")
  else
    vim.health.info("No OpenCode template (using defaults)")
  end
end

----------------------------------------------------------------------
-- Check Node.js / npm / npx
----------------------------------------------------------------------
local function check_node_npm()
  vim.health.start("ai.dependencies")

  if command_exists("node") then
    local version = vim.fn.system("node --version"):gsub("%s+", "")
    vim.health.ok("Node.js installed: " .. version)
  else
    vim.health.warn("Node.js not found")
    vim.health.info("Required for Claude Code, ccstatusline, ECC")
    vim.health.info("Install: https://nodejs.org/")
  end

  if command_exists("npm") then
    local version = vim.fn.system("npm --version"):gsub("%s+", "")
    vim.health.ok("npm installed: " .. version)
  else
    vim.health.warn("npm not found (included with Node.js)")
  end

  if command_exists("npx") then
    vim.health.ok("npx available")
  else
    vim.health.warn("npx not found (included with Node.js)")
  end
end

----------------------------------------------------------------------
-- Check ccstatusline configuration
----------------------------------------------------------------------
local function check_ccstatusline()
  vim.health.start("ai.ccstatusline")

  if not command_exists("npx") then
    vim.health.warn("ccstatusline requires npx (install Node.js)")
    return
  end

  vim.health.ok("npx available (ccstatusline runs via npx)")

  -- 检查 settings.json 中是否已配置 statusLine
  local settings_path = vim.fn.expand("~/.claude/settings.json")
  if vim.fn.filereadable(settings_path) == 1 then
    local ok, content = pcall(vim.fn.readfile, settings_path)
    if ok then
      local json_str = table.concat(content, "\n")
      local ok2, settings = pcall(vim.json.decode, json_str)
      if ok2 and settings and settings.statusLine then
        vim.health.ok("statusLine configured in settings.json")
        if settings.statusLine.command then
          vim.health.ok("  command: " .. settings.statusLine.command)
        end
      else
        vim.health.warn("statusLine not configured in settings.json")
        vim.health.info("Run :ClaudeCodeGenerateConfig to add it")
      end
    end
  else
    vim.health.info("settings.json not found, statusLine not configured")
  end
end

----------------------------------------------------------------------
-- Check ECC (Everything Claude Code) installation
----------------------------------------------------------------------
local function check_ecc()
  vim.health.start("ai.ecc")

  local Ecc = require("ai.ecc")
  local ecc = Ecc.get_status()

  if not ecc then
    vim.health.warn("ECC not installed")
    vim.health.info("Install: " .. Ecc.install_hint())
    return
  end

  vim.health.ok("ECC installed")

  if ecc.installed_at then
    vim.health.ok("Installed at: " .. ecc.installed_at)
  end
  if ecc.repo_version then
    vim.health.ok("Version: " .. ecc.repo_version)
  end
  if #ecc.modules > 0 then
    vim.health.ok("Modules (" .. #ecc.modules .. "): " .. table.concat(ecc.modules, ", "))
  end

  -- 检查 MCP servers 配置
  local mcp_path = vim.fn.expand("~/.claude/mcp-configs/mcp-servers.json")
  if vim.fn.filereadable(mcp_path) == 1 then
    local ok3, mcp_content = pcall(vim.fn.readfile, mcp_path)
    if ok3 then
      local json_str = table.concat(mcp_content, "\n")
      local ok4, mcp = pcall(vim.json.decode, json_str)
      if ok4 and mcp and mcp.mcpServers then
        local count = vim.tbl_count(mcp.mcpServers)
        vim.health.ok("MCP servers configured: " .. count)
        if count > 10 then
          vim.health.warn("MCP servers > 10, may impact context window")
        end
      end
    end
  end

  -- 检查关键目录
  local dirs = { "rules", "agents", "commands", "skills", "hooks" }
  for _, dir in ipairs(dirs) do
    local dir_path = vim.fn.expand("~/.claude/" .. dir)
    if vim.fn.isdirectory(dir_path) == 1 then
      vim.health.ok("  ~/.claude/" .. dir .. "/ exists")
    else
      vim.health.info("  ~/.claude/" .. dir .. "/ not found")
    end
  end
end

----------------------------------------------------------------------
-- Check Claude Code installation and configuration
----------------------------------------------------------------------
local function check_claude_code()
  vim.health.start("ai.claude_code")

  -- Check installation
  local installed = command_exists("claude")
  if installed then
    vim.health.ok("Claude Code CLI installed")
  else
    vim.health.warn("Claude Code CLI not found in PATH")
    vim.health.info("Install with: npm install -g @anthropic-ai/claude-code")
  end

  -- Check config directory
  local config_dir = vim.fn.expand("~/.claude")
  if vim.fn.isdirectory(config_dir) == 1 then
    vim.health.ok("Claude Code config dir exists")
  else
    vim.health.info("Claude Code config dir not found (will be created on first use)")
  end

  -- Check settings.json
  local settings_path = config_dir .. "/settings.json"
  if vim.fn.filereadable(settings_path) == 1 then
    vim.health.ok("Claude Code settings exists")

    local ok, content = pcall(vim.fn.readfile, settings_path)
    if ok then
      local json_str = table.concat(content, "\n")
      local ok2, settings = pcall(vim.json.decode, json_str)
      if ok2 and settings then
        if settings.apiProvider then
          vim.health.ok("API provider: " .. settings.apiProvider)
        end
      end
    end
  else
    vim.health.info("Claude Code settings not found")
    vim.health.info("Run :ClaudeCodeGenerateConfig to create it")
  end

  -- Check template
  local template_path = vim.fn.stdpath("config") .. "/claude_code.template.jsonc"
  if vim.fn.filereadable(template_path) == 1 then
    vim.health.ok("Claude Code template exists")
  else
    vim.health.info("No Claude Code template (using defaults)")
  end
end

----------------------------------------------------------------------
-- Check API keys validity
----------------------------------------------------------------------
local function check_api_keys()
  vim.health.start("ai.keys")

  local Keys = require("ai.keys")
  local Providers = require("ai.providers")

  local keys_data = Keys.read()
  local keys_path = vim.fn.stdpath("state") .. "/ai_keys.lua"

  if not keys_data then
    vim.health.error("Keys file not found: " .. keys_path)
    vim.health.info("Run :AIEditKeys to create it")
    return
  end

  vim.health.ok("Keys file exists: " .. keys_path)

  -- Check each provider's key
  local valid_count = 0
  local invalid_count = 0
  local missing_count = 0

  for provider, def in pairs(Providers) do
    if type(def) == "table" and def.api_key_name then
      local config = Keys.get_config(provider)

      if not config or not config.api_key or config.api_key == "" then
        missing_count = missing_count + 1
      else
        local valid, msg = validate_api_key(provider, config.api_key)
        if valid then
          valid_count = valid_count + 1
        else
          invalid_count = invalid_count + 1
          vim.health.warn(string.format("%s API key: %s", provider, msg))
        end
      end
    end
  end

  if valid_count > 0 then
    vim.health.ok("Valid API keys: " .. valid_count)
  end

  if invalid_count > 0 then
    vim.health.warn("Invalid API keys: " .. invalid_count)
  end

  if missing_count > 0 then
    vim.health.info("Missing API keys: " .. missing_count)
    vim.health.info("Run :AIEditKeys to configure")
  end

  -- Check base_url configurations
  local base_url_count = 0
  for provider, config in pairs(keys_data) do
    if provider ~= "profile" and type(config) == "table" and config.base_url then
      base_url_count = base_url_count + 1
    end
  end

  if base_url_count > 0 then
    vim.health.ok("Custom base URLs: " .. base_url_count)
  end
end

----------------------------------------------------------------------
-- Check Avante.nvim
----------------------------------------------------------------------
local function check_avante()
  vim.health.start("ai.avante")

  -- Check plugin installed
  local avante_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim"
  if vim.fn.isdirectory(avante_path) == 1 then
    vim.health.ok("Avante.nvim plugin installed")
  else
    vim.health.warn("Avante.nvim not installed")
    vim.health.info("Run :Lazy sync to install")
    return
  end

  -- Check build artifacts (使用统一的跨平台检测)
  local ok, Builder = pcall(require, "ai.avante.builder")
  if ok then
    local binaries = Builder.get_binaries()
    if #binaries > 0 then
      vim.health.ok("Avante built (" .. #binaries .. " binaries, " .. Builder.get_platform_ext() .. ")")

      -- List key binaries
      local required = { "avante_tokenizers", "avante_templates" }
      for _, req in ipairs(required) do
        local found = false
        for _, f in ipairs(binaries) do
          if f:match(req) then
            found = true
            break
          end
        end
        if found then
          vim.health.ok("  ✓ " .. req)
        else
          vim.health.warn("  ✗ " .. req .. " missing")
        end
      end
    else
      vim.health.error("Avante not built (no binaries found)")
      vim.health.info("Run :AvanteBuild to build")
    end
  else
    -- Fallback: 手动检测
    local build_dir = avante_path .. "/build"
    if vim.fn.isdirectory(build_dir) == 1 then
      local so_files = vim.fn.glob(build_dir .. "/*.so", false, true)
      local dylib_files = vim.fn.glob(build_dir .. "/*.dylib", false, true)
      local dll_files = vim.fn.glob(build_dir .. "/*.dll", false, true)
      local all_files = {}
      vim.list_extend(all_files, so_files)
      vim.list_extend(all_files, dylib_files)
      vim.list_extend(all_files, dll_files)

      if #all_files > 0 then
        vim.health.ok("Avante built (" .. #all_files .. " binaries)")
      else
        vim.health.error("Avante not built (no binaries found)")
        vim.health.info("Run :AvanteBuild to build")
      end
    else
      vim.health.error("Avante build directory not found")
      vim.health.info("Run :AvanteBuild to build")
    end
  end
end

----------------------------------------------------------------------
-- Main check function
----------------------------------------------------------------------
function M.check()
  -- AI Module core
  vim.health.start("ai")
  local ai = require("ai")

  if ai then
    vim.health.ok("AI module loaded")
  else
    vim.health.error("AI module not loaded")
    return
  end

  local backend = ai.get_backend and ai.get_backend()
  if backend and backend.name then
    vim.health.ok("Backend registered: " .. backend.name)
  else
    vim.health.error("No backend registered")
    vim.health.info("Run :lua require('ai').setup()")
  end

  -- Check each component
  check_api_keys()
  check_avante()
  check_opencode()
  check_node_npm()
  check_ccstatusline()
  check_ecc()
  check_claude_code()
end

return M
