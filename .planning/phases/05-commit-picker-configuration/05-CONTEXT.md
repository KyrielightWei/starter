# Phase 05: Commit Picker Configuration - Context

**Gathered:** 2026-04-26
**Status:** Decisions recorded from discuss-phase, ready for planning

<domain>
## Phase Boundary

Phase 5 adds user-configurable commit picker range settings and base commit boundary control.
Users can:
- Configure how many commits appear in the picker (counting from newest backward)
- Set a base commit as the review boundary to limit displayed commits
- Toggle between scope modes: unpushed / last N / since base

Builds on Phase 4 (commit picker foundation). Phase 6 (diff navigation) depends on Phase 4.
</domain>

<decisions>
## Implementation Decisions (from discuss-phase)

### Configuration UX
- **Config Panel:** Visual settings panel (reuse Provider Manager pattern)
- **Command:** `:AICommitConfig` or nested under picker to access settings

### Storage Format
- **Config File:** New dedicated config file (separate from ai_keys.lua, separate from Provider Manager)
- **Location:** `~/.config/nvim/commit_picker_config.lua` (follow existing Lua config pattern)

### Base Commit Behavior
- **Persistent:** Base commit replaces `origin/HEAD` as default boundary until user changes it
- **Visual:** Base commit shown as a marker in the picker UI

### Scope Presets (D-18 new)
- **Modes:** unpushed / last N / since base — user toggles in picker
- **Persistence:** Selected mode persists across sessions (like base commit)

### Carry-Forward from Phase 4
- D-02 through D-17 from Phase 4 still apply
- Module structure: `lua/commit_picker/` directory
- Error messages in Chinese (bilingual approach)
- Keymap: `<leader>kC` for picker

### Phase 4 Carry-Forward Updates
- D-15 (fallback last 20) → now configurable count, not hardcoded
- D-02 (unpushed default) → now one of three modes, user-selectable
</decisions>

<canonical_refs>
## Canonical References

### Project Standards
- `.planning/ROADMAP.md` — Phase 05 goal, CDRV-03, CDRV-04
- `lua/ai/provider_manager/` — Reference pattern for settings panel
- `lua/ai/provider_manager/config_resolver.lua` — Config persistence pattern

### Code from Phase 4
- `lua/commit_picker/git.lua` — Needs range config injection
- `lua/commit_picker/init.lua` — Needs config loading + mode routing
- `lua/commit_picker/display.lua` — May need base commit visual marker

</canonical_refs>

<specifics>
## Specific Ideas

- Settings panel reuses Provider Manager picker pattern (fzf-lua actions)
- Config schema: `{ mode = "unpushed", count = 20, base_commit = nil }`
- Mode selector: `<leader>kC` opens picker, `<M-c>` opens config (or `:AICommitConfig`)
- Base commit stored as full SHA for stability across rebases
</specifics>

<deferred>
## Deferred Ideas

- Commit search/filtering (future phase)
- Commit message editing (out of scope)
- Interactive rebase integration (future phase)
</deferred>

---

*Phase: 05-commit-picker-configuration*
*Context created: 2026-04-26*
