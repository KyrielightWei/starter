## Context

The local AI plugin currently includes a Commit Picker that can list commits, select one or two SHAs, and open `diffview.nvim` using `DiffviewOpenEnhanced`. This is useful for inspecting generated code, but it does not capture review intent: there is no session state, no comments anchored to code, and no export format that an AI tool can consume for follow-up reasoning.

The target workflow is an AI-generated-code review loop:

```text
AI generates code
  └─ maybe multiple commits or worktree changes
       └─ reviewer selects range and opens diff
            └─ reviewer adds comments while reading code
                 └─ comments are exported as notes + metadata + AI prompt
                      └─ AI evaluates, discusses, or modifies code
```

Existing constraints:

- Keep the implementation inside the local AI plugin at `local-plugins/ai/`.
- Continue using `diffview.nvim` as the primary diff display layer.
- Do not turn Commit Picker into a review-state owner.
- Store review data in the project by default so AI tools can read it with repository context.
- Preserve existing Commit Picker behavior for users who only want to open diffs.

## Goals / Non-Goals

**Goals:**

- Provide a unified AI review session workflow via `:AIReviewStart`.
- Support review scopes for single commits, commit ranges, `base..HEAD`, and worktree changes.
- Cache Commit Picker-selected ranges for later review use.
- Allow comments to be added from diffview with lightweight UI: signs and floating previews.
- Anchor comments to code using file, side, line, line text, context, optional hunk, range, commit, and timestamps.
- Persist sessions under `.ai-review/` by default.
- Export `notes.md`, `notes.json`, and `fix-prompt.md`.
- Phrase AI prompts as review follow-up instructions: evaluate, discuss, accept, reject, clarify, or modify as appropriate.
- Add tests for pure logic and smoke tests for commands/UI integration.

**Non-Goals:**

- Replacing or rewriting `diffview.nvim`.
- GitHub-style inline comment blocks inserted into diff buffers.
- Multi-user or remote collaboration.
- Threaded comment conversations.
- Automatically applying review comments as code patches.
- Fully automatic anchor re-location after arbitrary code movement.
- Supporting non-diffview diff backends in the MVP.

## Decisions

### 1. Add an independent `ai_review` module

The review workbench will be implemented as a new module tree:

```text
local-plugins/ai/lua/ai_review/
  init.lua          # commands orchestration: start/add/panel/export/status/close
  range.lua         # range model and diffview argument generation
  session.lua       # active session lifecycle and session metadata
  store.lua         # project-local paths, JSON I/O, atomic writes, backups
  comments.lua      # comment CRUD and status transitions
  anchor.lua        # extract code anchors from current diffview/file buffer
  diffview.lua      # open diffview, install signs/keymaps/floating previews
  export.lua        # notes.md, notes.json, fix-prompt.md generation
  panel.lua         # review list/panel, jump/edit/delete/export
```

Rationale: review state, comment anchoring, and export behavior are separate concerns from Commit Picker. Keeping them separate avoids turning Commit Picker into a monolithic review tool.

Alternative considered: add review features directly into `commit_picker`. This would be faster initially but would entangle range selection, diff display, comments, persistence, and export.

### 2. Keep `diffview.nvim` as the only MVP diff backend

`diffview.nvim` already supports commit diffs, range diffs, worktree diffs, file trees, and hunk navigation. The review module will overlay signs, keymaps, and floating previews on top of diffview buffers instead of modifying diffview internals.

The integration must use documented diffview hooks:

```lua
hooks = {
  diff_buf_read = function(bufnr, ctx) end,
  diff_buf_win_enter = function(bufnr, winid, ctx) end,
  view_opened = function(view) end,
}
```

The existing project configuration uses a hook name resembling `diffview_buf_read`; the implementation should verify and correct hook usage as part of integration.

Alternative considered: implement a custom diff UI. This would offer maximum control but duplicates a hard problem and is too risky for MVP.

### 3. Store review data project-locally by default

Default storage:

```text
.ai-review/
  current.json
  ranges/
    last.json
    ranges.json
  sessions/
    <session-id>/
      session.json
      notes.md
      notes.json
      fix-prompt.md
```

`current.json` should only point to the active session, not duplicate full state:

```json
{
  "active_session": "2026-06-10-1430-ai-review"
}
```

Rationale: project-local data makes it easy for AI tools to inspect review comments in context. Because the data may be personal and noisy, docs should recommend adding `.ai-review/` to `.gitignore` unless a team intentionally wants to share review artifacts.

Alternative considered: store only under Neovim state. This avoids repository clutter but makes it harder for AI coding tools to discover and use review output.

### 4. Model review range explicitly

Supported range types:

```json
{ "type": "single_commit", "sha": "..." }
{ "type": "commit_range", "base": "...", "head": "..." }
{ "type": "since_base", "base": "...", "head": "HEAD" }
{
  "type": "worktree",
  "include_staged": true,
  "include_unstaged": true,
  "include_untracked": true
}
```

Worktree review must explicitly define staged, unstaged, and untracked behavior. AI tools often create new files, so untracked files should not be silently excluded from review sessions.

### 5. Treat Commit Picker as a range selector/cache source

Commit Picker should preserve its default behavior:

```text
Enter = open selected diff
```

Review-specific behavior should be explicit:

- `:AIReviewStart` can call Commit Picker in a range-selection mode.
- Commit Picker may expose a review action such as “save selected range for review”.
- Selected review ranges are cached under `.ai-review/ranges/last.json` and appended to `ranges.json`.

This avoids ambiguity between “I want to inspect a diff” and “I want to create a review session range”.

### 6. Anchor comments using content-first metadata

Each comment should store enough context for both humans and AI tools to understand the referenced code even if line numbers drift:

```json
{
  "id": "comment-001",
  "created_at": "2026-06-10T14:35:00+08:00",
  "updated_at": "2026-06-10T14:35:00+08:00",
  "severity": "must-fix",
  "status": "open",
  "message": "这里缺少错误处理",
  "anchor": {
    "file": "lua/foo.lua",
    "side": "right",
    "meaning": "new",
    "line": 42,
    "line_text": "if result.code ~= 0 then",
    "context_before": ["..."],
    "context_after": ["..."],
    "hunk": "@@ -38,8 +38,12 @@ ...",
    "commit": "def5678",
    "partial": false
  }
}
```

Side semantics:

- Default to `right` / new code.
- If the cursor is on the left diff buffer or a deleted/old-side line, bind to `left` / old code.
- If exact mapping fails, allow a partial anchor with `anchor.partial = true` rather than dropping the user’s comment.

### 7. Use lightweight UI: signs plus floating previews

MVP UI should avoid inline comment blocks. It will instead:

- Mark commented lines with signs.
- Show comment previews via a keymap or cursor-hold floating window.
- Provide a panel/list for full management.

Rationale: signs and floats do not mutate diff buffers and are resilient to diffview refreshes. Inline blocks are visually attractive but risky because diffview buffers are generated and can refresh.

### 8. Export three artifacts

Each export writes:

```text
notes.md       # human-readable review summary
notes.json     # structured session/range/comment metadata
fix-prompt.md  # AI follow-up prompt
```

The prompt must not assume every comment must become a code change. It should ask the AI to classify each comment as accepted, rejected, needing discussion, or needing clarification, then modify code only when appropriate.

## Risks / Trade-offs

- Diffview buffer mapping is imperfect → Store content-first anchors with line text, surrounding context, optional hunk, side, and partial-anchor fallback.
- Worktree diffs can omit untracked files if default diffview args exclude them → Make worktree include flags explicit and document/review diffview args.
- `.ai-review/` may clutter repositories → Recommend `.ai-review/` in `.gitignore` and provide optional state-directory export.
- Keymap collisions with existing AI keymaps → Put review commands under a dedicated `<leader>kr...` namespace and avoid existing `<leader>kp` / `<leader>ke` bindings.
- Session JSON corruption could lose comments → Use atomic writes and back up malformed session files before creating replacements.
- Panel implementation could expand MVP scope → Treat panel as useful but keep the first implementation focused on session, add-comment, signs/previews, and export.
- Diffview hook API or internal buffer names may change → Use documented hooks and buffer APIs first; avoid depending on private diffview internals unless guarded.

## Migration Plan

1. Add the new `ai_review` modules without changing existing Commit Picker defaults.
2. Register new commands and keymaps under non-conflicting names.
3. Add project-local `.ai-review/` storage and documentation.
4. Add optional Commit Picker review range caching.
5. Integrate diffview signs and floating previews using documented hooks.
6. Add exports and tests.
7. Update docs to describe the review workflow.

Rollback is straightforward: remove the new commands/keymaps and `ai_review` module. Existing Commit Picker behavior should remain compatible throughout.

## Open Questions

- Should `.ai-review/` be automatically added to `.gitignore`, or should the docs only recommend it?
- Should the first version include a full Review Panel, or start with a simpler list/export interface?
- Should exported prompts include the full diff hunk for every comment by default, or only when the hunk can be reliably extracted?
- What exact keymap namespace should be used: compact `<leader>kr` actions or fully nested `<leader>kr...` actions?
