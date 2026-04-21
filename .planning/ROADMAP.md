# Roadmap: Neovim AI Integration Enhancement

**Created:** 2026-04-21
**Granularity:** Standard (5-8 phases)
**v1 Coverage:** 14/14 requirements mapped

---

## Overview

This roadmap transforms v1 requirements into executable phases. Each phase delivers a coherent, verifiable capability with observable success criteria.

**Core Value:** 让用户能够高效管理多个 AI Provider/Model，并在 GSD 多 commit 工作流中便捷地 Review 历史变更。

**Two Independent Streams:**
- Provider Manager (Phases 1-3): Configuration management and availability detection
- Commit Review (Phases 4-6): Commit picker and diff visualization

---

## Phases

- [ ] **Phase 1: Provider Manager Core UI** - View and manage Provider/Model configurations through visual panel
- [ ] **Phase 2: Provider Manager Detection Commands** - Manual availability testing commands
- [ ] **Phase 3: Provider Manager Auto Detection & Status** - Automatic validation and visual status indicators
- [ ] **Phase 4: Commit Picker Foundation** - Visual commit selection with unpushed default
- [ ] **Phase 5: Commit Picker Configuration** - Customize picker display range and boundaries
- [ ] **Phase 6: Commit Diff Display** - View diffs between selected commits

---

## Phase Details

### Phase 1: Provider Manager Core UI

**Goal:** Users can view and manage Provider/Model configurations through a visual panel

**Depends on:** Nothing (foundation)

**Requirements:** PMGR-01, PMGR-02, PMGR-03, PMGR-04

**Success Criteria** (what must be TRUE):
1. User can open a management panel and see all configured providers with their models listed
2. User can add a new provider/model configuration through the panel interface
3. User can delete an existing provider/model configuration from the panel
4. User can edit provider/model settings (rename, modify endpoint) directly in the panel

**Plans:** TBD

**UI hint:** yes

---

### Phase 2: Provider Manager Detection Commands

**Goal:** Users can manually test Provider/Model availability to validate configurations

**Depends on:** Phase 1

**Requirements:** PMGR-05, PMGR-06

**Success Criteria** (what must be TRUE):
1. User can run a command to test availability of a specific provider/model and see the result
2. User can run a command to test availability of all providers/models at once

**Plans:** TBD

**UI hint:** no

---

### Phase 3: Provider Manager Auto Detection & Status

**Goal:** Users receive automatic availability validation and visual status indicators

**Depends on:** Phase 2

**Requirements:** PMGR-07, PMGR-08

**Success Criteria** (what must be TRUE):
1. When user switches default model, system automatically tests availability before confirming the switch
2. User sees availability status indicators (✓ available, ✗ unavailable, ⏱ timeout, ⚠ error) for each provider/model in displays

**Plans:** TBD

**UI hint:** yes

---

### Phase 4: Commit Picker Foundation

**Goal:** Users can select commits to review from a visual floating picker

**Depends on:** Nothing (independent stream)

**Requirements:** CDRV-01, CDRV-02

**Success Criteria** (what must be TRUE):
1. User can open a floating commit picker window from any Neovim session
2. User sees unpushed commits listed by default when picker opens (origin/HEAD..HEAD)

**Plans:** TBD

**UI hint:** yes

---

### Phase 5: Commit Picker Configuration

**Goal:** Users can customize the commit picker display range and boundaries

**Depends on:** Phase 4

**Requirements:** CDRV-03, CDRV-04

**Success Criteria** (what must be TRUE):
1. User can configure how many commits appear in the picker (counting from newest backward)
2. User can set a base commit as the review boundary to limit displayed commits

**Plans:** TBD

**UI hint:** yes

---

### Phase 6: Commit Diff Display

**Goal:** Users can view diffs between selected commits for review

**Depends on:** Phase 4

**Requirements:** CDRV-05, CDRV-06

**Success Criteria** (what must be TRUE):
1. User can select one commit from picker and view its diff against the previous commit
2. User can select two commits from picker and view the complete diff between them

**Plans:** TBD

**UI hint:** yes

---

## Coverage Validation

| Requirement | Phase | Status |
|-------------|-------|--------|
| PMGR-01 | Phase 1 | Pending |
| PMGR-02 | Phase 1 | Pending |
| PMGR-03 | Phase 1 | Pending |
| PMGR-04 | Phase 1 | Pending |
| PMGR-05 | Phase 2 | Pending |
| PMGR-06 | Phase 2 | Pending |
| PMGR-07 | Phase 3 | Pending |
| PMGR-08 | Phase 3 | Pending |
| CDRV-01 | Phase 4 | Pending |
| CDRV-02 | Phase 4 | Pending |
| CDRV-03 | Phase 5 | Pending |
| CDRV-04 | Phase 5 | Pending |
| CDRV-05 | Phase 6 | Pending |
| CDRV-06 | Phase 6 | Pending |

**Summary:**
- v1 requirements: 14 total
- Mapped to phases: 14 ✓
- Unmapped: 0 ✓
- Orphaned: 0 ✓

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Provider Manager Core UI | 0/3 | Not started | - |
| 2. Provider Manager Detection Commands | 0/2 | Not started | - |
| 3. Provider Manager Auto Detection & Status | 0/2 | Not started | - |
| 4. Commit Picker Foundation | 0/2 | Not started | - |
| 5. Commit Picker Configuration | 0/2 | Not started | - |
| 6. Commit Diff Display | 0/2 | Not started | - |

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