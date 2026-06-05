# Repository Guidelines

## Project Structure & Module Organization

This repository is a LazyVim/Neovim configuration written mainly in Lua. The entry point is `init.lua`, which loads the LazyVim setup from `lua/config/`. Plugin specs live in `lua/plugins/`, one file per plugin area such as `ai.lua`, `git.lua`, `terminal.lua`, and `lsp.lua`.

The AI integration layer is under `lua/ai/`. Core modules include provider registration, key management, config resolution, sync helpers, Avante/OpenCode adapters, terminal integration, and provider management. Commit review UI code lives in `lua/commit_picker/`. Tests are in `tests/`, with AI tests under `tests/ai/` and commit picker tests under `tests/commit_picker/`. Documentation and usage notes are in `docs/`; templates and generated tool configuration sources are in `templates/`, `pi/`, and related tool folders.

## Build, Test, and Development Commands

- `stylua lua/ tests/`: format Lua source and tests.
- `stylua --check lua/ tests/`: verify formatting without changing files.
- `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/" -c "q"`: run the full Plenary test suite with the minimal test config.
- `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/ai/state_spec.lua" -c "q"`: run one test file.
- `nvim --headless -c "lua require('ai').setup()" -c "q"`: smoke-test AI module loading.

## Coding Style & Naming Conventions

Use Lua with 2-space indentation, double-quoted strings, and a 120-column target as configured by `stylua.toml`. Prefer module tables named `M`, local helper functions, and grouped `require` calls at the top of files. Use `snake_case` for variables and functions, `UPPER_CASE` for constants, and PascalCase only for imported module aliases such as `Providers` or `State`.

Plugin files should return Lazy.nvim spec tables. Optional dependencies should be loaded with `pcall(require, ...)`, and user-facing errors should use `vim.notify`.

## Testing Guidelines

Tests use `plenary.nvim` with `describe`, `it`, and `assert` conventions. Name test files as `*_spec.lua` and place them near the subsystem they cover, for example `tests/ai/providers_spec.lua`. Add focused tests for new modules, provider behavior, config resolution, picker logic, and state changes.

## Commit & Pull Request Guidelines

Recent commits use Conventional Commit style: `feat(pi): ...`, `fix(pi): ...`, `sync(pi): ...`. Keep commits scoped and imperative. PRs should describe the user-visible change, list verification commands run, mention affected config files, and include screenshots only for UI picker or visual workflow changes.

## Security & Configuration Tips

Do not commit local API keys, `.env` files, generated `node_modules/`, session files, or editor logs. Keep provider secrets in the configured external key files, not in Lua source or templates.
