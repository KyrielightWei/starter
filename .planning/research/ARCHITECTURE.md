# Architecture Research: Provider/Model Management & Commit Diff Review Integration

**Domain:** LazyVim Neovim AI Integration Enhancement
**Researched:** 2026-04-21
**Confidence:** HIGH (Based on direct codebase analysis)

## Executive Summary

This research analyzes how to integrate two new subsystems—**Provider/Model Management (PMGR)** and **Commit Diff Review (CDRV)**—into the existing `lua/ai/` module architecture. The existing architecture uses established patterns: Backend Adapter (strategy), Provider Registry (simple module), Key Management (CRUD), Config Resolver (multi-layer merge), and Skill Studio (10-module subsystem). 

**Key Recommendation:** Follow the **Skill Studio subsystem pattern** for both new features. Create `lua/ai/provider_manager/` and `lua/ai/commit_review/` directories with `init.lua` orchestrators and specialized sub-modules. This ensures consistency with the existing codebase and provides clear module boundaries.

## Existing Architecture Patterns

### Pattern Inventory (from codebase analysis)

| Pattern | Location | Purpose | Reusability |
|---------|----------|---------|-------------|
| **Backend Adapter** | `init.lua`, `*_adapter.lua` | Strategy pattern for AI backend switching | Use for unified command/keymap registration |
| **Provider Registry** | `providers.lua` | Simple module with `register()`, `list()`, `get()` | Extend for dynamic provider/model CRUD |
| **Key Management** | `keys.lua` | CRUD on `~/.local/state/nvim/ai_keys.lua` | Extend for agent-model config storage |
| **Config Resolver** | `config_resolver.lua` | 4-layer merge with `${ref:...}` resolution | Reuse for config hot-reload triggers |
| **Model Switch** | `model_switch.lua` | Two-step FZF-lua picker (provider → model) | Share picker patterns for PMGR UI |
| **Skill Studio** | `skill_studio/init.lua` + 10 modules | Subsystem with init orchestrator | **Primary pattern to follow** |
| **Git/Diffview** | `plugins/git.lua` | Plugin spec with hooks + enhanced commands | Extend for CDRV integration |

## Recommended Architecture for New Features

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         lua/ai/ (AI Module Root)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌───────────────┐ │
│  │   Existing Modules   │  │   Existing Modules   │  │ Existing Sys  │ │
│  │                      │  │                      │  │               │ │
│  │  providers.lua       │  │  keys.lua            │  │ skill_studio/ │ │
│  │  (Provider Registry) │  │  (Key CRUD)          │  │ (10 modules)  │ │
│  │                      │  │                      │  │               │ │
│  │  config_resolver.lua │  │  model_switch.lua    │  │ sync.lua      │ │
│  │  (Config Merge)      │  │  (Picker)            │  │ (Sync Engine) │ │
│  └───────────┬──────────┘  └───────────┬──────────┘  └───────┬───────┘ │
│              │                        │                     │         │
│              └────────────────────────┼─────────────────────┘         │
│                                       │                               │
│  ┌────────────────────────────────────▼─────────────────────────────┐ │
│  │                     NEW: Provider Manager Subsystem               │ │
│  │  lua/ai/provider_manager/                                         │ │
│  │                                                                    │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────┐ │ │
│  │  │ init.lua     │ │ ui.lua       │ │ registry.lua │ │ detect.lua│ │ │
│  │  │ (Orchestrator│ │ (Picker UI)  │ │ (Provider/   │ │ (Avail.   │ │ │
│  │  │  + Commands) │ │              │ │  Model CRUD) │ │  Check)   │ │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────┘ │ │
│  │                                                                    │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐              │ │
│  │  │ agent.lua    │ │ profiles.lua │ │ validator.lua│              │ │
│  │  │ (Agent-Model │ │ (Config      │ │ (Input       │              │ │
│  │  │  Assignment) │ │  Profiles)   │ │  Validation) │              │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘              │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     NEW: Commit Review Subsystem                   │ │
│  │  lua/ai/commit_review/                                             │ │
│  │                                                                    │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────┐ │ │
│  │  │ init.lua     │ │ picker.lua   │ │ diff.lua     │ │ comment.lua│ │
│  │  │ (Orchestrator│ │ (Commit      │ │ (Diffview    │ │ (Comment   │ │ │
│  │  │  + Commands) │ │  Selector)   │ │  Integration)│ │  Storage)  │ │ │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────┘ │ │
│  │                                                                    │ │
│  │  ┌──────────────┐ ┌──────────────┐                                │ │
│  │  │ summary.lua  │ │ config.lua   │                                │ │
│  │  │ (Markdown    │ │ (Settings:   │                                │ │
│  │  │  Generator)  │ │  count, base)│                                │ │
│  │  └──────────────┘ └──────────────┘                                │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     Integration Layer                              │ │
│  │                                                                    │ │
│  │  lua/ai/init.lua (Extended)                                        │ │
│  │  ├─ register_backend() → unchanged                                │ │
│  │  ├─ NEW: register_subsystem("provider_manager", module)           │ │
│  │  ├─ NEW: register_subsystem("commit_review", module)              │ │
│  │  └─ setup() → auto-loads subsystems                               │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## Module Responsibilities

### Provider Manager Subsystem (`lua/ai/provider_manager/`)

| Module | Responsibility | Interacts With |
|--------|----------------|----------------|
| `init.lua` | Orchestrator: setup, command registration, subsystem entry point | `ai.init.lua`, all sub-modules |
| `ui.lua` | FZF-lua picker for provider/model management UI | `fzf-lua`, `registry.lua`, `detect.lua` |
| `registry.lua` | Provider/Model CRUD operations, extends `providers.lua` | `providers.lua`, `keys.lua` |
| `detect.lua` | Availability detection (API call to provider endpoint) | `keys.lua`, `registry.lua` |
| `agent.lua` | Agent-Model assignment configuration | `keys.lua`, `profiles.lua` |
| `profiles.lua` | Configuration profile management (rename, switch, default) | `keys.lua` |
| `validator.lua` | Input validation for provider/model configs | `ui.lua`, `registry.lua` |

### Commit Review Subsystem (`lua/ai/commit_review/`)

| Module | Responsibility | Interacts With |
|--------|----------------|----------------|
| `init.lua` | Orchestrator: setup, command registration, subsystem entry point | `ai.init.lua`, all sub-modules |
| `picker.lua` | FZF-lua commit selector (unpushed commits, range selection) | `fzf-lua`, git operations |
| `diff.lua` | Diffview integration for commit diff display | `diffview.nvim`, `plugins/git.lua` |
| `comment.lua` | Persistent comment storage on diff lines | `summary.lua`, diff buffer |
| `summary.lua` | Markdown review summary file generation | `comment.lua`, `.tmp/` directory |
| `config.lua` | Review settings (commit count, base commit, etc.) | `init.lua`, user config |

## Integration with Existing Modules

### Provider Manager Integration Points

```
┌─────────────────────────────────────────────────────────────────┐
│                  Provider Manager Integration Flow              │
└─────────────────────────────────────────────────────────────────┘

providers.lua (existing)
    │
    ├──► provider_manager/registry.lua
    │    │  Extends: adds CRUD methods
    │    │  - registry.add_provider(name, config)
    │    │  - registry.remove_provider(name)
    │    │  - registry.update_provider(name, config)
    │    │  - registry.add_model(provider, model_id)
    │    │  - registry.remove_model(provider, model_id)
    │    │
    │    └──► providers.lua.register() (existing)
    │         (No modification needed — registry adds new entries)
    │
keys.lua (existing)
    │
    ├──► provider_manager/agent.lua
    │    │  Extends: stores agent-model config in same file
    │    │
    │    └──► keys.lua file format extended:
    │         return {
    │           profile = "default",
    │           bailian_coding = { ... },
    │           -- NEW: agent_models section
    │           agent_models = {
    │             default = "pmgr:default",  -- profile reference
    │             profiles = {
    │               ["pmgr:default"] = {
    │                 planner = "bailian_coding/qwen3.6-plus",
    │                 coder = "bailian_coding/glm-5",
    │                 reviewer = "openai/gpt-4o",
    │               },
    │               ["pmgr:fast"] = {
    │                 planner = "deepseek/deepseek-chat",
    │                 coder = "deepseek/deepseek-chat",
    │                 reviewer = "deepseek/deepseek-chat",
    │               },
    │             },
    │           },
    │         }
    │
model_switch.lua (existing)
    │
    ├──► provider_manager/ui.lua
    │    │  Shares: picker pattern (two-step selection)
    │    │  - Uses same fzf-lua.fzf_exec pattern
    │    │  - Different action callbacks (CRUD vs selection)
    │    │
    │    └──► No modification needed (pattern reuse only)

config_watcher.lua (existing)
    │
    ├──► provider_manager/init.lua
    │    │  Triggers: on provider/model changes
    │    │  - Auto-sync to OpenCode/Claude Code
    │    │  - Invalidate config_resolver cache
    │    │
    │    └──► config_watcher pattern reused:
    │         - Watch ai_keys.lua for agent_models changes
    │         - Trigger sync.lua.sync_all()
```

### Commit Review Integration Points

```
┌─────────────────────────────────────────────────────────────────┐
│                  Commit Review Integration Flow                 │
└─────────────────────────────────────────────────────────────────┘

plugins/git.lua (existing)
    │
    ├──► commit_review/diff.lua
    │    │  Extends: adds commit diff commands
    │    │
    │    └──► New commands in plugins/git.lua:
    │         - DiffviewCommitReview (opens commit picker)
    │         - DiffviewCommitRange (select two commits)
    │         - DiffviewAddComment (add comment to diff line)
    │         - DiffviewGenerateSummary (generate review file)
    │
    │    └──► Hooks extended:
    │         - diffview_buf_read: add comment keymaps
    │         - Add <leader>gc for "Add Comment"
    │         - Add <leader>gG for "Generate Summary"
    │
git operations (system)
    │
    ├──► commit_review/picker.lua
    │    │  Uses: git log commands
    │    │  - git log --oneline -n<count> (commit list)
    │    │  - git log @{u}..HEAD (unpushed commits)
    │    │  - git diff <sha1>..<sha2> (range diff)
    │    │
    │    └──► commit_review/diff.lua
    │         - Opens diffview with commit range args
    │         - :DiffviewOpen <sha1>..<sha2>
    │
.diffview.nvim (plugin)
    │
    ├──► commit_review/diff.lua
    │    │  Reuses: diffview buffer creation
    │    │  - Extended hooks for comment annotations
    │    │  - Virtual text for comments overlay
    │    │
    │    └──► commit_review/comment.lua
    │         - Stores comments in memory + .tmp/ file
    │         - Uses vim.api.nvim_buf_set_virtual_text
```

## Data Flow Diagrams

### Flow 1: Provider Management Panel

```
User runs :AIProviderManager
    │
    ▼
provider_manager/init.lua → open()
    │
    ▼
ui.lua → open_picker()
    │
    ├──► Load providers from providers.lua
    │    └──► registry.lua.list_providers()
    │         └──► providers.lua.list() (existing)
    │
    ├──► Load models per provider
    │    └──► registry.lua.list_models(provider)
    │         ├──► providers.lua.get(provider).static_models
    │         └──► fetch_models.lua.fetch(provider) (dynamic)
    │
    ├──► Load availability status
    │    └──► detect.lua.get_status(provider, model)
    │         └──► Cached results or pending
    │
    ▼
FZF-lua picker shows:
    ┌─────────────────────────────────────┐
    │ Provider > Model > Status > Actions │
    │ ─────────────────────────────────── │
    │ bailian_coding > qwen3.6-plus > ✓  │
    │ bailian_coding > glm-5 > ✓         │
    │ openai > gpt-4o > ⏳ (pending)      │
    │ deepseek > deepseek-chat > ✗       │
    │ ─────────────────────────────────── │
    │ [a] Add [d] Delete [e] Edit [t] Test│
    └─────────────────────────────────────┘
    │
    ▼ (User action)
    ├─► Add: ui.lua.show_add_form() → validator.lua.validate() → registry.lua.add()
    ├─► Delete: registry.lua.remove() → confirm → update keys.lua
    ├─► Edit: ui.lua.show_edit_form() → registry.lua.update()
    └► Test: detect.lua.check(provider, model) → update status
```

### Flow 2: Availability Detection

```
User runs :AIProviderTest <provider> <model>
    │
    ▼
provider_manager/detect.lua → check(provider, model)
    │
    ├──► Get API key
    │    └──► keys.lua.get_key(provider)
    │
    ├──► Get endpoint
    │    └──► keys.lua.get_base_url(provider)
    │    └──► fallback: providers.lua.get(provider).endpoint
    │
    ├──► Build test request
    │    └──► Simple API call: POST /chat/completions
    │         Body: { model: "<model>", messages: [{"role":"user","content":"ping"}], max_tokens: 1 }
    │
    ├──► Execute request (async, timeout 10s)
    │    └──► vim.loop.new_tcp() or curl via vim.fn.system()
    │
    ▼
Results:
    ├─► 200 OK → Status = "available" (✓)
    ├─► 401/403 → Status = "invalid_key" (🔑)
    ├─► Timeout → Status = "timeout" (⏳)
    └► Error → Status = "error" (✗) + error message
    │
    ▼
Cache result in detect.lua._status_cache
    │
    ▼
UI refresh (if picker open) → status indicator update
```

### Flow 3: Agent-Model Configuration

```
User runs :AIAgentConfig
    │
    ▼
provider_manager/agent.lua → open_config()
    │
    ├──► Load current profile
    │    └──► keys.lua.read().agent_models.default
    │
    ├──► Load profile options
    │    └──► keys.lua.read().agent_models.profiles
    │
    ▼
FZF-lua picker shows:
    ┌─────────────────────────────────────┐
    │ Agent > Current Model > Suggestions │
    │ ─────────────────────────────────── │
    │ planner > qwen3.6-plus > [switch]   │
    │ coder > glm-5 > [switch]            │
    │ reviewer > gpt-4o > [switch]        │
    │ ─────────────────────────────────── │
    │ Profile: pmgr:default               │
    │ [s] Switch Model [p] Change Profile │
    └─────────────────────────────────────┘
    │
    ▼ (User selects agent + model)
    ├──► agent.lua.switch_agent_model(agent, model)
    │    └──► model_switch.select() → callback
    │    └──► agent.lua.update_config(agent, new_model)
    │         └──► keys.lua.write(updated agent_models)
    │
    ▼ (User changes profile)
    ├──► agent.lua.switch_profile(profile_name)
    │    └──► keys.lua.write({ ... default = profile_name })
    │    └──► config_watcher triggers → sync_all()
```

### Flow 4: Commit Review Workflow

```
User runs :AICommitReview
    │
    ▼
commit_review/init.lua → open()
    │
    ▼
picker.lua → open_commit_picker()
    │
    ├──► Get commit list
    │    └──► git log --oneline @{u}..HEAD (unpushed)
    │    └──► config.lua.get("commit_count") → limit
    │
    ├──► Get base commit (if set)
    │    └──► config.lua.get("base_commit")
    │    └──► Filter commits >= base
    │
    ▼
FZF-lua picker shows:
    ┌─────────────────────────────────────┐
    │ SHA > Author > Message > Date       │
    │ ─────────────────────────────────── │
    │ abc123 > wx > feat: add x > 2024-01 │
    │ def456 > wx > fix: bug y > 2024-01  │
    │ ─────────────────────────────────── │
    │ [Enter] Single Commit Diff          │
    │ [Ctrl-s] Select Range (two commits) │
    └─────────────────────────────────────┘
    │
    ▼ (Single commit)
    ├──► diff.lua.open_commit_diff(sha)
    │    └──► git diff <sha>^..<sha>
    │    └──► :DiffviewOpen <sha>^..<sha>
    │    └──► comment.lua.attach_to_buffer()
    │
    ▼ (Range selection)
    ├──► picker.lua.select_range(sha1, sha2)
    │    └──► diff.lua.open_range_diff(sha1, sha2)
    │         └──► :DiffviewOpen <sha1>..<sha2>
    │
    ▼ (Diff view open)
    ├──► Buffer hooks: <leader>gc → Add Comment
    │    └──► comment.lua.add_comment(bufnr, line, text)
    │         └──► Store in comment.lua._comments[sha][file][line]
    │         └──► Show virtual text annotation
    │
    ▼ (Review complete)
    ├──► User runs :AIReviewSummary
    │    └──► summary.lua.generate()
    │         ├──► Gather all comments from comment.lua._comments
    │         ├──► Format as Markdown:
    │         │    # Review Summary: <sha1>..<sha2>
    │         │    Date: <timestamp>
    │         │    
    │         │    ## Commits Reviewed
    │         │    - abc123: feat: add x
    │         │    - def456: fix: bug y
    │         │    
    │         │    ## Comments
    │         │    ### src/main.lua
    │         │    - L42: [abc123] Comment text...
    │         │
    │         └──► Write to .tmp/review_<sha1>_<sha2>_<timestamp>.md
```

## Recommended Build Order

Based on dependency analysis, the recommended phase order is:

### Phase 1: Provider Manager Core (Foundation)

**Files to create:**
```
lua/ai/provider_manager/
├── init.lua         # Orchestrator + command registration
├── registry.lua     # CRUD operations (depends on providers.lua, keys.lua)
├── validator.lua    # Input validation
└── ui.lua           # FZF-lua picker (depends on registry, validator)
```

**Dependencies:**
- `registry.lua` → `providers.lua` (existing, no modification)
- `registry.lua` → `keys.lua` (existing, may extend file format)
- `ui.lua` → `fzf-lua` (existing via plugins/editor.lua)
- `init.lua` → `ai.init.lua` (extend setup() to load subsystem)

**Why first:**
- Foundation for agent config and availability detection
- Independent of commit review feature
- Extends existing proven patterns

### Phase 2: Provider Manager Extensions

**Files to create:**
```
lua/ai/provider_manager/
├── detect.lua       # Availability detection (depends on keys.lua)
├── agent.lua        # Agent-model config (depends on keys.lua)
└── profiles.lua     # Profile management (depends on agent.lua)
```

**Dependencies:**
- `detect.lua` → `keys.lua` for API keys
- `detect.lua` → async HTTP client (use vim.loop or system curl)
- `agent.lua` → `model_switch.lua` pattern reuse
- `profiles.lua` → `agent.lua`, `keys.lua`

**Why second:**
- Extends Phase 1 foundation
- Availability detection requires working registry
- Agent config requires profile system

### Phase 3: Commit Review Core

**Files to create:**
```
lua/ai/commit_review/
├── init.lua         # Orchestrator + command registration
├── config.lua       # Settings storage
├── picker.lua       # Commit selector (depends on git, fzf-lua)
└── diff.lua         # Diffview integration (depends on plugins/git.lua)
```

**Dependencies:**
- `picker.lua` → git operations (system)
- `picker.lua` → `fzf-lua` (existing)
- `diff.lua` → `diffview.nvim` (existing)
- `diff.lua` → `plugins/git.lua` (extend hooks)

**Why third:**
- Independent of provider manager
- Uses existing git/diffview infrastructure
- Foundation for comment/summary features

### Phase 4: Commit Review Extensions

**Files to create:**
```
lua/ai/commit_review/
├── comment.lua      # Comment storage + virtual text
└── summary.lua      # Markdown generation
```

**Dependencies:**
- `comment.lua` → `diff.lua` (buffer attachment)
- `comment.lua` → `.tmp/` directory (create if needed)
- `summary.lua` → `comment.lua` (comment collection)

**Why last:**
- Requires working diff view integration
- Summary depends on comment accumulation
- Can be built incrementally after Phase 3

## Architectural Patterns to Follow

### Pattern 1: Subsystem Orchestrator (Skill Studio Style)

**What:** A single `init.lua` that coordinates all sub-modules, handles setup, command registration, and exposes the subsystem's public API.

**When to use:** For feature-rich subsystems with multiple specialized modules.

**Trade-offs:** 
- ✅ Clear entry point, easy to understand subsystem boundaries
- ✅ Sub-modules remain focused on single responsibilities
- ❌ Requires careful orchestration to avoid circular dependencies

**Example (from skill_studio/init.lua pattern):**
```lua
-- lua/ai/provider_manager/init.lua
local M = {}

local Registry = require("ai.provider_manager.registry")
local UI = require("ai.provider_manager.ui")
local Detect = require("ai.provider_manager.detect")
local Agent = require("ai.provider_manager.agent")
local Profiles = require("ai.provider_manager.profiles")

local _setup_done = false

function M.setup(opts)
  if _setup_done then return M end
  _setup_done = true
  
  opts = opts or {}
  Registry.setup(opts.registry or {})
  UI.setup(opts.ui or {})
  Detect.setup(opts.detect or {})
  Agent.setup(opts.agent or {})
  Profiles.setup(opts.profiles or {})
  
  M.register_commands()
  return M
end

function M.register_commands()
  vim.api.nvim_create_user_command("AIProviderManager", function()
    M.open()
  end, { desc = "Open Provider/Model Manager" })
  -- ... more commands
end

function M.open()
  UI.open_picker()
end

return M
```

### Pattern 2: Registry Extension (No Modification)

**What:** Instead of modifying existing `providers.lua`, create a new registry module that adds CRUD methods and calls the existing `register()` when adding.

**When to use:** When extending existing simple modules without breaking compatibility.

**Trade-offs:**
- ✅ Zero modification to existing modules
- ✅ Existing code continues working unchanged
- ✅ Clear separation of concerns
- ❌ Slight duplication (registry reads from providers, but doesn't replace it)

**Example:**
```lua
-- lua/ai/provider_manager/registry.lua
local Providers = require("ai.providers")
local Keys = require("ai.keys")

local M = {}

function M.list_providers()
  return Providers.list()  -- Delegates to existing module
end

function M.add_provider(name, config)
  -- Validate first
  local Validator = require("ai.provider_manager.validator")
  if not Validator.validate_provider(name, config) then
    return false
  end
  
  -- Register in providers.lua (existing pattern)
  Providers.register(name, config)
  
  -- Also update keys.lua to ensure default profile
  local tbl = Keys.read() or {}
  tbl[name] = tbl[name] or { default = { api_key = "", base_url = config.endpoint or "" } }
  Keys.write(tbl)
  
  return true
end

function M.remove_provider(name)
  -- Mark as disabled rather than truly removing
  -- (Avoid breaking existing configs that reference it)
  local tbl = Keys.read() or {}
  tbl[name] = nil
  Keys.write(tbl)
  
  -- Invalidate config resolver cache
  require("ai.config_resolver").invalidate_cache()
end

return M
```

### Pattern 3: Config File Extension (Backward Compatible)

**What:** Extend the `ai_keys.lua` file format with new sections without breaking existing structure.

**When to use:** When adding new configuration needs that should coexist with existing keys.

**Trade-offs:**
- ✅ All configuration in one place (user familiarity)
- ✅ Existing keys.lua module can still work
- ❌ File format becomes more complex over time
- ❌ Need careful migration for existing files

**Example (extended keys.lua format):**
```lua
-- ~/.local/state/nvim/ai_keys.lua (new format)
return {
  profile = "default",
  
  -- Existing: Provider key config
  bailian_coding = {
    default = {
      api_key = "sk-xxx",
      base_url = "https://coding.dashscope.aliyuncs.com/v1",
    },
  },
  
  -- NEW: Agent-Model configuration
  agent_models = {
    default = "pmgr:default",  -- Current active profile
    profiles = {
      ["pmgr:default"] = {
        planner = "bailian_coding/qwen3.6-plus",
        coder = "bailian_coding/glm-5",
        reviewer = "deepseek/deepseek-chat",
      },
      ["pmgr:fast"] = {
        planner = "deepseek/deepseek-chat",
        coder = "deepseek/deepseek-chat",
        reviewer = "deepseek/deepseek-chat",
      },
    },
  },
  
  -- NEW: Provider metadata (optional)
  provider_meta = {
    bailian_coding = {
      added_at = "2024-01-15",
      notes = "Primary coding assistant",
    },
  },
}
```

### Pattern 4: Async Detection with Cache

**What:** Availability detection runs asynchronously with results cached to avoid repeated API calls.

**When to use:** When checking remote service availability that might be slow or rate-limited.

**Trade-offs:**
- ✅ Non-blocking UI (picker shows cached/pending status)
- ✅ Results persist across sessions
- ❌ Cache might become stale (need refresh option)

**Example:**
```lua
-- lua/ai/provider_manager/detect.lua
local M = {}

local _status_cache = {}  -- { [provider_model_key] = { status, timestamp, error } }
local _pending = {}       -- Ongoing checks

local function check_availability(provider, model, callback)
  local key = provider .. "/" .. model
  
  -- Return cached if fresh (< 1 hour)
  if _status_cache[key] and os.time() - _status_cache[key].timestamp < 3600 then
    callback(_status_cache[key])
    return
  end
  
  -- Already checking?
  if _pending[key] then return end
  _pending[key] = true
  
  -- Async check
  vim.loop.new_timer():start(0, 0, function()
    -- HTTP request logic here...
    local status = perform_api_check(provider, model)
    
    vim.schedule(function()
      _status_cache[key] = {
        status = status.ok and "available" or "error",
        timestamp = os.time(),
        error = status.error,
      }
      _pending[key] = nil
      callback(_status_cache[key])
    end)
  end)
end

function M.get_status(provider, model)
  local key = provider .. "/" .. model
  return _status_cache[key] or { status = "pending", timestamp = 0 }
end

return M
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Modifying Existing Modules Directly

**What people do:** Edit `providers.lua` or `keys.lua` to add new methods inline.

**Why it's wrong:**
- Breaks existing tests that expect specific structure
- Creates merge conflicts if upstream changes
- Makes rollback difficult (can't just remove new subsystem)

**Do this instead:** Create extension modules in subsystem directory that delegate to existing modules (Pattern 2).

### Anti-Pattern 2: Global State for Comments

**What people do:** Store review comments in a global `_G.review_comments` table.

**Why it's wrong:**
- State lost on Neovim restart
- Multiple concurrent reviews conflict
- No persistence for review summary

**Do this instead:** 
- Use module-local state + file persistence in `.tmp/review_<id>.lua`
- Load from file when resuming review
- Clear on summary generation

### Anti-Pattern 3: Blocking UI for Detection

**What people do:** Call provider API synchronously in picker, blocking Neovim.

**Why it's wrong:**
- Picker freezes during check (10s timeout)
- Multiple checks in sequence block for minutes
- User cannot cancel or navigate

**Do this instead:** Async detection with cached/pending status (Pattern 4). Show "⏳ Checking..." and update asynchronously.

### Anti-Pattern 4: Duplicate Picker Code

**What people do:** Copy-paste FZF picker code from `model_switch.lua` into new modules.

**Why it's wrong:**
- Code duplication leads to maintenance burden
- Different behavior patterns diverge over time
- Bug fixes need multiple locations

**Do this instead:** 
- Create shared picker utility in `lua/ai/util.lua` or `lua/ai/ui_helpers.lua`
- Or just follow the same pattern but with clear documentation reference

## Integration Checklist

### For lua/ai/init.lua (Extension)

```lua
-- Add to existing init.lua setup() function:
function M.setup(opts)
  -- ... existing code ...
  
  -- NEW: Load provider_manager subsystem
  local ok_pm, ProviderManager = pcall(require, "ai.provider_manager")
  if ok_pm then
    ProviderManager.setup(opts.provider_manager or {})
  end
  
  -- NEW: Load commit_review subsystem  
  local ok_cr, CommitReview = pcall(require, "ai.commit_review")
  if ok_cr then
    CommitReview.setup(opts.commit_review or {})
  end
  
  return M
end
```

### For plugins/git.lua (Extension)

Add new keys and commands:
```lua
-- In keys section:
{ "<leader>gR", "<cmd>AICommitReview<cr>", desc = "Commit Review" },
{ "<leader>gC", "<cmd>AIReviewSummary<cr>", desc = "Generate Review Summary" },

-- In hooks.diffview_buf_read:
-- Add comment keymaps:
vim.keymap.set("n", "<leader>gc", function()
  require("ai.commit_review.comment").add_comment_at_line()
end, { buffer = bufnr, desc = "Add Comment to Diff Line" })
```

## Sources

- Codebase analysis: `lua/ai/providers.lua`, `lua/ai/keys.lua`, `lua/ai/model_switch.lua`, `lua/ai/config_resolver.lua`, `lua/ai/skill_studio/init.lua`, `lua/plugins/git.lua`
- Existing architecture documentation: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/FLOWS.md`
- Skill Studio pattern: 10-module subsystem structure from `lua/ai/skill_studio/`

---
*Architecture research for: Provider/Model Management & Commit Diff Review integration*
*Researched: 2026-04-21*