## ADDED Requirements

### Requirement: Config generation uses selected version
The system SHALL generate tool configurations based on the currently selected template version.

#### Scenario: Generate OpenCode config with default version
- **WHEN** user calls `:OpenCodeGenerateConfig` and version is "default"
- **THEN** system reads `templates/opencode/default.template.jsonc` and generates config

#### Scenario: Generate OpenCode config with custom version
- **WHEN** user calls `:OpenCodeGenerateConfig` and version is "secure"
- **THEN** system reads `templates/opencode/secure.template.jsonc` and generates config

#### Scenario: Generate Claude Code config with selected version
- **WHEN** user calls `:ClaudeCodeGenerateConfig` and version is "minimal"
- **THEN** system reads `templates/claude_code/minimal.template.jsonc` and generates config

### Requirement: Config generation with explicit version override
The system SHALL allow specifying version directly in generate command.

#### Scenario: Generate with explicit version
- **WHEN** user calls `:OpenCodeGenerateConfig secure`
- **THEN** system uses "secure" version regardless of current selection

#### Scenario: Explicit version does not persist
- **WHEN** user generates with explicit version "quick"
- **THEN** current version selection remains unchanged

### Requirement: Sync respects version selection
The system SHALL use selected versions when syncing multiple tools.

#### Scenario: Sync all tools with their versions
- **WHEN** user calls `:AISyncAll`
- **THEN** each tool uses its currently selected version for config generation

#### Scenario: Sync single tool with its version
- **WHEN** user calls `:AISyncOne opencode`
- **THEN** OpenCode uses its currently selected version

### Requirement: Version validation before generation
The system SHALL validate that selected version template exists before generating.

#### Scenario: Missing template file
- **WHEN** current version is "custom" but file does not exist
- **THEN** system shows error "Template version 'custom' not found" and suggests available versions

#### Scenario: Fallback to default on missing version
- **WHEN** selected version template is missing
- **THEN** system offers option to fallback to "default" version

### Requirement: Generation preview with version
The system SHALL show which version is being used in generation preview.

#### Scenario: Preview shows version info
- **WHEN** user previews generated config
- **THEN** header shows "Generated from version: {version_name}"

#### Scenario: Template path shown in preview
- **WHEN** user previews generated config
- **THEN** preview shows the template file path used

### Requirement: Backward compatibility
The system SHALL maintain backward compatibility with existing usage patterns.

#### Scenario: No version selected uses default
- **WHEN** user has never selected a version
- **THEN** system automatically uses "default" version

#### Scenario: Existing commands work unchanged
- **WHEN** user calls `:OpenCodeGenerateConfig` without arguments
- **THEN** system works exactly as before, using default version

#### Scenario: Legacy template still works if not migrated
- **WHEN** migration has not occurred and legacy template exists
- **THEN** system reads from legacy `opencode.template.jsonc` path

### Requirement: Config backup on overwrite
The system SHALL backup existing config files before generating new config, showing overwrite warnings.

#### Scenario: Backup before generation
- **WHEN** user generates config and existing config file exists
- **THEN** system creates backup at `opencode.json.bak1`

#### Scenario: Max 2 backups retained
- **WHEN** two backups already exist
- **THEN** system rotates backups (bak2 deleted, bak1 becomes bak2, new backup becomes bak1)

#### Scenario: Overwrite warning display
- **WHEN** new config will overwrite fields from existing config
- **THEN** system shows warning listing fields that will change

#### Scenario: Restore from backup
- **WHEN** user calls `:OpenCodeRestoreBackup 1`
- **THEN** system restores config from `opencode.json.bak1`

### Requirement: No sensitive data in templates
The system SHALL NOT store API keys or sensitive data in template files.

#### Scenario: Template without API key
- **WHEN** user edits template file
- **THEN** template contains placeholder `"{file:${API_KEY_PATH}}"` instead of actual API key

#### Scenario: API key injected dynamically
- **WHEN** config is generated from template
- **THEN** system reads API key from `ai_keys.lua` and injects into generated config

#### Scenario: Warning on sensitive data in template
- **WHEN** template contains string matching API key pattern
- **THEN** system shows warning "Template may contain sensitive data"