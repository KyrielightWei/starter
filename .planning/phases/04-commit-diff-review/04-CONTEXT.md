## Phase 4 Context

### Phase Description
**Commit Diff Review** - Users can review diffs and track progress across multiple commits in a GSD workflow.

### User Decisions

#### Locked
- **E-01**: Use fzf-lua as picker (same as Phase 1 Provider Manager)
- **E-02**: Commit picker defaults to unpushed commits (origin/HEAD..HEAD)
- **E-03**: Single commit = diff against parent; Two commits = diff between them
- **E-04**: Use nvim-diffview.nvim for diff display

#### Assumptions (the agent's discretion)
- Git commands (`git log`, `git diff`, `git rev-list`) available and compatible
- Picker window centered, sized similar to Phase 1 provider manager
- Diff display uses existing diffview.nvim integration pattern
- Phase 4 and Phase 5/6 are sequential (Phase 4 first, then config, then navigation)

### Requirements from ROADMAP
- **CDRV-01**: Commit picker with unpushed default
- **CDRV-02**: Diff view for selected commits

### External Dependencies
- `fzf-lua` (already installed)
- `sindrets/diffview.nvim` (already installed per STACK.md)
- `git` CLI (>= 2.31 per STACK.md)
