# Phase 04 Execution Summary: Commit Diff Review

## One-liner

Users can open a floating fzf-lua commit picker (defaulting to unpushed commits), select 1-2 commits, and view diffs in diffview.nvim via `<leader>kC` or `:AICommitPicker`.

## Requirements Delivered

| Requirement | Status | Evidence |
|-------------|--------|----------|
| CDRV-01: Unpushed commit picker with fallback | ✅ | git.get_unpushed() defaults to origin/HEAD..HEAD; get_commit_list() falls back to last 20 |
| CDRV-02: Diff review via picker | ✅ | Selection → Diff.open_diff() opens DiffviewOpenEnhanced with correct git range |

## Success Criteria

| # | Criterion | Status |
|---|-----------|--------|
| 1 | User can open a floating window commit picker to select commits for review | ✅ `<leader>kC` / `:AICommitPicker` |
| 2 | Picker defaults to unpushed commits (origin/HEAD..HEAD) for workflow continuity | ✅ git.get_unpushed() with fallback to last 20 |

## Files Created

- `lua/commit_picker/__init__.lua` — Package init (4 lines)
- `lua/commit_picker/git.lua` — Git data fetching (122 lines)
- `lua/commit_picker/display.lua` — fzf-lua picker UI (108 lines)
- `lua/commit_picker/selection.lua` — Selection state (50 lines)
- `lua/commit_picker/diff.lua` — Diffview integration (68 lines)
- `lua/commit_picker/init.lua` — Entry point wiring (95 lines)

## Files Modified

- `lua/ai/init.lua` — Added `<leader>kC` keymap to keys table and commit_picker setup() call

## Commits

| Commit | Message |
|--------|---------|
| 3d0e8cd | feat(04-01): create git.lua and display.lua for commit picker |
| d7ef02b | feat(04-02): create selection.lua and diff.lua for commit review |
| 8d4274a | feat(04-03): create init.lua entry point and wire into AI module |

## Verification Results

All 3 waves passed automated verification:

| Wave | Test | Result |
|------|------|--------|
| 1 | git.lua get_ahead_behind() | ✅ { ahead = 89, behind = 0 } |
| 1 | display.lua exports | ✅ show_picker, close functions |
| 2 | selection.lua state | ✅ get/set/clear/has_selection OK |
| 2 | diff.lua exports | ✅ open_diff function |
| 3 | init.lua exports | ✅ setup and open functions |
| 3 | ai/init.lua integration | ✅ No errors on setup |
| E2E | SHA extraction | ✅ Display line → short_sha match |
| E2E | Unpushed detection | ✅ 92 unpushed commits found |

## Architecture

```
lua/commit_picker/
├── __init__.lua      ← Package init (empty)
├── init.lua          ← Entry point: open(), setup(), get_modules()
├── git.lua           ← Git ops: get_commit_list, get_unpushed, get_ahead_behind
├── display.lua       ← fzf-lua picker: show_picker, close
├── selection.lua     ← State: get/set/clear/has_selection
└── diff.lua          ← Diff: open_diff (DiffviewOpenEnhanced)
```

**User flow:**
1. Press `<leader>kC` or run `:AICommitPicker`
2. `M.open()` fetches unpushed commits via `Git.get_unpushed()`
3. If empty, fallback to last 20 commits with info notification
4. `Display.show_picker()` opens fzf-lua picker with formatted commits
5. User selects (multi-select with ctrl-space), presses `<CR>`
6. `Selection.set_selected()` stores SHAs (max 2)
7. `Diff.open_diff()` opens diffview with sha^..sha or sha1..sha2

## Deviations from Plan

| # | Rule | Type | Description |
|---|------|------|-------------|
| 1 | Rule 2 | Modernization | Used `vim.system()` instead of `io.popen()` (per execution rules) |
| 2 | Rule 2 | Robustness | Used NUL-separated git format for parsing (handles multi-line subjects) |
| 3 | Rule 2 | UX | Added static `<leader>kC` keymap in ai/init.lua keys table for which-key grouping |

## Known Limitations

1. **Highlight format**: The `highlight_callback` uses ANSI escape sequences. May need adjustment if fzf-lua version differs from expected API.
2. **Preview sync**: fzf-lua preview callback is synchronous; `vim.system():wait()` is used. Very large commits with many files may briefly block during preview rendering.
3. **No range customization**: Picker always defaults to unpushed or last 20 — cannot specify custom range (belongs to Phase 5).
4. **No single vs two-commit UX indicator**: When user selects 2+ commits, no visual indicator that range diff will be shown — belongs to Phase 6 (CDRV-05, CDRV-06).
5. **No persistence**: Selection state is module-local and resets between invocations.

## Threat Flags

None — all threat mitigations applied:
- T-04-01: Static git commands, no user input interpolation
- T-04-05: SHA validation (7-40 hex chars) before vim.cmd
- T-04-06: Graceful diffview unavailability fallback

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| No new trust boundaries | All | Only reads git log data (public), passes validated SHAs to diffview |

## Next Steps for Phase 5/6

### Phase 5: Commit Picker Configuration (CDRV-03, CDRV-04)
- Allow user to configure picker range (e.g., last N commits, specific branch, date range)
- Persist picker preferences

### Phase 6: Navigation Experience (CDRV-05, CDRV-06)
- Single vs two-commit mode indicator in picker
- Navigate between commits within the selected range
- Commit message display alongside diff

## Self-Check: PASSED
