-- tests/ai/skill_studio_spec.lua
-- Tests for skill_studio module

describe("skill_studio", function()
  local Backup
  local Validator
  local Converter
  local Reviewer

  before_each(function()
    package.loaded["ai.skill_studio.backup"] = nil
    package.loaded["ai.skill_studio.validator"] = nil
    package.loaded["ai.skill_studio.converter"] = nil
    package.loaded["ai.skill_studio.reviewer"] = nil

    Backup = require("ai.skill_studio.backup")
    Validator = require("ai.skill_studio.validator")
    Converter = require("ai.skill_studio.converter")
    Reviewer = require("ai.skill_studio.reviewer")

    Backup.setup(vim.fn.getcwd() .. "/tests/tmp/backups")
  end)

  after_each(function()
    vim.fn.delete(vim.fn.getcwd() .. "/tests/tmp", "rf")
  end)

  describe("backup", function()
    it("should save and load items", function()
      local item = {
        type = "skill",
        target = "claude",
        level = "project",
        frontmatter = {
          name = "test-skill",
          description = "A test skill",
        },
        body = "Test content",
      }

      local id = Backup.save(item)
      assert.is_not_nil(id)
      assert.is_true(id:match("^skill_") ~= nil)

      local loaded = Backup.load(id)
      assert.are.same(item.frontmatter.name, loaded.frontmatter.name)
      assert.are.same(item.body, loaded.body)
    end)

    it("should list saved items", function()
      local item = {
        type = "skill",
        target = "claude",
        level = "project",
        frontmatter = { name = "list-test-skill" },
        body = "Content",
      }

      Backup.save(item)
      local list = Backup.list()

      assert.is_true(#list >= 1)
    end)

    it("should delete items", function()
      local item = {
        type = "skill",
        target = "claude",
        level = "project",
        frontmatter = { name = "delete-test" },
      }

      local id = Backup.save(item)
      assert.is_true(Backup.delete(id))

      local loaded = Backup.load(id)
      assert.is_nil(loaded)
    end)

    it("should update items", function()
      local item = {
        type = "skill",
        target = "claude",
        level = "project",
        frontmatter = { name = "update-test" },
        body = "Original",
      }

      local id = Backup.save(item)

      item.body = "Updated"
      Backup.update(id, item)

      local loaded = Backup.load(id)
      assert.are.same("Updated", loaded.body)
    end)
  end)

  describe("validator", function()
    it("should validate skill name format", function()
      local valid_skill = {
        type = "skill",
        frontmatter = {
          name = "valid-skill-name",
          description = "A valid skill description that is long enough for validation",
        },
        body = "This is the skill body with enough content to pass validation.",
      }

      local result = Validator.validate(valid_skill)
      assert.is_true(result.valid)
    end)

    it("should reject invalid skill names", function()
      local invalid_skill = {
        type = "skill",
        frontmatter = {
          name = "Invalid Name!",
          description = "Description",
        },
        body = "Body content",
      }

      local result = Validator.validate(invalid_skill)
      assert.is_false(result.valid)
    end)

    it("should validate MCP configuration", function()
      local valid_mcp = {
        type = "mcp",
        config = {
          test_server = {
            type = "stdio",
            command = "npx",
            args = { "-y", "test-server" },
          },
        },
      }

      local result = Validator.validate(valid_mcp)
      assert.is_true(result.valid)
    end)

    it("should reject MCP without required fields", function()
      local invalid_mcp = {
        type = "mcp",
        config = {
          test_server = {
            type = "stdio",
          },
        },
      }

      local result = Validator.validate(invalid_mcp)
      assert.is_false(result.valid)
    end)
  end)

  describe("converter", function()
    it("should convert Claude skill to OpenCode format", function()
      local claude_skill = {
        type = "skill",
        target = "claude",
        level = "project",
        frontmatter = {
          name = "test-skill",
          description = "A test skill",
          version = "1.0.0",
        },
        body = "Skill content",
      }

      local opencode_skill = Converter.convert(claude_skill, "opencode")

      assert.are.same("opencode", opencode_skill.target)
      assert.are.same("opencode", opencode_skill.frontmatter.compatibility)
    end)

    it("should convert OpenCode skill to Claude format", function()
      local opencode_skill = {
        type = "skill",
        target = "opencode",
        level = "project",
        frontmatter = {
          name = "test-skill",
          description = "A test skill",
          compatibility = "opencode",
        },
        body = "Skill content",
      }

      local claude_skill = Converter.convert(opencode_skill, "claude")

      assert.are.same("claude", claude_skill.target)
      assert.is_nil(claude_skill.frontmatter.compatibility)
    end)

    it("should convert MCP config between formats", function()
      local claude_mcp = {
        type = "mcp",
        target = "claude",
        level = "project",
        config = {
          test = {
            type = "stdio",
            command = "npx",
            args = { "-y", "test" },
          },
        },
      }

      local opencode_mcp = Converter.convert(claude_mcp, "opencode")

      assert.are.same("local", opencode_mcp.config.test.type)
    end)
  end)

  describe("reviewer", function()
    it("should review skill and return score", function()
      local skill = {
        type = "skill",
        frontmatter = {
          name = "well-named-skill",
          description = "Use this when you need to perform a specific task with clear guidance.",
        },
        body = [[
## When This Skill Applies
Use when doing X.

## Instructions
1. Step one
2. Step two

## Examples
Example: input -> output
]],
      }

      local result = Reviewer.review(skill)
      assert.is_true(result.valid)
      assert.is_true(result.score > 50)
    end)

    it("should generate improvement suggestions", function()
      local weak_skill = {
        type = "skill",
        frontmatter = {
          name = "bad",
          description = "short",
        },
        body = "minimal",
      }

      local improvements = Reviewer.get_improvements(weak_skill)
      assert.is_true(#improvements > 0)
    end)

    it("should generate review report", function()
      local skill = {
        type = "skill",
        frontmatter = {
          name = "report-skill",
          description = "Use when generating reports with proper formatting.",
        },
        body = "## When to use\nUse for reports.\n\n## Instructions\n1. Format\n2. Output",
      }

      local report = Reviewer.generate_report(skill)
      assert.is_true(report:find("Review Report") ~= nil)
      assert.is_true(report:find("Score") ~= nil)
    end)
  end)
end)