## ADDED Requirements

### Requirement: Pi sync target registration
The system SHALL expose Pi as a first-class AI sync target alongside OpenCode and Claude Code.

#### Scenario: Pi appears in sync status
- **WHEN** the sync target status is requested
- **THEN** the returned status includes a Pi target with its display name, enabled state, and installed state

#### Scenario: Pi can be selected for sync
- **WHEN** the user opens the AI sync selector
- **THEN** Pi is available as a selectable target when the target is enabled

#### Scenario: Sync all includes Pi
- **WHEN** the user runs sync-all
- **THEN** the sync center invokes the Pi config writer as part of the enabled target set

### Requirement: Pi global-only configuration generation
The system SHALL generate and write Pi configuration only under the global `~/.pi/agent` directory for this change.

#### Scenario: Global settings are written
- **WHEN** the user runs `:PiGenerateConfig`
- **THEN** the system writes the generated Pi settings to `~/.pi/agent/settings.json`

#### Scenario: Project Pi config is not written
- **WHEN** the user runs `:PiGenerateConfig` from a repository with a `.pi` directory
- **THEN** the system does not write or modify `.pi/settings.json`

### Requirement: Pi settings template version support
The system SHALL generate Pi settings from the active Pi template version when available and fall back to the legacy root Pi template when no versioned template exists.

#### Scenario: Versioned Pi template exists
- **WHEN** the active Pi template version is `default` and `templates/pi/default.template.jsonc` exists
- **THEN** Pi settings generation uses `templates/pi/default.template.jsonc`

#### Scenario: Versioned Pi template is absent
- **WHEN** no matching `templates/pi/<version>.template.jsonc` exists but `pi.template.jsonc` exists
- **THEN** Pi settings generation uses `pi.template.jsonc` as the legacy fallback

#### Scenario: Template editing opens the source template
- **WHEN** the user runs `:PiEditTemplate`
- **THEN** the system opens the active versioned Pi template if it exists, otherwise the legacy Pi template

### Requirement: Conservative Pi JSON merge
The system SHALL preserve user-owned fields when syncing Pi JSON configuration files.

#### Scenario: Existing user setting is preserved
- **WHEN** `~/.pi/agent/settings.json` contains a user field absent from the Pi template
- **THEN** `:PiGenerateConfig` preserves that field after writing settings

#### Scenario: Mergeable arrays are de-duplicated
- **WHEN** existing settings and template settings both contain `packages`, `skills`, `prompts`, `extensions`, or `themes`
- **THEN** the written settings contain a de-duplicated union for those fields

#### Scenario: Invalid existing JSON is backed up
- **WHEN** an existing target JSON file cannot be parsed
- **THEN** the system backs up the invalid file before writing generated JSON

### Requirement: Pi model generation from Neovim provider registry
The system SHALL generate Pi model configuration from the Neovim AI provider/key/model registry using the Pi models template as a base.

#### Scenario: Configured provider appears in Pi models
- **WHEN** a provider is registered in `ai.providers` and has sufficient endpoint/model metadata
- **THEN** generated Pi `models.json` includes a corresponding provider entry compatible with Pi model configuration

#### Scenario: Pi models preserve base template providers
- **WHEN** `pi/models.template.jsonc` contains a provider that is not generated dynamically
- **THEN** generated Pi `models.json` preserves that provider unless explicitly superseded by generated provider data

#### Scenario: Raw API keys are not written to templates
- **WHEN** Pi model configuration is generated
- **THEN** raw secret API key values are not written into repository templates or generated template files

### Requirement: Pi resource synchronization with manifest tracking
The system SHALL synchronize Pi template-managed resources with a manifest that records output paths and hashes.

#### Scenario: Missing resource is written
- **WHEN** a template-managed Pi resource target does not exist under `~/.pi/agent`
- **THEN** Pi sync writes the target file and records it in `.starter-sync-manifest.json`

#### Scenario: Unmodified managed resource is updated
- **WHEN** a target file hash matches the manifest's last synced hash and the source template changed
- **THEN** Pi sync overwrites the target with the new template content and updates the manifest hash

#### Scenario: User-modified managed resource is backed up
- **WHEN** a target file hash differs from the manifest's last synced hash
- **THEN** Pi sync backs up the target before writing the new template-managed content

### Requirement: Pi local skills avoid package skill duplication
The system SHALL sync only project-owned local Pi skills by default and SHALL NOT copy local duplicates of package-provided superpowers skills.

#### Scenario: OpenSpec local skill is synced
- **WHEN** Pi resource sync runs
- **THEN** the local `pi/skills/openspec` skill is copied to `~/.pi/agent/skills/openspec`

#### Scenario: Superpowers local duplicates are not synced by default
- **WHEN** Pi resource sync runs and local folders such as `pi/skills/test-driven-development` exist
- **THEN** those superpowers-derived folders are not copied to `~/.pi/agent/skills` by default

### Requirement: Pi theme output follows theme name
The system SHALL write Pi theme templates using the theme `name` field as the output filename.

#### Scenario: Flexoki dark theme is written by name
- **WHEN** `pi/theme.template.jsonc` contains `"name": "flexoki-dark"`
- **THEN** Pi sync writes the theme to `~/.pi/agent/themes/flexoki-dark.json`

### Requirement: Pi package declarations without automatic installation
The system SHALL declare required Pi packages in settings and report missing packages without automatically installing them.

#### Scenario: Required packages are declared
- **WHEN** Pi settings are generated
- **THEN** the written settings include required package declarations from the Pi template

#### Scenario: Missing package is reported
- **WHEN** `pi list` does not include a package declared in generated settings
- **THEN** `:PiStatus` reports the package as missing and shows a manual `pi install` hint

#### Scenario: Sync does not install packages
- **WHEN** the user runs `:PiGenerateConfig` or `:AISync`
- **THEN** the system does not execute `pi install` or `pi update`

### Requirement: Pi commands and status reporting
The system SHALL provide user commands for Pi generation, preview, template editing, and status reporting.

#### Scenario: Pi generation command exists
- **WHEN** the AI module is set up
- **THEN** `:PiGenerateConfig` is registered and invokes Pi config writing

#### Scenario: Pi preview command exists
- **WHEN** the AI module is set up
- **THEN** `:PiPreviewConfig` is registered and displays generated Pi configuration without writing it

#### Scenario: Pi status command exists
- **WHEN** the AI module is set up
- **THEN** `:PiStatus` is registered and reports Pi CLI, global config, resource, and package status

### Requirement: Pi health check integration
The system SHALL include Pi in the AI health check surface.

#### Scenario: Pi CLI missing is reported
- **WHEN** `:checkhealth ai` runs and the `pi` executable is not available
- **THEN** the health report warns that Pi CLI is missing and suggests how to install or verify it

#### Scenario: Pi config exists is reported
- **WHEN** `:checkhealth ai` runs and `~/.pi/agent/settings.json` exists
- **THEN** the health report indicates that Pi global settings exist
