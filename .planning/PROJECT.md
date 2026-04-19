# AI Component Manager

**Type**: Brownfield — extending existing LazyVim AI integration module

**What This Is**: An extensible component management system for AI agent harnesses (Claude Code, OpenCode). Users can install components (ECC, GSD) to local cache, then explicitly deploy them to specific tools. All operations show real-time progress.

**What This Is Not**: A replacement for the underlying components. ECC and GSD are third-party tools. This system manages their lifecycle.

## Core Value
A single Neovim-native UI where users can:
1. **Install** components from network to local cache (one-time download)
2. **Deploy** cached components to specific tools via symlink or copy (fast, explicit control)
3. **Track** versions and update status across cache and all deployed tools
4. **Switch** which component each tool uses (OpenCode → GSD, Claude Code → ECC)

## Key Decisions
| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Two-step install (cache → deploy) | User wants explicit control over every step | Explicit: user caches first, then deploys to selected tools |
| Symlink over copy | Trackable, fast, revertible | Primary: symlink. Fallback: copy if symlink fails |
| fzf-lua for UI | Already in project, good performance | Keep fzf-lua, improve display format |
| Cache at `~/.local/share/nvim/ai_components/cache/` | Standard XDG location, independent of project | Use XDG_DATA_HOME |
| State at `~/.local/state/nvim/ai_component_state.lua` | Standard XDG state location | Already implemented, extend format |

## Target Users
- Developers using multiple AI agent tools (Claude Code + OpenCode) who want:
  - Consistent component management
  - Offline capability after initial cache
  - Fast switching between components per tool
  - Clear visibility into what's installed where

## Context
- Existing LazyVim Neovim configuration with AI module
- 83 Lua files, 6 test files
- ECC component partially migrated, GSD component partially migrated
- Picker UI exists but needs major redesign
- Config generators (`opencode.lua`, `claude_code.lua`) have critical bugs

## Evolution
This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-19 after initialization*
