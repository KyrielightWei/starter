---
description: Explain the code module in detail with examples
argument-hint: "<module-or-file>"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Explain                                             ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/prompts/explain.md                            ║
║  调用: /explain <module>                                               ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Explain this code in detail: $@

## Explanation Structure

### 1. Overview

- What is this module?
- What problem does it solve?
- Where is it used?

### 2. Public API

List all exported functions with:
- Function signature
- Parameter descriptions
- Return value
- Example usage

### 3. Key Concepts

- Core algorithms
- Design patterns
- Data structures
- Dependencies

### 4. Code Walkthrough

Walk through important functions:
- Input processing
- Core logic
- Output generation
- Error handling

### 5. Examples

Provide concrete examples:
- Basic usage
- Common patterns
- Edge cases

### 6. Gotchas

- Common mistakes
- Performance considerations
- Thread safety (if applicable)
- Breaking changes history

## Output Format

```markdown
## Module: <name>

### Overview
[Brief description]

### Public API

#### `function_name(param1, param2)`
- `param1` (type): Description
- `param2` (type): Description
- Returns: type - Description
- Example:
  ```lua
  local result = module.function_name(arg1, arg2)
  ```

### Key Concepts
[Concepts and patterns]

### Examples
[Concrete examples]

### Gotchas
[Common issues]
```