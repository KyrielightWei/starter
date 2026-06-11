## ADDED Requirements

### Requirement: Start review session from unified entrypoint
The system SHALL provide a unified review entrypoint that creates an AI review session for a selected review range.

#### Scenario: Start session from cached range
- **WHEN** the user runs `:AIReviewStart` and chooses the most recent cached Commit Picker range
- **THEN** the system creates an active review session using that range and opens the corresponding diff view

#### Scenario: Start session from worktree
- **WHEN** the user runs `:AIReviewStart` and chooses worktree review
- **THEN** the system creates an active review session for staged, unstaged, and untracked changes unless the user selects a narrower worktree scope

### Requirement: Persist project-local session state
The system SHALL persist review sessions under a project-local `.ai-review/sessions/<session-id>/session.json` path by default.

#### Scenario: Session is created
- **WHEN** a review session starts
- **THEN** the system writes a session file containing id, timestamps, repository path, review range, and an empty comments list

#### Scenario: Active session pointer is updated
- **WHEN** a review session becomes active
- **THEN** the system writes `.ai-review/current.json` with the active session id

### Requirement: Auto-create temporary session when adding a comment without active session
The system SHALL create a temporary review session if the user adds a review comment without an active session.

#### Scenario: Add comment without active session
- **WHEN** the user invokes comment creation from a diff buffer and no active session exists
- **THEN** the system creates a temporary active session and stores the new comment in it

### Requirement: Support explicit review range types
The system SHALL represent review ranges as explicit typed data structures.

#### Scenario: Commit range session
- **WHEN** a session is created for two commits
- **THEN** the stored range has type `commit_range` and includes `base` and `head` SHAs

#### Scenario: Worktree session
- **WHEN** a session is created for worktree review
- **THEN** the stored range has type `worktree` and includes flags for staged, unstaged, and untracked changes

### Requirement: Handle storage errors safely
The system SHALL not silently lose review data when session storage fails.

#### Scenario: Session write fails
- **WHEN** the system cannot write the session file
- **THEN** it reports an error and keeps the user-entered data available in memory for retry where possible

#### Scenario: Session JSON is malformed
- **WHEN** the active session file cannot be parsed
- **THEN** the system preserves a backup of the malformed file and reports the problem before creating or selecting a replacement session
