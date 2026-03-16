-- tests/ai/state_spec.lua
-- Unit tests for state manager module

local State = require("ai.state")

describe("ai.state module", function()
  -- Clear state before each test
  before_each(function()
    State.clear()
  end)

  describe("get()", function()
    it("returns nil values initially", function()
      local result = State.get()
      assert.are.equal(nil, result.provider)
      assert.are.equal(nil, result.model)
    end)

    it("returns a table with provider and model keys", function()
      local result = State.get()
      assert.is_table(result)
      assert.is_not_nil(result.provider)
      assert.is_not_nil(result.model)
    end)
  end)

  describe("set()", function()
    it("sets provider and model", function()
      State.set("openai", "gpt-4")
      local result = State.get()
      assert.are.equal("openai", result.provider)
      assert.are.equal("gpt-4", result.model)
    end)

    it("overwrites previous values", function()
      State.set("openai", "gpt-4")
      State.set("deepseek", "deepseek-chat")
      local result = State.get()
      assert.are.equal("deepseek", result.provider)
      assert.are.equal("deepseek-chat", result.model)
    end)
  end)

  describe("subscribe()", function()
    it("calls callback on state change", function()
      local called = false
      State.subscribe(function()
        called = true
      end)

      State.set("openai", "gpt-4")

      assert.is_true(called)
    end)

    it("passes new state to callback", function()
      local received_state = nil
      State.subscribe(function(state)
        received_state = state
      end)

      State.set("deepseek", "deepseek-chat")

      assert.are.equal("deepseek", received_state.provider)
      assert.are.equal("deepseek-chat", received_state.model)
    end)

    it("supports multiple subscribers", function()
      local call_count = 0
      State.subscribe(function()
        call_count = call_count + 1
      end)
      State.subscribe(function()
        call_count = call_count + 1
      end)

      State.set("openai", "gpt-4")

      assert.are.equal(2, call_count)
    end)

    it("returns subscriber ID", function()
      local id = State.subscribe(function() end)
      assert.is_number(id)
    end)
  end)

  describe("unsubscribe()", function()
    it("removes subscriber", function()
      local called = false
      local id = State.subscribe(function()
        called = true
      end)

      State.unsubscribe(id)
      State.set("openai", "gpt-4")

      assert.is_false(called)
    end)

    it("returns true if subscriber existed", function()
      local id = State.subscribe(function() end)
      local result = State.unsubscribe(id)
      assert.is_true(result)
    end)

    it("returns false if subscriber did not exist", function()
      local result = State.unsubscribe(999)
      assert.is_false(result)
    end)
  end)

  describe("backward compatibility", function()
    it("_G.AI_MODEL reads from state", function()
      State.set("openai", "gpt-4")

      assert.are.equal("openai", _G.AI_MODEL.provider)
      assert.are.equal("gpt-4", _G.AI_MODEL.model)
    end)
  end)
end)
