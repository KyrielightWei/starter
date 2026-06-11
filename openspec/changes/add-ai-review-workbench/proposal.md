## Why

AI tools can generate large code changes across multiple commits or the working tree, but the current Commit Picker only helps choose commits and open diffview. Review feedback is not captured, anchored to code, or exportable in a form that an AI tool can use to reason about follow-up changes.

This change introduces an AI Review Workbench that turns diff review into a structured session: reviewers can select a diff range, add anchored comments while viewing diffview, and export both human-readable notes and machine-readable metadata for AI-assisted iteration.

## What Changes

- Add a new `ai_review` module under the local AI plugin.
- Add a unified review entrypoint for starting review sessions over commit ranges, `base..HEAD`, or worktree changes.
- Persist review state in project-local `.ai-review/` files by default, with optional export to Neovim state storage.
- Extend Commit Picker so selected commit ranges can be cached for later review session startup without making Commit Picker responsible for review state.
- Integrate with `diffview.nvim` as the primary diff display layer.
- Add lightweight diffview review interactions: add comments from the current diff line, show signs for commented lines, and preview comments in floating windows.
- Store comments with code anchors that include file, side, line, line text, surrounding context, optional hunk text, related commit/range, and timestamps.
- Export review output as Markdown notes, JSON metadata, and an AI-oriented prompt that asks the AI to evaluate, discuss, or modify based on each comment.
- Add review commands and keymaps under the existing AI key namespace while avoiding current key conflicts.

No breaking changes are intended. Existing Commit Picker behavior should continue to work for opening diffs.

## Capabilities

### New Capabilities

- `ai-review-session`: Creating, resuming, storing, and closing project-local AI review sessions over commit or worktree ranges.
- `ai-review-comments`: Adding, anchoring, listing, editing, deleting, marking, and previewing review comments associated with diff lines or files.
- `ai-review-export`: Exporting review sessions as Markdown notes, JSON metadata, and AI follow-up prompts.
- `ai-review-diffview-integration`: Opening review ranges in diffview and overlaying review signs, floating previews, and review keymaps without modifying diffview internals.
- `commit-range-cache`: Caching Commit Picker-selected ranges in `.ai-review/ranges/` for reuse by review sessions.

### Modified Capabilities

- None.

## Impact

- Affected plugin code:
  - `local-plugins/ai/lua/ai_review/` new modules.
  - `local-plugins/ai/plugin/ai.lua` for commands and keymaps.
  - `local-plugins/ai/lua/commit_picker/` for optional review range cache integration.
  - `lua/plugins/git.lua` for diffview hook naming and review keymap integration, if needed.
- Affected docs:
  - AI plugin README/help docs.
  - Commit Picker guide or a new AI Review Workbench guide.
- Dependencies:
  - Reuses existing `diffview.nvim` and `fzf-lua` dependencies.
  - Does not introduce a new diff UI dependency.
- Data/storage:
  - Creates project-local `.ai-review/` directories containing session, range, notes, JSON, and prompt files.
  - The design should document whether `.ai-review/` should be ignored by git by default.
- Testing:
  - New tests under `local-plugins/ai/tests/ai_review/` for range, session, comments, anchors, export, and command registration behavior.
