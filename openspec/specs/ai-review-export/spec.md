# ai-review-export Specification

## Purpose
TBD - created by archiving change add-ai-review-workbench. Update Purpose after archive.
## Requirements
### Requirement: Export review notes as Markdown
The system SHALL export a human-readable Markdown review summary for the active session.

#### Scenario: Export notes markdown
- **WHEN** the user runs `:AIReviewExport`
- **THEN** the system writes `notes.md` containing repository, review range, timestamps, comment count, and all comments grouped or labeled with severity and code anchors

### Requirement: Export structured review metadata as JSON
The system SHALL export complete structured review metadata for the active session.

#### Scenario: Export notes json
- **WHEN** the user runs `:AIReviewExport`
- **THEN** the system writes `notes.json` containing the session id, repository, range, comments, anchors, statuses, severities, and timestamps

### Requirement: Export AI follow-up prompt
The system SHALL export an AI-oriented prompt that asks an AI tool to evaluate review comments and act appropriately.

#### Scenario: Export fix prompt
- **WHEN** the user runs `:AIReviewExport`
- **THEN** the system writes `fix-prompt.md` containing instructions to evaluate each comment as accepted, rejected, needing discussion, or needing clarification before modifying code

#### Scenario: Prompt does not require every comment to be modified
- **WHEN** the prompt includes comments with severity `suggestion`, `question`, or `note`
- **THEN** the prompt instructs the AI to reason about whether code changes are appropriate instead of blindly applying all comments

### Requirement: Support export destination selection
The system SHALL export to the project-local session directory by default and allow export to Neovim state storage when requested.

#### Scenario: Default project export
- **WHEN** the user exports without choosing a destination
- **THEN** the system writes export files under `.ai-review/sessions/<session-id>/`

#### Scenario: Local state export
- **WHEN** the user chooses local state export
- **THEN** the system writes export files under a repository-specific path in Neovim state storage

### Requirement: Preserve traceability in exports
The system SHALL include source traceability in every exported review comment.

#### Scenario: Comment traceability
- **WHEN** a comment is exported
- **THEN** the exported comment includes its id, creation time, severity, status, file, side, line, line text, context, and related commit or range information

