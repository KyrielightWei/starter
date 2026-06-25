## 1. Module Skeleton and Command Registration

- [x] 1.1 Create `local-plugins/ai/lua/ai_review/` module structure with `init`, `range`, `session`, `store`, `comments`, `anchor`, `diffview`, `export`, and `panel` modules
- [x] 1.2 Register `:AIReviewStart`, `:AIReviewAdd`, `:AIReviewPanel`, `:AIReviewExport`, `:AIReviewStatus`, and `:AIReviewClose` in `local-plugins/ai/plugin/ai.lua`
- [x] 1.3 Add non-conflicting review keymaps under a dedicated `<leader>kr...` namespace
- [x] 1.4 Add module load smoke checks for the new `ai_review` modules

## 2. Project-local Storage

- [x] 2.1 Implement `.ai-review/` path resolution for repository-local storage
- [x] 2.2 Implement optional Neovim state-directory export path resolution
- [x] 2.3 Implement JSON read/write helpers with atomic writes in `ai_review.store`
- [x] 2.4 Implement backup behavior for malformed session JSON files
- [x] 2.5 Document `.ai-review/` storage and gitignore recommendation

## 3. Review Range Model

- [x] 3.1 Implement range data constructors for `single_commit`, `commit_range`, `since_base`, and `worktree`
- [x] 3.2 Implement range validation for commit SHAs and cached range reuse
- [x] 3.3 Implement conversion from range model to `DiffviewOpenEnhanced` arguments
- [x] 3.4 Ensure worktree ranges explicitly represent staged, unstaged, and untracked behavior
- [x] 3.5 Add unit tests for range construction, validation, and diffview argument generation

## 4. Review Session Lifecycle

- [x] 4.1 Implement session id generation and session metadata creation
- [x] 4.2 Implement active session pointer at `.ai-review/current.json`
- [x] 4.3 Implement session load, save, resume, status, and close operations
- [x] 4.4 Implement temporary session creation when adding a comment without active session
- [x] 4.5 Add unit tests for session create/load/save/resume/close and malformed JSON behavior

## 5. Comment and Anchor Model

- [x] 5.1 Implement comment creation with `note`, `must-fix`, `suggestion`, and `question` severities
- [x] 5.2 Implement comment status support for `open` and `resolved`
- [x] 5.3 Implement comment edit, delete, list, and resolve operations
- [x] 5.4 Implement anchor extraction from normal buffers and diffview buffers
- [x] 5.5 Capture file, side, meaning, line, line text, context before/after, optional hunk, commit/range, and partial-anchor state
- [x] 5.6 Add unit tests for comments and anchor extraction with mocked buffers

## 6. Diffview Integration

- [x] 6.1 Verify and correct diffview hook usage to documented `diff_buf_read` and `diff_buf_win_enter` hooks
- [x] 6.2 Implement review range opening through existing `DiffviewOpenEnhanced`
- [x] 6.3 Install review keymaps in diffview diff buffers during review sessions
- [x] 6.4 Implement review signs for lines with comments
- [x] 6.5 Implement sign restoration when diffview buffers are reloaded or re-entered
- [x] 6.6 Implement floating preview for comments under the cursor
- [x] 6.7 Add smoke tests or mocks for diffview missing, keymap install, sign placement, and preview behavior

## 7. Commit Picker Range Cache Integration

- [x] 7.1 Add review range cache writer for `.ai-review/ranges/last.json` and `.ai-review/ranges/ranges.json`
- [x] 7.2 Preserve normal Commit Picker default action for opening diffs
- [x] 7.3 Add an explicit Commit Picker review range selection mode or action for `:AIReviewStart`
- [x] 7.4 Validate cached range reuse before starting a session
- [x] 7.5 Add tests for range cache save/load/validate behavior

## 8. Review Panel

- [x] 8.1 Implement a minimal Review Panel showing active session range and comments
- [x] 8.2 Support jump to comment anchor where possible
- [x] 8.3 Support edit, delete, resolve, and export actions from the panel
- [x] 8.4 Handle partial anchors gracefully in panel display and jump behavior
- [x] 8.5 Add tests or smoke checks for panel rendering and action dispatch

## 9. Export

- [x] 9.1 Implement `notes.md` export with repository, range, timestamps, severity labels, anchors, context, and comments
- [x] 9.2 Implement `notes.json` export with complete structured session metadata
- [x] 9.3 Implement `fix-prompt.md` export that asks AI to evaluate, discuss, accept, reject, clarify, or modify comments as appropriate
- [x] 9.4 Support default project-local export and optional Neovim state-directory export
- [x] 9.5 Add unit tests for Markdown, JSON, and prompt export contents

## 10. Documentation and Verification

- [x] 10.1 Update AI plugin documentation with AI Review Workbench commands, keymaps, storage, and workflow
- [x] 10.2 Update Commit Picker documentation to explain review range cache behavior
- [x] 10.3 Run Stylua on changed Lua files
- [x] 10.4 Run the relevant Plenary tests for `ai_review` and affected Commit Picker tests
- [x] 10.5 Run a headless Neovim command-registration smoke test for new AI review commands
- [x] 10.6 Manually verify the MVP workflow: start review, open diffview, add comment, preview sign/float, export artifacts
