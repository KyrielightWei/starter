# Stack — Technology Stack & Dependencies

**Project:** LazyVim Neovim Configuration with AI Integration
**Mapped:** 2026-04-21

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
