---
description: Implement the feature using TDD workflow - write tests first
argument-hint: "<feature-description>"
---

<!--
╔════════════════════════════════════════════════════════════════════════╗
║  Prompt Template - Implement (TDD)                                     ║
║                                                                        ║
║  安装: 复制到 ~/.pi/agent/prompts/implement.md                          ║
║  调用: /implement <feature>                                            ║
╚════════════════════════════════════════════════════════════════════════╝
-->

Implement this feature using TDD: $@

## TDD Cycle

### 1. 🔴 Red: Write Failing Test

1. Understand requirements
2. Design API interface
3. Write test cases:
   - Normal input
   - Edge cases
   - Error handling
4. Run test - confirm it fails

### 2. 🟢 Green: Write Minimal Implementation

- Write minimal code to pass the test
- No extra features
- Can be "ugly" code

### 3. 🔵 Refactor: Clean Up Code

After tests pass:
- Check for duplication
- Optimize structure
- Improve naming
- Run tests after each change

## Test Structure

```lua
describe("module_name", function()
  describe("function_name", function()
    it("should do X", function()
      assert.are.equal(expected, actual)
    end)

    it("should handle edge case Y", function()
      -- edge case test
    end)

    it("should error on invalid Z", function()
      -- error handling test
    end)
  end)
end)
```

## Verification Commands

```bash
# Run tests
nvim --headless -c "PlenaryBustedDirectory tests/" -c "q"

# Format
stylua lua/

# Lint
luacheck lua/
```

## Output Format

After implementation:

```markdown
## TDD Complete

### Test File
[Path to test file]

### Test Cases
- [x] Normal input → [expected result]
- [x] Edge case → [expected result]
- [x] Error handling → [expected result]

### Implementation File
[Path to implementation]

### Test Status
All tests pass ✓
```