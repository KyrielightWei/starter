# Project Research Summary

**Project:** Neovim AI Integration Enhancement (Provider/Model Management + Commit Diff Review)
**Domain:** LazyVim Plugin Development
**Researched:** 2026-04-21
**Confidence:** HIGH

## Executive Summary

This project enhances an existing LazyVim Neovim AI integration with two new subsystems: an interactive Provider/Model Management system and a Commit Diff Review workflow. The existing codebase (`lua/ai/`) already has well-established patterns—Backend Adapter (strategy), Provider Registry, Key Management, and a Skill Studio subsystem (10 modules) that serves as the primary architectural reference.

Research confirms that **no new heavyweight dependencies are needed**. The recommended approach follows the existing Skill Studio pattern: create `lua/ai/provider_manager/` and `lua/ai/commit_review/` subsystem directories with `init.lua` orchestrators and specialized sub-modules. This ensures consistency, clear boundaries, and zero modifications to existing modules (use extension/delegation instead).

Key risks include **async UI blocking** during availability detection, **API key file format breaking changes** when extending `ai_keys.lua`, and **state subscription memory leaks** in picker lifecycle. These are preventable with established patterns: command-driven detection (not picker-triggered), `pcall` wrappers with schema validation, and `BufWipeout` autocmd cleanup.

## Key Findings

### Recommended Stack

The existing codebase has proven patterns for all required functionality. FZF-lua is preferred over Telescope for picker UI (faster C binary, already integrated in 3 modules). HTTP calls use `curl` via `io.popen` (verified in `fetch_models.lua`). Configuration storage extends `ai_keys.lua` with backward-compatible new sections. Diffview.nvim hooks provide extension points for comment annotations.

**Core technologies:**
- **FZF-lua** (ibhagwan/fzf-lua): Picker UI for management panel & commit selection — sub-500ms startup, built-in `git_commits`, custom previewers, proven pattern in `model_switch.lua`
- **curl/io.popen**: Availability detection API calls — timeout via `--max-time 10s`, synchronous acceptable for manual-triggered detection
- **ai_keys.lua extension**: Provider/Model config + Agent profiles — backward compatible, unified location, uses `dofile()` with `pcall` validation
- **diffview.nvim hooks**: Diff buffer customization — `hooks.diff_buf_read` for comment keymaps, virtual text annotations
- **vim.fn.writefile**: Review summary generation — standard API, Markdown format, path: `.tmp/review_<sha1>_<sha2>_<timestamp>.md`

### Expected Features

Feature research analyzed two domains with clear MVP priorities. Provider/Model Management table stakes (list providers, quick model switching, API key storage) are **already implemented**. Commit Diff Review table stakes (view diff, select commit, navigate hunks) are **available via diffview.nvim**.

**Must have (P1 — MVP):**
- Availability Detection (single provider) — validate default model before use
- Availability Status in Picker — show ✓/✗/⏱ indicators
- Unpushed Commit Picker — select from `origin/HEAD..HEAD`
- Single Commit Diff View — show diff for selected commit
- Commit SHA Display — full SHA in picker

**Should have (P2 — v1.x):**
- Provider/Model CRUD Panel — visual management vs manual editing
- Agent-Model Profiles — different models for planner/coder/reviewer roles
- Commit Range Selection — review multiple commits together
- Review Summary (basic) — auto-generate structured markdown report

**Defer (P3 — v2+):**
- Multi-Provider Model Lists (OpenCode-specific) — needs compatibility verification
- Profile Switching Automation — after Agent-Model profiles stabilize
- Persistent Line Comments — complex line mapping, requires diff buffer integration
- Full Review Summary with threading — includes file list, line numbers, comment threading

### Architecture Approach

Follow the **Skill Studio subsystem pattern** (10-module structure): create directory with `init.lua` orchestrator that handles setup, command registration, and coordinates specialized sub-modules. Each sub-module has single responsibility. Integration with existing modules uses delegation (call existing functions) rather than modification.

**Major components:**

1. **lua/ai/provider_manager/** — Provider/Model Management subsystem
   - `init.lua`: Orchestrator + command registration (`:AIProviderManager`, `:AIAgentConfig`)
   - `registry.lua`: CRUD operations, delegates to `providers.lua`/`keys.lua`
   - `detect.lua`: Availability detection with cache, async HTTP
   - `agent.lua`: Agent-Model assignment configuration
   - `profiles.lua`: Profile management (rename, switch, default)
   - `ui.lua`: FZF-lua picker for management panel
   - `validator.lua`: Input validation for provider/model configs

2. **lua/ai/commit_review/** — Commit Diff Review subsystem
   - `init.lua`: Orchestrator + command registration (`:AICommitReview`, `:AIReviewSummary`)
   - `picker.lua`: FZF-lua commit selector (unpushed commits, range selection)
   - `diff.lua`: Diffview integration for commit diff display
   - `comment.lua`: Persistent comment storage on diff lines
   - `summary.lua`: Markdown review summary file generation
   - `config.lua`: Review settings (commit count, base commit)

3. **Integration points** — Extend without modification
   - `ai/init.lua`: Load subsystems via `pcall(require, "ai.provider_manager")`
   - `plugins/git.lua`: Add keymaps `<leader>gR`, `<leader>gC`, extend diffview hooks

### Critical Pitfalls

Top pitfalls identified from codebase analysis and established patterns:

1. **API Key File Format Breaking Change** — `dofile()` silently fails on syntax errors. Use `pcall(dofile)` with schema validation, add version field, test both old and new formats.
2. **Async UI Blocking** — FZF picker callback blocks on HTTP requests. Never run API checks inside picker. Use command-driven detection (`:AIProviderTest`) with cached status display.
3. **State Subscription Memory Leak** — `State.subscribe()` callbacks never cleaned up. Add `BufWipeout` autocmd to unsubscribe when picker closes, return cleanup function from subscription.
4. **Diffview LSP Conflict** — LSP attaches to diff buffers, causing CPU spike. Set `vim.b[bufnr].lsp_enabled = false` before attach, verify timing.
5. **Git Worktree Path Resolution** — `.git` file parsing has whitespace issues. Trim whitespace: `content:match("gitdir:%s*(%S+)")`, handle relative paths.

## Implications for Roadmap

Based on dependency analysis and existing patterns, suggested phase structure:

### Phase 1: Provider Manager Core (Foundation)
**Rationale:** Foundation layer for all provider-related features. Independent of commit review. Extends existing proven patterns.
**Delivers:** Management panel UI, provider/model CRUD operations, input validation
**Addresses:** Availability Status in Picker (P1), CRUD Panel infrastructure (P2)
**Avoids:** Pitfall #3 (State Subscription Leak) — implement cleanup in picker lifecycle
**Uses:** FZF-lua picker pattern from `model_switch.lua`, `providers.lua` delegation

### Phase 2: Provider Manager Extensions
**Rationale:** Extends Phase 1 foundation. Availability detection requires working registry. Agent config requires profile system.
**Delivers:** Availability detection with cache, Agent-Model configuration profiles
**Addresses:** Availability Detection (P1), Agent-Model Profiles (P2)
**Avoids:** Pitfall #2 (Async UI Blocking) — command-driven detection, not picker-triggered
**Avoids:** Pitfall #1 (API Key Format Breaking) — backward compatible format extension

### Phase 3: Commit Review Core
**Rationale:** Independent of provider manager. Uses existing git/diffview infrastructure. Foundation for comment/summary features.
**Delivers:** Unpushed commit picker, single commit diff view, commit SHA display
**Addresses:** Unpushed Commit Picker (P1), Single Commit Diff View (P1)
**Avoids:** Pitfall #5 (Git Worktree Error) — test in worktree directory
**Uses:** FZF-lua `git_commits` builtin, diffview.nvim integration

### Phase 4: Commit Review Extensions
**Rationale:** Requires working diff view integration. Summary depends on comment accumulation.
**Delivers:** Commit range selection, review summary generation, comment infrastructure
**Addresses:** Commit Range Selection (P2), Review Summary (P2), Comments (P3)
**Avoids:** Pitfall #4 (Diffview LSP Conflict) — disable LSP for diff buffers
**Implements:** Virtual text annotations for comments, Markdown summary format

### Phase 5: Integration & Polish
**Rationale:** Final integration testing, performance optimization, edge case handling.
**Delivers:** Full workflow testing, profile switching automation, OpenCode multi-provider
**Addresses:** Profile Switching (P3), Multi-Provider (P3)
**Avoids:** Pitfall #7 (Multi-Provider Race) — picker close cancels pending requests

### Phase Ordering Rationale

- **Dependency chain:** Provider Manager Core → Extensions → Commit Review → Extensions
- **Independent streams:** Phase 1-2 and Phase 3-4 can potentially parallelize if team available
- **Pitfall timing:** Address state leaks early (Phase 1), async blocking in detection phase (Phase 2), worktree issues in commit picker (Phase 3)
- **MVP scope:** Phases 1-3 cover all P1 features; Phases 4-5 cover P2/P3

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** Availability detection — async patterns, caching strategy, status indicator UX
- **Phase 4:** Comment storage — diff buffer line mapping, virtual text positioning, persistence format
- **Phase 5:** OpenCode multi-provider — verify compatibility, aggregate model lists from multiple endpoints

Phases with standard patterns (skip research-phase):
- **Phase 1:** Well-documented FZF-lua picker pattern, existing `model_switch.lua` reference
- **Phase 3:** Standard git log commands, diffview.nvim has clear documentation

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against existing codebase (`fetch_models.lua`, `keys.lua`, `model_switch.lua`, `git.lua`) |
| Features | HIGH | Direct analysis of competitor plugins (avante.nvim, codecompanion.nvim, diffview.nvim, advanced-git-search) |
| Architecture | HIGH | Based on existing Skill Studio subsystem pattern (10 modules), codebase analysis |
| Pitfalls | HIGH | Derived from codebase analysis and established Neovim plugin development patterns |

**Overall confidence:** HIGH

### Gaps to Address

- **OpenCode multi-provider compatibility:** Not verified if OpenCode supports aggregated model lists from multiple providers. Validate during Phase 5 planning.
- **Comment line mapping complexity:** Diff buffer line → actual file line mapping may have edge cases with file renames, hunks. Test during Phase 4.
- **Profile switching UX:** When should profile auto-switch? On model change? On task detection? Define clear UX during Phase 2 planning.

## Sources

### Primary (HIGH confidence)
- **Existing codebase** — `lua/ai/providers.lua`, `lua/ai/keys.lua`, `lua/ai/model_switch.lua`, `lua/ai/skill_studio/init.lua`, `lua/plugins/git.lua` — verified patterns, working implementations
- **FZF-lua README** — https://github.com/ibhagwan/fzf-lua — git_commits builtin, custom actions, previewers
- **diffview.nvim README** — https://github.com/sindrets/diffview.nvim — hooks, DiffviewFileHistory, buffer lifecycle

### Secondary (HIGH confidence)
- **avante.nvim README** — https://github.com/yetone/avante.nvim — Provider configuration, API key handling, model switching patterns
- **CodeCompanion.nvim README** — https://github.com/olimorris/codecompanion.nvim — Adapter system, ACP support
- **advanced-git-search.nvim README** — https://github.com/aaronhallaert/advanced-git-search.nvim — Commit picker patterns, diff_commit_file

### Tertiary (HIGH confidence)
- **Neovim Lua docs** — https://neovim.io/doc/user/lua.html — io.popen, vim.ui.input, vim.fn.writefile, vim.loop patterns
- **vim-fugitive README** — https://github.com/tpope/vim-fugitive — Git command wrapper patterns

---
*Research completed: 2026-04-21*
*Ready for roadmap: yes*