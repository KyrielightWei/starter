-- tests/ai/providers_spec.lua
-- Unit tests for providers.lua

local Providers = require("ai.providers")

describe("ai.providers module", function()
  describe("register()", function()
    it("registers a provider with config", function()
      Providers.register("test_provider", {
        api_key_name = "TEST_API_KEY",
        endpoint = "https://test.example.com",
        model = "test-model",
      })

      assert.is_table(Providers.test_provider)
      assert.are.equal("TEST_API_KEY", Providers.test_provider.api_key_name)
      assert.are.equal("https://test.example.com", Providers.test_provider.endpoint)
      assert.are.equal("test-model", Providers.test_provider.model)
    end)

    it("sets default timeout to 30000", function()
      Providers.register("timeout_test", {
        api_key_name = "TIMEOUT_KEY",
        endpoint = "https://timeout.example.com",
        model = "timeout-model",
      })

      assert.are.equal(30000, Providers.timeout_test.timeout)
    end)

    it("allows custom timeout", function()
      Providers.register("custom_timeout", {
        api_key_name = "CUSTOM_KEY",
        endpoint = "https://custom.example.com",
        model = "custom-model",
        timeout = 60000,
      })

      assert.are.equal(60000, Providers.custom_timeout.timeout)
    end)
  end)

  describe("list()", function()
    it("returns a table of provider names", function()
      local list = Providers.list()
      assert.is_table(list)
    end)

    it("includes registered providers", function()
      Providers.register("list_test", {
        api_key_name = "LIST_KEY",
        endpoint = "https://list.example.com",
        model = "list-model",
      })

      local list = Providers.list()
      local found = false
      for _, name in ipairs(list) do
        if name == "list_test" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("get()", function()
    it("returns provider config by name", function()
      Providers.register("get_test", {
        api_key_name = "GET_KEY",
        endpoint = "https://get.example.com",
        model = "get-model",
      })

      local config = Providers.get("get_test")
      assert.is_table(config)
      assert.are.equal("GET_KEY", config.api_key_name)
    end)

    it("returns nil for non-existent provider", function()
      local config = Providers.get("non_existent_provider")
      assert.is_nil(config)
    end)
  end)

  describe("default values", function()
    it("has default_provider set", function()
      assert.is_string(Providers.default_provider)
    end)

    it("has default_model set", function()
      assert.is_string(Providers.default_model)
    end)
  end)
end)
