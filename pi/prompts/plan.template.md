---
description: Create a detailed implementation plan before touching code
argument-hint: "<task-description>"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Plan                                                ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/prompts/plan.md                               ║
║  调用: /plan <task>                                                    ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Create an implementation plan for: $@

## Plan Structure

### 1. Problem Statement

- What needs to be done?
- Why is it needed?
- What are the constraints?

### 2. Current State

- What exists now?
- What works well?
- What needs improvement?

### 3. Proposed Solution

- High-level approach
- Key decisions
- Alternatives considered

### 4. Implementation Steps

Break down into ordered steps:

```
Step 1: [Description]
  - Files to modify: [...]
  - Expected outcome: [...]
  - Verification: [...]

Step 2: [Description]
  ...

Step N: [Description]
  ...
```

### 5. Testing Strategy

- Test files to create/modify
- Test cases to cover
- Verification commands

### 6. Risks and Mitigations

- What could go wrong?
- How to handle issues?
- Rollback strategy

### 7. Estimated Effort

- Time estimate
- Complexity rating
- Dependencies

## Output Format

Write the plan to `.planning/<task-name>.md`:

```markdown
# Implementation Plan: <task-name>

## Problem Statement
[What and why]

## Current State
[Current situation]

## Proposed Solution
[Approach]

## Implementation Steps

### Step 1: [Name]
- Files: [...]
- Changes: [...]
- Verification: [...]

### Step 2: ...

## Testing Strategy
[Tests]

## Risks
[Risks and mitigations]

## Effort
[Estimate]
```