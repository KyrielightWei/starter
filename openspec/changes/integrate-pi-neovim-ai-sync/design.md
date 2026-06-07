## Context

The repository is a LazyVim/Neovim configuration with an `lua/ai/` layer that already coordinates OpenCode and Claude Code. Current AI tool sync is centered in `lua/ai/sync.lua`; tool-specific generators live in `lua/ai/opencode.lua` and `lua/ai/claude_code.lua`; provider/key/model data flows through `lua/ai/providers.lua`, `lua/ai/keys.lua`, and `lua/ai/provider_manager/registry.lua`.

Pi is already represented by templates and scripts:

- `pi.template.jsonc`
- `pi/models.template.jsonc`
- `pi/keybindings.template.jsonc`
- `pi/theme.template.jsonc`
- `pi/extensions/**`
- `pi/prompts/**`
- `pi/skills/openspec/**`
- `scripts/install-pi-dev.sh`

However, Pi is not a first-class target in the Neovim AI module. The shell installer can copy templates and install packages, but it sits outside the normal sync, preview, status, template-version, provider, and health-check surfaces.

The design constraints are:

- Pi sync writes only to global `~/.pi/agent`.
- Sync must be conservative and preserve user-owned global Pi fields where possible.
- Sync must not execute `pi install` or `pi update` automatically.
- Pi packages such as `git:github.com/obra/superpowers` and `npm:@fission-ai/openspec` are trusted as package declarations but still require explicit user installation.
- Local duplicate copies of superpowers skills should not shadow package-provided skills.

## Goals / Non-Goals

**Goals:**

- Add Pi as a first-class `:AISync` target.
- Provide Pi-specific commands for generation, preview, template editing, and status.
- Generate Pi settings through the existing template-version direction, with legacy fallback.
- Generate Pi models from the existing Neovim provider/key/model system, not only from a static template.
- Sync Pi extensions, statusbar, prompts, theme, keybindings, local OpenSpec skill, and `AGENTS.md` into `~/.pi/agent`.
- Use manifest/hash tracking for resource files so user edits and template-managed files can be distinguished.
- Report missing packages without installing them.
- Add tests and docs.

**Non-Goals:**

- Do not implement Component Manager 2.0.
- Do not implement cross-tool superpowers/OpenSpec distribution beyond Pi target sync.
- Do not install, update, or remove Pi packages automatically.
- Do not alter OpenCode or Claude Code sync behavior except for shared sync UI/status additions.
- Do not write secrets or raw API keys into Pi templates.
- Do not sync project-local `.pi` configuration in this change.

## Decisions

### Decision 1: Add `lua/ai/pi.lua` as a full tool adapter

Create a new module shaped like the existing OpenCode and Claude Code adapters. Public functions:

- `generate_settings(opts)`
- `generate_models(opts)`
- `write_config(opts)`
- `preview_config(opts)`
- `edit_template(opts)`
- `get_status()`
- `check_installation()`

Rationale: Pi has enough tool-specific behavior that adding ad hoc logic to `sync.lua` would make the sync center too large. A dedicated adapter keeps Pi file layout, package checks, manifest tracking, and provider-to-model conversion isolated.

Alternative considered: reuse `scripts/install-pi-dev.sh` from Neovim commands. Rejected because the script performs installation-oriented work and does not integrate with Provider Manager, TemplateVersion, status, preview, or tests.

### Decision 2: Use TemplateVersion for Pi settings, with legacy fallback

Pi settings generation should first look for:

```text
templates/pi/<version>.template.jsonc
```

The active version comes from `State.get_template_version("pi")`, defaulting to `default`. If no versioned Pi template exists, fallback to the existing root-level `pi.template.jsonc`.

Rationale: the repository already has an active template-version architecture for OpenCode and Claude Code. Pi should join that architecture instead of creating a second template convention.

Alternative considered: always read `pi.template.jsonc`. Rejected because it would diverge from the ongoing config-template-versioning direction.

### Decision 3: Generate Pi models from Neovim providers plus Pi template base

`pi/models.template.jsonc` remains the base model config, but `ai.pi.generate_models()` should also include provider definitions derived from:

- `Providers.list()` / `Providers.get()`
- `Keys.get_key()` and `Keys.get_base_url()`
- `provider_manager.registry` global/tool defaults where needed

The generated Pi model provider entries must use environment variable references or non-secret references when possible. Raw keys must not be copied into templates. If a provider has no configured key, it can remain absent or be present with an environment-variable key name depending on the provider definition; tests should define the exact behavior.

Rationale: Pi becomes part of the same AI management system only if it reflects the same configured providers and defaults.

Alternative considered: copy `pi/models.template.jsonc` only. Rejected because it would leave Pi statically configured and prone to drift from OpenCode/Claude defaults.

### Decision 4: JSON merge is conservative and field-aware

For JSON targets:

- `settings.json`
- `models.json`
- `keybindings.json`
- theme JSON

The writer should parse existing JSON, parse template JSONC, and merge conservatively:

- nested objects merge recursively
- user-only fields are preserved
- array fields `packages`, `skills`, `prompts`, `extensions`, and `themes` are de-duplicated unions
- non-merge arrays default to template behavior unless tests specify otherwise
- invalid existing JSON is backed up before writing generated content

Rationale: users may edit global Pi config outside Neovim. Sync must not unnecessarily erase user fields.

Alternative considered: template overwrites everything. Rejected as too destructive for global `~/.pi/agent`.

### Decision 5: Resource file sync uses a manifest and content hashes

Resource sync should write a manifest at:

```text
~/.pi/agent/.starter-sync-manifest.json
```

The manifest records each template-managed output path, source path, and last synced hash. Sync behavior:

```text
missing target                  → write
same target hash as manifest    → safe overwrite
changed target hash             → backup target, then write
same content as new source      → update manifest, no backup
```

The implementation may also add generated comments to `.ts` and `.md` outputs for human clarity, but comments are not the primary source of truth.

Rationale: a manifest lets the sync process distinguish user edits from previously generated files even across multi-file extensions.

Alternative considered: generated-file comments only. Rejected because comments are unreliable for JSON, existing files, and changed generated files.

### Decision 6: Only sync project-owned local skills by default

The Pi resource sync should copy `pi/skills/openspec/**` as the local project-owned skill. It must not copy local duplicates of superpowers skills by default because those skills are provided by the `git:github.com/obra/superpowers` package declared in Pi settings.

Rationale: duplicate local skill copies can shadow package skills, create name collisions, and drift from upstream.

Alternative considered: copy every folder under `pi/skills`. Rejected because the repository currently includes local superpowers-like copies that should be package-provided in Pi.

### Decision 7: Theme output filename is derived from `theme.name`

When syncing `pi/theme.template.jsonc`, parse the template and write:

```text
~/.pi/agent/themes/<theme.name>.json
```

For the current template, that means:

```text
~/.pi/agent/themes/flexoki-dark.json
```

Rationale: Pi settings select themes by name. Writing to a mismatched filename such as `kanagawa.json` while the theme name is `flexoki-dark` is confusing and can break discovery.

### Decision 8: Missing packages are status warnings, not sync failures

`write_config()` ensures `settings.json.packages` contains required package declarations. `get_status()` may run `pi list` when the CLI exists and report missing packages. Missing packages should not make config generation fail.

Rationale: package installation executes external commands and may perform network and dependency operations. The user explicitly chose not to run package installation from Neovim sync.

### Decision 9: Commands and sync integration mirror existing tool patterns

Add commands in `lua/ai/init.lua`:

- `:PiGenerateConfig`
- `:PiPreviewConfig`
- `:PiEditTemplate`
- `:PiStatus`

Register Pi in `lua/ai/sync.lua`:

```lua
pi = {
  name = "Pi",
  enabled = true,
  sync = function()
    return require("ai.pi").write_config()
  end,
  check = function()
    return vim.fn.executable("pi") == 1
  end,
}
```

Rationale: users already use `:AISync` and `<leader>kS` to coordinate tool config. Pi should appear in the same selector and summary.

## Risks / Trade-offs

- Provider schema mismatch between Neovim providers and Pi `models.json` → Add focused tests for generated provider shape and keep `pi/models.template.jsonc` as a safe base.
- User edits to generated resource files get overwritten after backup → Use manifest hashes and clear notifications with backup paths.
- Missing packages make synced Pi unusable for some commands → Report explicit `pi install <package>` hints in `:PiStatus` and health checks.
- Existing local superpowers skill copies remain in the repo and confuse future maintainers → Document that Pi sync only copies `openspec` and package-provided skills remain package-provided.
- TemplateVersion active change may not be fully archived yet → Implement Pi fallback to legacy `pi.template.jsonc` so this change can work before or after template-versioning is completed.
- Global-only sync may not cover project-specific Pi workflows → Explicitly leave `.pi` project sync for a later change.

## Migration Plan

1. Add `templates/pi/default.template.jsonc` from the current `pi.template.jsonc` or use fallback if the template-version directory is absent.
2. Implement `ai.pi` and sync commands.
3. First `:PiGenerateConfig` creates required global directories and writes/merges files under `~/.pi/agent`.
4. Existing conflicting resource files are backed up before template-managed files are written.
5. `:PiStatus` reports missing packages and manual install commands.

Rollback strategy:

- JSON files with invalid or conflicting existing content are backed up with timestamped backups before replacement.
- Resource files that were changed from the last manifest hash are backed up before replacement.
- Users can remove generated files under `~/.pi/agent` or restore timestamped backups manually.

## Open Questions

None for the first implementation pass. This change uses the global provider registry for Pi model generation, emits provider API key environment-variable names instead of raw secrets, and makes `:PiPreviewConfig` show a JSON summary containing settings, models, resources, and missing packages.
