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

        -- Check agents/categories for oh-my-opencode
        if config.agents then
          local agent_count = 0
          for _ in pairs(config.agents) do
            agent_count = agent_count + 1
          end
          vim.health.ok("OMO agents: " .. agent_count)
        else
          vim.health.warn("No OMO agents configured")
        end

        if config.categories then
          local cat_count = 0
          for _ in pairs(config.categories) do
            cat_count = cat_count + 1
          end
          vim.health.ok("OMO categories: " .. cat_count)
        else
          vim.health.warn("No OMO categories configured")
        end
      end
    end
  else
    vim.health.warn("OpenCode config not found")
    vim.health.info("Run :OpenCodeGenerateConfig to create it")
  end

  -- Check oh-my-opencode.json
  local omo_path = vim.fn.expand("~/.config/opencode/oh-my-opencode.json")
  if vim.fn.filereadable(omo_path) == 1 then
    vim.health.ok("oh-my-opencode.json exists")
  else
    vim.health.info("oh-my-opencode.json not found (optional)")
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

  -- Check build artifacts
  local build_dir = avante_path .. "/build"
  if vim.fn.isdirectory(build_dir) == 1 then
    local so_files = vim.fn.glob(build_dir .. "/*.so", false, true)
    if #so_files > 0 then
      vim.health.ok("Avante built (" .. #so_files .. " binaries)")

      -- List key binaries
      local required = { "avante_tokenizers.so", "avante_templates.so" }
      for _, req in ipairs(required) do
        local found = false
        for _, f in ipairs(so_files) do
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
      vim.health.error("Avante not built (no .so files)")
      vim.health.info("Run :AvanteBuild to build")
    end
  else
    vim.health.error("Avante build directory not found")
    vim.health.info("Run :AvanteBuild to build")
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
  check_claude_code()
end

return M
