# plugin-structure Specification

## Purpose
TBD - created by archiving change restructure-ai-plugin. Update Purpose after archive.
## Requirements
### Requirement: Plugin directory structure
The AI module SHALL be located at `local-plugins/ai/` with standard Neovim plugin layout: `plugin/`, `lua/`, `doc/`, `tests/`.

#### Scenario: Directory layout
- **WHEN** inspecting the `local-plugins/ai/` directory
- **THEN** it SHALL contain `plugin/ai.lua`, `lua/ai/`, `lua/commit_picker/`, `tests/`, `doc/`, and `README.md`

### Requirement: lazy.nvim loading
The starter config SHALL load the plugin via lazy.nvim `dir` option pointing to `local-plugins/ai/`. The plugin SHALL load eagerly (`lazy = false`) so commands and keymaps are immediately available.

#### Scenario: Plugin loads on startup
- **WHEN** Neovim starts with the starter config
- **THEN** `plugin/ai.lua` SHALL be auto-sourced and all AI commands SHALL be available without manual loading

#### Scenario: lazy spec structure
- **WHEN** reading `lua/plugins/ai.lua`
- **THEN** it SHALL return a lazy.nvim spec with `dir` pointing to `local-plugins/ai/`, `name = "ai-tools"`, `lazy = false`, and `dependencies = { "nvim-lua/plenary.nvim" }`

### Requirement: Commit Picker bundled in plugin
The `commit_picker/` module SHALL be located at `local-plugins/ai/lua/commit_picker/` and loaded as part of the plugin.

#### Scenario: Commit Picker require path unchanged
- **WHEN** code calls `require("commit_picker.init")`
- **THEN** the module SHALL resolve correctly via the plugin's runtimepath entry

### Requirement: Skill Studio removed
The `skill_studio/` module SHALL NOT exist in the plugin. All `Skill*` commands SHALL be removed.

#### Scenario: No skill_studio directory
- **WHEN** inspecting `local-plugins/ai/lua/ai/`
- **THEN** there SHALL be no `skill_studio/` directory

#### Scenario: Skill commands not registered
- **WHEN** Neovim starts
- **THEN** `SkillNew`, `SkillList`, `SkillEdit`, `SkillDelete`, `SkillCopy`, `SkillValidate`, `SkillConvert` SHALL NOT be registered

### Requirement: Terminal stays in starter
The `lua/plugins/terminal.lua` file SHALL remain in the starter config. It SHALL call `require("ai.terminal")` and `require("ai.terminal_picker")` from the plugin.

#### Scenario: Terminal commands work after extraction
- **WHEN** user runs `:TermSelect`
- **THEN** the terminal picker from `local-plugins/ai/lua/ai/terminal_picker.lua` SHALL open

### Requirement: Template data stays in starter
Template files (`templates/`, `pi/`, `*.template.jsonc`) SHALL remain in the starter repo root. The plugin SHALL read them via configurable paths, not bundle them.

#### Scenario: Templates not in plugin directory
- **WHEN** inspecting `local-plugins/ai/`
- **THEN** there SHALL be no `templates/`, `pi/`, or `*.template.jsonc` files

### Requirement: tests moved into plugin
Tests SHALL be located at `local-plugins/ai/tests/` with subdirectories `ai/` and `commit_picker/`.

#### Scenario: Test files in plugin
- **WHEN** inspecting `local-plugins/ai/tests/`
- **THEN** it SHALL contain `ai/` and `commit_picker/` test directories with all existing test files

### Requirement: plugins/opencode.lua deleted
The file `lua/plugins/opencode.lua` SHALL be deleted. All its commands SHALL be registered in `plugin/ai.lua` instead.

#### Scenario: No duplicate opencode plugin file
- **WHEN** inspecting `lua/plugins/`
- **THEN** `opencode.lua` SHALL NOT exist

