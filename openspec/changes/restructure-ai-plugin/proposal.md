## Why

The `lua/ai/` module has grown to 37 files / 11,700 lines, embedded directly in the LazyVim starter config. It manages 3 AI coding tools (OpenCode, Claude Code, Pi) with provider management, key management, terminal integration, config sync, commit picker, and more. While it already has a `setup()` function, commands and keymaps are scattered across 5 registration points with 4 duplicate command registrations, inconsistent naming (`OpenCodeWriteConfig` vs `OpenCodeGenerateConfig`), and 55 commands flat in the namespace. Template paths are hardcoded via `stdpath("config")` in 12 places across 6 files. Restructuring it as a proper local plugin will make it maintainable, extractable, and easier to use.

## What Changes

- **Extract `lua/ai/` into `local-plugins/ai/`** — Standard Neovim plugin structure with `plugin/`, `lua/`, `doc/`, `tests/`. Loaded via lazy.nvim `dir` from `lua/plugins/ai.lua`.
- **Unify command registration** — All commands registered in a single `plugin/ai.lua`. Delete `lua/plugins/opencode.lua` (26 commands merged). Reduce 55 → ~35 commands with consistent naming: `<Tool>Generate/Preview/Edit/Status` pattern, low-frequency ops under `AI <subcommand>`.
- **Redesign keymaps** — 4 high-frequency keys under `<leader>k`: `kk` (model), `ks` (sync), `ke` (keys), `kp` (providers). Commit Picker keys stay under `<leader>k` but are flagged for future redesign.
- **Add `ai/paths.lua`** — Unified path resolution module replacing 12 hardcoded `stdpath("config")` calls across 6 files. Accepts `template_dir` config option.
- **Separate templates from code** — Template data (`templates/`, `pi/`, `*.template.jsonc`) stays in starter as user config. Plugin gets `doc/templates.md` documenting template structure and fields.
- **Delete Skill Studio** — Remove `lua/ai/skill_studio/` (2 files, 7 commands). Unused functionality.
- **Terminal stays in starter** — `lua/plugins/terminal.lua` remains as starter config, calling `require("ai.terminal")` from the plugin.
- **Rich documentation** — `README.md` (quick start, command reference), `doc/ai.txt` (vimdoc), `doc/configuration.md`, `doc/templates.md`, `doc/architecture.md`.
- **Move `commit_picker/` into plugin** — Only used by `ai/init.lua`, belongs with the plugin.
- **Move tests into plugin** — `tests/ai/` and `tests/commit_picker/` → `local-plugins/ai/tests/`.

## Capabilities

### New Capabilities
- `plugin-structure`: Local plugin extraction — directory layout, lazy.nvim loading, runtimepath integration, `plugin/ai.lua` auto-load entry point.
- `command-interface`: Unified command registration — consolidated naming, `AI <subcommand>` pattern for low-frequency ops, elimination of duplicates.
- `path-resolution`: Unified `ai/paths.lua` module — configurable `template_dir`, replacing all hardcoded `stdpath("config")` paths.
- `documentation`: Plugin documentation — README, vimdoc, configuration guide, template reference, architecture doc.

### Modified Capabilities
(none — no existing specs)

## Impact

- **Code moved**: `lua/ai/` → `local-plugins/ai/lua/ai/`, `lua/commit_picker/` → `local-plugins/ai/lua/commit_picker/`
- **Code deleted**: `lua/ai/skill_studio/` (2 files), `lua/plugins/opencode.lua` (merged into plugin)
- **Code added**: `local-plugins/ai/plugin/ai.lua`, `lua/ai/paths.lua`, `doc/` (5 files)
- **Code modified**: 6 files for path resolution (`pi.lua`, `opencode.lua`, `claude_code.lua`, `template_version.lua`, `health.lua`, `config_watcher.lua`), `init.lua` (slim down)
- **Config changed**: `lua/plugins/ai.lua` (lazy spec → `dir` loading)
- **Tests moved**: `tests/ai/`, `tests/commit_picker/` → `local-plugins/ai/tests/`
- **No breaking changes for end user**: Same commands (minus duplicates), same keymaps (minus unused), same functionality. `require("ai.terminal")` still works from starter's `plugins/terminal.lua`.
