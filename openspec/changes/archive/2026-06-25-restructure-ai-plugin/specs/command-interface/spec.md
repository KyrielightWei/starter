## ADDED Requirements

### Requirement: Single registration point
All user commands and keymaps SHALL be registered in exactly one file: `local-plugins/ai/plugin/ai.lua`. No other file SHALL call `nvim_create_user_command` or `vim.keymap.set` for AI functionality.

#### Scenario: Only plugin/ai.lua registers commands
- **WHEN** searching for `nvim_create_user_command` in `local-plugins/ai/lua/`
- **THEN** zero matches SHALL be found (all registrations are in `plugin/ai.lua`)

### Requirement: No duplicate commands
Each command name SHALL be registered exactly once across the entire codebase.

#### Scenario: No duplicate command names
- **WHEN** collecting all registered command names
- **THEN** each name SHALL appear exactly once

### Requirement: High-frequency commands
The following commands SHALL exist with short, memorable names:
- `AISync` — select and sync config to a tool
- `AIKeys` — edit API keys
- `AIProvider` — open Provider Manager
- `AIModel` — switch model (with scope selection)

#### Scenario: AISync works
- **WHEN** user runs `:AISync`
- **THEN** the sync selection UI SHALL open (replacing `AISyncAll` and `AISyncSelect`)

#### Scenario: AIModel replaces AIModelSwitch
- **WHEN** user runs `:AIModel`
- **THEN** the model switch UI SHALL open with current config displayed (replacing `AIModelSwitch`, `AIModelClearTool`, `AIModelShowConfig`)

### Requirement: Tool config commands follow consistent pattern
Each tool (OpenCode, ClaudeCode, Pi) SHALL have exactly these commands: `<Tool>Generate`, `<Tool>Preview`, `<Tool>Edit`, `<Tool>Status`.

#### Scenario: OpenCode commands
- **WHEN** listing OpenCode commands
- **THEN** exactly `OpenCodeGenerate`, `OpenCodePreview`, `OpenCodeEdit`, `OpenCodeStatus` SHALL exist

#### Scenario: ClaudeCode commands
- **WHEN** listing ClaudeCode commands
- **THEN** exactly `ClaudeCodeGenerate`, `ClaudeCodePreview`, `ClaudeCodeEdit`, `ClaudeCodeStatus` SHALL exist

#### Scenario: Pi commands
- **WHEN** listing Pi commands
- **THEN** exactly `PiGenerate`, `PiPreview`, `PiEdit`, `PiStatus` SHALL exist

### Requirement: OpenCodeTheme subcommand
`OpenCodeTheme` SHALL accept a subcommand argument: `generate`, `preview`, or `edit`. This replaces the 4 separate TUI/theme commands.

#### Scenario: OpenCodeTheme generate
- **WHEN** user runs `:OpenCodeTheme generate`
- **THEN** TUI config SHALL be generated (replacing `OpenCodeGenerateTUI`)

#### Scenario: OpenCodeTheme preview
- **WHEN** user runs `:OpenCodeTheme preview`
- **THEN** theme SHALL be previewed (replacing `OpenCodePreviewTheme` and `OpenCodePreviewTUI`)

#### Scenario: OpenCodeTheme edit
- **WHEN** user runs `:OpenCodeTheme edit`
- **THEN** theme template SHALL be opened for editing (replacing `OpenCodeEditTheme`)

### Requirement: ClaudeCodeStatus includes dependency check
`ClaudeCodeStatus` SHALL display installation status, config status, AND dependency check results. This replaces the separate `ClaudeCodeCheckDeps` command.

#### Scenario: ClaudeCodeStatus shows deps
- **WHEN** user runs `:ClaudeCodeStatus`
- **THEN** output SHALL include ECC framework status and missing dependencies (previously only in `ClaudeCodeCheckDeps`)

### Requirement: AI subcommands for low-frequency operations
The `AI` command SHALL support subcommands via `nvim_create_user_command` with `nargs`:
- `AI template list [tool]`
- `AI template select [tool]`
- `AI template create <tool> <name> [source]`
- `AI template delete <tool> <name>`
- `AI template rename <tool> <old> <new>`
- `AI template edit`
- `AI context copy`
- `AI context show`
- `AI prompt edit`
- `AI prompt list`
- `AI watch`
- `AI watch force`
- `AI export`
- `AI backup <tool> [n]`

#### Scenario: AI template list
- **WHEN** user runs `:AI template list opencode`
- **THEN** available template versions for opencode SHALL be listed

#### Scenario: AI context copy
- **WHEN** user runs `:AI context copy`
- **THEN** current buffer context SHALL be copied to clipboard

#### Scenario: AI backup
- **WHEN** user runs `:AI backup opencode 2`
- **THEN** the second most recent OpenCode config backup SHALL be restored

### Requirement: Keymap design
The plugin SHALL register exactly these keymaps under `<leader>k`:
- `<leader>kk` → `AIModel`
- `<leader>ks` → `AISync`
- `<leader>ke` → `AIKeys`
- `<leader>kp` → `AIProvider`
- `<leader>kC` → Commit Picker (existing, flagged for future redesign)
- `<leader>kf` → Next Commit (existing, flagged for future redesign)
- `<leader>kb` → Prev Commit (existing, flagged for future redesign)
- `<leader>kd` → Diff Viewer (existing, flagged for future redesign)

#### Scenario: High-frequency keymaps registered
- **WHEN** Neovim starts and which-key is available
- **THEN** `<leader>k` SHALL show a group "AI Tools" with `kk`, `ks`, `ke`, `kp` entries

### Requirement: Removed commands
The following commands SHALL NOT exist:
- `SkillNew`, `SkillList`, `SkillEdit`, `SkillDelete`, `SkillCopy`, `SkillValidate`, `SkillConvert` (Skill Studio deleted)
- `OpenCodeWriteConfig` (renamed to `OpenCodeGenerate`)
- `OpenCodeGenerateConfig` (renamed to `OpenCodeGenerate`)
- `OpenCodeValidateTemplate` (merged into `OpenCodeGenerate`)
- `OpenCodeRestoreBackup` (replaced by `AI backup opencode`)
- `ClaudeCodeRestoreBackup` (replaced by `AI backup claude`)
- `ClaudeCodeEditSettings` (merged into `ClaudeCodeEdit`)
- `ClaudeCodeEditConfig` (merged into `ClaudeCodeEdit`)
- `ClaudeCodePreviewConfig` (renamed to `ClaudeCodePreview`)
- `ClaudeCodePreviewSettings` (renamed to `ClaudeCodePreview`)
- `ClaudeCodeCheckDeps` (merged into `ClaudeCodeStatus`)
- `ClaudeCodeEditStatusline` (merged into `ClaudeCodeEdit`)
- `OpenCodeGenerateTUI` (replaced by `OpenCodeTheme generate`)
- `OpenCodePreviewTUI` (replaced by `OpenCodeTheme preview`)
- `OpenCodeEditTheme` (replaced by `OpenCodeTheme edit`)
- `OpenCodePreviewTheme` (replaced by `OpenCodeTheme preview`)
- `AIModelSwitch` (renamed to `AIModel`)
- `AIModelClearTool` (merged into `AIModel`)
- `AIModelShowConfig` (merged into `AIModel`)
- `AISyncAll` (merged into `AISync`)
- `AISyncSelect` (merged into `AISync`)
- `AIEditKeys` (merged into `AIKeys`)
- `AIProviderManager` (renamed to `AIProvider`)
- `AICheckProvider` (merged into `AIProvider`)
- `AICheckAllProviders` (merged into `AIProvider`)
- `AIClearDetectionCache` (merged into `AIProvider`)
- `AICopyContext` (replaced by `AI context copy`)
- `AIShowContext` (replaced by `AI context show`)
- `AIEditPrompts` (replaced by `AI prompt edit`)
- `AIListPrompts` (replaced by `AI prompt list`)
- `AIConfigWatch` (replaced by `AI watch`)
- `AIConfigForceSync` (replaced by `AI watch force`)
- `AIExportKeys` (replaced by `AI export`)

#### Scenario: Old commands not found
- **WHEN** Neovim starts
- **THEN** none of the above command names SHALL be registered
