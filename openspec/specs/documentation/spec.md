# documentation Specification

## Purpose
TBD - created by archiving change restructure-ai-plugin. Update Purpose after archive.
## Requirements
### Requirement: README.md
The plugin SHALL have a `README.md` at `local-plugins/ai/README.md` containing:
- Project overview (1-2 sentences)
- Installation instructions (lazy.nvim `dir` loading)
- Quick start guide (first-time setup)
- Command reference table (all commands grouped by frequency)
- Keymap reference table
- Links to detailed docs

#### Scenario: README structure
- **WHEN** reading `local-plugins/ai/README.md`
- **THEN** it SHALL contain sections: overview, installation, quick start, commands, keymaps, and links to docs

#### Scenario: Command reference table
- **WHEN** reading the commands section
- **THEN** it SHALL list all commands grouped as: high-frequency, tool config (OpenCode/ClaudeCode/Pi), and AI subcommands

### Requirement: vimdoc documentation
The plugin SHALL provide `doc/ai.txt` in vimdoc format, enabling `:help ai`.

#### Scenario: help tag exists
- **WHEN** user runs `:help ai`
- **THEN** vim SHALL open the ai plugin documentation

#### Scenario: vimdoc content
- **WHEN** reading `doc/ai.txt`
- **THEN** it SHALL contain: command reference, keymap reference, setup() options, and configuration overview

### Requirement: Configuration guide
The plugin SHALL provide `doc/configuration.md` covering:
- Provider configuration (how to add/modify providers)
- API key management (auth.json, environment variables)
- Template system (versioned templates, legacy fallback)
- Config hot-reload (config_watcher)

#### Scenario: Configuration guide exists
- **WHEN** reading `doc/configuration.md`
- **THEN** it SHALL contain sections for provider config, API keys, templates, and hot-reload

### Requirement: Template reference
The plugin SHALL provide `doc/templates.md` documenting the structure and fields of each tool's configuration template:
- `settings.json` fields (for Pi)
- `models.json` structure
- `opencode.json` structure (permission, watcher, compaction, provider)
- `claude_code settings.json` structure (permissions, sandbox, env, statusLine)
- `ccstatusline` configuration structure

#### Scenario: Template reference covers all tools
- **WHEN** reading `doc/templates.md`
- **THEN** it SHALL document template structure for OpenCode, Claude Code, and Pi

### Requirement: Architecture doc
The plugin SHALL provide `doc/architecture.md` covering:
- Module dependency graph
- Data flow (provider → key → config → sync)
- How to add a new AI tool
- How to add a new command

#### Scenario: Architecture doc exists
- **WHEN** reading `doc/architecture.md`
- **THEN** it SHALL contain a module dependency diagram and data flow description

