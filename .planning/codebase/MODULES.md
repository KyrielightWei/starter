# Modules — Module Breakdown

**Project:** LazyVim Neovim Configuration with AI Integration
**Mapped:** 2026-04-21

## Core Config Modules (`lua/config/`)

### `lua/config/lazy.lua`
- **Purpose:** Lazy.nvim plugin manager bootstrap
- **Behavior:** Sets up plugin specs directory (`lua/plugins/`), triggers lazy installation
- **Dependencies:** None (first thing loaded after init.lua)

### `lua/config/options.lua`
- **Purpose:** Neovim runtime option settings
- **Typical settings:** `cursorline`, `mouse`, `encoding`, `tabstop`, `shiftwidth`
- **Dependencies:** None

### `lua/config/keymaps.lua`
- **Purpose:** Global leader-key keymaps (non-AI)
- **Typical mappings:** Navigation, file operations, window management
- **Dependencies:** None

### `lua/config/autocmds.lua`
- **Purpose:** Autocommand groups for filetype detection, buffer events, etc.
- **Dependencies:** None

---

## Plugin Specs (`lua/plugins/`)

### `plugins/ai.lua` — AI Backend
- **Plugin:** `yetone/avante.nvim`
- **Load:** `VeryLazy`
- **Build:** `make` (Rust binary compilation)
- **Config:** Calls `require("ai").setup()` — bridges into AI module
- **Role:** Provides the primary AI chat/edit interface within Neovim

### `plugins/cmp.lua` — Code Completion
- **Plugin:** `saghen/blink.cmp`
- **Sources:** lsp (priority 100), snippets (90), path (80), buffer (70)
- **Options:** Auto-bracket insertion enabled
- **Role:** Inline code autocomplete

### `plugins/color.lua` — Theme
- **Active:** `lytmode.nvim` (lazy=false, priority 1000) + `evergarden` (fall variant, green accent)
- **Active colorscheme:** `lytmode` (set via LazyVim opts)
- **Commented alternatives:** zephyr, kanagawa, dracula, sonokai, aurora, miasma
- **Role:** Visual theming

### `plugins/editor.lua` — Editor Enhancements
- **fzf-lua:** Adds `<leader>so` for Treesitter symbol search
- **telescope.nvim:** Adds `<leader>sg` for project-root-aware grep
  - Uses custom `get_project_root()` function that searches upward for markers (.git, Makefile, package.json, etc.)
- **Role:** File/code search and navigation

### `plugins/extra.lua` — LeetCode
- **Plugin:** `leetcode.nvim`
- **Dependencies:** fzf-lua, plenary.nvim, nui.nvim
- **Options:** CN site enabled, translator on, problem translation on
- **Role:** LeetCode problem solving integration

### `plugins/format.lua` — Code Formatting
- **Plugin:** `conform.nvim`
- **Formatters by filetype:**
  - Lua → stylua
  - JSON/JSONC → jq / prettier
  - JS/TS/JSX/TSX → prettier
  - HTML/CSS/SCSS/MD/YAML → prettier
  - Python → ruff_format
  - Go → goimports + gofmt
  - Rust → rustfmt
  - C/C++ → clang_format_for_ob (custom style with 2-space indent, specific brace wrapping)
  - Shell → shfmt
  - Fish → fish_indent
  - TOML → taplo
- **Custom formatter:** `clang_format_for_ob` includes a heavily configured clang-format style inline
- **Role:** Format-on-save across all supported languages

### `plugins/git.lua` — Git Integration (largest single file: 496 lines)
- **Plugins:** vim-fugitive + diffview.nvim
- **Custom features:**
  - Git version enforcement (>= 2.31) with interactive selection UI
  - Custom git binary resolver (scans PATH, common paths, local config)
  - Git worktree detection (reads `.git` file for gitdir)
  - Local config persistence at `~/.local/state/nvim/diffview_local.lua`
  - Path security validation (prevents injection and traversal)
  - LSP disabled in diffview buffers (prevents extra ccls instances)
  - Custom keymaps: `]h`/`[h` for hunk navigation, `?` for help
  - User commands: `:DiffviewSetGit`, `:DiffviewGitInfo`, `:DiffviewOpenEnhanced`, `:DiffviewFileHistoryEnhanced`
- **Keymaps:** `<leader>gv`, `<leader>gV`, `<leader>gf`, `<leader>gF`
- **Role:** Code review, diff viewing, git history

### `plugins/lsp.lua` — Language Server Protocol
- **Plugin:** nvim-lspconfig
- **Servers configured:**
  - **clangd:** autostart=false, custom root_dir, UTF-16 offset, background index, clang-tidy, IWYU headers, detailed completion, LLVM fallback
  - **ccls:** autostart=false, extensive init_options (cache, clang, completion, diagnostics, index, workspace symbols), disabled in setup (returns false)
- **Root markers (clangd):** Makefile, configure.ac, configure.in, config.h.in, meson.build, meson_options.txt, build.ninja, compile_commands.json, compile_flags.txt, .git
- **Focus:** Heavy C/C++ support (clangd preferred, ccls available)
- **Role:** IDE features (go-to-def, hover, diagnostics, completion) for C/C++

### `plugins/opencode.lua` — AI Tool Commands (185 lines)
- **OpenCode commands:** `:OpenCodeGenerateConfig`, `:OpenCodeEditTemplate`, `:OpenCodeValidateTemplate`, `:OpenCodePreviewConfig`, `:OpenCodeStatus`
- **Claude Code commands:** `:ClaudeCodeGenerateConfig`, `:ClaudeCodeEditTemplate`, `:ClaudeCodeEditConfig`, `:ClaudeCodeEditStatusline`, `:ClaudeCodePreviewConfig`, `:ClaudeCodeStatus`, `:ClaudeCodeCheckDeps`
- **Sync commands:** `:AISyncAll`, `:AISyncSelect`, `:AIExportKeys`
- **Key/Context commands:** `:AIEditKeys`, `:AICopyContext`, `:AIShowContext`
- **Prompt commands:** `:AIEditPrompts`, `:AIListPrompts`
- **Config watcher commands:** `:AIConfigWatch`, `:AIConfigForceSync`
- **Plugin:** `toggleterm.nvim` (optional extension)
  - Adds `<leader>kC` (Copy Context) and `<leader>kY` (Sync All)
  - Schedules config watcher on load
- **Role:** Entry point for all AI tool management commands

### `plugins/skill_studio.lua` — Skill Studio
- **Content:** Returns `{}` (empty)
- **Role:** Skills Studio loaded via `ai/init.lua` setup, not as independent plugin

### `plugins/terminal.lua` — Terminal Management
- **Plugin:** `toggleterm.nvim`
- **Config:** float mode, curved border, persist_size + persist_mode, close_on_exit=false, winbar
- **User commands:** `:TermSelect`, `:TermNew`, `:TermKillAll`
- **Keymaps:**
  - `<leader>tt` → Terminal selector
  - `<leader>ta` → Toggle all terminals
  - `<leader>tl` → Send current line to terminal
  - `<leader>tL` → Send visual selection to terminal
  - Terminal mode: `<C-h/j/k/l>` → navigate windows
- **Lualine override:** Custom terminal extension showing managed terminal names, mode (TERMINAL/NORMAL), and keyboard hints
- **Role:** Terminal multiplexing within Neovim

### `plugins/ui.lua` — UI Components
- **codediff.nvim:** VSCode-style diff, line+char highlighting, configurable
- **bufferline.nvim:** Buffer management with keymaps for pick, close left/right, non-pinned cleanup, move
- **Commented out:** lualine config (managed in terminal.lua instead)
- **Role:** Visual UI enhancements

### `plugins/util.lua` — Utilities / Dashboard
- **Plugin:** `snacks.nvim`
- **Features:**
  - Dashboard with custom ASCII art (two-pane layout: left + right headers)
  - Sections: header art, keymap cheatsheet, recent files, projects, live git status panel, startup info
  - lazygit integration
- **Role:** Neovim startup dashboard and git status at a glance

---

## AI Module (`lua/ai/`)

### `init.lua` — Module Entry
- **Core responsibility:** Backend registration, keymap setup, command setup
- **Pattern:** Strategy pattern — any `*_adapter.lua` can be registered as backend
- **Keymaps:** `<leader>k` prefix with 10+ mappings (chat, edit, model switch, key manager, sessions, toggle, diff, suggestions)
- **Commands:** `AIChat`, `AIChatNew`, `AIEdit`, `AIAsk`, `AIToggle`, `AIDiff`, `ECCInstall`, `ECCStatus`
- **Lazy loading:** Uses `__index` metamethod to auto-load default backend on first access
- **Backends:** Default is `avante`

### `providers.lua` — Provider Registry
- **12 providers registered:**
  1. `deepseek` — api.deepseek.com
  2. `openai` — api.openai.com
  3. `qwen` — template endpoint `{QWEN_BASE_ENDPOINT}`
  4. `minimax` — template endpoint `{MINIMAX_BASE_ENDPOINT}`
  5. `kimi` — template endpoint `{KIMI_BASE_ENDPOINT}`
  6. `glm` — template endpoint `{GLM_BASE_ENDPOINT}`
  7. `bailian` — dashscope compatible mode
  8. `bailian_coding` — coding.dashscope (default)
  9. `dashscope` — api.dashscope.com
  10. `moonshot` — api.moonshot.ai
  11. `ollama` — localhost
  12. (base openai entry — inherited by others)
- **Default:** `bailian_coding` / `qwen3.6-plus`
- **API:** `register(name, conf)`, `list()`, `get(name)`

### `keys.lua` — API Key Manager
- **Storage:** `~/.config/nvim/ai_keys.lua` (Lua file, `return { ... }`)
- **Operations:** Read, write, get_key(provider), set_key(provider, key), get_base_url(provider), set_base_url(provider, url)
- **Integration:** Used by ConfigResolver, Sync, and provider config building

### `state.lua` — State Manager
- **Purpose:** Centralized state for current provider/model
- **API:** `get()`, `set(provider, model)`, `subscribe(callback)`
- **Backward compat:** `_G.AI_MODEL` still accessible with deprecation warning

### `util.lua` — Utility Functions
- **Purpose:** Common helpers (path handling, string operations, etc.)
- **Used by:** Multiple AI modules

### `health.lua` — Health Checks
- **Purpose:** `:checkhealth ai` validation
- **Validates:** Module loading, provider connectivity, configuration correctness

### `fetch_models.lua` — Dynamic Model Fetching
- **Purpose:** Fetch available models from provider APIs
- **Used by:** Model switcher for dynamic model lists

### `model_switch.lua` & `model_selector.lua` — Model Switching UI
- **Purpose:** FZF-lua based model picker
- **Data source:** Provider static_models + optionally fetched models
- **Action:** Updates State with new provider/model

### `config_resolver.lua` — Configuration Resolver (362 lines)
- **Layers:** defaults → template (JSONC) → project config → dynamic providers
- **Features:**
  - JSONC comment stripping (handles `//` and `/* */`)
  - Deep merge with override semantics
  - Reference resolution: `${env:VAR}`, `${provider:name:field}`, `${key:provider}`, `${file:path}`, `${exec:cmd}`
  - Provider config builder (generates OpenAI-compatible provider entries)
  - 5-second cache with `invalidate_cache()`
  - Path-based get/set API (`get("model")`, `set("permission.edit", "auto")`)

### `config_watcher.lua` — Config Hot-Reload
- **Triggers:** `BufWritePost` on template/keys/project-config files, `DirChanged`
- **Behavior:** 500ms debounce timer → `Sync.sync_all({ silent = true })` + cache invalidation
- **Commands:** `:AIConfigWatch`, `:AIConfigForceSync`

### `context.lua` — Context Collection (370 lines)
- **Collects:** file info, visual selection, project root, git status/branch, LSP diagnostics, cursor context, Treesitter symbol, function at cursor
- **Outputs:** structured context table + markdown-formatted prompt + clipboard copy
- **Used by:** `:AICopyContext`, `:AIShowContext`, AI tool config generation

### `system_prompt.lua` — System Prompt Management
- **Directory:** `~/.config/nvim/prompts/`
- **Files:** `todo_workflow.md` (default), `code_style.md` (user), `custom.md` (user)
- **Per-tool composition:** Each tool (opencode, claude_code, avante) gets its own list of files to merge
- **Commands:** `:AIEditPrompts`, `:AIListPrompts`

### `sync.lua` — Sync Engine (234 lines)
- **Targets:** opencode, claude_code (extensible via `register_target()`)
- **Operations:** `sync_all()`, `sync_one(name)`, `select_and_sync()` (fzf-lua), `export_keys()`, `export_to_env_file(path)`
- **Checks:** Verifies tool is installed before syncing
- **Results:** Per-target success/failure with notifications

### `opencode.lua` — OpenCode Config Generator
- **Commands:** `write_config()`, `edit_template()`, `validate_template()`, `preview_config()`
- **Source:** ConfigResolver.resolve() → generates `~/.config/opencode/config.json`
- **Status:** `get_status()` → installed/config/template check

### `claude_code.lua` — Claude Code Config Generator
- **Commands:** `write_settings()`, `edit_template()`, `edit_settings()`, `preview_settings()`, `edit_ccstatusline_template()`
- **Generates:** Claude Code settings + CLAUDE.md
- **ECC integration:** Detects and reports ECC framework version, modules
- **Dependencies:** Checks for required CLI tools

### `ecc.lua` — Everything Claude Code
- **Purpose:** ECC framework installer and status checker
- **Commands:** `open_installer()`, `show_status()`

### `avante/` Sub-module

| File | Purpose |
|------|---------|
| `avante/config.lua` | Builds avante.nvim config from Providers + Keys |
| `avante/methods.lua` | Implements chat, edit, ask, model_switch, etc. for Avante |
| `avante/adapter.lua` | Low-level adapter glue between AI module and Avante |
| `avante/builder.lua` | Config construction helpers |

### `avante_adapter.lua` — Default Backend Adapter
- **Implements:** chat, chat_new, edit, ask, model_switch, key_manager, sessions, toggle, diff, suggestion_next/prev/accept
- **Delegates to:** avante/ sub-module methods
- **Role:** Satisfies the adapter interface expected by init.lua

### `adapter_template.lua` — Adapter Development Guide
- **Purpose:** Template + documentation for creating new backend adapters
- **Required methods:** Lists all methods a new adapter must implement

### `terminal.lua` & `terminal_picker.lua` — Terminal System
- **terminal.lua:** Core manager — create_free(), toggle_all(), kill_all(), get_all(), label management
- **terminal_picker.lua:** FZF-lua picker for selecting/switching between managed terminals

### `skill_studio/` Sub-module (10 files)

| File | Purpose |
|------|---------|
| `skill_studio/init.lua` | Entry point, setup, command registration |
| `skill_studio/registry.lua` | Skill file registry and lookup |
| `skill_studio/picker.lua` | FZF-lua skill file picker |
| `skill_studio/validator.lua` | Skill file structure/content validation |
| `skill_studio/extractor.lua` | Extract skills from code/text |
| `skill_studio/generator.lua` | Generate new skill files |
| `skill_studio/converter.lua` | Format conversion between skill types |
| `skill_studio/reviewer.lua` | Skill content review/preview |
| `skill_studio/templates.lua` | Skill file templates |
| `skill_studio/backup.lua` | Backup/restore skill files |
| `skill_studio/ui.lua` | UI components |

---

## Test Modules (`tests/`)

| File | Coverage | Pattern |
|------|----------|---------|
| `tests/init.lua` | Test harness entry | Global setup stub |
| `tests/minimal_init.lua` | Minimal Neovim config for tests | Sets rtp, disables plugins, basic variables |
| `tests/ai/state_spec.lua` | State manager | describe/it/assert with plenary |
| `tests/ai/providers_spec.lua` | Provider registry | Registration, listing, retrieval |
| `tests/ai/util_spec.lua` | Utility functions | Helper function correctness |
| `tests/ai/init_spec.lua` | AI module integration | Backend registration, keymap setup |
| `tests/ai/skill_studio_spec.lua` | Skill Studio | Registry, validation, picker |

---

## Cross-Module Dependencies Graph

```
                    ┌─────────────────┐
                    │   init.lua      │  ← Entry point
                    │  (AI module)    │
                    └──┬───┬───┬─────┘
                       │   │   │
            ┌──────────┘   │   └──────────┐
            ▼              ▼              ▼
      ┌──────────┐  ┌───────────┐  ┌─────────────┐
      │ providers │  │   keys    │  │ avante/     │
      │  .lua     │  │  .lua     │  │ sub-module  │
      └─────┬────┘  └─────┬─────┘  └──────┬──────┘
            │             │               │
            ▼             ▼               ▼
      ┌─────────────────────────────────────────┐
      │          config_resolver.lua            │
      │   (merges defaults + template + project │
      │    + providers, resolves references)    │
      └──────────────┬──────────────────────────┘
                     │
            ┌────────┴────────┐
            ▼                 ▼
      ┌───────────┐    ┌──────────┐
      │ sync.lua  │    │ watcher  │
      └─────┬─────┘    └────┬─────┘
            │               │
            ▼               ▼
      ┌──────────┐   ┌───────────┐
      │ opencode │   │ claude_code│
      └──────────┘   └───────────┘

      ┌──────────┐   ┌───────────┐
      │ context  │   │ sys_prompt│
      └────┬─────┘   └────┬──────┘
           │              │
           └──────┬───────┘
                  ▼
            (used by sync engine)

      ┌──────────┐   ┌───────────────┐
      │ terminal │   │skill_studio/  │
      └──────────┘   └───────────────┘
           │
           └─► toggleterm.nvim
```
