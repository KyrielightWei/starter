## ADDED Requirements

### Requirement: Unified paths module
A module `lua/ai/paths.lua` SHALL provide all path resolution for template and config files. Other modules SHALL NOT call `vim.fn.stdpath("config")` directly for template paths.

#### Scenario: Module exists
- **WHEN** requiring `ai.paths`
- **THEN** it SHALL return a table with functions for resolving all template and resource paths

### Requirement: Configurable template_dir
The `paths.lua` module SHALL accept a `template_dir` configuration option (default: `vim.fn.stdpath("config")`). This determines where template files are read from.

#### Scenario: Default template_dir
- **WHEN** `setup()` is called without `template_dir` option
- **THEN** `template_dir` SHALL default to `vim.fn.stdpath("config")`

#### Scenario: Custom template_dir
- **WHEN** `setup({ template_dir = "/custom/path" })` is called
- **THEN** all path resolution SHALL use `/custom/path` as the base

### Requirement: Path resolution functions
The `paths.lua` module SHALL provide these functions:
- `settings_template(tool)` → path to versioned settings template (e.g., `templates/pi/default.template.jsonc`)
- `legacy_template(tool)` → path to legacy template (e.g., `opencode.template.jsonc`)
- `resource(rel)` → path to resource file in starter root (e.g., `pi/AGENTS.template.md`)
- `config_dir()` → the configured template_dir

#### Scenario: Pi settings template path
- **WHEN** calling `Paths.settings_template("pi")`
- **THEN** it SHALL return `<template_dir>/templates/pi/default.template.jsonc`

#### Scenario: OpenCode legacy template path
- **WHEN** calling `Paths.legacy_template("opencode")`
- **THEN** it SHALL return `<template_dir>/opencode.template.jsonc`

#### Scenario: Pi resource path
- **WHEN** calling `Paths.resource("pi/AGENTS.template.md")`
- **THEN** it SHALL return `<template_dir>/pi/AGENTS.template.md`

### Requirement: Modules use paths.lua
The following modules SHALL use `paths.lua` for all template path resolution instead of local helper functions:
- `ai/pi.lua` (currently 2 `stdpath` calls)
- `ai/opencode.lua` (currently 2 `stdpath` calls)
- `ai/claude_code.lua` (currently 2 `stdpath` calls)
- `ai/template_version.lua` (currently 3 `stdpath` calls)
- `ai/health.lua` (currently 2 `stdpath` calls)
- `ai/config_watcher.lua` (currently 1 `stdpath` call)

#### Scenario: pi.lua uses paths
- **WHEN** `ai/pi.lua` needs to find `pi/AGENTS.template.md`
- **THEN** it SHALL call `Paths.resource("pi/AGENTS.template.md")` instead of building the path locally

#### Scenario: No direct stdpath in modules
- **WHEN** searching for `stdpath("config")` in `local-plugins/ai/lua/ai/` (excluding `paths.lua`)
- **THEN** zero matches SHALL be found

### Requirement: Backward compatibility
The path resolution SHALL produce identical paths to the current implementation when `template_dir` is the default (`vim.fn.stdpath("config")`).

#### Scenario: Default paths match current behavior
- **WHEN** `template_dir` is default
- **THEN** `Paths.settings_template("pi")` SHALL return the same path as the current `template_version_path()` in `pi.lua`
- **AND** `Paths.legacy_template("opencode")` SHALL return the same path as the current `get_opencode_template_path()` in `opencode.lua`
- **AND** `Paths.legacy_template("claude_code")` SHALL return the same path as the current `get_template_path()` in `claude_code.lua`
