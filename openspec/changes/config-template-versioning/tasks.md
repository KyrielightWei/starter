## 1. Core Module Setup

- [ ] 1.1 Create `lua/ai/template_version.lua` module with basic structure
- [ ] 1.2 Implement `get_templates_dir()` - returns `~/.config/nvim/templates/`
- [ ] 1.3 Implement `get_tool_templates_dir(tool)` - returns `templates/{tool}/`
- [ ] 1.4 Implement `get_template_path(tool, version)` - returns full path to template file

## 2. State Module Extension

- [ ] 2.1 Add `template_versions` field to State internal state
- [ ] 2.2 Implement `State.get_template_version(tool)` - returns current version (default "default")
- [ ] 2.3 Implement `State.set_template_version(tool, version)` - sets current version
- [ ] 2.4 Add persistence for template versions (save to state file)

## 3. Version Discovery

- [ ] 3.1 Implement `TemplateVersion.list(tool)` - scan directory and return version names
- [ ] 3.2 Implement `TemplateVersion.exists(tool, version)` - check if template file exists
- [ ] 3.3 Add error handling for missing templates directory

## 4. Version CRUD Operations

- [ ] 4.1 Implement `TemplateVersion.create(tool, name, source)` - create new version
- [ ] 4.2 Implement `TemplateVersion.delete(tool, name)` - delete version (with default protection)
- [ ] 4.3 Implement `TemplateVersion.rename(tool, old_name, new_name)` - rename version
- [ ] 4.4 Implement `TemplateVersion.copy(tool, source, target)` - copy version

## 5. Legacy Migration

- [ ] 5.1 Implement `TemplateVersion.check_legacy_template(tool)` - detect legacy file
- [ ] 5.2 Implement `TemplateVersion.migrate_legacy(tool)` - move legacy to default
- [ ] 5.3 Add migration notification to user
- [ ] 5.4 Add migration trigger on first use of version features

## 6. Picker UI Module

- [ ] 6.1 Create `lua/ai/template_picker.lua` module
- [ ] 6.2 Implement `TemplatePicker.open(tool)` - basic FZF picker for versions
- [ ] 6.3 Add preview window showing template content
- [ ] 6.4 Add version metadata display (name, modified time, size)
- [ ] 6.5 Implement picker actions: select, edit, delete, create, copy

## 7. User Commands

- [ ] 7.1 Create `:AITemplateSelect [tool]` command with picker
- [ ] 7.2 Create `:AITemplateList [tool]` command to list versions
- [ ] 7.3 Create `:AITemplateCreate <tool> <name> [source]` command
- [ ] 7.4 Create `:AITemplateDelete <tool> <name>` command
- [ ] 7.5 Create `:AITemplateRename <tool> <old> <new>` command
- [ ] 7.6 Register commands in `lua/ai/init.lua`

## 8. Config Generation Integration

- [ ] 8.1 Modify `opencode.lua` `read_template_config()` to accept version parameter
- [ ] 8.2 Modify `opencode.lua` `generate_config()` to use State.get_template_version()
- [ ] 8.3 Modify `claude_code.lua` to support version selection
- [ ] 8.4 Add version validation before generation (check file exists)
- [ ] 8.5 Add version info header in preview output
- [ ] 8.6 Update `:OpenCodeGenerateConfig [version]` to accept optional version
- [ ] 8.7 Update `:ClaudeCodeGenerateConfig [version]` to accept optional version

## 9. Backup Strategy

- [ ] 9.1 Implement `backup_config(tool)` - backup existing config before generation
- [ ] 9.2 Implement backup rotation (max 2 backups: bak1, bak2)
- [ ] 9.3 Implement `show_overwrite_warning(old_config, new_config)` - display changed fields
- [ ] 9.4 Implement `restore_backup(tool, backup_num)` - restore from backup
- [ ] 9.5 Create `:OpenCodeRestoreBackup [1|2]` command
- [ ] 9.6 Create `:ClaudeCodeRestoreBackup [1|2]` command
- [ ] 9.7 Add backup integration to `generate_config()` flow

## 10. Security Design

- [ ] 10.1 Implement `validate_template_security(content)` - check for sensitive data patterns
- [ ] 10.2 Add warning when template contains potential API key or secret
- [ ] 10.3 Ensure templates use placeholder format for API keys: `{file:${API_KEY_PATH}}`
- [ ] 10.4 Verify API key injection from `ai_keys.lua` during config generation

## 11. Sync Integration

- [ ] 11.1 Update `sync.lua` to respect version selection for each tool
- [ ] 11.2 Add version display in sync preview

## 12. Tests

- [ ] 12.1 Create `tests/ai/template_version_spec.lua` with unit tests
- [ ] 12.2 Test version discovery scenarios
- [ ] 12.3 Test CRUD operations
- [ ] 12.4 Test migration logic
- [ ] 12.5 Test State extension methods
- [ ] 12.6 Test backup strategy
- [ ] 12.7 Test security validation
- [ ] 12.8 Run full test suite and verify all pass