## ADDED Requirements

### Requirement: Add anchored review comment
The system SHALL allow the user to add a review comment from the current diff or file location.

#### Scenario: Add comment from diff line
- **WHEN** the user places the cursor on a diff line and invokes `:AIReviewAdd`
- **THEN** the system records a comment in the active session with severity, message, timestamp, and code anchor metadata

#### Scenario: Add comment with default severity
- **WHEN** the user adds a comment without choosing a severity
- **THEN** the system stores the comment with severity `note`

### Requirement: Store content-first code anchors
The system SHALL store enough code context for each comment to remain understandable even when line numbers change.

#### Scenario: Anchor captures code context
- **WHEN** a comment is added from a code line
- **THEN** the anchor includes file path, side, line number, line text, up to three context lines before and after, related commit or range metadata, and creation time

#### Scenario: Anchor captures optional hunk
- **WHEN** the system can determine the surrounding diff hunk
- **THEN** the anchor includes the hunk text in the stored comment metadata

### Requirement: Support left and right side anchors
The system SHALL distinguish whether a comment refers to old-side or new-side code.

#### Scenario: Default to new side
- **WHEN** the user adds a comment from a normal new-side diff buffer or file buffer
- **THEN** the anchor side is stored as `right` with meaning `new`

#### Scenario: Bind deleted or old-side code
- **WHEN** the user adds a comment from an old-side or deleted-code location
- **THEN** the anchor side is stored as `left` with meaning `old`

### Requirement: Allow partial anchors
The system SHALL allow comment creation even when exact code position mapping is incomplete.

#### Scenario: Exact mapping fails
- **WHEN** the system cannot determine all anchor fields for the current location
- **THEN** it stores the comment with available fields and sets `anchor.partial` to `true`

### Requirement: Manage comments in a session
The system SHALL support listing, editing, deleting, and changing the status of comments in the active session.

#### Scenario: Delete comment
- **WHEN** the user deletes a comment from the review panel or command interface
- **THEN** the comment is removed from the active session and persisted to disk

#### Scenario: Edit comment
- **WHEN** the user edits a comment message or severity
- **THEN** the system updates the comment, updates its `updated_at` timestamp, and persists the session

#### Scenario: Resolve comment
- **WHEN** the user marks a comment resolved
- **THEN** the comment status is stored as `resolved`
