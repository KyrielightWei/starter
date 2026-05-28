# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **LazyVim Neovim configuration** with an AI integration layer. The core value is the `lua/ai/` module that provides a unified interface for two AI CLIs (OpenCode and Claude Code) and multiple AI providers (OpenAI, DeepSeek, Qwen, GLM, Bailian Coding, Zenmux, Glink, etc.).

> Avante was removed; the codebase no longer ships a chat-sidebar backend. AI interaction happens via the OpenCode and Claude Code terminals.

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

**Core flow:**
```
init.lua (entry point, keymaps + commands)
    ↓
providers.lua (provider registry: endpoints, default model, static_models, model_info)
    ↓
keys.lua (API key / base_url / base_url_claude / global_default / tool_default in ~/.local/state/nvim/ai_keys.lua)
    ↓
config_resolver.lua (multi-layer config merging: defaults → template → project)
    ↓
opencode.lua / claude_code.lua (write final JSON to disk)
```

**Key files:**

| File | Purpose |
|------|---------|
| `init.lua` | Entry point, keymaps and user-command registration |
| `providers.lua` | Provider registry (register/list/get/unregister) |
| `keys.lua` | API key, base_url, profile, global_default, tool_default management |
| `config_resolver.lua` | Multi-layer config merging + `${env}/${provider}/${key}/${file}` references |
| `json_util.lua` | Shared JSON / JSONC / deep_merge helpers used by opencode/claude_code/config_resolver |
| `opencode.lua` | OpenCode config generator (writes `~/.config/opencode/opencode.json`) |
| `opencode_tui.lua` | OpenCode TUI config generator |
| `claude_code.lua` | Claude Code config generator (writes `~/.claude/settings.json`) + ccstatusline sync |
| `state.lua` | Centralized state manager (provider/model/template_version) with subscriber pattern |
| `terminal.lua` | toggleterm-backed terminal manager (preset + free + SSH; M-1~M-9 switching) |
| `terminal_picker.lua` | Picker UI for terminal selection |
| `model_switch.lua` | fzf provider → model → scope (global / opencode / claude_code) selector |
| `fetch_models.lua` | Async + sync `/v1/models` fetch with 5-min cache |
| `sync.lua` | Sync hub: writes OpenCode + Claude Code configs together |
| `system_prompt.lua` | Merges prompt files from `~/.config/nvim/prompts/` per tool |
| `context.lua` | File / selection / project / LSP diagnostics / git diff collection |
| `health.lua` | `:checkhealth ai` implementation |
| `config_backup.lua` / `config_watcher.lua` | Pre-write backup + file-change detection |
| `template_version.lua` / `template_picker.lua` | Multi-version templates per tool |
| `ecc.lua` | Everything Claude Code framework installer |
| `skill_studio/` | Claude Code SKILL.md CRUD + validate + convert (opencode/qoder) |
| `provider_manager/` | CRUD + status + cache + fzf picker for providers |

### User Commands

| Command | Description |
|---------|-------------|
| `:AIKeys` | Edit `~/.local/state/nvim/ai_keys.lua` |
| `:AISync` | fzf-select tool and sync its config |
| `:AIModelSwitch` | Switch provider + model + scope (global / opencode / claude_code) |
| `:AIModelShowConfig` | Show current global + tool-level defaults |
| `:AIModelClearTool` | Clear tool-specific override (fall back to global default) |
| `:OpenCodeWriteConfig` | Generate `~/.config/opencode/opencode.json` |
| `:OpenCodeEditTemplate` | Edit `opencode.template.jsonc` |
| `:OpenCodePreviewConfig` | Preview the merged config in a scratch buffer |
| `:OpenCodeRestoreBackup [n]` | Restore OpenCode config from backup |
| `:ClaudeCodeGenerateConfig` | Generate `~/.claude/settings.json` |
| `:ClaudeCodeEditSettings` / `:ClaudeCodeEditTemplate` | Edit settings or template |
| `:ClaudeCodePreviewSettings` | Preview the merged settings |
| `:ClaudeCodeRestoreBackup [n]` | Restore Claude Code config from backup |
| `:AITemplateSelect <tool>` | Pick active template version for a tool |
| `:AITemplateList / Create / Delete / Rename / Edit` | Template version CRUD |
| `:SkillNew / SkillList / SkillEdit / SkillDelete / SkillCopy / SkillValidate / SkillConvert` | Skill Studio commands |
| `:ECCInstall` / `:ECCStatus` | Everything Claude Code framework |

### Keymaps

Prefix: `<leader>k` (AI Tools)

| Key | Mode | Action |
|-----|------|--------|
| `<leader>kp` | n | Provider Manager |
| `<leader>ks` | n | Model Switch (with scope selection) |
| `<leader>kK` | n | Edit API Keys |
| `<leader>kS` | n | Sync Configs |
| `<leader>kC` | n | Commit Picker |
| `<leader>kf` / `<leader>kb` | n | Cycle next/prev commit in picker |
| `<leader>kd` | n | Diff Viewer (Diffview or fugitive fallback) |

### Key Configuration Files

- `opencode.template.jsonc` — Template for OpenCode config (edit, then run `:OpenCodeWriteConfig`)
- `claude_code.template.jsonc` — Template for Claude Code settings
- `ccstatusline.template.jsonc` — Template for `~/.config/ccstatusline/settings.json`
- `~/.local/state/nvim/ai_keys.lua` — API keys, base URLs, and defaults (not in repo)

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

Then add the key in `ai_keys.lua` (`:AIKeys`).

### Configuration Resolution

`config_resolver.lua` supports dynamic references in configs:
- `${env:VAR}` — Environment variable
- `${provider:name:field}` — Reference another provider's `model` / `endpoint` / `api_key`
- `${key:provider}` — Reference a provider's resolved API key
- `${file:path}` — Read file contents (restricted to a path whitelist: `~/.config/`, `~/.local/state/`, `~/.claude/`, `~/.opencode/`, `stdpath('config')`, `stdpath('state')`, `stdpath('data')`, and the current working directory)
- `${exec:...}` — Disabled (security)

Multi-layer merging: defaults → template → project (`.opencode.json`).

API keys are written as `{env:VAR_NAME}` references when the user uses `${env:...}` in `ai_keys.lua`, or as `{file:path}` references pointing to mode-0600 files under `~/.config/opencode/api_key_<provider>.txt` otherwise. Switching from a plaintext key to an `${env:...}` reference automatically deletes the stale plaintext file on the next config write.

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
- **Shared helpers**: JSON serialization, JSONC parsing, and deep_merge live in `ai.json_util` — do not re-implement them inside individual modules.

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
Terminal.create_preset("opencode")  -- or "claude", "cfuse"
Terminal.create_preset("claude", { args = "--model claude-opus-4-6" })
```

## OpenCode Integration

1. Edit `opencode.template.jsonc`
2. Run `:OpenCodeWriteConfig`
3. Generates `~/.config/opencode/opencode.json` (provider registry merged from `ai_keys.lua`) and `~/.config/opencode/tui.json`.

Config generation never triggers network requests — model lists come from `providers.lua` `static_models`. To refresh model lists from the live `/v1/models` endpoint, use `:AIModelSwitch` (which calls the async fetcher).
