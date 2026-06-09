## 1. Plugin Directory Structure

- [x] 1.1 Create `local-plugins/ai/` directory with subdirectories: `plugin/`, `lua/`, `doc/`, `tests/`
- [x] 1.2 Move `lua/ai/` → `local-plugins/ai/lua/ai/` (all 37 files including subdirectories)
- [x] 1.3 Move `lua/commit_picker/` → `local-plugins/ai/lua/commit_picker/` (8 files)
- [x] 1.4 Move `tests/ai/` → `local-plugins/ai/tests/ai/` (16 test files)
- [x] 1.5 Move `tests/commit_picker/` → `local-plugins/ai/tests/commit_picker/` (2 test files)
- [x] 1.6 Delete `lua/ai/skill_studio/` directory (init.lua + converter.lua)

## 2. Path Resolution Module

- [x] 2.1 Create `local-plugins/ai/lua/ai/paths.lua` with `setup(opts)` accepting `template_dir` config (default: `vim.fn.stdpath("config")`)
- [x] 2.2 Implement `paths.settings_template(tool)` → `<template_dir>/templates/<tool>/<version>.template.jsonc`
- [x] 2.3 Implement `paths.legacy_template(tool)` → `<template_dir>/<tool>.template.jsonc`
- [x] 2.4 Implement `paths.resource(rel)` → `<template_dir>/<rel>`
- [x] 2.5 Implement `paths.config_dir()` → returns configured `template_dir`
- [x] 2.6 Add tests for `paths.lua` covering default and custom `template_dir`

## 3. Migrate Modules to paths.lua

- [x] 3.1 Update `ai/pi.lua` — replace `default_repo_root()`, `get_config_dir()`, `get_repo_root()` with `paths.lua` calls (2 stdpath sites)
- [x] 3.2 Update `ai/opencode.lua` — replace `get_nvim_config_dir()`, `get_opencode_template_path()` with `paths.lua` calls (2 stdpath sites)
- [x] 3.3 Update `ai/claude_code.lua` — replace `get_config_dir()`, `get_template_path()`, `get_ccstatusline_template_path()` with `paths.lua` calls (2 stdpath sites)
- [x] 3.4 Update `ai/template_version.lua` — replace `get_templates_dir()`, legacy path construction with `paths.lua` calls (3 stdpath sites)
- [x] 3.5 Update `ai/health.lua` — replace template path checks with `paths.lua` calls (2 stdpath sites)
- [x] 3.6 Update `ai/config_watcher.lua` — no stdpath("config") calls found, uses glob patterns only. No change needed.
- [x] 3.7 Update `ai/init.lua` `setup()` to call `Paths.setup(opts)` with `template_dir` from config

## 4. Command and Keymap Registration

- [x] 4.1 Create `local-plugins/ai/plugin/ai.lua` — single registration point for all commands and keymaps
- [x] 4.2 Register high-frequency commands: `AISync`, `AIKeys`, `AIProvider`, `AIModel`
- [x] 4.3 Register tool config commands: `OpenCodeGenerate/Preview/Edit/Status`, `ClaudeCodeGenerate/Preview/Edit/Status`, `PiGenerate/Preview/Edit/Status`
- [x] 4.4 Register `OpenCodeTheme` with subcommand argument (generate/preview/edit)
- [x] 4.5 Register `AI` subcommand handler for: template CRUD, context, prompt, watch, export, backup
- [x] 4.6 Register Commit Picker keymaps: `<leader>kC/kf/kb/kd` with TODO comment for future redesign
- [x] 4.7 Register high-frequency keymaps: `<leader>kk/ks/ke/kp`
- [x] 4.8 Slim down `ai/init.lua` — remove `commands` array, `keys` array, `setup_commands()`, `setup_keys()`. Keep `setup()` for module initialization only
- [x] 4.9 Move Provider Manager command registration from `provider_manager/init.lua` `setup()` into `plugin/ai.lua`

## 5. Cleanup

- [x] 5.1 Delete `lua/plugins/opencode.lua` (all commands moved to `plugin/ai.lua`)
- [x] 5.2 Update `lua/plugins/ai.lua` — change from plenary trigger to lazy.nvim `dir` spec: `{ dir = vim.fn.stdpath("config") .. "/local-plugins/ai", name = "ai-tools", lazy = false, dependencies = { "nvim-lua/plenary.nvim" } }`
- [x] 5.3 Verify `lua/plugins/terminal.lua` still works — calls `require("ai.terminal")` and `require("ai.terminal_picker")` which resolve via plugin runtimepath

## 6. Tests

- [x] 6.1 Update `tests/minimal_init.lua` — add `local-plugins/ai` to runtimepath
- [x] 6.2 Verify all existing tests pass with new directory structure (test paths updated for new location)
- [x] 6.3 Update `tests/ai/pi_spec.lua` — adjust `project_root()` to account for new test location (`local-plugins/ai/tests/`)

## 7. Documentation

- [x] 7.1 Write `local-plugins/ai/README.md` — overview, install, quick start, command reference table, keymap table, links to docs
- [x] 7.2 Write `local-plugins/ai/doc/ai.txt` — vimdoc format with command reference, keymap reference, setup() options
- [x] 7.3 Write `local-plugins/ai/doc/configuration.md` — provider config, API key management, template system, hot-reload
- [x] 7.4 Write `local-plugins/ai/doc/templates.md` — template structure and field reference for OpenCode, Claude Code, Pi
- [x] 7.5 Write `local-plugins/ai/doc/architecture.md` — module dependency graph, data flow, extension guide

## 8. Verification

- [x] 8.1 Run `stylua --check` on all Lua files in `local-plugins/ai/`
- [x] 8.2 Verify no `stdpath("config")` calls remain in `local-plugins/ai/lua/ai/` (excluding `paths.lua`)
- [x] 8.3 Verify no `nvim_create_user_command` calls remain in `local-plugins/ai/lua/` (all in `plugin/`)
- [x] 8.4 Verify no duplicate command names across the codebase
- [x] 8.5 Verify all removed commands (Skill*, old naming) are not registered
- [x] 8.6 Verify `require("ai.pi")`, `require("ai.terminal")`, `require("commit_picker.init")` all resolve correctly
- [x] 8.7 Smoke test: start Neovim, verify `:AISync`, `:AIKeys`, `:AIProvider`, `:AIModel` work
- [x] 8.8 Smoke test: verify `:PiGenerate`, `:OpenCodeGenerate`, `:ClaudeCodeGenerate` work
- [x] 8.9 Smoke test: verify `:TermSelect` works (terminal in starter calling plugin module)
