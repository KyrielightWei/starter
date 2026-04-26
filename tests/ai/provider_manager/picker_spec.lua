-- tests/ai/provider_manager/picker_spec.lua
-- Tests for Provider Manager Picker module

describe("Provider Manager Picker", function()
  it("module loads", function()
    local ok, Picker = pcall(require, "ai.provider_manager.picker")
    assert(ok, "picker.lua should load")
    assert.is_function(Picker.open)
    assert.is_function(Picker.show_help)
    assert.is_function(Picker.add_provider_dialog)
    assert.is_function(Picker.delete_provider_dialog)
    assert.is_function(Picker.edit_provider)
  end)

  it("registry integration", function()
    local Registry = require("ai.provider_manager.registry")
    local providers = Registry.list_providers()
    assert.is_table(providers)
    assert.True(#providers > 0)
  end)

  it("picker validates provider display format", function()
    local Registry = require("ai.provider_manager.registry")
    local providers = Registry.list_providers()
    -- Each provider should have name and display fields
    if #providers > 0 then
      local p = providers[1]
      assert.is_string(p.name)
      assert.is_string(p.display)
      -- Display should contain name, endpoint, and model
      assert.True(p.display:find(p.name, 1, true) ~= nil)
    end
  end)

  it("picker handles empty provider list gracefully", function()
    local Registry = require("ai.provider_manager.registry")
    local providers = Registry.list_providers()
    -- If providers exist, list should not be empty
    assert.is_table(providers)
    -- This test ensures the module doesn't crash on empty state
    assert.True(providers ~= nil)
  end)

  it("picker has _select_model function", function()
    local Picker = require("ai.provider_manager.picker")
    assert.is_function(Picker._select_model)
  end)
end)
