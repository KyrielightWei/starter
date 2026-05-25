# AGENTS.md - Guide for AI Coding Agents

This document provides essential information for AI coding agents working in this LazyVim/Neovim configuration repository.

## Project Overview

This is a **LazyVim Neovim configuration** written in **Lua**. It's a modular configuration system with an AI integration layer.

### Project Structure
```
.
├── init.lua                  # Entry point
├── lua/
│   ├── config/               # Core configuration
│   │   ├── lazy.lua         # Plugin manager setup
│   │   ├── options.lua      # Neovim options
│   │   ├── keymaps.lua      # Global keymaps
│   │   └── autocmds.lua     # Autocommands
│   ├── plugins/              # Plugin specifications
│   │   └── *.lua            # Individual plugin configs
│   └── ai/                   # AI integration module
│       ├── init.lua         # Main entry, backend registration
│       ├── state.lua        # State manager (get/set/subscribe)
│       ├── providers.lua    # Provider registry (OpenAI, DeepSeek, etc.)
│       ├── keys.lua         # API key management
│       ├── util.lua         # Utility functions
│       ├── health.lua       # Health check module (:checkhealth ai)
│       ├── adapter_template.lua  # Adapter development guide
│       ├── avante/          # Avante backend implementation
│       │   ├── config.lua   # Configuration builder
│       │   └── methods.lua  # Backend methods (chat, edit, etc.)
│       └── *_adapter.lua    # Other backend adapters
├── tests/                    # Test suite
│   ├── init.lua             # Test entry point
│   ├── minimal_init.lua     # Minimal Neovim config for testing
│   └── ai/                  # AI module tests
│       ├── state_spec.lua   # State manager tests
│       ├── providers_spec.lua # Providers tests
│       ├── util_spec.lua    # Utility tests
│       └── init_spec.lua    # Integration tests
└── prompts/                  # Workflow documentation
```

---

## Build/Lint/Test Commands

### Formatting
```bash
# Format all Lua files with stylua
stylua lua/

# Format specific file
stylua lua/ai/init.lua

# Check formatting without modifying
stylua --check lua/
```

### Linting
```bash
# Using luacheck (if installed)
luacheck lua/

# Using selene (if installed)
selene lua/
```

### Testing
```bash
# Run all tests with plenary.nvim
nvim --headless -c "PlenaryBustedDirectory tests/" -c "q"

# Run specific test file
nvim --headless -c "PlenaryBustedFile tests/ai/state_spec.lua" -c "q"

# Run tests with minimal config
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/" -c "q"

# Quick syntax check
nvim --headless -c "lua print('OK')" -c "q"
```

### Health Check
```bash
# Run AI module health check
nvim -c "checkhealth ai" -c "q"

# Or programmatically
nvim --headless -c "lua require('ai').setup()" -c "checkhealth ai" -c "q" 2>&1
```

### Validation
```bash
# Verify Lua syntax
nvim -c "lua print('OK')" -c "q"

# Check if plugins load correctly
nvim --headless "+Lazy! sync" +qa

# Verify AI module loads
nvim --headless -c "lua require('ai').setup()" -c "q" 2>&1
```

---

## AI Module Architecture

### State Management
The AI module uses a centralized state manager (`lua/ai/state.lua`) instead of global variables.

```lua
local State = require("ai.state")

-- Get current state
local state = State.get()  -- Returns { provider, model }

-- Set state
State.set("openai", "gpt-4")

-- Subscribe to state changes
State.subscribe(function(new_state)
  print("State changed to:", new_state.provider, new_state.model)
end)
```

**Backward Compatibility**: `_G.AI_MODEL` still works but shows a deprecation warning.

### Backend Adapter Pattern
Each backend adapter must implement these methods:
- `chat()` - Open chat window
- `chat_new()` - Create new chat session
- `edit()` - Edit selected code
- `ask()` - Quick ask
- `model_switch()` - Switch model
- `key_manager()` - Manage API keys
- `sessions()` - Manage sessions
- `toggle()` - Toggle panel
- `diff()` - View diff
- `suggestion_next/prev/accept()` - Handle suggestions

See `lua/ai/adapter_template.lua` for a complete guide.

---

## Code Style Guidelines

### Formatting Rules (from stylua.toml)
- **Indentation**: 2 spaces (not tabs)
- **Column width**: 120 characters
- **Quote style**: Prefer double quotes for strings

### Imports and Requires
```lua
-- Group requires at the top of the file
local Providers = require("ai.providers")
local Keys = require("ai.keys")
local State = require("ai.state")
local Util = require("ai.util")

-- Use pcall for optional dependencies
local ok, module = pcall(require, "optional_module")
if not ok then
  vim.notify("Module not found", vim.log.levels.WARN)
  return
end
```

### Module Pattern
```lua
-- File header comment
-- lua/ai/module_name.lua
-- Brief description

local M = {}

-- Private functions use local
local function private_helper()
  -- implementation
end

-- Public functions attach to M
function M.public_function()
  -- implementation
end

return M
```

### Section Separators
```lua
----------------------------------------------------------------------
-- Section Title
-- @param name type: description (optional)
----------------------------------------------------------------------
```

### Function Definitions
```lua
-- Public function
function M.setup(opts)
  opts = opts or {}
  -- implementation
end

-- Private function
local function build_config()
  -- implementation
end
```

### Error Handling
```lua
-- Use pcall for safe operations
local ok, result = pcall(require, "module")
if not ok then
  vim.notify("Error: " .. result, vim.log.levels.ERROR)
  return
end

-- Use vim.notify for user feedback
vim.notify("Success message", vim.log.levels.INFO)
vim.notify("Warning message", vim.log.levels.WARN)
vim.notify("Error message", vim.log.levels.ERROR)

-- Use pcall for unsafe operations
pcall(vim.cmd, "AvanteToggle")
```

### Naming Conventions
```lua
-- Variables: snake_case
local my_variable = "value"
local config_table = {}

-- Functions: snake_case
function M.get_config() end
local function process_data() end

-- Constants: UPPER_CASE
local DEFAULT_TIMEOUT = 30000
local MAX_RETRIES = 3

-- Module tables: PascalCase when used as classes
local Providers = require("ai.providers")
local ModelSwitch = require("ai.model_switch")
local State = require("ai.state")

-- Boolean variables: use is_/has_ prefix
local is_configured = false
local has_plugins = true
```

### Table Definitions
```lua
-- Multi-line tables with trailing commas
local config = {
  provider = "openai",
  model = "gpt-4",
  timeout = 30000,
  options = {
    temperature = 0.7,
    max_tokens = 2048,
  },
}

-- Inline for simple cases
local colors = { "red", "green", "blue" }
```

### Plugin Configuration Pattern
```lua
-- lua/plugins/plugin_name.lua
return {
  {
    "author/plugin-name",
    event = "VeryLazy",  -- or keys = {}, cmd = {}
    opts = {
      -- plugin options
    },
    config = function(_, opts)
      require("plugin").setup(opts)
    end,
  },
}
```

### Keymaps Definition
```lua
-- Define in tables and iterate
local keys = {
  { "<leader>kc", mode = "n", fn = call("chat"), desc = "AI Chat" },
  { "<leader>ke", mode = "v", fn = call("edit"), desc = "AI Edit" },
}

function M.setup_keys()
  for _, key in ipairs(keys) do
    vim.keymap.set(key.mode, key[1], key.fn, { desc = key.desc })
  end
end
```

### User Commands
```lua
local commands = {
  { "AIChat", call("chat"), desc = "Open AI Chat" },
  { "AIEdit", call("edit"), desc = "AI Edit Selection", range = true },
}

function M.setup_commands()
  for _, cmd in ipairs(commands) do
    local opts = { desc = cmd.desc }
    if cmd.range then opts.range = true end
    vim.api.nvim_create_user_command(cmd[1], cmd[2], opts)
  end
end
```

### String Formatting
```lua
-- Use string.format for complex strings
local msg = string.format("Switched to %s / %s", provider, model)

-- Use gsub for substitutions
local endpoint = endpoint:gsub("{(%w+_BASE_ENDPOINT)}", "")
```

### Vim API Usage
```lua
-- Get current buffer name
local bufname = vim.api.nvim_buf_get_name(0)

-- Get current working directory
local cwd = vim.loop.cwd()  -- or vim.uv.cwd() in newer versions

-- Check if file exists
if vim.fn.filereadable(path) == 1 then
  -- file exists
end

-- Write file
vim.fn.writefile(lines, path)

-- Defer execution
vim.defer_fn(function()
  -- delayed code
end, 100)
```

---

## Best Practices

1. **Lazy Loading**: Use `event = "VeryLazy"` or `keys = {}` for plugins
2. **Safe Requires**: Always use `pcall` for optional modules
3. **User Feedback**: Use `vim.notify` with appropriate log levels
4. **Configuration**: Use `opts = {}` pattern for plugin options
5. **Documentation**: Add file header comments explaining module purpose
6. **Error Recovery**: Provide fallbacks when dependencies are missing
7. **State Management**: Use `require("ai.state")` instead of `_G.AI_MODEL`
8. **Testing**: Write tests for new modules in `tests/ai/`

---

## Workflow Patterns

### Adding a New Provider
1. Edit `lua/ai/providers.lua`
2. Call `M.register("provider_name", { ... })`
3. No other changes needed

### Adding a New Backend Adapter
1. Read `lua/ai/adapter_template.lua` for the complete guide
2. Create `lua/ai/xxx_adapter.lua`
3. Implement required methods: `chat`, `edit`, `ask`, etc.
4. Return implementation from `M.setup()`
5. Update `lua/ai/init.lua` if changing default backend

### Adding a New Plugin
1. Create `lua/plugins/plugin_name.lua`
2. Return plugin spec table
3. Use appropriate lazy-loading event

### Writing Tests
1. Create test file in `tests/ai/xxx_spec.lua`
2. Use plenary.nvim test framework (`describe`, `it`, `assert`)
3. Run with: `nvim --headless -c "PlenaryBustedFile tests/ai/xxx_spec.lua" -c "q"`

---

## Avante.nvim 构建管理

### 自动构建提示

当首次使用 AI 功能时，如果 Avante.nvim 未构建，会弹出选择对话框：

```
┌─────────────────────────────────────────────────────────┐
│  Avante.nvim 需要构建才能正常使用                        │
│  构建大约需要 2-5 分钟，完成后即可使用所有功能            │
└─────────────────────────────────────────────────────────┘

选择：
  🚀 立即构建（推荐）
  ⏭️  跳过构建
```

### 构建进度显示

选择"立即构建"后，会在浮动窗口显示构建日志：

```
╔══════════════════════════════════════════════════════════════╗
║            Avante.nvim 构建日志                              ║
╚══════════════════════════════════════════════════════════════╝

⏳ 正在构建... 这可能需要 2-5 分钟
[build output...]
══════════════════════════════════════════════════════════════
✅ 构建成功！
══════════════════════════════════════════════════════════════
```

### 手动命令

```vim
" 手动触发构建
:AvanteBuild

" 查看构建状态
:AvanteBuildStatus
```

### 优雅降级

如果选择"跳过构建"：
- AI 聊天功能不可用（会再次提示构建）
- Key 管理等非核心功能仍可用
- 下次使用时会再次询问

<!-- GSD:project-start source:PROJECT.md -->
## Project

**LazyVim Neovim AI Integration Enhancement**

这是一个成熟的 LazyVim Neovim 配置，带有一个完整的 AI 集成层。核心价值是 `lua/ai/` 模块，它为多个 AI 后端（Avante、OpenCode）和提供商（OpenAI、DeepSeek、Qwen、GLM 等）提供统一接口。本次目标是增强 Provider/Model 管理能力和 Commit Diff Review 功能。

**Core Value:** **让用户能够高效管理多个 AI Provider/Model，并在 GSD 多 commit 工作流中便捷地 Review 历史变更。**

### Constraints

- **技术栈**: Lua 5.1/5.4（Neovim），必须兼容现有 LazyVim 模块结构
- **UI 框架**: 使用现有 FZF-lua 或 Telescope 作为 picker 后端
- **配置存储**: 与现有 `ai_keys.lua` 文件格式兼容
- **依赖限制**: 不引入新的 heavyweight 插件，优先复用现有依赖
- **性能要求**: 管理面板启动时间 < 500ms，可用性检测单次< 10s
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Core Platform
| Technology | Purpose | Version Constraint |
|------------|---------|--------------------|
| **Neovim** | Editor runtime | >= 0.10 (assumed from API usage) |
| **Lua 5.1/LuaJIT** | Configuration language | Embedded in Neovim |
| **LazyVim** | Base distribution | Latest (via `LazyVim/LazyVim`) |
## Plugin Manager
| Technology | Purpose | Notes |
|------------|---------|-------|
| **Lazy.nvim** | Plugin management | Bootstrap via `config/lazy.lua`, spec files in `lua/plugins/` |
## Plugin Inventory
### AI Integration
| Plugin | Purpose | Load Strategy | Build |
|--------|---------|---------------|-------|
| `yetone/avante.nvim` | AI chat/code editing panel | `VeryLazy` | `make` (Rust binary) |
### Code Completion
| Plugin | Purpose | Load Strategy |
|--------|---------|---------------|
| `saghen/blink.cmp` | Autocomplete (LSP, path, snippet, buffer) | Lazy (via trigger) |
| *Note: Replaces nvim-cmp + cmp.nvim ecosystem* | | |
### LSP & Language Support
| Plugin | Purpose | Notes |
|--------|---------|-------|
| `neovim/nvim-lspconfig` | LSP server configuration | clangd (primary), ccls (fallback, autostart=false) |
| Mason (via LazyVim) | LSP server installer | Not explicitly configured |
### Code Formatting
| Plugin | Purpose | Formatters Configured |
|--------|---------|----------------------|
| `stevearc/conform.nvim` | Format-on-save | Stylua, prettier, jq, ruff_format, goimports+gofmt, rustfmt, clang-format (custom style), shfmt, fish_indent, taplo |
### File Navigation & Search
| Plugin | Purpose | Keymaps |
|--------|---------|---------|
| `ibhagwan/fzf-lua` | Fuzzy finder (treesitter, sync picker) | `<leader>so` |
| `nvim-telescope/telescope.nvim` | Grepper (project-root aware) | `<leader>sg` |
| `nvim-treesitter/nvim-treesitter` | Syntax highlighting, AST parsing | (via LazyVim) |
### Git Integration
| Plugin | Purpose | Custom Features |
|--------|---------|-----------------|
| `sindrets/diffview.nvim` | Diff viewer, file history, merge tool | Git version checker (>= 2.31), custom git binary resolver, worktree support, LSP disabled in diff buffers, enhanced commands |
| `tpope/vim-fugitive` | Git commands | Standard |
| `Snacks.nvim` (lazygit) | LazyGit integration | Via dashboard |
### UI Components
| Plugin | Purpose | Configuration |
|--------|---------|---------------|
| `nvim-lualine/lualine.nvim` | Status line | Custom terminal extension (managed by terminal.lua) |
| `akinsho/bufferline.nvim` | Tab/buffer bar | Pick, close, move keymaps |
| `esmuellert/codediff.nvim` | VSCode-style diff viewer | Custom highlights, whitespace config |
| `MunifTanjim/nui.nvim` | UI components | Used by leetcode.nvim |
### Terminal
| Plugin | Purpose | Configuration |
|--------|---------|---------------|
| `akinsho/toggleterm.nvim` | Embedded terminal | Float mode, curved border, persist_size/mode, close_on_exit=false, winbar enabled, custom keymaps |
### Colorschemes
| Plugin | Status | Role |
|--------|--------|------|
| `github-main-user/lytmode.nvim` | **Active** | Primary colorscheme, priority 1000, `lazy=false` |
| `everviolet/nvim` | Available | Fallback, "fall" variant, green accent |
| Others (commented) | Disabled | Zephyr, Kanagawa, Dracula, Sonokai, Aurora, Miasma |
### Dashboard & Utility
| Plugin | Purpose | Features |
|--------|---------|----------|
| `snacks.nvim` | Dashboard, lazygit | Custom ASCII art header, recent files, projects, git status pane, startup |
### Extra
| Plugin | Purpose | Notes |
|--------|---------|-------|
| `kawre/leetcode.nvim` | LeetCode integration | CN site enabled, fzf-lua dependency, HTML treesitter auto-update |
## External Tooling (CLI Dependencies)
### Required by Plugins
| Tool | Required By | Minimum Version |
|------|-------------|-----------------|
| `git` | diffview.nvim | >= 2.31 (enforced by custom checker) |
| `make` | avante.nvim build | Standard |
| `stylua` | Lua formatting | Via conform.nvim |
| `prettier` | JS/TS/CSS/HTML/MD formatting | Via conform.nvim |
| `clangd` | C/C++ LSP | Installed via Mason |
| `ccls` | C/C++ LSP (fallback) | Manual install |
| `clang-format` | C/C++ formatting | Via conform.nvim (custom args) |
| `jq` | JSON formatting | Via conform.nvim |
| `ruff` | Python formatting | Via conform.nvim |
| `goimports`/`gofmt` | Go formatting | Via conform.nvim |
| `rustfmt` | Rust formatting | Via conform.nvim |
| `shfmt` | Shell formatting | Via conform.nvim |
| `fish_indent` | Fish shell formatting | Via conform.nvim |
| `taplo` | TOML formatting | Via conform.nvim |
| `claude` | Claude Code | CLI tool from Anthropic |
| `opencode` | OpenCode | CLI tool |
### AI Providers (Network Dependencies)
| Provider | Endpoint | Default Model |
|----------|----------|---------------|
| `bailian_coding` | `https://coding.dashscope.aliyuncs.com/v1` | `qwen3.6-plus` |
| `deepseek` | `https://api.deepseek.com` | `deepseek-chat` |
| `openai` | `https://api.openai.com` | `gpt-4o-mini` |
| `qwen` | `https://{QWEN_BASE_ENDPOINT}` | `qwen-2.5-chat` |
| `minimax` | `https://{MINIMAX_BASE_ENDPOINT}` | `minimax-latest` |
| `kimi` | `https://{KIMI_BASE_ENDPOINT}` | `kimi-k2-0711-preview` |
| `glm` | `https://{GLM_BASE_ENDPOINT}` | `GLM-4.7` |
| `bailian` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `bailian-chat-v1` |
| `dashscope` | `https://api.dashscope.com` | `qwen2.5-coder` |
| `moonshot` | `https://api.moonshot.ai` | `moonshot-v1` |
| `ollama` | `http://localhost:11434` | `qwen2.5-coder:latest` |
## Testing Stack
| Technology | Purpose |
|------------|---------|
| `plenary.nvim` | Test framework (describe/it/assert pattern) |
| `minimal_init.lua` | Isolated test environment (no plugin loading) |
## Configuration Files
| Path | Purpose |
|------|---------|
| `~/.config/nvim/ai_keys.lua` | API keys and base URLs |
| `~/.config/nvim/opencode.template.jsonc` | OpenCode config template (JSONC with comments) |
| `~/.config/nvim/prompts/*.md` | System prompt files |
| `~/.config/nvim/.opencode.json` | Project-level OpenCode config |
| `~/.config/opencode/config.json` | Generated OpenCode config |
| `~/.config/opencode/api_key_{provider}.txt` | Per-provider API key files (XDG) |
| `~/.local/state/nvim/diffview_local.lua` | Custom git binary path |
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Overview
- A plugin-managed Neovim IDE built on LazyVim with custom keymaps, themes, and tooling
- A centralized AI module that connects multiple LLM providers to multiple AI coding tools (Avante.nvim, OpenCode, Claude Code)
- Configuration resolution, sync, hot-reload, and skill management systems
- Terminal multiplexing via toggleterm with a custom picker
- Comprehensive test suite using plenary.nvim
## High-Level Architecture
```
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
### Config Resolution Pipeline
### Key Management
### Terminal Multiplexing
### Plugin Architecture
## File Counts
| Directory | Files |
|-----------|-------|
| `lua/config/` | 4 |
| `lua/plugins/` | 14 |
| `lua/ai/` | 15 root + 3 avante/ + 10 skill_studio/ = **28** |
| `tests/` | 1 root + 1 minimal + 5 ai/ = **7** |
| **Total Lua files** | **~53** |
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->


<!-- OB_TOOL_ENV_START -->

---

## OB Tool Environment

Source: `/home/weixiaoxian.wxx/bin/ob_ai_tool_env`
Updated: 2026-05-21 16:20

All AI tools (Claude, OpenCode, Qoder) reference these files via AGENTS.md.

### Commands → Skills

Commands linked to `.claude/commands/` and converted to skills:

- `/ob-flow-review` — Generate an OB-style merge review and start farm tests based on current git commits

### OB Code Review Skills

Source: `/data/1/weixiaoxian.wxx/dev_tool/oceanbase-skills/packages/oceanbase-develop`

Linked to: `.claude/skills/`

OceanBase 代码审查专项 skills:
- `ob-code-review` — OceanBase 代码审查协调器。提供交互式选择界面，协调调用六个专项审查agents（含可选的Schema/DDL审查）进行完整的OceanBase代码规范审查。
- `ob-code-style-reviewer` — OceanBase 代码风格审查专家。专注于检查命名规范、注释要求、格式统一和代码可读性问题。
- `ob-concurrency-reviewer` — OceanBase 并发安全审查专家。专注于检查多线程安全、锁使用和竞态条件问题。
- `ob-error-handling-reviewer` — OceanBase 错误处理审查专家。专注于检查错误码处理、错误传播和 OB_FAIL 模式使用。
- `ob-memory-safety-reviewer` — OceanBase 内存安全审查专家。专注于检查内存管理、边界检查和资源泄漏问题。
- `ob-schema-review` — OceanBase Schema 和 DDL MR 审查协调器。拉取 MR diff、做静态预检、按变更文件动态分桶，并聚焦增量代码风险输出高信噪比 review。可选读取语雀背景（需用户明确要求）。可选读取 Dima 工作项上下文（需用户触发或指定）。适用于 schema review、DDL review、MR review 和 OceanBase Schema 相关变更审查。
- `ob-security-reviewer` — OceanBase 安全审查专家。专注于检查敏感信息泄露、注入风险和输入验证问题。
- `ob-vector-memory-leak-reviewer` — OceanBase 向量索引内存泄漏审查专家。专注于检查租户销毁、并发安全、allocator 生命周期和内存泄漏问题。

### Rules

Linked to: `.claude/rules/`

- [OB Build & Test Rules](.claude/rules/ob-build-test.md)
- [OB Hotspot Aggregation Rules](.claude/rules/ob-hotspot-aggregation.md)

---

#### Embedded Rules

For tools without rule file support:

---

##### OB Build & Test Rules


Project-level build and test workflow rules for OceanBase projects.

##### Build Rules

###### Standard Build Command
Always use the following command to compile the project with debug logging enabled:
```bash
./build.sh release --init -DENABLE_DEBUG_LOG=ON
```

###### Output Directory
All build artifacts are generated under `build_release/`. Do NOT build in other directories unless explicitly requested.

###### Compile Targets with `ob-make`
Use `ob-make` instead of raw `make` — it leverages the compilation cache for faster rebuilds.

To compile a specific test case, navigate to the corresponding directory under `build_release/` that mirrors the source file path, then run `ob-make`:

```bash
# For test file unittest/storage/tx/test_hotspot_free_cbs_deadlock.cpp
# Navigate to corresponding build directory and run ob-make
cd build_release/unittest/storage/tx
ob-make
```

**Key Points**:
1. Use the relative path under `build_release/` that matches the source file location.
2. **DO NOT specify case name after `ob-make`** — `ob-make` compiles all targets in the current directory. Specifying a case name like `ob-make test_xxx` is incorrect and may cause unexpected behavior.

###### Incremental Rebuilds
After modifying source files, **do NOT re-run `./build.sh`** unless:
- CMakeLists.txt changes
- Build flags need updating
- `--init` artifacts are corrupted

Instead, just run `ob-make` in `build_release/` to leverage the cache.

###### When CMakeLists.txt Changes

If you modify CMakeLists.txt, you must regenerate build system:

```bash
# Re-run build.sh (this will regenerate CMake files)
./build.sh release -DENABLE_DEBUG_LOG=ON
```

**Note**: Do NOT use `cmake .` directly. Always use `build.sh` to regenerate build files.

##### Test Rules

###### Adding New Test Files

When adding a new test file, you must register it in CMakeLists.txt:

**For unit tests** (`unittest/storage/tx/CMakeLists.txt`):
```cmake
# Add this line at the end
storage_unittest(test_your_new_test_name)
```

**For integration tests** (`unittest/storage/tx/it/CMakeLists.txt`):
```cmake
# Add this line
tx_it_test(test_your_integration_test_name)
```

**Important**: After modifying CMakeLists.txt, regenerate CMake cache before compiling.

###### Test File Header Template

OB test files require specific headers and macros:

```cpp
/**
 * Copyright (c) 2021 OceanBase
 * OceanBase CE is licensed under Mulan PubL v2.
 * ... (full license header)
 */

#include <gtest/gtest.h>
#define USING_LOG_PREFIX TRANS  // Set appropriate log prefix
#define private public          // Allow testing private members
#define protected public        // Allow testing protected members

#include "storage/tx/ob_tx_hotspot_define.h"  // Your target header
// ... other includes

namespace oceanbase
{
using namespace ::testing;
using namespace transaction;

class YourTestClass : public ::testing::Test
{
public:
  virtual void SetUp() override
  {
    // Initialize OceanBase cluster version (required for many components)
    oceanbase::ObClusterVersion::get_instance().update_data_version(DATA_CURRENT_VERSION);
  }
  virtual void TearDown() override {}
};

TEST_F(YourTestClass, test_case_name)
{
  // Your test code
}

} // namespace oceanbase

int main(int argc, char **argv)
{
  system("rm -rf test_your_test.log*");
  ObLogger &logger = ObLogger::get_logger();
  logger.set_file_name("test_your_test.log", true, false, ...);
  logger.set_log_level(OB_LOG_LEVEL_DEBUG);
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
```

###### Required Headers for Transaction Tests

| Component | Required Include | Additional Setup |
|-----------|------------------|------------------|
| ObTxHotspotRedoCache | `storage/tx/ob_tx_hotspot_define.h` | `TransModulePageAllocator` |
| ObClusterVersion | `share/ob_cluster_version.h` (via utility.h) | `update_data_version(DATA_CURRENT_VERSION)` |
| Logging | `lib/utility/utility.h` | `USING_LOG_PREFIX` macro |
| Test framework | `<gtest/gtest.h>` | First include |

###### Compile and Run Single Test Cases

Test cases are located under `unittest/` and `mittest/` directories within `build_release/`.

To compile and run a specific test:
1. Navigate to the corresponding test directory under `build_release/` that mirrors the source file's path.
2. Run `ob-make` in that directory to compile the test case.
3. Execute the compiled test binary directly.

**Example**:
```bash
# For test file unittest/storage/tx/test_hotspot_free_cbs_deadlock.cpp
cd build_release/unittest/storage/tx
ob-make

# Run the test
./test_hotspot_free_cbs_deadlock
```

###### Test Execution
- Run test binaries from their build directory.
- If a test fails, capture the output and report the failure context.
- Do NOT run the full test suite unless explicitly requested — it is time-consuming.

###### Test Discovery
If you need to find relevant test cases for a modified file:
- Check `unittest/` and `mittest/` directories for files named similarly to the source file.
- Look for `*_test.cpp` or `*_unittest.cpp` patterns adjacent to or corresponding to the changed source files.

##### Common Compilation Issues

###### Issue: Undefined reference to mock classes
**Cause**: Test file not properly linked with mock libraries.
**Solution**: Use appropriate test function in CMakeLists.txt:
- `storage_unittest()` for basic tests
- `tx_unittest()` for tests needing `mock_tx_ctx` and `mock_tx_log_adapter`
- `tx_it_test()` for integration tests needing `tx_node` and `oceanbase`

###### Issue: Private member access fails
**Cause**: Missing `#define private public` before including headers.
**Solution**: Add macros before target header includes:
```cpp
#define private public
#define protected public
#include "storage/tx/ob_tx_target_header.h"
```

###### Issue: ObClusterVersion not initialized
**Cause**: Many OB components require cluster version to be set.
**Solution**: Add in SetUp():
```cpp
oceanbase::ObClusterVersion::get_instance().update_data_version(DATA_CURRENT_VERSION);
```

###### Issue: TransModulePageAllocator required
**Cause**: `ObTxHotspotRedoCache` constructor needs allocator.
**Solution**:
```cpp
TransModulePageAllocator allocator;
ObTxHotspotRedoCache cache(allocator);
```

###### Issue: ATOMIC_STORE for is_inited_
**Cause**: Cache not marked as initialized.
**Solution**:
```cpp
ATOMIC_STORE(&cache.is_inited_, 1);
```

###### Issue: Lock required for cache operations
**Cause**: Cache operations need `hotspot_lock_` held.
**Solution**:
```cpp
SpinWLockGuard guard(cache.hotspot_lock_);
```

###### Issue: hotspot_cache_ needs entries before operations
**Cause**: Operations like `handle_abort_response_()` require cache entries.
**Solution**:
```cpp
ObTxRedoExtractArg arg;
cache.hotspot_cache_.push_back(arg);
```

###### Issue: CMake can't find new test file
**Cause**: CMakeLists.txt changed but build system not regenerated.
**Solution**:
```bash
# Re-run build.sh to regenerate build files
./build.sh release -DENABLE_DEBUG_LOG=ON

# Then compile in the specific test directory
cd build_release/unittest/storage/tx
ob-make
```

##### Constraints

- Never use plain `make` — always use `ob-make`.
- **Never specify case name after `ob-make`** — e.g., `ob-make test_xxx` is WRONG. Just run `ob-make` without arguments in the target directory.
- To compile a specific test, navigate to the corresponding directory under `build_release/` (e.g., `build_release/unittest/storage/tx`) and run `ob-make` there.
- Never re-run `./build.sh` unless necessary — check if incremental build via `ob-make` is sufficient first.
- Never use `cmake .` directly — always use `build.sh` to regenerate build files when CMakeLists.txt changes.
- Always compile and run relevant tests before declaring code changes as ready.
- If `build_release/` does not exist, the initial `./build.sh release --init` has not been run yet — inform the user.
- Always add test file to CMakeLists.txt before compiling.
- Always re-run `build.sh` after modifying CMakeLists.txt to regenerate build files.

  ✓  Embedded: ob-build-test
---

##### OB Hotspot Aggregation Rules


Coding guidelines and debugging tips for hotspot transaction aggregation module.

##### Module Overview

Hotspot aggregation allows a primary transaction to aggregate redo logs from multiple secondary transactions across different log streams, enabling efficient cross-LS transaction coordination.

**Key files**:
- `src/storage/tx/ob_tx_hotspot_define.h/cpp`: Hotspot redo cache management
- `src/storage/tx/ob_tx_hotspot_helper.h/cpp`: Aggregation flow control and state machine

##### Key Concepts

###### CB (Log Callback) Lists

| List | Purpose | Release Mechanism |
|------|---------|-------------------|
| `idle_hotspot_cbs_` | Available CBs waiting for use | Normal return after use |
| `free_hotspot_cbs_` | CBs that failed submit (no callback attached) | **No automatic release** |
| `busy_hotspot_cbs_` | CBs submitted to clog pipeline | Released via clog callback |

**Important**: `free_hotspot_cbs_` contains orphaned CBs that failed during submit. They have no clog callback attached and cannot be released automatically. Must be handled explicitly in abort/cleanup paths.

###### State Machine: TxRedoFlushStatus

```
NORMAL_START (10)
      ↓
PRIMARY_PREPARING (110)
      ↓ dispatch
PRIMARY_COLLECTING (120)    ← Leader switch interrupts here
      ↓ success
PRIMARY_AGGR_SUCCEEDED (150)
      ↓ OR force abort
PRIMARY_AGGR_FAILED (160)   ← Terminal state, no retry
```

**Terminal states**: `PRIMARY_AGGR_SUCCEEDED` (150) and `PRIMARY_AGGR_FAILED` (160)

###### `cbs_is_working_()` Function

```cpp
bool cbs_is_working_()
{
  return busy_hotspot_cbs_.get_size() > 0 || free_hotspot_cbs_.get_size() > 0;
}
```

Returns true if any CB is "in use". Used in cleanup/abort paths to check if CBs can be released.

##### Common Bugs and Patterns

###### Pattern 1: Free CBs Deadlock

**Bug**: When `handle_abort_response_()` checks `cbs_is_working_()`, it treats `free` and `busy` the same, but free CBs have no release path.

**Fix**: In abort path, explicitly move free CBs to idle:
```cpp
if (cbs_is_working_()) {
  ret = OB_EAGAIN;
  // Attempt to release free CBs to idle
  int tmp_ret = release_free_cbs_to_idle_();
}
```

###### Pattern 2: Leader Switch During Aggregation

When leader switch occurs during `PRIMARY_COLLECTING`:
1. Submit fails with `OB_NOT_MASTER (-4038)`
2. CBs go to `free_hotspot_cbs_` (no callback)
3. `switch_to_follower_forcedly` triggers abort
4. State set to `PRIMARY_AGGR_FAILED`
5. Cleanup path enters infinite retry if free CBs not handled

**Required handling**: Ensure abort path can release free CBs.

###### Pattern 3: OB_TMP_FAIL in Dispatch Loop

```cpp
for (int i = 0; OB_SUCC(ret) && i < cb_view.free_cb_count; i++) {
  tmp_ret = OB_SUCCESS;
  if (OB_TMP_FAIL(submit_redo_log_generated_by_others())) {
    // OB_TMP_FAIL only sets tmp_ret, NOT ret!
    // ret stays SUCCESS, loop continues
  }
}
```

**Implication**: Submit failures don't break the loop. CBs accumulate in `free_hotspot_cbs_`.

##### Debugging Tips

###### Check CB List Sizes

```cpp
TRANS_LOG(INFO, "hotspot cb status",
          K(busy_hotspot_cbs_.get_size()),
          K(free_hotspot_cbs_.get_size()),
          K(idle_hotspot_cbs_.get_size()));
```

###### Key Logs to Search

| Pattern | Meaning |
|---------|---------|
| `"wait hotspot log cb to be zero"` | Cleanup blocked by CBs |
| `"busy hotspot log cbs still in clog pipeline"` | Waiting for callbacks |
| `"released orphaned free hotspot cbs"` | Free CBs moved to idle |
| `"PRIMARY_AGGR_FAILED"` | Terminal abort state |

###### Common Error Codes

| Code | Name | Meaning |
|------|------|---------|
| -4038 | OB_NOT_MASTER | Leader switch occurred |
| -4023 | OB_EAGAIN | Retry needed / state not ready |
| -6268 | OB_TX_NOLOGCB | No available log callback |

##### Test Patterns

###### Test CB Working Logic

```cpp
// Test cbs_is_working_() returns false when all lists empty
EXPECT_FALSE(cache.cbs_is_working_());

// Test free>0 causes cbs_is_working_() true
// This is the condition causing deadlock in abort path
```

###### Test State Transitions

```cpp
// COLLECTING -> AGGR_FAILED is valid (force abort)
EXPECT_EQ(OB_SUCCESS, is_valid_transition(PRIMARY_COLLECTING, PRIMARY_AGGR_FAILED));

// AGGR_FAILED is terminal - no further transitions
EXPECT_EQ(OB_STATE_NOT_MATCH, is_valid_transition(PRIMARY_AGGR_FAILED, PRIMARY_COLLECTING));
```

##### Constraints

- Always handle `free_hotspot_cbs_` in abort/cleanup paths
- Never assume free CBs will be released by clog callback
- Check `redo_flush_status_` (actual state), not `redo_status` (parameter)
- Terminal states block all further aggregation operations
  ✓  Embedded: ob-hotspot-aggregation
<!-- OB_TOOL_ENV_END -->
