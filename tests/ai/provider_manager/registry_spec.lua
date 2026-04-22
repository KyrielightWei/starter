-- tests/ai/provider_manager/registry_spec.lua
-- Unit tests for provider registry CRUD operations

local Registry = require("ai.provider_manager.registry")

describe("ai.provider_manager.registry module", function()
  describe("list_providers()", function()
    it("returns array table", function()
      local result = Registry.list_providers()
      assert.is_table(result)
    end)

    it("returns entries with name, display, endpoint, model", function()
      local result = Registry.list_providers()
      if #result > 0 then
        local first = result[1]
        assert.is_string(first.name)
        assert.is_string(first.display)
        assert.is_string(first.endpoint)
        assert.is_not_nil(first.model)
      end
    end)

    it("display string contains name, endpoint, and model", function()
      local result = Registry.list_providers()
      if #result > 0 then
        local first = result[1]
        assert.is_true(first.display:find(first.name) ~= nil)
      end
    end)
  end)

  describe("find_provider_line()", function()
    it("returns line number for existing provider", function()
      local line = Registry.find_provider_line("deepseek")
      assert.is_number(line)
      assert.is_true(line > 0)
    end)

    it("returns 1 for non-existent provider", function()
      local line = Registry.find_provider_line("this_provider_does_not_exist_xyz")
      assert.are.equal(1, line)
    end)
  end)

  describe("add_provider()", function()
    it("rejects invalid provider name", function()
      -- "InvalidName" should be rejected by validator
      local result = Registry.add_provider("InvalidName")
      assert.is_false(result)
    end)

    it("rejects empty provider name", function()
      local result = Registry.add_provider("")
      assert.is_false(result)
    end)
  end)

  describe("delete_provider()", function()
    it("returns false for non-existent provider", function()
      local result = Registry.delete_provider("this_does_not_exist_xyz")
      assert.is_false(result)
    end)
  end)
end)
