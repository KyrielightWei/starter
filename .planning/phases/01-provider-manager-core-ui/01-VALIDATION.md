---
phase: 01
slug: provider-manager-core-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-04-22"
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | plenary.nvim (Neovim Lua test) |
| **Config file** | `tests/minimal_init.lua` (existing) |
| **Quick run command** | `nvim --headless -c "PlenaryBustedFile tests/ai/provider_manager/registry_spec.lua" -c "q"` |
| **Full suite command** | `nvim --headless -c "PlenaryBustedDirectory tests/ai/provider_manager/" -c "q"` |
| **Estimated runtime** | ~5-10 seconds |

---

## Sampling Rate

- **After every task commit:** Run unit test for affected module
- **After every plan wave:** Run full `tests/ai/provider_manager/` suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | PMGR-01 | — | N/A (view only) | unit | `PlenaryBustedFile tests/ai/provider_manager/registry_spec.lua::list_providers` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | PMGR-02 | T-01-01 | Input validation before add | unit | `PlenaryBustedFile tests/ai/provider_manager/validator_spec.lua` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | PMGR-03 | T-01-02 | Confirmation before delete | unit | `PlenaryBustedFile tests/ai/provider_manager/registry_spec.lua::delete_provider` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | PMGR-04 | — | N/A (file edit) | manual | Open picker, Ctrl-E, verify file opens | N/A | ⬜ pending |
| 01-03-01 | 03 | 2 | PMGR-08 | — | N/A (keymap/command) | manual | Press `<leader>kp`, run `:AIProviderManager` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/ai/provider_manager/init.lua` — test harness setup
- [ ] `tests/ai/provider_manager/registry_spec.lua` — stubs for PMGR-01, PMGR-02, PMGR-03
- [ ] `tests/ai/provider_manager/validator_spec.lua` — stubs for input validation
- [ ] `tests/ai/provider_manager/picker_spec.lua` — stubs for picker actions (mock fzf-lua)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Picker opens with provider list | PMGR-01 | FZF-lua is UI, headless tests don't render | Press `<leader>kp`, verify picker shows providers |
| Ctrl-E opens providers.lua at correct line | PMGR-04 | File navigation requires interactive Neovim | Select provider, Ctrl-E, verify file/line |
| Help window displays keybindings | UI-SPEC | Floating window UI, headless doesn't render | Press Ctrl-/ in picker, verify help appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending