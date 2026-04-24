# Architecture — System Architecture

**Project:** LazyVim Neovim Configuration with AI Integration Layer
**Mapped:** 2026-04-21

## Overview

This is a **LazyVim Neovim configuration** written in **Lua**, extended with a full-featured **AI integration layer** (`lua/ai/`). It provides:

- A plugin-managed Neovim IDE built on LazyVim with custom keymaps, themes, and tooling
- A centralized AI module that connects multiple LLM providers to multiple AI coding tools (Avante.nvim, OpenCode, Claude Code)
- Configuration resolution, sync, hot-reload, and skill management systems
- Terminal multiplexing via toggleterm with a custom picker
- Comprehensive test suite using plenary.nvim

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Neovim                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │              LazyVim Core                       │     │
│  │  lua/config/ (options, keymaps, lazy, autocmds) │     │
│  └────────────────────┬───────────────────────────┘     │
│                       │                                 │
│  ┌────────────────────▼───────────────────────────┐     │
│  │            Plugin System                       │     │
│  │  lua/plugins/ (14 plugin spec files)            │     │
│  │    ai  cmp  color  editor  extra  format        │     │
│  │    git  lsp  opencode  skill_studio  terminal    │     │
│  │    ui  util                                     │     │
│  └────────────────────┬───────────────────────────┘     │
│                       │                                 │
│  ┌────────────────────▼───────────────────────────┐     │
│  │              AI Module (lua/ai/)                │     │
│  │                                                 │     │
│  │  ┌───────────┐  ┌──────────┐  ┌──────────────┐  │     │
│  │  │ Providers │  │ Keys Mgr │  │ Config       │  │     │
│  │  │ Registry  │  │          │  │ Resolver     │  │     │
│  │  └─────┬─────┘  └────┬─────┘  └──────┬───────┘  │     │
│  │        │             │               │          │     │
│  │  ┌─────▼─────────────▼───────────────▼──────┐    │     │
│  │  │            Backend Adapter               │    │     │
│  │  │    avante_adapter.lua (default)          │    │     │
│  │  │    (implements chat, edit, ask, etc.)     │    │     │
│  │  └─────────────────┬────────────────────────┘    │     │
│  │                    │                             │     │
│  │  ┌─────────────────▼────────────────────────┐    │     │
│  │  │         avante/ sub-module               │    │     │
│  │  │   config.lua  methods.lua  adapter.lua    │    │     │
│  │  │   builder.lua                             │    │     │
│  │  └─────────────────┬────────────────────────┘    │     │
│  │                    │                             │     │
│  │  ┌─────────────────┼────────────────────────┐    │     │
│  │  │                 │                        │    │     │
│  │  ▼                 ▼                        ▼    │     │
│  │ Context         System Prompt            Sync     │     │
│  │ Module          Module                   Engine   │     │
│  │                 │                        │        │     │
│  │                 ▼                        ▼        │     │
│  │           Config Watcher         OpenCode /      │     │
│  │           (hot-reload)         Claude Code       │     │
│  │                                Modules            │     │
│  │                                     │             │     │
│  │  ┌──────────────────────────────────┼──────────┐  │     │
│  │  │          Terminal System          │          │  │     │
│  │  │  terminal.lua + terminal_picker   │          │  │     │
│  │  │  (toggleterm-based multiplexer)   │          │  │     │
│  │  └──────────────────────────────────┼──────────┘  │     │
│  │                                     │             │     │
│  │  ┌──────────────────────────────────┼──────────┐  │     │
│  │  │        Skill Studio              │          │  │     │
│  │  │  extractor, generator, picker,    │          │  │     │
│  │  │  registry, ui, templates, etc.    │          │  │     │
│  │  └──────────────────────────────────┘          │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │            Test Suite (tests/)                  │     │
│  │  ai/state_spec.lua  providers_spec.lua          │     │
│  │  ai/util_spec.lua   ai/init_spec.lua            │     │
│  │  ai/skill_studio_spec.lua                       │     │
│  └────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

## Component Layers

### Layer 1: Neovim Core Config (`lua/config/`)

| File | Responsibility |
|------|----------------|
| `init.lua` | Entry point — bootstraps LazyVim, loads options, keymaps, lazy loader |
| `config/lazy.lua` | Plugin manager bootstrap (Lazy.nvim) |
| `config/options.lua` | Neovim runtime options (cursorline, mouse, encoding, etc.) |
| `config/keymaps.lua` | Global keymaps leader key bindings |
| `config/autocmds.lua` | Autocommands for filetype, buffer events |

### Layer 2: Plugin System (`lua/plugins/`)

14 plugin spec files loaded by Lazy.nvim. Each returns a list of plugin specifications. Categories:

| Category | File | Key Plugins |
|----------|------|-------------|
| **AI** | `ai.lua` | avante.nvim (default AI backend) |
| **Completion** | `cmp.lua` | blink.cmp (LSP, path, snippet, buffer sources) |
| **Colors** | `color.lua` | lytmode.nvim (active), evergarden (fallback) |
| **Editor** | `editor.lua` | fzf-lua, telescope.nvim (project-aware grep) |
| **Extra** | `extra.lua` | leetcode.nvim (CN support) |
| **Format** | `format.lua` | conform.nvim (per-language formatters) |
| **Git** | `git.lua` | vim-fugitive, diffview.nvim (custom git binary resolver, worktree support) |
| **LSP** | `lsp.lua` | nvim-lspconfig (clangd, ccls — heavy C/C++ config) |
| **Opencode** | `opencode.lua` | User commands for OpenCode/Claude Code config generation |
| **Skill Studio** | `skill_studio.lua` | Placeholder — loaded via ai module |
| **Terminal** | `terminal.lua` | toggleterm.nvim + ai.terminal manager + lualine override |
| **UI** | `ui.lua` | codediff.nvim, bufferline.nvim |
| **Utility** | `util.lua` | snacks.nvim (dashboard with ASCII art) |

### Layer 3: AI Module (`lua/ai/`) — 8 subsystems

#### 3a. Provider & Configuration Stack

| Module | Role |
|--------|------|
| `providers.lua` | Registry of 12 LLM providers (deepseek, openai, qwen, minimax, kimi, glm, bailian, bailian_coding, dashscope, moonshot, ollama). Each provider declares: inherited protocol, api_key_name, endpoint, default model, static model list. |
| `keys.lua` | API key/base_url management stored in `~/.config/nvim/ai_keys.lua`. Provides CRUD for keys and base URLs. |
| `config_resolver.lua` | Multi-layer config merging: defaults → template (opencode.template.jsonc) → project config (.opencode.json) → dynamic providers. Supports `${ref:...}` syntax (env, provider:key, file, exec). 5-second cache with invalidation. |
| `config_watcher.lua` | Autocmd-based file watcher (BufWritePost, DirChanged) with 500ms debounce. Auto-syncs configs when key/template/project-config files change. |

#### 3b. Backend Adapter System

| Module | Role |
|--------|------|
| `init.lua` | Module entry. Registers backend adapters via `register_backend(name, adapter)`. Auto-sets up keymaps (`<leader>k` prefix) and user commands (`AIChat`, `AIEdit`, etc.). Uses `__index` metamethod for lazy delegation to backend methods. |
| `avante_adapter.lua` | Default backend adapter — wraps avante.nvim into the adapter interface. |
| `avante/config.lua` | Avante configuration builder (provider/model/key resolution) |
| `avante/methods.lua` | Backend method implementations (chat, edit, ask, etc.) |
| `avante/adapter.lua` | Low-level avante adapter glue |
| `avante/builder.lua` | Avante config construction utilities |
| `adapter_template.lua` | Template file for creating new backend adapters |

#### 3c. AI Tool Integration

| Module | Role |
|--------|------|
| `opencode.lua` | OpenCode config generation from templates + provider registry. Writes `~/.config/opencode/config.json`. |
| `claude_code.lua` | Claude Code settings generation (CLAUDE.md, settings.json). Includes ECC framework detection. |
| `sync.lua` | Central sync hub. Targets: opencode, claude_code. Supports `sync_all()`, `sync_one()`, `select_and_sync()` (fzf-lua picker), `export_keys()`. Exportable to `.env` file. |
| `system_prompt.lua` | Manages prompt files in `~/.config/nvim/prompts/`. Per-tool prompt composition (opencode, claude_code, avante each get their own set of merged .md files). |
| `context.lua` | Context collection: file info, visual selection, project root, git status, LSP diagnostics, cursor context, Treesitter symbol detection. Copy-to-clipboard and prompt formatting. |

#### 3d. Terminal System

| Module | Role |
|--------|------|
| `terminal.lua` | Core terminal manager built on toggleterm. Creates/manages labeled terminals, supports toggle-all, kill-all. |
| `terminal_picker.lua` | FZF-based terminal selector UI. |
| `plugins/terminal.lua` | Toggleterm configuration + lualine terminal extension (shows managed terminal names, mode hints) + keymap bindings (`<leader>tt`, `<leader>ta`, `<leader>tl`, `<leader>tL`). |

#### 3e. Skill Studio

10-module subsystem for managing AI skill files:

| Module | Role |
|--------|------|
| `skill_studio/init.lua` | Entry point, setup command registration |
| `skill_studio/registry.lua` | Skill file registry and lookup |
| `skill_studio/picker.lua` | FZF-lua skill picker UI |
| `skill_studio/validator.lua` | Validates skill file structure and content |
| `skill_studio/extractor.lua` | Extracts skill content from code/text |
| `skill_studio/generator.lua` | Generates new skill files |
| `skill_studio/converter.lua` | Converts between skill formats |
| `skill_studio/reviewer.lua` | Review/preview skill content |
| `skill_studio/templates.lua` | Skill file templates |
| `skill_studio/backup.lua` | Backup/restore skill files |
| `skill_studio/ui.lua` | UI components for skill management |

#### 3f. Supporting Modules

| Module | Role |
|--------|------|
| `fetch_models.lua` | Dynamic model list fetching from provider APIs |
| `model_switch.lua` | FZF-lua model selector for quick switching |
| `model_selector.lua` | Additional model selection UI |
| `util.lua` | Common utilities (path handling, string formatting, etc.) |
| `health.lua` | `:checkhealth ai` — validates module setup, provider connectivity |
| `ecc.lua` | Everything Claude Code framework installer and status checker |

### Layer 4: Test Suite (`tests/`)

| File | Coverage |
|------|----------|
| `tests/init.lua` | Test harness entry |
| `tests/minimal_init.lua` | Minimal Neovim config for plenary test runner |
| `tests/ai/state_spec.lua` | State manager unit tests |
| `tests/ai/providers_spec.lua` | Provider registry tests |
| `tests/ai/util_spec.lua` | Utility function tests |
| `tests/ai/init_spec.lua` | AI module integration tests |
| `tests/ai/skill_studio_spec.lua` | Skill Studio subsystem tests |

## Design Decisions

### Backend Adapter Pattern
The AI module uses a **strategy pattern** — `init.lua` defines a generic interface, and any `*_adapter.lua` file implements it. Switching AI plugins only requires changing `default_backend` and creating the adapter file.

### Config Resolution Pipeline
4-layer merge: defaults → user template → project config → dynamic providers. References (`${env:VAR}`, `${provider:x:endpoint}`, `${key:provider}`, `${file:path}`, `${exec:cmd}`) are resolved after merging. Results are cached for 5 seconds.

### Key Management
Keys are stored in a Lua file (`~/.config/nvim/ai_keys.lua`) with a `return { ... }` structure. The Keys module provides CRUD. Base URLs are also stored per-provider. The Sync module exports keys to XDG-compliant paths for external tools.

### Terminal Multiplexing
toggleterm.nvim is wrapped by the `ai.terminal` module which adds label management, batch toggle, and a picker UI. Lualine is overridden for terminal buffers to show terminal names and mode hints instead of default toggleterm behavior.

### Plugin Architecture
Lazy.nvim loads each `lua/plugins/*.lua` file as a plugin spec. Lazy loading is primarily via `event = "VeryLazy"` or `keys = {}` / `cmd = {}` triggers. The system avoids early-loading plugins to maintain Neovim startup time.

## File Counts

| Directory | Files |
|-----------|-------|
| `lua/config/` | 4 |
| `lua/plugins/` | 14 |
| `lua/ai/` | 15 root + 3 avante/ + 10 skill_studio/ = **28** |
| `tests/` | 1 root + 1 minimal + 5 ai/ = **7** |
| **Total Lua files** | **~53** |
