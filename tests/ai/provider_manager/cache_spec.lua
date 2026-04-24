-- tests/ai/provider_manager/cache_spec.lua
-- Unit tests for provider manager cache module

local Cache = require("ai.provider_manager.cache")

describe("ai.provider_manager.cache module", function()
  local cache_dir
  local cache_file

  before_each(function()
    cache_dir = vim.fn.stdpath("state")
    cache_file = cache_dir .. "/ai_detection_cache.lua"
    Cache.clear()
  end)

  after_each(function()
    Cache.clear()
  end)

  describe("get()", function()
    it("returns nil when no cached result exists", function()
      local result = Cache.get("openai", "gpt-4")
      assert.is_nil(result)
    end)
  end)

  describe("set() and get()", function()
    it("stores result and retrieves it", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "" })
      local result = Cache.get("openai", "gpt-4")
      assert.is_not_nil(result)
      assert.are.equal("available", result.status)
      assert.are.equal(150, result.response_time)
      assert.are.equal("", result.error_msg)
      assert.is_not_nil(result.timestamp)
    end)

    it("stores multiple providers independently", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 100, error_msg = "" })
      Cache.set("deepseek", "deepseek-chat", { status = "timeout", response_time = 5000, error_msg = "timeout" })

      local result1 = Cache.get("openai", "gpt-4")
      local result2 = Cache.get("deepseek", "deepseek-chat")

      assert.are.equal("available", result1.status)
      assert.are.equal("timeout", result2.status)
    end)

    it("creates cache directory if missing", function()
      local test_dir = cache_dir .. "/test_cache_dir"
      vim.fn.mkdir(test_dir, "p")

      local result = Cache.get("test_provider", "test_model")
      assert.is_nil(result)
    end)
  end)

  describe("is_valid()", function()
    it("returns true for fresh available result", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "" })
      assert.is_true(Cache.is_valid("openai", "gpt-4"))
    end)

    it("returns false for expired available result (TTL 300s)", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "", timestamp = os.time() - 301 })
      assert.is_false(Cache.is_valid("openai", "gpt-4"))
    end)

    it("returns false for expired timeout result (TTL 60s)", function()
      Cache.set("openai", "gpt-4", { status = "timeout", response_time = 5000, error_msg = "timeout", timestamp = os.time() - 61 })
      assert.is_false(Cache.is_valid("openai", "gpt-4"))
    end)

    it("returns false for expired error result (TTL 30s)", function()
      Cache.set("openai", "gpt-4", { status = "error", response_time = 200, error_msg = "500 error", timestamp = os.time() - 31 })
      assert.is_false(Cache.is_valid("openai", "gpt-4"))
    end)

    it("returns false for expired unavailable result (TTL 120s)", function()
      Cache.set("openai", "gpt-4", { status = "unavailable", response_time = 100, error_msg = "404", timestamp = os.time() - 121 })
      assert.is_false(Cache.is_valid("openai", "gpt-4"))
    end)

    it("returns true for non-expired timeout result (within 60s)", function()
      Cache.set("openai", "gpt-4", { status = "timeout", response_time = 5000, error_msg = "timeout", timestamp = os.time() - 30 })
      assert.is_true(Cache.is_valid("openai", "gpt-4"))
    end)

    it("returns true for non-expired error result (within 30s)", function()
      Cache.set("openai", "gpt-4", { status = "error", response_time = 200, error_msg = "500 error", timestamp = os.time() - 15 })
      assert.is_true(Cache.is_valid("openai", "gpt-4"))
    end)

    it("returns false when no cached result exists", function()
      assert.is_false(Cache.is_valid("nonexistent", "model"))
    end)
  end)

  describe("invalidate()", function()
    it("removes cached result", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "" })
      Cache.invalidate("openai", "gpt-4")
      assert.is_nil(Cache.get("openai", "gpt-4"))
    end)

    it("does not affect other cached results", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "" })
      Cache.set("deepseek", "deepseek-chat", { status = "timeout", response_time = 5000, error_msg = "timeout" })

      Cache.invalidate("openai", "gpt-4")

      assert.is_nil(Cache.get("openai", "gpt-4"))
      assert.is_not_nil(Cache.get("deepseek", "deepseek-chat"))
      assert.are.equal("timeout", Cache.get("deepseek", "deepseek-chat").status)
    end)

    it("handles invalidation of non-existent entry gracefully", function()
      Cache.invalidate("nonexistent", "model")
      assert.is_nil(Cache.get("nonexistent", "model"))
    end)
  end)

  describe("get_all()", function()
    it("returns all cached results", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "" })
      Cache.set("deepseek", "deepseek-chat", { status = "timeout", response_time = 5000, error_msg = "timeout" })

      local all = Cache.get_all()
      assert.is_table(all)
      assert.is_not_nil(all["openai"])
      assert.is_not_nil(all["openai"]["gpt-4"])
      assert.is_not_nil(all["deepseek"])
      assert.is_not_nil(all["deepseek"]["deepseek-chat"])
    end)

    it("returns empty table when no cached results", function()
      local all = Cache.get_all()
      assert.is_table(all)
      assert.equals(0, vim.tbl_count(all))
    end)
  end)

  describe("clear()", function()
    it("removes all cached results", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "" })
      Cache.set("deepseek", "deepseek-chat", { status = "timeout", response_time = 5000, error_msg = "timeout" })

      Cache.clear()

      assert.is_nil(Cache.get("openai", "gpt-4"))
      assert.is_nil(Cache.get("deepseek", "deepseek-chat"))
      assert.equals(0, vim.tbl_count(Cache.get_all()))
    end)

    it("removes cache file from disk", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "" })
      Cache.clear()

      assert.equals(0, vim.fn.filereadable(cache_file))
    end)
  end)

  describe("differentiated TTLs", function()
    it("available status has 300s TTL", function()
      Cache.set("test", "model", { status = "available", response_time = 100, error_msg = "", timestamp = os.time() - 299 })
      assert.is_true(Cache.is_valid("test", "model"))

      Cache.set("test", "model", { status = "available", response_time = 100, error_msg = "", timestamp = os.time() - 301 })
      assert.is_false(Cache.is_valid("test", "model"))
    end)

    it("timeout status has 60s TTL", function()
      Cache.set("test", "model", { status = "timeout", response_time = 5000, error_msg = "timeout", timestamp = os.time() - 59 })
      assert.is_true(Cache.is_valid("test", "model"))

      Cache.set("test", "model", { status = "timeout", response_time = 5000, error_msg = "timeout", timestamp = os.time() - 61 })
      assert.is_false(Cache.is_valid("test", "model"))
    end)

    it("error status has 30s TTL", function()
      Cache.set("test", "model", { status = "error", response_time = 200, error_msg = "500", timestamp = os.time() - 29 })
      assert.is_true(Cache.is_valid("test", "model"))

      Cache.set("test", "model", { status = "error", response_time = 200, error_msg = "500", timestamp = os.time() - 31 })
      assert.is_false(Cache.is_valid("test", "model"))
    end)

    it("unavailable status has 120s TTL", function()
      Cache.set("test", "model", { status = "unavailable", response_time = 100, error_msg = "404", timestamp = os.time() - 119 })
      assert.is_true(Cache.is_valid("test", "model"))

      Cache.set("test", "model", { status = "unavailable", response_time = 100, error_msg = "404", timestamp = os.time() - 121 })
      assert.is_false(Cache.is_valid("test", "model"))
    end)
  end)

  describe("persistence", function()
    it("survives module reload", function()
      Cache.set("openai", "gpt-4", { status = "available", response_time = 150, error_msg = "" })

      local new_cache = require("ai.provider_manager.cache")
      local result = new_cache.get("openai", "gpt-4")

      assert.is_not_nil(result)
      assert.are.equal("available", result.status)
    end)
  end)
end)
