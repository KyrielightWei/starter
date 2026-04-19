# Architecture Map

## Project Type
**LazyVim Neovim Configuration** with AI integration layer

## Core Modules

### `lua/ai/` — AI Integration Module
The heart of the project. Provides AI tool management across Claude Code, OpenCode, and other harnesses.

| File | Purpose |
|------|---------|
| `ai/init.lua` | Main entry point, coordinates all AI modules |
| `ai/providers.lua` | Provider registry (OpenAI, DeepSeek, Qwen, etc.) |
| `ai/state.lua` | Centralized state management (get/set/subscribe) |
| `ai/keys.lua` | API key management |
| `ai/health.lua` | Health check module (`:checkhealth ai`) |

#### Component Management (new, partially built)
| File | Purpose |
|------|---------|
| `ai/components/init.lua` | Component manager entry |
| `ai/components/registry.lua` | Component registry |
| `ai/components/discovery.lua` | Auto-discovery |
| `ai/components/switcher.lua` | Tool-component switching |
| `ai/components/ecomponents/` | ECC implementation |
| `ai/components/gsd/` | GSD implementation |

#### Tool Config Generators
| File | Purpose |
|------|---------|
| `ai/opencode.lua` | OpenCode config generation |
| `ai/claude_code.lua` | Claude Code config generation |
| `ai/ecc.lua` | ECC shim → `components/ecc` |
| `ai/gsd.lua` | GSD shim → `components/gsd` |

### `lua/config/` — Neovim Core Config
| File | Purpose |
|------|---------|
| `lazy.lua` | Plugin manager |
| `options.lua` | Neovim options |
| `keymaps.lua` | Global keymaps |
| `autocmds.lua` | Autocommands |

### `lua/plugins/` — Plugin Specs
| File | Purpose |
|------|---------|
| `ai.lua` | AI-related plugins |
| `opencode.lua` | OpenCode plugin |
| `skill_studio.lua` | Skill studio plugin |
| `terminal.lua` | Terminal management |
| `lsp.lua` | LSP config |
| `cmp.lua` | Autocompletion |

### `prompts/` — Workflow Documentation
| File | Purpose |
|------|---------|
| `code_style.md` | Code style guide |
| `todo_workflow.md` | Todo workflow |
| `custom.md` | Custom prompts |

### `tests/` — Test Suite
Tests using plenary.nvim for AI modules.

## Data Flow
```
User Neovim → ai/ module → provider → AI API → response
              ↓
          components/ → install/deploy → Claude Code / OpenCode
```
