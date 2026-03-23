# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **LazyVim Neovim configuration** with an AI integration layer. The core value is the `lua/ai/` module that provides a unified interface for multiple AI backends (Avante, OpenCode) and providers (OpenAI, DeepSeek, Qwen, GLM, etc.).

## Key Commands

### Formatting
```bash
stylua lua/           # Format all Lua files
stylua --check lua/   # Check formatting without modifying
```

### Testing
```bash
nvim --headless -c "PlenaryBustedDirectory tests/" -c "q"           # Run all tests
nvim --headless -c "PlenaryBustedFile tests/ai/state_spec.lua" -c "q"  # Run single test
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/" -c "q"  # With minimal config
```

### Validation
```bash
nvim --headless -c "lua require('ai').setup()" -c "q" 2>&1  # Verify AI module loads
nvim -c "checkhealth ai" -c "q"                              # Run health check
```

## Architecture Overview

### AI Module (`lua/ai/`)

The AI module uses a **backend adapter pattern** - switching AI plugins only requires changing `default_backend` in `init.lua` and implementing the corresponding adapter.

**Core flow:**
```
init.lua (entry point)
    ↓
providers.lua (registry of AI providers with endpoints and models)
    ↓
keys.lua (API key and base_url storage in ~/.local/state/nvim/ai_keys.lua)
    ↓
config_resolver.lua (multi-layer config merging: defaults → template → project)
    ↓
Backend Adapter (avante/adapter.lua, etc.)
```

**Key files:**

| File | Purpose |
|------|---------|
| `init.lua` | Entry point, backend registration, keymaps/commands setup |
| `providers.lua` | Provider registry (openai, deepseek, qwen, glm, bailian_coding, etc.) |
| `keys.lua` | API key and base_url management with profile support |
| `config_resolver.lua` | Multi-layer config merging with dynamic references |
| `model_selector.lua` | Intelligent model selection based on agent/category requirements |
| `opencode.lua` | OpenCode config generator (generates ~/.config/opencode/opencode.json) |
| `state.lua` | Centralized state manager (replaces global _G.AI_MODEL) |
| `terminal.lua` | Unified terminal management for AI CLIs (OpenCode, Claude Code, Aider) |
| `skill_studio/` | Skill/MCP authoring tools (create, list, convert, validate skills) |
| `claude_code.lua` | Claude Code integration and config generation |
| `config_watcher.lua` | File-based config change detection |
| `context.lua` | Context gathering for AI prompts |
| `system_prompt.lua` | System prompt construction |

### Backend Adapter Interface

All adapters must implement: `chat`, `chat_new`, `edit`, `ask`, `model_switch`, `key_manager`, `sessions`, `toggle`, `diff`, `suggestion_next`, `suggestion_prev`, `suggestion_accept`. See `adapter_template.lua` for the complete guide.

### User Commands

| Command | Description |
|---------|-------------|
| `:AIChat` / `:AIChatNew` | Open/create AI chat |
| `:AIEdit` | Edit selection with AI (visual mode) |
| `:AIAsk` | Quick ask floating window |
| `:AIToggle` / `:AIDiff` | Panel control |
| `:OpenCodeGenerateConfig` | Generate OpenCode config from template |
| `:OpenCodeEditTemplate` | Edit the config template |
| `:SkillNew` / `:SkillList` / `:SkillConvert` | Skill Studio commands |

### Keymaps

Prefix: `<leader>k` (AI Interactive)

| Key | Mode | Action |
|-----|------|--------|
| `<leader>kc` | n | AI Chat |
| `<leader>kn` | n | New Chat |
| `<leader>ke` | v | Edit Selection |
| `<leader>kq` | n | Quick Ask |
| `<leader>ks` | n | Model Switch |
| `<leader>kk` | n | Key Manager |
| `<leader>kt` | n | Toggle Panel |
| `<M-]>/<M-[>/<M-\>` | i | Suggestion navigation |

### Key Configuration Files

- `opencode.template.jsonc` - Template for OpenCode config (edit this, then run `:OpenCodeGenerateConfig`)
- `~/.local/state/nvim/ai_keys.lua` - API keys and base URLs (not in repo)

### Adding a New Provider

Edit `lua/ai/providers.lua`:
```lua
M.register("provider_name", {
  api_key_name = "PROVIDER_API_KEY",
  endpoint = "https://api.provider.com",
  model = "default-model",
  static_models = { "model-1", "model-2" },
})
```

Then add the key in `ai_keys.lua` or via `:AIKeyManager`.

### Configuration Resolution

`config_resolver.lua` supports dynamic references in configs:
- `${env:VAR}` - Environment variable
- `${provider:name:field}` - Reference another provider's field
- `${file:path}` - Read from file

Multi-layer merging: defaults → template → project configs.

## Code Conventions

- **Indentation**: 2 spaces (stylua.toml)
- **Column width**: 120 characters
- **Quote style**: Double quotes for strings
- **Module pattern**: `local M = {}` with public functions on `M`, private functions as `local function name()`
- **Safe requires**: Use `pcall(require, "module")` for optional dependencies
- **Error handling**: Use `vim.notify()` with appropriate log levels
- **Naming**: `snake_case` for variables/functions, `UPPER_CASE` for constants, `PascalCase` for module imports (e.g., `local State = require("ai.state")`)
- **Booleans**: Prefix with `is_` or `has_`
- **Comments in Chinese**: The codebase uses Chinese comments; maintain this convention

## Important Patterns

### State Management
```lua
local State = require("ai.state")
State.get()  -- { provider, model }
State.set("provider_name", "model_name")
State.subscribe(callback)  -- React to state changes
```

### Terminal Module
```lua
local Terminal = require("ai.terminal")
Terminal.toggle("opencode")  -- or "claude", "aider"
Terminal.toggle("claude", { args = "--model claude-opus-4-6" })
```

## OpenCode Integration

1. Edit `opencode.template.jsonc`
2. Run `:OpenCodeGenerateConfig`
3. Generates `~/.config/opencode/opencode.json` and `oh-my-opencode.json` with model assignments

The generator uses `model_selector.lua` to assign models to agents/categories based on capability profiles (reasoning, speed, coding, creativity, context, cost scores).