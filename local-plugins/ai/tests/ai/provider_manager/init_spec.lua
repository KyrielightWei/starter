-- tests/ai/provider_manager/init_spec.lua
-- Tests for Provider Manager init orchestrator

describe("Provider Manager Init", function()
  it("module loads and exports setup()", function()
    local PM = require("ai.provider_manager")
    assert.is_table(PM)
    assert.is_function(PM.setup)
  end)

  it("setup returns module for chaining", function()
    local PM = require("ai.provider_manager")
    local result = PM.setup()
    assert.are_same(PM, result)
  end)

  it("exposes open function", function()
    local PM = require("ai.provider_manager")
    assert.is_function(PM.open)
  end)

  it("exposes show_help function", function()
    local PM = require("ai.provider_manager")
    assert.is_function(PM.show_help)
  end)

  it("picker is accessible via require path", function()
    local Picker = require("ai.provider_manager.picker")
    assert.is_function(Picker.open)
  end)
end)
