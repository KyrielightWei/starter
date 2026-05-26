---
description: Create a well-structured git commit with conventional commit format
argument-hint: "[message]"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Commit                                              ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/prompts/commit.md                             ║
║  调用: /commit [message]                                               ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Create a commit for the staged changes.

$@

## Process

### 1. Review Changes

```bash
git diff --cached --stat
git diff --cached
```

### 2. Craft Commit Message

Use conventional commit format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactor (no feature/fix)
- `docs`: Documentation
- `style`: Formatting (no code change)
- `test`: Adding tests
- `chore`: Maintenance

**Scopes:**
- Module name
- Component name
- Feature area

### 3. Commit

```bash
git commit -m "type(scope): description"
```

## Guidelines

- Atomic commit (one logical change)
- Clear, descriptive message
- Reference issues/PRs if applicable
- No secrets or credentials

## Example Messages

```
feat(ai): add model switching command

Add /model command to switch between providers and models.
Supports Ctrl+P cycling through scoped models.

fix(state): correct state restoration on branch switch

State was not correctly restored when switching branches
in /tree view. Now properly reconstructs from session.

refactor(providers): simplify provider registration

Extract common logic into helper function. No behavior change.

docs(README): update installation instructions

Add note about --ignore-scripts flag.

test(state): add unit tests for state manager

Cover get, set, subscribe, and branch restoration.
```