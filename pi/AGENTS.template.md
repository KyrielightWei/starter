# Agent Instructions

## Style
- Use concise, idiomatic code
- Follow existing patterns in the codebase
- Avoid unnecessary abstractions
- Chinese comments in code (maintain repo convention)
- Double quotes for strings, 2-space indent

## Tools
- Use `read` before `edit` or `write`
- Run verification after changes
- Never suppress type errors with `as any` or `@ts-ignore`
- Never commit secrets

## Git
- Atomic commits with clear conventional commit messages
- Never commit secrets or credentials
- Stage only intended files

## Workflow
- Ask before implementing ambiguous requests
- Verify changes with build/lint commands
- Keep functions small, files focused
