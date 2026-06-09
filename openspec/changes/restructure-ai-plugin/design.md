## Context

The `lua/ai/` module is a 37-file / 11,700-line subsystem embedded in a LazyVim starter config (`starter/`). It manages configuration sync for 3 AI coding CLI tools (OpenCode, Claude Code, Pi), provides provider/key management, terminal integration, commit picker, and skill studio.

Current problems:
- **Scattered registration**: Commands registered in 5 places (`init.lua` commands array, `plugins/opencode.lua` module-level, `plugins/terminal.lua` module-level, `provider_manager/init.lua`, `skill_studio/init.lua`). 4 duplicate command registrations exist.
- **Hardcoded paths**: 12 places across 6 files call `vim.fn.stdpath("config")` to find templates, each with its own local helper function.
- **No plugin boundary**: `lua/ai/` lives directly in the starter config's `lua/` directory, mixed with `lua/config/` and `lua/plugins/`.
- **Naming inconsistency**: `OpenCodeWriteConfig` vs `OpenCodeGenerateConfig`, `AISync` vs `AISyncAll` vs `AISyncSelect`.
- **Unused code**: Skill Studio (2 files, 7 commands) is never used.

Constraints:
- Must remain in the same git repository (user preference: "保持同仓库，但结构化").
- Template data files (`templates/`, `pi/`, `*.template.jsonc`) stay in starter as user configuration.
- `lua/plugins/terminal.lua` stays in starter, calls `require("ai.terminal")` from the plugin.
- Commit Picker moves into the plugin but its keymaps are flagged for future redesign.

## Goals / Non-Goals

**Goals:**
- Extract `lua/ai/` into `local-plugins/ai/` with standard Neovim plugin structure (`plugin/`, `lua/`, `doc/`, `tests/`)
- Single command registration point in `plugin/ai.lua` — no duplicates
- Consistent command naming: `<Tool>Generate/Preview/Edit/Status` + `AI <subcommand>` for low-frequency ops
- Unified path resolution via `ai/paths.lua` module
- 4 high-frequency keymaps under `<leader>k`
- Delete Skill Studio entirely
- Rich documentation: README, vimdoc, configuration guide, template reference, architecture doc
- All existing functionality preserved (minus Skill Studio)

**Non-Goals:**
- Changing any AI tool's actual configuration logic (provider resolution, key management, sync algorithms)
- Redesigning Commit Picker keymaps (flagged for future work)
- Extracting to a separate git repository
- Changing terminal integration behavior
- Modifying template file contents

## Decisions

### D1: `local-plugins/ai/` as plugin directory

**Choice**: Place the plugin at `local-plugins/ai/` under the starter repo root.

**Alternatives considered**:
- `plugins/ai/` at root — too ambiguous, conflicts with `lua/plugins/`
- `lua/ai-plugin/` under lua — no physical isolation, still mixed with starter code

**Rationale**: `local-plugins/` is a clear namespace for local plugins. If more local plugins are needed later, they go alongside. The name is self-documenting.

### D2: lazy.nvim `dir` loading

**Choice**: `lua/plugins/ai.lua` uses `{ dir = vim.fn.stdpath("config") .. "/local-plugins/ai", name = "ai-tools", lazy = false }`.

**Alternatives considered**:
- Manual `runtimepath` manipulation — fragile, no dependency management
- Separate packpath entry — more complex, lazy.nvim already handles this

**Rationale**: lazy.nvim's `dir` option is the standard way to load local plugins. It handles runtimepath, dependencies, and is consistent with how remote plugins are loaded.

### D3: Single `plugin/ai.lua` registration point

**Choice**: All commands and keymaps registered in `local-plugins/ai/plugin/ai.lua`. Delete `lua/plugins/opencode.lua`. Commands from `provider_manager/init.lua` and the old `plugins/opencode.lua` module-level code are consolidated here.

**Alternatives considered**:
- Keep per-module registration (each module registers its own commands in `setup()`) — current approach, leads to scattering
- Split into multiple plugin files (`plugin/ai-commands.lua`, `plugin/ai-keys.lua`) — unnecessary fragmentation for a single plugin

**Rationale**: One file, one place to look. `plugin/` directory is auto-loaded by Neovim when the plugin's runtimepath entry is added. `lazy = false` ensures it loads immediately.

### D4: `ai/paths.lua` unified path resolution

**Choice**: New module `lua/ai/paths.lua` that centralizes all path resolution. Accepts `template_dir` config (defaults to `vim.fn.stdpath("config")`). Other modules call `Paths.get("templates/pi/default.template.jsonc")` instead of building paths themselves.

**Alternatives considered**:
- Pass `template_dir` through `setup()` opts to each module individually — too many parameters, each module has its own `get_config_dir()` helper
- Use a global `vim.g.ai_template_dir` — global state, hard to test

**Rationale**: A single module with a clear API. `setup()` sets the config once, all modules read from `paths.lua`. Easy to test by overriding the config.

### D5: Command naming — `<Tool><Action>` + `AI <sub>`

**Choice**:
- High-frequency: `AISync`, `AIKeys`, `AIProvider`, `AIModel` (short, no tool prefix)
- Tool config: `OpenCodeGenerate`, `OpenCodePreview`, `OpenCodeEdit`, `OpenCodeStatus` (consistent pattern)
- Low-frequency: `AI template list`, `AI context copy`, `AI prompt edit`, `AI backup`, `AI watch`, `AI export` (subcommands)

**Alternatives considered**:
- All under `AI` prefix (`AI sync`, `AI keys`, `AI opencode generate`) — too verbose for frequent use
- Keep current naming — inconsistent, duplicates

**Rationale**: Frequent ops get short names. Tool-specific ops follow a predictable pattern. Rare ops are discoverable via `:AI <Tab>`.

### D6: Documentation structure

**Choice**:
- `README.md` — overview, install, quick start, command reference table
- `doc/ai.txt` — vimdoc format for `:help ai`
- `doc/configuration.md` — provider setup, API key management, template system, hot reload
- `doc/templates.md` — template file structure and field reference for each tool
- `doc/architecture.md` — module dependency graph, data flow, extension guide (for contributors)

**Alternatives considered**:
- Single large README — too long, hard to navigate
- Only vimdoc — less readable for GitHub browsing

**Rationale**: README for quick reference and GitHub. vimdoc for `:help` integration. Separate guides for depth.

### D7: Skill Studio deletion

**Choice**: Delete `lua/ai/skill_studio/` entirely (2 files: `init.lua` 506 lines, `converter.lua` 132 lines). Remove 7 `Skill*` commands.

**Rationale**: User confirmed it's unused. Removing it reduces complexity and file count.

## Risks / Trade-offs

- **[Duplicate commands during migration]** → Delete `lua/plugins/opencode.lua` in the same commit as creating `plugin/ai.lua`. No intermediate state with duplicates.
- **[Path resolution regression]** → Add tests for `ai/paths.lua` covering all path patterns. Verify each module resolves paths correctly after migration.
- **[Terminal broken after move]** → `lua/plugins/terminal.lua` calls `require("ai.terminal")`. After extraction, `local-plugins/ai/lua/` is on runtimepath via lazy.nvim `dir`, so `require("ai.terminal")` still resolves. Verify with a smoke test.
- **[Commit Picker keymaps need future work]** → Keep current keymaps (`<leader>kC/kf/kb/kd`) as-is. Add a TODO comment. Not blocking this change.
- **[Template data still in starter]** → This is intentional. Plugin reads config from starter via `paths.lua`. Clear separation: plugin = code, starter = data.
