# Roadmap — AI Component Manager V1

**Granularity**: Standard (5-8 phases, 3-5 plans each)
**Model Profile**: Balanced
**Project Code**: CM

---

## Phase 1: Critical Bug Fixes
**Goal**: Unblock all crash paths and establish working component switching
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04, FIX-05
**Success Criteria**:
1. `:OpenCodeWriteConfig` runs without crashing
2. Switching OpenCode to GSD → restart → GSD commands available
3. Switching Claude Code to ECC → restart → ECC agents available
4. `list_outdated()` returns non-empty when components have updates
5. ECC uninstall does not delete non-ECC content

## Phase 2: Cache + Deploy Infrastructure
**Goal**: Local cache directory + syncer + manager lifecycle
**Requirements**: ARCH-01, ARCH-02, ARCH-07, ARCH-10
**Success Criteria**:
1. Cache directory `~/.local/share/nvim/ai_components/cache/` exists with structure
2. `syncer.symlink_component()` creates working symlinks
3. `manager.install_to_cache("ecc")` downloads to cache
4. `manager.deploy_to("ecc", "claude")` deploys via symlinks
5. State file tracks deployment records

## Phase 3: Component Cache Integrations
**Goal**: Migrate ECC and GSD installers to cache model
**Requirements**: ARCH-03, ARCH-04, ARCH-05, ARCH-06, ARCH-08, ARCH-09
**Success Criteria**:
1. ECC installs to cache first (git clone + npm install to cache dir)
2. GSD installs to cache first (git clone + npm install + build:hooks)
3. ECC deployer creates symlinks for rules/agents/skills/commands/hooks
4. GSD deployer creates symlinks for commands/gsd/agents/skills/gsd/hooks/bin
5. `update_cache()` only touches cache, not deployments

## Phase 4: Progress UI
**Goal**: Real-time progress window + redesigned picker
**Requirements**: UI-01, UI-02, UI-03, UI-04
**Success Criteria**:
1. Picker shows cache status + deploy status per tool in one line
2. Progress window shows step-by-step install/deploy logs
3. Header shows current tool assignments
4. Actions dynamically enabled/disabled based on state

## Phase 5: Integration Verification
**Goal**: End-to-end verification + documentation
**Requirements**: All above
**Success Criteria**:
1. Fresh install → cache ECC → deploy to Claude Code → commands work
2. Cache GSD → deploy to OpenCode → commands work
3. Switch OpenCode to GSD → generate config → OpenCode uses GSD
4. Update cache → redeploy → both tools get new version
5. Health check reports accurate status

---

## Success Summary
| Phase | Goal | Status |
|-------|------|--------|
| 1 | Bug fixes (unblock) | Pending |
| 2 | Cache infrastructure | Pending |
| 3 | Component integrations | Pending |
| 4 | Progress UI | Pending |
| 5 | Verification | Pending |
