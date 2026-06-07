## 1. Pi Template and Path Foundations

- [x] 1.1 Add `templates/pi/default.template.jsonc` from the current `pi.template.jsonc` or ensure `ai.pi` has a tested fallback to the legacy template
- [x] 1.2 Define Pi global path helpers for `~/.pi/agent`, `settings.json`, `models.json`, `keybindings.json`, `themes/`, `extensions/`, `prompts/`, `skills/`, and `.starter-sync-manifest.json`
- [x] 1.3 Define repository template path helpers for Pi settings, models, keybindings, theme, extensions, prompts, skills, and `AGENTS.template.md`
- [x] 1.4 Add JSONC parsing and formatting helpers by reusing `ai.json_util` rather than duplicating parser logic

## 2. Core `ai.pi` Module

- [x] 2.1 Create `lua/ai/pi.lua` with public functions `generate_settings`, `generate_models`, `write_config`, `preview_config`, `edit_template`, `get_status`, and `check_installation`
- [x] 2.2 Implement active Pi settings template resolution through `ai.template_version` and `ai.state`, with fallback to `pi.template.jsonc`
- [x] 2.3 Implement conservative JSON merge for Pi settings, models, keybindings, and theme targets
- [x] 2.4 Implement de-duplicated union handling for `packages`, `skills`, `prompts`, `extensions`, and `themes`
- [x] 2.5 Implement invalid existing JSON backup before replacement

## 3. Pi Model Generation

- [x] 3.1 Implement Pi model base loading from `pi/models.template.jsonc`
- [x] 3.2 Convert entries from `ai.providers` into Pi-compatible provider/model definitions
- [x] 3.3 Resolve endpoints from provider defaults and `ai.keys` base URL configuration
- [x] 3.4 Ensure generated model config does not write raw API key secrets into repository templates
- [x] 3.5 Preserve base template providers unless a generated provider intentionally supersedes them
- [x] 3.6 Decide and document whether providers without configured keys are omitted or emitted with environment variable placeholders

## 4. Resource Sync Manifest

- [x] 4.1 Implement SHA-256 or stable content hash utility for resource sync
- [x] 4.2 Implement manifest load/save for `~/.pi/agent/.starter-sync-manifest.json`
- [x] 4.3 Implement managed file decision logic for missing, unchanged, changed, and already-current target files
- [x] 4.4 Implement timestamped backups for user-modified managed resources before overwrite
- [x] 4.5 Record source path, target relative path, content hash, and sync timestamp in the manifest

## 5. Pi Resource Synchronization

- [x] 5.1 Sync `pi/AGENTS.template.md` to `~/.pi/agent/AGENTS.md`
- [x] 5.2 Sync single-file extensions from `pi/extensions/*.template.ts` to `~/.pi/agent/extensions/*.ts`
- [x] 5.3 Sync multi-file extensions from `pi/extensions/*/*.template.ts` to corresponding `~/.pi/agent/extensions/*/*.ts`
- [x] 5.4 Sync prompts from `pi/prompts/*.template.md` to `~/.pi/agent/prompts/*.md`
- [x] 5.5 Sync only the project-owned local `pi/skills/openspec/**` skill to `~/.pi/agent/skills/openspec/**`
- [x] 5.6 Do not sync local superpowers-derived folders such as `test-driven-development`, `systematic-debugging`, `using-git-worktrees`, or `verification-before-completion`
- [x] 5.7 Parse `pi/theme.template.jsonc` and write it to `~/.pi/agent/themes/<theme.name>.json`
- [x] 5.8 Sync keybindings from `pi/keybindings.template.jsonc` to `~/.pi/agent/keybindings.json` with conservative JSON handling

## 6. Package Detection and Status

- [x] 6.1 Ensure generated Pi settings include required package declarations from the Pi template
- [x] 6.2 Implement `pi list` parsing when the Pi CLI is available
- [x] 6.3 Report missing packages in `get_status()` without treating them as write failures
- [x] 6.4 Include manual `pi install <package>` hints for missing packages
- [x] 6.5 Ensure no Pi sync path invokes `pi install` or `pi update`

## 7. Commands, Sync, and Health Integration

- [x] 7.1 Register `:PiGenerateConfig` in `lua/ai/init.lua`
- [x] 7.2 Register `:PiPreviewConfig` in `lua/ai/init.lua`
- [x] 7.3 Register `:PiEditTemplate` in `lua/ai/init.lua`
- [x] 7.4 Register `:PiStatus` in `lua/ai/init.lua`
- [x] 7.5 Add Pi to `lua/ai/sync.lua` targets with display name `Pi`
- [x] 7.6 Add Pi checks to `lua/ai/health.lua`
- [x] 7.7 Keep existing OpenCode and Claude Code behavior unchanged except for shared sync/status surfaces

## 8. Preview and User Feedback

- [x] 8.1 Implement `preview_config()` scratch buffer output for generated Pi settings and models
- [x] 8.2 Include resource sync summary in preview without writing files
- [x] 8.3 Include package missing summary in `:PiStatus`
- [x] 8.4 Notify users when backups are created during write
- [x] 8.5 Keep notifications concise and consistent with existing AI module notification style

## 9. Tests

- [x] 9.1 Add `tests/ai/pi_spec.lua`
- [x] 9.2 Test Pi template resolution with versioned template and legacy fallback
- [x] 9.3 Test conservative settings merge preserves user-only fields
- [x] 9.4 Test de-duplicated union merge for packages and resource path arrays
- [x] 9.5 Test generated model config includes provider data from a mocked provider registry
- [x] 9.6 Test raw API key values are not written into generated template outputs
- [x] 9.7 Test invalid existing JSON creates a backup before replacement
- [x] 9.8 Test theme output filename is derived from `theme.name`
- [x] 9.9 Test manifest behavior for missing, unchanged, and user-modified resource targets
- [x] 9.10 Test only `openspec` local skill is selected for sync by default
- [x] 9.11 Test missing Pi CLI status returns structured status instead of failing
- [x] 9.12 Test package detection reports missing packages but does not fail sync

## 10. Documentation and Verification

- [x] 10.1 Update `docs/ai-module.md` with Pi commands and sync target behavior
- [x] 10.2 Update `pi/README.md` to describe Neovim-managed Pi sync and the no-auto-install package policy
- [ ] 10.3 Optionally add `docs/pi-integration.md` if the Pi behavior is too detailed for existing docs
- [x] 10.4 Run `stylua lua/ tests/`
- [x] 10.5 Run `stylua --check lua/ tests/`
- [ ] 10.6 Run `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/ai/pi_spec.lua" -c "q"`
- [x] 10.7 Run `nvim --headless -u tests/minimal_init.lua -c "lua require('ai').setup()" -c "q"`
