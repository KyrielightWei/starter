# Requirements

## V1 — Bug Fixes + Architecture (CM-01:CM-06)

### Critical Fixes
- [ ] **FIX-01**: Remove dead code in `opencode.lua` lines 453-516. Eliminate non-existent `Ecc.ensure_installed()` call that crashes `:OpenCodeWriteConfig`.
- [ ] **FIX-02**: Make `opencode.lua:write_config()` read `Switcher.get_active("opencode")` and dynamically load the assigned component's config injector instead of hardcoding ECC.
- [ ] **FIX-03**: Make `claude_code.lua:write_settings()` read `Switcher.get_active("claude")` and dynamically load the assigned component.
- [ ] **FIX-04**: Make `Registry.list_outdated()` return correct results by reading version cache from Switcher state.
- [ ] **FIX-05**: Fix ECC uninstaller to only delete ECC-specific subdirectories (`commands/ecc/`, `agents/ecc/`, etc.), not entire `~/.claude/commands/`, `~/.claude/agents/`, etc.

### Cache + Deploy Architecture
- [ ] **ARCH-01**: Create `syncer.lua` — recursive symlink/copy between cache and target tool directories, with copy fallback on symlink failure.
- [ ] **ARCH-02**: Create `manager.lua` — lifecycle manager with `install_to_cache()`, `deploy_to()`, `deploy_all()`, `update_cache()`, `is_cached()`, `cache_version()`, `is_deployed_to()`, `deployment_status()`.
- [ ] **ARCH-03**: ECC installs via `git clone` + `npm install` to cache directory `~/.local/share/nvim/ai_components/cache/ecc/` (not temp dir).
- [ ] **ARCH-04**: GSD installs via `git clone` + `npm install` + `npm run build:hooks` to cache directory `~/.local/share/nvim/ai_components/cache/gsd/` (not just npx execution).
- [ ] **ARCH-05**: ECC deployer creates symlinks from cache to tool directories for: `rules/`, `agents/`, `skills/`, `commands/`, `hooks/`.
- [ ] **ARCH-06**: GSD deployer creates symlinks from cache to tool directories for: `commands/gsd/`, `agents/`, `skills/gsd/`, `hooks/`, `bin/`.
- [ ] **ARCH-07**: Deployment records written to state file: `deployments = { ecc: ["claude"], gsd: ["claude", "opencode"] }`.
- [ ] **ARCH-08**: `update_cache()` re-clones/pulls cache only. Does not touch deployed targets.
- [ ] **ARCH-09**: `deploy_all()` iterates over all tools the component supports and deploys to each.
- [ ] **ARCH-10**: Component interface extended with: `is_cached()`, `get_cache_version()`, `deploy_to(target)`, `undeploy_from(target)`, `is_deployed_to(target)`, `get_deployed_targets()`.

### Progress UI
- [ ] **UI-01**: Single-line component display showing: [Cache Status] [Deploy Status per Tool] [Version] [Actions].
- [ ] **UI-02**: Progress window (floating) showing real-time install/deploy logs with step-by-step indicators.
- [ ] **UI-03**: Header shows current tool assignments: `opencode → GSD | claude → ECC`.
- [ ] **UI-04**: Actions contextually enabled/disabled based on state (e.g., Install disabled if cached, Deploy disabled if not cached).

## V2 — Polish (out of scope for now)
- [ ] `status_panel.lua` — full dashboard UI
- [ ] ccstatusline component migration (Phase 4)
- [ ] `types.lua`, `commands.lua` files
- [ ] Component marketplace / external installation
- [ ] `ecommands.lua` — per-component command registry

### Out of Scope
- Building ECC or GSD themselves — this system manages them, doesn't replace them
- Windows-specific symlink handling — fallback to copy mode
- Real-time network progress bars — step-level progress is sufficient
- ccstatusline migration — defer to after V1 stabilization

---

## Traceability

| Req | Phase | Status | Notes |
|-----|-------|--------|-------|
| FIX-01 | 1 | — | |
| FIX-02 | 1 | — | |
| FIX-03 | 1 | — | |
| FIX-04 | 1 | — | |
| FIX-05 | 1 | — | |
| ARCH-01 | 2 | — | |
| ARCH-02 | 2 | — | |
| ARCH-03 | 2 | — | |
| ARCH-04 | 2 | — | |
| ARCH-05 | 2 | — | |
| ARCH-06 | 2 | — | |
| ARCH-07 | 2 | — | |
| ARCH-08 | 2 | — | |
| ARCH-09 | 2 | — | |
| ARCH-10 | 2 | — | |
| UI-01 | 3 | — | |
| UI-02 | 3 | — | |
| UI-03 | 3 | — | |
| UI-04 | 3 | — | |
