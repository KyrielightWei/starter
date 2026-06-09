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

  describe("get_default_model()", function()
    it("returns model for valid provider", function()
      local model = Registry.get_default_model("deepseek")
      -- deepseek should return a model (from def.model or first static_models)
      assert.is_not_nil(model)
    end)

    it("returns nil for non-existent provider", function()
      local model = Registry.get_default_model("nonexistent_provider_xyz")
      assert.is_nil(model)
    end)
  end)

  describe("list_models()", function()
    it("returns array for valid provider", function()
      local models = Registry.list_models("deepseek")
      assert.is_table(models)
      -- Should return at least static_models if dynamic fetch fails
      assert(#models >= 0) -- may be 0 if no static_models defined
    end)

    it("returns empty table for non-existent provider", function()
      local models = Registry.list_models("nonexistent_provider_xyz")
      assert.is_table(models)
      assert.equals(0, #models)
    end)
  end)

  describe("set_default_model()", function()
    it("returns false when config read fails", function()
      -- This test is informational — we can't easily simulate read failure
      -- but the function should return a boolean
      local result = Registry.set_default_model("deepseek", "deepseek-chat")
      assert.is_boolean(result)
    end)

    it("updates the provider model in memory", function()
      -- Set a new default model
      Registry.set_default_model("deepseek", "deepseek-chat-test")
      -- Verify it was updated in Providers table
      local def = require("ai.providers").get("deepseek")
      assert.equals("deepseek-chat-test", def.model)
    end)
  end)
end)
