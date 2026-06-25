# ai-review-diffview-integration Specification

## Purpose
TBD - created by archiving change add-ai-review-workbench. Update Purpose after archive.
## Requirements
### Requirement: Open review ranges in diffview
The system SHALL open the selected review range using the existing diffview integration.

#### Scenario: Open commit range
- **WHEN** a review session starts for a commit range
- **THEN** the system opens diffview with the corresponding `base..head` range

#### Scenario: Open single commit
- **WHEN** a review session starts for a single commit
- **THEN** the system opens diffview for the selected commit against its parent

#### Scenario: Open worktree review
- **WHEN** a review session starts for worktree changes
- **THEN** the system opens diffview for the working tree with the configured staged, unstaged, and untracked behavior

### Requirement: Install review keymaps in diff buffers
The system SHALL install review-specific keymaps in diffview diff buffers without modifying diffview internals.

#### Scenario: Diff buffer is ready
- **WHEN** diffview emits a documented diff buffer hook for a review session
- **THEN** the system installs keymaps for adding comments, previewing comments, opening the review panel, and exporting review notes

### Requirement: Mark commented lines with signs
The system SHALL display signs on lines that have review comments in the active session.

#### Scenario: Comment is added
- **WHEN** a comment is successfully added to a diff line
- **THEN** the system places a review sign on the anchored line when that buffer is visible

#### Scenario: Diffview refreshes
- **WHEN** diffview reloads or re-enters a reviewed buffer
- **THEN** the system restores signs for comments whose anchors match the buffer

### Requirement: Preview comments with floating windows
The system SHALL allow users to preview comments associated with the current line in a floating window.

#### Scenario: Preview under cursor
- **WHEN** the user invokes the review preview action on a line with comments
- **THEN** the system opens a floating window showing comment severity, message, and anchor summary

#### Scenario: No comment under cursor
- **WHEN** the user invokes the review preview action on a line without comments
- **THEN** the system informs the user that no review comment exists at the current location

### Requirement: Fail gracefully without diffview
The system SHALL report a clear error when review diff display requires diffview but diffview is unavailable.

#### Scenario: Diffview missing
- **WHEN** the user starts a review session and `diffview.nvim` cannot be loaded
- **THEN** the system reports that diffview is required and does not create a misleading active diff state

