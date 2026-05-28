-- scripts/preview_config.lua
-- Preview generated OpenCode and Claude Code configs
-- Run: nvim --headless -l scripts/preview_config.lua

-- Mock Keys module for preview (since we can't read actual ai_keys.lua)
local Keys = require("ai.keys")

-- Show what the configs would look like with sample data
print("\n" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=")
print("OpenCode Configuration Preview")
print("=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "\n")

local Resolver = require("ai.config_resolver")
local Registry = require("ai.provider_manager.registry")

-- Get global default
local provider, model = Registry.get_global_default()
print(string.format("Global Default: %s / %s", provider or "bailian_coding", model or "qwen3.6-plus"))

-- Show defaults structure
local defaults = Resolver.get_defaults()
print("\nDefault Config Structure:")
print(string.format('  model: "%s"', defaults.model))
print(string.format('  small_model: "%s"', defaults.small_model))
print(string.format('  autoupdate: %s', tostring(defaults.autoupdate)))
print(string.format('  share: "%s"', defaults.share))

-- Show provider config structure for one provider
print("\nProvider Config Example (bailian_coding):")
local Providers = require("ai.providers")
local def = Providers.get("bailian_coding")
if def then
  print(string.format('  endpoint: "%s"', def.endpoint))
  print(string.format('  default model: "%s"', def.model))
  print("  static_models:", table.concat(def.static_models or {}, ", "))
  if def.model_info then
    for model_id, info in pairs(def.model_info) do
      print(string.format("    %s: context=%d, output=%d", model_id, info.limit.context, info.limit.output))
    end
  end
end

print("\n" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=")
print("Claude Code Configuration Preview")
print("=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "\n")

local ClaudeCode = require("ai.claude_code")

-- Show Claude Code settings structure
print("Settings Structure:")
print("  ~/.claude/settings.json")
print("\nKey Fields:")
print("  env.ANTHROPIC_AUTH_TOKEN: {api_key from ai_keys.lua}")
print("  env.ANTHROPIC_BASE_URL: {base_url_claude or base_url}")
print("  env.ANTHROPIC_DEFAULT_OPUS_MODEL: claude-opus-4-7 (smart mapping)")
print("  env.ANTHROPIC_DEFAULT_SONNET_MODEL: claude-sonnet-4-6")
print("  env.ANTHROPIC_DEFAULT_HAIKU_MODEL: claude-haiku-4-5")
print("  env.ANTHROPIC_SMALL_FAST_MODEL: claude-haiku-4-5")
print("\nPermissions:")
print("  deny: Read(~/.claude/settings.json), Bash(su *), Bash(rm -rf /*)")
print("  allow: Read, Write, Edit, Glob, Grep, Bash")
print("  ask: Read(**.pem), Bash(sudo *), Bash(rm *)")

print("\n" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=")
print("Model Switch Flow Summary")
print("=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "\n")

print("1. User triggers <leader>ks or <leader>kp")
print("2. FZF picker shows providers")
print("3. User selects provider (async fetch starts)")
print("4. FZF picker shows models from that provider")
print("5. User selects model")
print("6. Registry.set_global_default(provider, model)")
print("   → Updates ~/.local/state/nvim/ai_keys.lua")
print("   → Updates memory state")
print("   → Triggers Sync.sync_all()")
print("7. Sync generates:")
print("   → ~/.config/opencode/opencode.json")
print("   → ~/.config/opencode/api_key_*.txt")
print("   → ~/.claude/settings.json")
print("   → ~/.config/ccstatusline/settings.json")

print("\n" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=")
print("Fixes Applied")
print("=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "=" .. "\n")

print("1. picker.lua: Provider Manager now sets global_default (same as Model Switch)")
print("2. opencode.lua: Uses Providers.list() API (fixed iteration)")
print("3. config_resolver.lua: Uses Providers.list() API (fixed iteration)")
print("4. fetch_models.lua: Added fetch_async() (non-blocking)")
print("5. model_switch.lua: Uses async API with loading indicator")
print("6. sync.lua: Added pcall error handling and vim.schedule")
print("7. registry.lua: Added list_models_async()")
print("8. picker.lua: Uses async model fetch")

print("\n")