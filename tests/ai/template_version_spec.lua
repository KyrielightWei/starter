-- tests/ai/template_version_spec.lua
-- Unit tests for template version manager module

local assert = require("luassert")

describe("TemplateVersion module", function()
  local TV = require("ai.template_version")

  describe("path helpers", function()
    it("returns correct templates directory", function()
      local dir = TV.get_templates_dir()
      assert.is_true(dir:match("templates") ~= nil)
    end)

    it("returns correct tool directory", function()
      local dir = TV.get_tool_templates_dir("opencode")
      assert.is_true(dir:match("templates/opencode") ~= nil)
    end)

    it("returns correct template path", function()
      local path = TV.get_template_path("opencode", "default")
      assert.is_true(path:match("templates/opencode/default.template.jsonc") ~= nil)
    end)
  end)

  describe("version discovery", function()
    it("list returns empty for nonexistent tool", function()
      local versions = TV.list("nonexistent_tool_xyz")
      assert.are.same({}, versions)
    end)

    it("exists returns false for nonexistent version", function()
      assert.is_false(TV.exists("opencode", "nonexistent_xyz"))
    end)
  end)

  describe("CRUD operations", function()
    local test_tool = "test_tool_crud"
    local test_version = "test_version"

    after_each(function()
      -- Cleanup test artifacts
      local dir = TV.get_tool_templates_dir(test_tool)
      if vim.fn.isdirectory(dir) == 1 then
        vim.fn.delete(dir, "d")
      end
    end)

    it("create creates minimal template without source", function()
      local ok, result = TV.create(test_tool, test_version)
      assert.is_true(ok)
      assert.is_true(TV.exists(test_tool, test_version))
    end)

    it("create fails for existing version", function()
      TV.create(test_tool, test_version)
      local ok, err = TV.create(test_tool, test_version)
      assert.is_false(ok)
      assert.is_true(err:match("already exists") ~= nil)
    end)

    it("create copies from source when provided", function()
      TV.create(test_tool, "source_version")
      local ok = TV.create(test_tool, "copy_version", "source_version")
      assert.is_true(ok)
      assert.is_true(TV.exists(test_tool, "copy_version"))
    end)

    it("delete removes version", function()
      TV.create(test_tool, test_version)
      local ok, result = TV.delete(test_tool, test_version)
      assert.is_true(ok)
      assert.is_false(TV.exists(test_tool, test_version))
    end)

    it("delete fails for default version", function()
      TV.create(test_tool, "default")
      local ok, err = TV.delete(test_tool, "default")
      assert.is_false(ok)
      assert.is_true(err:match("Cannot delete default") ~= nil)
    end)

    it("rename changes version name", function()
      TV.create(test_tool, "old_name")
      local ok, result = TV.rename(test_tool, "old_name", "new_name")
      assert.is_true(ok)
      assert.is_true(TV.exists(test_tool, "new_name"))
      assert.is_false(TV.exists(test_tool, "old_name"))
    end)

    it("rename fails when target exists", function()
      TV.create(test_tool, "version1")
      TV.create(test_tool, "version2")
      local ok, err = TV.rename(test_tool, "version1", "version2")
      assert.is_false(ok)
      assert.is_true(err:match("already exists") ~= nil)
    end)

    it("copy creates duplicate", function()
      TV.create(test_tool, "source")
      local ok, result = TV.copy(test_tool, "source", "target")
      assert.is_true(ok)
      assert.is_true(TV.exists(test_tool, "target"))
    end)

    it("copy fails when target exists", function()
      TV.create(test_tool, "source")
      TV.create(test_tool, "target")
      local ok, err = TV.copy(test_tool, "source", "target")
      assert.is_false(ok)
      assert.is_true(err:match("already exists") ~= nil)
    end)
  end)

  describe("security validation", function()
    it("detects API key pattern", function()
      local content = '{"api_key": "sk-123456"}'
      local ok, warnings = TV.validate_security(content)
      assert.is_false(ok)
      assert.is_true(#warnings > 0)
    end)

    it("detects secret pattern", function()
      local content = '{"secret_token": "abc"}'
      local ok, warnings = TV.validate_security(content)
      assert.is_false(ok)
      assert.is_true(#warnings > 0)
    end)

    it("passes for safe content", function()
      local content = '{"model": "gpt-4"}'
      local ok, warnings = TV.validate_security(content)
      assert.is_true(ok)
      assert.are.same({}, warnings)
    end)
  end)

  describe("migration", function()
    it("check_migration_needed returns false when no legacy", function()
      -- Use a tool that definitely has no legacy file
      local needed = TV.check_migration_needed("nonexistent_xyz")
      assert.is_false(needed)
    end)
  end)
end)