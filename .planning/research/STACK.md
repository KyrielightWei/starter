# Stack Research — Provider/Model Management & Commit Diff Review

**Domain:** Neovim Plugin Enhancement
**Researched:** 2026-04-21
**Confidence:** HIGH (verified against existing codebase patterns)

## Executive Summary

This research covers the technology stack for two new features:
1. **Provider/Model 交互式管理系统** — Management panel, availability detection, Agent-Model configuration
2. **交互式 Commit Diff Review** — Commit picker, diff view comments, review summary generation

Key finding: The existing codebase already has proven patterns that can be extended. No new heavyweight dependencies needed.

---

## Recommended Stack

### UI Framework: FZF-lua

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **ibhagwan/fzf-lua** | Latest (via LazyVim) | Picker UI for management panel & commit selection | Already integrated, proven pattern in `model_switch.lua`, `terminal_picker.lua`. Has `git_commits` builtin, custom actions, previewers. Performance: sub-500ms startup. |

**Why FZF-lua over Telescope:**

| Criterion | FZF-lua | Telescope |
|-----------|---------|-----------|
| Performance | Faster (C binary fzf) | Slower (pure Lua) |
| Existing Integration | ✅ Already used in 3 modules | ✅ Available for grep only |
| Git Commands | ✅ Built-in `git_commits`, `git_bcommits` | ✅ Built-in but less performant |
| Custom Previewers | ✅ Supports `previewer.builtin` | ✅ Supports previewers |
| Multi-action Keys | ✅ `actions = { default, ctrl-v, ctrl-s }` | ✅ Similar pattern |
| Async Actions | ✅ `vim.schedule` pattern proven | ✅ Similar |

**Recommendation: FZF-lua** — Better performance, proven pattern in existing codebase, no additional configuration needed.

**Confidence: HIGH** — Verified in `lua/ai/model_switch.lua` (lines 16-95) and `lua/ai/terminal_picker.lua` (lines 104-226).

---

### HTTP/API Calls: curl via io.popen

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **curl** | System binary | Availability detection API calls | Already used in `fetch_models.lua`. Synchronous pattern acceptable for manual-triggered detection. Timeout via `--max-time 10s`. |

**Implementation Pattern (from fetch_models.lua):**

```lua
local cmd_parts = { "curl", "-s", "--max-time", "10" }
for _, header in ipairs(headers) do
  table.insert(cmd_parts, "-H")
  table.insert(cmd_parts, header)
end
table.insert(cmd_parts, url)

local cmd = ""
for i, part in ipairs(cmd_parts) do
  if i > 1 then cmd = cmd .. " " end
  cmd = cmd .. string.format("%q", part)
end

local fh = io.popen(cmd)
local out = fh:read("*a")
fh:close()
```

**Availability Detection Implementation:**
- Endpoint: `{base_url}/v1/models` (OpenAI-compatible)
- Headers: `Authorization: Bearer {api_key}`, `Content-Type: application/json`
- Success: JSON response with `data` array
- Failure: Empty/invalid response, timeout, connection error

**Why NOT vim.loop.spawn:**
- `io.popen` is simpler and proven in this codebase
- Availability detection is user-triggered (not startup blocking)
- No async requirement for this use case

**Confidence: HIGH** — Verified in `lua/ai/fetch_models.lua` (lines 42-105).

---

### Data Storage: Extend ai_keys.lua

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Lua table file** | N/A | Provider/Model config + Agent profiles | Unified location with existing keys. Backward compatible. Path: `vim.fn.stdpath("state") .. "/ai_keys.lua"` |

**Extended Format (backward compatible):**

```lua
return {
  profile = "default",

  -- Existing format (unchanged)
  bailian_coding = {
    default = {
      api_key = "sk-xxx",
      base_url = "https://coding.dashscope.aliyuncs.com/v1",
      base_url_claude = "",
    },
  },

  -- NEW: Availability status cache
  availability = {
    bailian_coding = {
      qwen3.6-plus = { status = "available", checked_at = "2026-04-21T10:00:00" },
      glm-5 = { status = "timeout", checked_at = "2026-04-21T09:55:00" },
    },
  },

  -- NEW: Agent-Model profiles
  agent_profiles = {
    default = {
      planner = { provider = "bailian_coding", model = "qwen3.6-plus" },
      coder = { provider = "bailian_coding", model = "qwen3.5-plus" },
      reviewer = { provider = "deepseek", model = "deepseek-chat" },
    },
    custom_1 = {
      planner = { provider = "openai", model = "gpt-4o-mini" },
      coder = { provider = "bailian_coding", model = "glm-5" },
      reviewer = { provider = "bailian_coding", model = "qwen3.6-plus" },
    },
  },
}
```

**Read Pattern (from keys.lua):**
```lua
function M.read()
  local path = keys_path()
  if vim.fn.filereadable(path) == 0 then return nil end
  return dofile(path)
end
```

**Write Pattern (from keys.lua):**
```lua
function M.write(tbl)
  local out = { "return {" }
  -- serialize table to Lua syntax
  table.insert(out, "}")
  vim.fn.writefile(out, keys_path())
end
```

**Confidence: HIGH** — Verified in `lua/ai/keys.lua` (lines 71-106).

---

### Diff View: Extend diffview.nvim

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **sindrets/diffview.nvim** | Latest (>= 2.31 git) | Commit diff viewing with comment support | Already configured. Has hooks for buffer customization. Supports `DiffviewFileHistory` for commit history. |

**Extension Points:**

| Feature | Diffview API | How to Extend |
|---------|--------------|---------------|
| Commit Picker | `DiffviewFileHistory` | Use FZF-lua `git_commits` first, then open diffview |
| Line Comments | `hooks.diff_buf_read` | Add virtual text/extmarks for comment markers |
| Comment Input | `vim.ui.input` | Capture comment text for selected line |
| Comment Storage | Project `.tmp/` file | Markdown format with commit SHA, file, line |

**Comment Implementation Pattern:**

```lua
-- In hooks.diff_buf_read
hooks = {
  diff_buf_read = function(bufnr)
    -- Add comment keymap
    vim.keymap.set("n", "<leader>rc", function()
      local line = vim.api.nvim_win_get_cursor(0)[1]
      local file = vim.api.nvim_buf_get_name(bufnr)
      vim.ui.input({ prompt = "Comment: " }, function(text)
        if text then
          -- Store comment
          Comments.add(file, line, text)
          -- Show virtual text
          vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
            virt_text = { { "💬 " .. text, "Comment" } },
            virt_text_pos = "right_align",
          })
        end
      end)
    end, { buffer = bufnr })
  end,
}
```

**Confidence: MEDIUM** — Diffview hooks documented but comment extension requires custom implementation.

---

### Review Summary: Markdown Generation

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **vim.fn.writefile** | N/A | Review summary file generation | Standard Neovim API. Markdown format for readability. |

**Review Summary Format:**

```markdown
# Code Review Summary

**Review Date:** 2026-04-21 10:30
**Commit Range:** abc123..def456
**Reviewer:** [AI Agent Name]

## Commits Reviewed

### abc123 - "feat: add provider management"
| File | Line | Comment |
|------|------|---------|
| lua/ai/providers.lua | 42 | Consider adding validation for endpoint format |
| lua/ai/keys.lua | 78 | Missing error handling for empty api_key |

### def456 - "fix: model switch timeout"
| File | Line | Comment |
|------|------|---------|
| lua/ai/model_switch.lua | 55 | Good timeout handling, but could use retry logic |

## Summary

- **Total Comments:** 3
- **Files Reviewed:** 3
- **Action Items:** 2
```

**File Path:** `{project_root}/.tmp/review_2026-04-21_abc123-def456.md`

**Confidence: HIGH** — Simple file generation with standard API.

---

## Supporting Libraries (Already Available)

| Library | Purpose | How to Use |
|---------|---------|------------|
| **plenary.nvim** | Test framework | Test new modules with `describe/it/assert` pattern |
| **nvim-web-devicons** | File icons | Already used, extend for provider icons |
| **vim.ui.select/input** | User prompts | For sub-pickers and comment input |

---

## Alternatives Considered

### UI Framework Alternatives

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| FZF-lua | Telescope | If user prefers Telescope ecosystem, or needs Telescope-specific extensions |
| FZF-lua | nui.nvim custom UI | For complex multi-panel UIs (not needed for picker-based interfaces) |

### HTTP Alternatives

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| curl/io.popen | vim.loop.spawn | For async/background operations (not needed for manual detection) |
| curl/io.popen | plenary.job | If plenary async patterns preferred |

### Storage Alternatives

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Lua table file | JSON file | If external tools need to read config |
| Lua table file | SQLite | For complex querying (overkill for this use case) |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Neovim startup HTTP calls** | Blocking startup, network delays | Manual command-triggered detection (`:AIProviderCheck`) |
| **Global state for availability** | Stale data, race conditions | Cache in `ai_keys.lua` with timestamps |
| **Inline buffer edits for comments** | Conflicts with diff content | Virtual text/extmarks (non-invasive) |
| **Rebase for review corrections** | Too risky for review workflow | Generate new review file |

---

## Stack Patterns by Variant

**For Provider Management Panel:**
- Use FZF-lua `fzf_exec` with multi-action keys
- Pattern: `actions = { default = edit, ctrl-d = delete, ctrl-a = add }`
- Previewer: Show provider details (endpoint, models, status)

**For Availability Detection:**
- Use curl `--max-time 10s` for timeout
- Cache results with timestamp in `ai_keys.lua`
- Status icons: ✓ (available), ⏱ (timeout), ✗ (error), ? (unknown)

**For Agent-Model Config:**
- Use nested picker: Select agent → Select provider → Select model
- Pre-populate with default profile
- Allow profile rename/save

**For Commit Diff Review:**
- Use FZF-lua `git_commits` for selection
- Default: Show unpushed commits (`git log @{u}..HEAD`)
- Multi-select for commit range comparison
- Open diffview.nvim for selected commit(s)

---

## Implementation Dependencies

| Phase | Module | Depends On |
|-------|--------|------------|
| PMGR Phase 1 | Management panel UI | FZF-lua (existing), providers.lua (existing) |
| PMGR Phase 2 | Availability detection | keys.lua (existing), curl pattern (existing) |
| PMGR Phase 3 | Agent-Model config | keys.lua format extension |
| CDRV Phase 1 | Commit picker | FZF-lua git_commits (builtin) |
| CDRV Phase 2 | Diff view comments | diffview.nvim hooks |
| CDRV Phase 3 | Review summary | vim.fn.writefile |

---

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| FZF-lua | Neovim >= 0.9 | Current project uses >= 0.10 |
| diffview.nvim | Git >= 2.31 | Already enforced in git.lua |
| curl | Any system | Required for fetch_models.lua |

---

## Sources

- **Existing Codebase** — Verified patterns in `fetch_models.lua`, `keys.lua`, `model_switch.lua`, `terminal_picker.lua`, `git.lua`
- **FZF-lua README** — https://github.com/ibhagwan/fzf-lua — git_commits builtin, custom actions, previewers (HIGH confidence)
- **diffview.nvim README** — https://github.com/sindrets/diffview.nvim — hooks, DiffviewFileHistory, merge tool (HIGH confidence)
- **Neovim Lua docs** — https://neovim.io/doc/user/lua.html — io.popen, vim.ui.input, vim.fn.writefile (HIGH confidence)

---
*Stack research for: Provider/Model Management & Commit Diff Review*
*Researched: 2026-04-21*