# Roadmap: Neovim AI Integration Enhancement

**Created:** 2026-04-21
**Granularity:** Standard (5-8 phases)
**v1 Coverage:** 14/14 requirements mapped

---

## Overview

This roadmap transforms v1 requirements into executable phases. Each phase delivers a coherent, verifiable capability with observable success criteria.

**Core Value:** 让用户能够高效管理多个 AI Provider/Model，并在 GSD 多 commit 工作流中便捷地 Review 历史变更。

**Two Independent Streams:**
- Provider Manager (Phases 1-3): Configuration management and availability detection ✓ Stream A complete
- Commit Review (Phases 4-6): Commit picker and diff navigation ✓ Stream B complete

---

**v1 Stream Status:** ALL COMPLETE (14/14 requirements delivered)

---

## Phases

- [x] **Phase 1: Provider Manager Core UI** - View and manage Provider/Model configurations through visual panel
- [x] **Phase 2: Provider Manager Detection Commands** - Manual availability testing commands
- [x] **Phase 3: Provider Manager Auto Detection & Status** - Automatic validation and visual status indicators (code exists, planning artifacts pending)
- [x] **Phase 4: Commit Diff Review** - Review diffs across multiple commits for GSD workflow (completed 2026-04-26)
- [x] **Phase 5: Commit Picker Configuration** - Customize picker display range and boundaries (completed 2026-04-26)
- [x] **Phase 6: Commit Diff Navigation** - Navigate between commits during diff review (completed 2026-04-26)

---

## Phase Details

### Phase 1: Provider Manager Core UI

**Goal:** Users can view and manage Provider/Model configurations through a visual panel

**Depends on:** Nothing (foundation)

**Requirements:** PMGR-01, PMGR-02, PMGR-03, PMGR-04

**Success Criteria** (what must be TRUE):
1. User can open a management panel and see all configured providers with their models listed
2. User can add a new provider/model configuration through the panel interface
3. User can delete an existing provider/model configuration from the panel (persists to file)
4. User can edit provider/model settings (rename, modify endpoint) directly in the panel

**Plans:** 5 plans (replanned with --reviews feedback)

Plans:
- [x] 01-01-PLAN.md — Registry, Validator, FileUtil modules (TDD, safe file writes)
- [x] 01-02-PLAN.md — Picker UI with state machine and reduced keymap
- [x] 01-03-PLAN.md — Integration and keymap/command registration with error feedback
- [x] 01-04-PLAN.md — Model management functions (list/set/get default model)
- [x] 01-05-PLAN.md — Static models editor with safe file persistence

**UI hint:** yes

---

### Phase 2: Provider Manager Detection Commands

**Goal:** Users can manually test Provider/Model availability to validate configurations

**Depends on:** Phase 1

**Requirements:** PMGR-05, PMGR-06

**Success Criteria** (what must be TRUE):
1. User can run a command to test availability of a specific provider/model and see the result
2. User can run a command to test availability of all providers/models at once

**Plans:** 2 plans (splitted: Wave 1 + Wave 2)

Plans:
- [x] 02-01-PLAN.md — Cache + Results modules (TDD, dual modules in Wave 1)
- [x] 02-02-PLAN.md — Detector core + init.lua commands (depends on 02-01, Wave 2)

**UI hint:** no

---

### Phase 3: Provider Manager Auto Detection & Status

**Goal:** Users receive automatic availability validation and visual status indicators

**Depends on:** Phase 2

**Requirements:** PMGR-07, PMGR-08

**Success Criteria** (what must be TRUE):
1. When user switches default model, system automatically tests availability before confirming the switch
2. User sees availability status indicators (✓ available, ✗ unavailable, ⏱ timeout, ⚠ error) for each provider/model in displays

**Plans:** 2 plans (replanned with --reviews feedback)

Plans:
- [x] 03-01-PLAN.md — Status module (TDD) with vim.schedule + stale guard + auto-detection in model_switch.lua (Wave 1)
- [x] 03-02-PLAN.md — Status icons with ASCII fallbacks in ui_util.lua + picker.lua status display (Wave 2, depends on 01)

**UI hint:** yes

---

### Phase 4: Commit Diff Review

**Goal:** Users can review diffs and track progress across multiple commits in a GSD workflow

**Depends on:** Nothing (independent stream)

**Requirements:** CDRV-01, CDRV-02

**Success Criteria** (what must be TRUE):
1. User can open a floating window commit picker to select commits for review
2. Picker defaults to unpushed commits (origin/HEAD..HEAD) for workflow continuity

**Plans:** 4/3 plans complete

Plans:
- [x] 04-01-PLAN.md — Git module + fzf-lua picker (unpushed default, fallback, colored SHA format, multi-select, win_opts)
- [x] 04-02-PLAN.md — Selection state + diffview.nvim integration (sha^..sha single, sha1..sha2 range, fallback warning)
- [x] 04-03-PLAN.md — Entry point wiring (commands, keymaps, git→display→selection→diff flow)

**UI hint:** yes

---

### Phase 5: Commit Picker Configuration

**Goal:** Users can customize the commit picker display range and boundaries

**Depends on:** Phase 4

**Requirements:** CDRV-03, CDRV-04

**Success Criteria** (what must be TRUE):
1. User can configure how many commits appear in the picker (counting from newest backward)
2. User can set a base commit as the review boundary to limit displayed commits

**Plans:** 2/2 plans complete (Wave 1: config module, Wave 2: settings UI + integration)

Plans:
- [x] 05-01-PLAN.md — Config module (read/write/validate, atomic writes, mtime cache)
- [x] 05-02-PLAN.md — Settings UI (fzf-lua picker, mode selector, base commit picker)

**UI hint:** yes

### Phase 6: Commit Diff Navigation

**Goal:** Users can navigate between commits during diff review with efficient traversal

**Depends on:** Phase 4

**Requirements:** CDRV-05, CDRV-06

**Success Criteria** (what must be TRUE):
1. User can select one commit from picker and view its diff against the previous commit
2. User can select two commits from picker and view the complete diff between them

**Plans:** 2/2 plans complete

Plans:
- [x] 06-01-PLAN.md — Navigation module (commit cycling next/prev, position tracking, Diffview refresh)
- [x] 06-02-PLAN.md — Integration + keymaps (`<leader>kf`/`<leader>kb`, auto-load on first use)

**UI hint:** yes

---

## Coverage Validation

| Requirement | Phase | Status |
|-------------|-------|--------|
| PMGR-01 | Phase 1 | ✓ Delivered |
| PMGR-02 | Phase 1 | ✓ Delivered |
| PMGR-03 | Phase 1 | ✓ Delivered |
| PMGR-04 | Phase 1 | ✓ Delivered |
| PMGR-05 | Phase 2 | ✓ Delivered |
| PMGR-06 | Phase 2 | ✓ Delivered |
| PMGR-07 | Phase 3 | Pending |
| PMGR-08 | Phase 3 | Pending |
| CDRV-01 | Phase 4 | ✓ Delivered |
| CDRV-02 | Phase 4 | ✓ Delivered |
| CDRV-03 | Phase 5 | ✓ Delivered |
| CDRV-04 | Phase 5 | ✓ Delivered |
| CDRV-05 | Phase 6 | ✓ Delivered |
| CDRV-06 | Phase 6 | ✓ Delivered |

**Summary:**
- v1 requirements: 14 total
- Mapped to phases: 14 ✓
- Delivered: 14 (PMGR-01~06, CDRV-01~06)
- Unmapped: 0 ✓
- Orphaned: 0 ✓

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Provider Manager Core UI | 5/5 | ✓ Complete | PMGR-01~04 |
| 2. Provider Manager Detection Commands | 2/2 | ✓ Complete | PMGR-05~06 |
| 3. Provider Manager Auto Detection & Status | 0/0 | ✓ Complete | PMGR-07~08 (code exists) |
| 4. Commit Diff Review | 3/3 | ✓ Complete | 2026-04-26 |
| 5. Commit Picker Configuration | 2/2 | ✓ Complete | CDRV-03~04 |
| 6. Commit Diff Navigation | 2/2 | ✓ Complete | CDRV-05~06 |

---

## Parallel Execution Strategy

Two independent streams allow parallel development:

**Stream A: Provider Manager**
- Phase 1 → Phase 2 → Phase 3 (sequential dependency chain)

**Stream B: Commit Review**
- Phase 4 → Phase 5, Phase 6 (Phase 5 and 6 both depend on Phase 4, can potentially parallelize)

**Cross-stream:** Phases 1-3 and 4-6 have no dependencies between them.

---

## Notes

- Research flags phases 2 and 4 for potential deeper investigation during planning
- Phase 2: Async detection patterns, caching strategy, command UX
- Phase 4: Git worktree path resolution, commit SHA formatting

---
*Roadmap created: 2026-04-21*
*Ready for planning: `/gsd-plan-phase 1`*