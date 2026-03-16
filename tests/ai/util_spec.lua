-- tests/ai/util_spec.lua
-- Unit tests for util.lua

local Util = require("ai.util")

describe("ai.util module", function()
  describe("merge_table()", function()
    it("merges two tables", function()
      local a = { x = 1 }
      local b = { y = 2 }
      local result = Util.merge_table(a, b)

      assert.are.equal(1, result.x)
      assert.are.equal(2, result.y)
    end)

    it("overwrites values in a with values from b", function()
      local a = { x = 1, y = 1 }
      local b = { y = 2 }
      local result = Util.merge_table(a, b)

      assert.are.equal(1, result.x)
      assert.are.equal(2, result.y)
    end)

    it("handles nil first argument", function()
      local b = { y = 2 }
      local result = Util.merge_table(nil, b)

      assert.are.equal(2, result.y)
    end)

    it("handles nil second argument", function()
      local a = { x = 1 }
      local result = Util.merge_table(a, nil)

      assert.are.equal(1, result.x)
    end)
  end)

  describe("beautify_model_item()", function()
    it("returns label and id from model item", function()
      local m = { id = "gpt-4", owned_by = "openai", created = 1234567890 }
      local label, id = Util.beautify_model_item(m)

      assert.are.equal("gpt-4", id)
      assert.is_string(label)
      assert.is_true(label:find("gpt-4") ~= nil)
    end)

    it("handles model item without id", function()
      local m = { owned_by = "test" }
      local label, id = Util.beautify_model_item(m)

      assert.is_string(id)
      assert.is_string(label)
    end)

    it("handles model item as string", function()
      local label, id = Util.beautify_model_item("simple-model")

      assert.are.equal("simple-model", id)
      assert.is_string(label)
    end)
  end)

  describe("get_env_var()", function()
    it("returns API key env var for provider", function()
      local env_var = Util.get_env_var("deepseek")
      assert.are.equal("DEEPSEEK_API_KEY", env_var)
    end)

    it("returns OPENAI_API_KEY for unknown provider", function()
      local env_var = Util.get_env_var("unknown_provider")
      assert.are.equal("OPENAI_API_KEY", env_var)
    end)
  end)

  describe("env_var_map", function()
    it("is a table", function()
      assert.is_table(Util.env_var_map)
    end)

    it("contains entries for registered providers", function()
      assert.is_not_nil(Util.env_var_map.deepseek)
      assert.is_not_nil(Util.env_var_map.openai)
    end)
  end)
end)
