# Stack

## Language
- **Lua** (Neovim Lua API) — 83 Lua files
- **Shell** (bash/zsh) — scripts, shell config
- **JSON/JSONC** — configuration files

## Runtime
- **Neovim** (LazyVim base) with LuaJIT
- **Node.js** — for external tool integration (ECC, GSD install scripts)

## Key Dependencies
- **Lazy.nvim** — plugin manager
- **fzf-lua** — fuzzy finder (used by component picker)
- **plenary.nvim** — testing framework
- **stylua** — Lua code formatter

## External Tools
- **ECC (Everything Claude Code)** — git-based, npm package manager for rules/agents/skills
- **GSD (Get Shit Done)** — npm package `get-shit-done-cc`, npx-based
- **ccstatusline** — status line config for Claude Code
- **OpenCode CLI** — `@opencode/cli` npm package

## Conventions
- 2-space indentation (stylua.toml)
- Double quotes preferred (stylua.toml)
- 120 char line width
- Module pattern: `local M = {}; function M.foo() end; return M`
- Use `vim.notify` for user feedback
- `pcall` for optional dependencies
- Tests in `tests/ai/` using plenary.nvim's `describe/it/assert`
