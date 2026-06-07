## Why

Pi is already present in this repository as a set of templates and shell scripts, but it is not integrated into the Neovim AI management layer that currently coordinates OpenCode and Claude Code. This creates drift: Pi providers, models, packages, extensions, statusbar, prompts, and local skills must be installed or refreshed outside the normal `:AISync` workflow.

This change makes Pi a first-class Neovim AI sync target while preserving user-owned global Pi configuration and avoiding automatic third-party package installation.

## What Changes

- Add Pi as a sync target alongside OpenCode and Claude Code.
- Add a new `ai.pi` module that generates and syncs global Pi configuration under `~/.pi/agent`.
- Generate Pi `settings.json` using the existing template-version system, with legacy fallback to `pi.template.jsonc`.
- Generate Pi `models.json` from the existing Neovim provider/key/model registry plus the Pi models template as a base.
- Sync Pi-managed resources:
  - keybindings
  - themes
  - extensions, including statusbar
  - prompt templates
  - local project-owned skills
  - global `AGENTS.md`
- Track synced files with a manifest and content hashes instead of relying only on generated-file comments.
- Detect missing Pi packages from `settings.json.packages` and report them, but do not run `pi install` automatically.
- Add Pi commands for generation, preview, template editing, and status reporting.
- Add tests and documentation for the Pi sync target.

## Capabilities

### New Capabilities

- `pi-neovim-ai-sync`: Pi configuration generation, resource synchronization, status reporting, and sync-center integration from the Neovim AI module.

### Modified Capabilities

None. No existing OpenSpec capabilities are present in `openspec/specs/`, and this change introduces a new Pi integration capability rather than changing an existing spec contract.

## Impact

- Affected Lua modules:
  - New `lua/ai/pi.lua`
  - `lua/ai/sync.lua`
  - `lua/ai/init.lua`
  - `lua/ai/health.lua`
  - possibly `lua/ai/template_version.lua` if Pi template defaults need registration/fallback support
- Affected templates and resources:
  - `templates/pi/default.template.jsonc` or legacy `pi.template.jsonc`
  - `pi/models.template.jsonc`
  - `pi/keybindings.template.jsonc`
  - `pi/theme.template.jsonc`
  - `pi/extensions/**`
  - `pi/prompts/**`
  - `pi/skills/openspec/**`
  - `pi/AGENTS.template.md`
- Affected commands:
  - New `:PiGenerateConfig`
  - New `:PiPreviewConfig`
  - New `:PiEditTemplate`
  - New `:PiStatus`
  - Existing `:AISync` includes Pi
- Affected tests:
  - New `tests/ai/pi_spec.lua`
  - Possible updates to sync/init/health tests if present later
- External behavior:
  - Writes only to global `~/.pi/agent`.
  - Does not install or update Pi packages automatically.
  - Does not modify application code or existing OpenCode/Claude Code behavior except adding Pi to sync/status surfaces.
