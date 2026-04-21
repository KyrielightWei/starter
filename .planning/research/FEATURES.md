# Feature Research

**Domain:** Neovim AI Integration Enhancement (Provider Management + Commit Diff Review)
**Researched:** 2026-04-21
**Confidence:** HIGH (Based on direct GitHub README analysis of avante.nvim, codecompanion.nvim, diffview.nvim, fugitive.vim, advanced-git-search.nvim)

## Feature Landscape

### Domain 1: Provider/Model Management

#### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **List all configured providers** | Users need visibility into available options | LOW | Already exists via `providers.lua` registry |
| **List available models per provider** | Standard in all AI plugins (avante, codecompanion) | LOW | Static model lists already defined per provider |
| **Quick model switching** | Users switch models frequently based on task | LOW | Already implemented via `<leader>ks` FZF-lua picker |
| **API key storage** | Required for authentication | LOW | Already implemented in `keys.lua`, stored in `~/.local/state/nvim/ai_keys.lua` |
| **Default provider/model setting** | Plugins need a starting point | LOW | Already in `init.lua` via `State.set()` |
| **Environment variable key fallback** | Common pattern (AVANTE_* prefix in avante.nvim) | LOW | Already supported via `config_resolver.lua` `${env:...}` syntax |

#### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Interactive Provider/Model CRUD Panel** | Visual management vs manual file editing | HIGH | New feature. FZF-lua picker with CRUD actions (view/add/edit/delete) |
| **Availability Detection (Manual)** | Verify provider connectivity before use | MEDIUM | Hand-triggered detection via command. Avoids startup latency from auto-detection |
| **Availability Status Indicators** | Visual feedback (✓/✗/⏱/⚠) in picker | MEDIUM | Depends on availability detection. Shows which providers/models actually work |
| **Agent-Model Configuration Profiles** | Different models for different agent roles (planner, coder, reviewer) | HIGH | Competitive edge. No other plugin offers role-based model assignment |
| **Profile Switching on Default Model Change** | Auto-load matching agent profile | MEDIUM | Enhances workflow consistency. When switching to "coding" model, auto-load coding agent profile |
| **Multi-Provider Model Lists (for OpenCode)** | Aggregate models from multiple providers for tool compatibility | MEDIUM | OpenCode-specific feature. Needs verification of OpenCode's multi-provider support |

#### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Startup Auto-Detection** | Users want instant feedback on availability | Causes massive API calls at Neovim startup (12+ providers). Network latency, rate limits, cold start penalty | Manual command-driven detection (`:AICheckProviders`) |
| **Auto Cost/Speed Optimization** | Smart routing to cheapest/fastest model | Users have different priorities. Auto decisions often wrong. Complex to tune correctly | User-controlled Agent-Model profiles |
| **Dynamic Model Discovery from API** | Always up-to-date model lists | API endpoints vary, rate limits, version inconsistencies. Some providers don't expose model list API | Static curated model lists with manual updates |
| **Global Model for All Agents** | Simpler mental model | Different tasks need different models. Planner needs reasoning, coder needs speed, reviewer needs precision | Agent-Model profile system |

---

### Domain 2: Commit Diff Review

#### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **View commit diff** | Core git workflow functionality | LOW | Diffview.nvim already supports via `:DiffviewFileHistory` |
| **Select commit from list** | Basic interaction pattern | LOW | Need picker for commit selection |
| **Navigate between files in diff** | Reviewing multi-file commits | LOW | Diffview.nvim provides via file panel |
| **Jump between hunks** | Efficient diff navigation | LOW | Vim native `[c` / `]c` supported |
| **Close diff view** | Return to normal workflow | LOW | `:DiffviewClose` / `:tabclose` |

#### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Unpushed Commit Focus** | Review only what needs attention before push | LOW | Default filter to `origin/HEAD..HEAD` range |
| **Commit Range Selection** | Review multiple commits at once | MEDIUM | Select two commits → show combined diff. Useful for GSD multi-commit workflows |
| **Base Commit Boundary Setting** | Define review scope boundaries | MEDIUM | Set "start point" for review sessions (e.g., last pushed commit) |
| **Persistent Line Comments** | Track review notes with file/line context | HIGH | Unique feature. Comments survive diff view close. Stored in review file |
| **Review Summary Generation** | Auto-generate structured markdown report | MEDIUM | Competitive edge. No other Neovim plugin offers this. Includes commit SHAs, files, line numbers, comments |
| **Comment Storage in `.tmp/`** | Non-polluting location for transient review artifacts | LOW | Matches GSD workflow conventions |

#### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Modify Code During Review** | Fix issues while reviewing | Breaks review intent. Should review first, then fix separately. Complexity of partial edits during review session | Pure review mode → separate fix phase |
| **Dynamic Commit Rebase** | Squash/reorder commits during review | Highly destructive. Risk of losing work. Git history complexity. Out of scope for review tool | Use external git tools after review |
| **Commit Comment Synchronization** | Push comments to GitHub/GitLab PRs | Requires API integration per platform. Scope explosion. Different comment formats per platform | Export to markdown, manual paste if needed |
| **AI-Assisted Review Comments** | Auto-generate review suggestions | Adds AI dependency to review workflow. May not match user's review style. Token cost | Manual review with AI as assistant (separate tool) |

---

## Feature Dependencies

```
[Provider/Model CRUD Panel]
    └──requires──> [FZF-lua Picker Infrastructure] (already exists)
    └──requires──> [Provider Registry] (already exists)

[Availability Detection]
    └──requires──> [HTTP/API Client] (needs implementation)
    └──requires──> [API Key Storage] (already exists)

[Availability Status Indicators]
    └──requires──> [Availability Detection]

[Agent-Model Configuration Profiles]
    └──requires──> [Profile Storage Format] (extend ai_keys.lua)
    └──requires──> [Profile Picker UI]
    └──enhances──> [Default Model Switching]

[Commit Diff Review]
    └──requires──> [Diffview.nvim] (already integrated)
    └──requires──> [Commit Picker] (new FZF-lua picker)

[Persistent Line Comments]
    └──requires──> [Comment Storage Format]
    └──requires──> [Diff Buffer Line Detection]
    └──requires──> [Commit SHA Extraction]

[Review Summary Generation]
    └──requires──> [Persistent Line Comments]
    └──requires──> [Markdown Formatter]

[Base Commit Boundary Setting]
    └──enhances──> [Commit Range Selection]
    └──enhances──> [Unpushed Commit Focus]
```

### Dependency Notes

- **Provider/Model CRUD Panel requires FZF-lua**: Project already has fzf-lua integration via `editor.lua` and `model_switch.lua`. Reuse existing patterns.
- **Availability Detection requires HTTP Client**: Need to implement minimal HTTP client (curl-based via `vim.loop` or use plenary's `curl` wrapper).
- **Agent-Model Profiles requires Storage Extension**: Extend existing `ai_keys.lua` format to include `agent_profiles = {}` section.
- **Commit Diff Review requires Diffview.nvim**: Already integrated with worktree support. Reuse existing `:DiffviewOpenEnhanced` command pattern.
- **Persistent Comments requires Line Detection**: Need to map diff buffer lines to actual file lines (handle diff offsets).
- **Review Summary requires Comments**: Can only generate summary after comments are collected.

---

## MVP Definition

### Launch With (v1) — Minimum Viable

**Provider/Model Management:**
- [x] ~~List providers~~ (existing)
- [x] ~~Quick model switching~~ (existing)
- [x] ~~API key storage~~ (existing)
- [ ] **Availability Detection (Single Provider)** — Validate default model before use
- [ ] **Availability Status in Picker** — Show ✓/✗ next to providers/models

**Commit Diff Review:**
- [ ] **Unpushed Commit Picker** — Select from `origin/HEAD..HEAD`
- [ ] **Single Commit Diff View** — Show diff for selected commit
- [ ] **Commit SHA Display** — Show full SHA in picker

### Add After Validation (v1.x)

**Provider/Model Management:**
- [ ] **Provider/Model CRUD Panel** — Trigger: Users report manual editing friction
- [ ] **Availability Detection (All Providers)** — Trigger: Users want full status check
- [ ] **Agent-Model Profiles (Single Profile)** — Trigger: GSD workflow requires role separation

**Commit Diff Review:**
- [ ] **Commit Range Selection** — Trigger: GSD generates multi-commit batches
- [ ] **Base Commit Boundary** — Trigger: Users need scoped review sessions
- [ ] **Review Summary (Basic)** — Trigger: Review tracking becomes manual

### Future Consideration (v2+)

**Provider/Model Management:**
- [ ] **Multi-Provider Model Lists (OpenCode)** — Verify OpenCode compatibility first
- [ ] **Profile Switching Automation** — After Agent-Model profiles are stable
- [ ] **Detection History/Caching** — Avoid re-checking known-good providers

**Commit Diff Review:**
- [ ] **Persistent Line Comments** — Complex line mapping, defer until v1.x validates basic review
- [ ] **Review Summary (Full)** — Includes file list, line numbers, comment threading

---

## Feature Prioritization Matrix

### Provider/Model Management

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| List providers/models | HIGH | LOW (existing) | P1 (done) |
| Quick model switching | HIGH | LOW (existing) | P1 (done) |
| API key storage | HIGH | LOW (existing) | P1 (done) |
| Availability Detection (single) | HIGH | MEDIUM | P1 |
| Availability Status in Picker | HIGH | MEDIUM | P1 |
| CRUD Panel | MEDIUM | HIGH | P2 |
| Agent-Model Profiles | MEDIUM | HIGH | P2 |
| Detection (all providers) | MEDIUM | MEDIUM | P2 |
| Profile Switching Automation | LOW | MEDIUM | P3 |
| Multi-Provider Lists | LOW | MEDIUM | P3 |

### Commit Diff Review

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Unpushed Commit Picker | HIGH | LOW | P1 |
| Single Commit Diff View | HIGH | LOW (reuse diffview) | P1 |
| Commit SHA Display | HIGH | LOW | P1 |
| Commit Range Selection | HIGH | MEDIUM | P2 |
| Base Commit Boundary | MEDIUM | MEDIUM | P2 |
| Review Summary (Basic) | MEDIUM | MEDIUM | P2 |
| Persistent Line Comments | MEDIUM | HIGH | P3 |
| Review Summary (Full) | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch (MVP)
- P2: Should have, add when possible (v1.x)
- P3: Nice to have, future consideration (v2+)

---

## Competitor Feature Analysis

### Provider/Model Management

| Feature | Avante.nvim | CodeCompanion.nvim | Our Approach |
|---------|-------------|--------------------|--------------|
| Provider configuration | Static opts in setup() | Adapters table | Static + dynamic via registry |
| Model switching | `:AvanteSwitchProvider` command | Via chat buffer | FZF-lua picker `<leader>ks` |
| API key storage | Env vars (AVANTE_*) | Env vars / adapter opts | File storage (`ai_keys.lua`) + env fallback |
| Multiple providers simultaneously | Dual boost mode | Multiple adapters | Agent-Model profiles |
| Availability check | None (assumes valid) | None | Manual detection command |
| CRUD UI | None (manual config) | None | Picker-based CRUD panel |

### Commit Diff Review

| Feature | Diffview.nvim | Advanced Git Search | Fugitive.vim | Our Approach |
|---------|---------------|---------------------|--------------|--------------|
| Commit selection | File history panel | Picker with search | `:Git` command | FZF-lua picker for commits |
| Diff viewing | Full diff tabpage | Diff split | `:Gdiffsplit` | Reuse Diffview.nvim |
| Commit range | Via `DiffviewOpen A..B` | Range selection | Manual range args | Picker-based range selection |
| Line comments | None | None | None | Persistent line comments |
| Review summary | None | None | None | Auto-generated markdown |
| Unpushed focus | Manual range args | `changed_on_branch` | Manual | Default unpushed filter |
| Copy commit hash | `<C-y>` in picker | `<C-y>` | Manual | Include in picker actions |

---

## Sources

### Provider/Model Management
- **avante.nvim README** — https://github.com/yetone/avante.nvim (Provider configuration patterns, API key handling, model switching)
- **CodeCompanion.nvim README** — https://github.com/olimorris/codecompanion.nvim (Adapter system, ACP support, MCP integration)
- **Existing codebase** — `lua/ai/providers.lua`, `lua/ai/keys.lua`, `lua/ai/model_switch.lua` (Already implemented features)

### Commit Diff Review
- **diffview.nvim README** — https://github.com/sindrets/diffview.nvim (File history view, diff layouts, hooks system)
- **advanced-git-search.nvim README** — https://github.com/aaronhallaert/advanced-git-search.nvim (Commit picker patterns, diff_commit_file, copy hash/patch)
- **vim-fugitive README** — https://github.com/tpope/vim-fugitive (Git command wrapper, Gdiffsplit, summary window)
- **Existing codebase** — `lua/plugins/git.lua` (Diffview integration, worktree support, git_cmd configuration)

### Confidence Assessment

| Domain | Confidence | Reason |
|--------|------------|--------|
| Provider/Model Management | HIGH | Direct analysis of two major AI plugins (avante, codecompanion) plus existing implementation |
| Commit Diff Review | HIGH | Direct analysis of three major git plugins (diffview, advanced-git-search, fugitive) plus existing diffview integration |
| Anti-Features | HIGH | Derived from explicit PROJECT.md Out of Scope section |

---
*Feature research for: Neovim AI Integration Enhancement*
*Researched: 2026-04-21*