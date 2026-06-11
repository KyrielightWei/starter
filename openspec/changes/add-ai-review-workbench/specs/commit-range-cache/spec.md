## ADDED Requirements

### Requirement: Cache review ranges selected by Commit Picker
The system SHALL cache Commit Picker-selected review ranges in the project-local `.ai-review/ranges/` directory.

#### Scenario: Save last review range
- **WHEN** the user selects a commit or commit range for review from Commit Picker
- **THEN** the system writes `.ai-review/ranges/last.json` with the selected range, selected commits, repository path, and timestamp

#### Scenario: Append range history
- **WHEN** the user saves a review range from Commit Picker
- **THEN** the system appends or updates the range in `.ai-review/ranges/ranges.json`

### Requirement: Preserve normal Commit Picker diff behavior
The system SHALL preserve existing Commit Picker behavior for opening diffs.

#### Scenario: Open diff from Commit Picker
- **WHEN** the user selects commits in normal Commit Picker mode and presses the default action
- **THEN** the system opens the diff as before and does not require a review session

### Requirement: Support review range selection mode
The system SHALL provide a review-specific Commit Picker mode or action that returns a range for review session startup.

#### Scenario: Select range during review start
- **WHEN** `:AIReviewStart` asks the user to choose a new commit range
- **THEN** Commit Picker can run in review range mode and return the selected range to the review workflow instead of only opening diffview

### Requirement: Validate cached ranges before reuse
The system SHALL validate cached review ranges before using them to start a session.

#### Scenario: Cached range exists
- **WHEN** the user chooses the most recent cached range in `:AIReviewStart`
- **THEN** the system verifies the referenced commits or range are still valid in the repository before creating the session

#### Scenario: Cached range is invalid
- **WHEN** the cached range cannot be validated
- **THEN** the system reports the issue and asks the user to choose another range
