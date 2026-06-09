-- tests/ai/provider_manager/validator_spec.lua
-- Unit tests for provider name validator

local Validator = require("ai.provider_manager.validator")

describe("ai.provider_manager.validator module", function()
  describe("validate_provider_name()", function()
    it("rejects empty string", function()
      local valid, err = Validator.validate_provider_name("")
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.is_true(err:find("empty") ~= nil or err:find("Empty") ~= nil)
    end)

    it("rejects nil input", function()
      local valid, err = Validator.validate_provider_name(nil)
      assert.is_false(valid)
      assert.is_not_nil(err)
    end)

    it("rejects uppercase name", function()
      local valid, err = Validator.validate_provider_name("InvalidName")
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.is_true(err:find("lowercase") ~= nil or err:find("Lowercase") ~= nil)
    end)

    it("accepts valid kebab-case name", function()
      local valid, err = Validator.validate_provider_name("valid-provider")
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("accepts valid snake_case name", function()
      local valid, err = Validator.validate_provider_name("valid_provider")
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects name starting with number", function()
      local valid, err = Validator.validate_provider_name("123invalid")
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.is_true(err:find("letter") ~= nil or err:find("Letter") ~= nil)
    end)

    it("rejects existing provider name", function()
      local valid, err = Validator.validate_provider_name("deepseek")
      assert.is_false(valid)
      assert.is_not_nil(err)
      assert.is_true(err:find("already") ~= nil or err:find("exists") ~= nil)
    end)
  end)
end)
