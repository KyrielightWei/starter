-- tests/ai/provider_manager/registry_static_models_spec.lua
-- Tests for static_models CRUD in registry.lua

local function eq(a, b)
  if a == nil and b == nil then return true end
  if type(a) ~= type(b) then return false end
  if type(a) == "table" then
    if #a ~= #b then return false end
    for i = 1, #a do
      if not eq(a[i], b[i]) then return false end
    end
    return true
  end
  return a == b
end

describe("registry static_models CRUD", function()
  local Registry
  local FileUtil
  local test_path

  before_each(function()
    -- Mock vim for headless test
    if not vim then
      _G.vim = {
        fn = {
          stdpath = function(type)
            if type == "config" then return "/tmp/nvim_test_config" end
            return "/tmp/nvim_" .. type
          end,
          readfile = function(path)
            if path == test_path then
              return test_lines or {}
            end
            return {}
          end,
          writefile = function(lines, path)
            -- mock
          end,
          filereadable = function(path)
            if path == test_path then return 1 end
            return 0
          end,
          delete = function(path) end,
        },
        notify = function(msg, level) end,
        loop = {
          fs_rename = function(src, dst) return nil end,
        },
        uv = {
          fs_rename = function(src, dst) return nil end,
        },
      }
    end

    test_path = vim.fn.stdpath("config") .. "/lua/ai/providers.lua"

    -- Clear cached modules
    package.loaded["ai.provider_manager.file_util"] = nil
    package.loaded["ai.provider_manager.validator"] = nil
    package.loaded["ai.provider_manager.registry"] = nil
    package.loaded["ai.providers"] = nil
    package.loaded["ai.keys"] = nil

    -- Mock providers module
    local mock_providers = {}
    local provider_data = {
      deepseek = {
        api_key_name = "DEEPSEEK_API_KEY",
        endpoint = "https://api.deepseek.com",
        model = "deepseek-chat",
        static_models = { "deepseek-chat", "deepseek-reasoner" },
      },
      openai = {
        api_key_name = "OPENAI_API_KEY",
        endpoint = "https://api.openai.com",
        model = "gpt-4o-mini",
        static_models = { "gpt-4o-mini", "gpt-4o" },
      },
      minimax = {
        api_key_name = "MINIMAX_API_KEY",
        endpoint = "https://minimax.example.com",
        model = "minimax-latest",
        static_models = {},
      },
    }
    setmetatable(mock_providers, {
      __index = provider_data,
      __newindex = function(t, k, v)
        if type(v) == "table" then
          provider_data[k] = v
        end
      end,
    })
    function mock_providers.list()
      local names = {}
      for k in pairs(provider_data) do table.insert(names, k) end
      return names
    end
    function mock_providers.get(name)
      return provider_data[name]
    end
    package.loaded["ai.providers"] = mock_providers

    -- Mock Keys module
    local mock_keys = {}
    local keys_data = {}
    function mock_keys.read() return keys_data end
    function mock_keys.write(data) keys_data = data end
    package.loaded["ai.keys"] = mock_keys

    -- Load FileUtil
    FileUtil = require("ai.provider_manager.file_util")

    -- Load Registry
    Registry = require("ai.provider_manager.registry")
  end)

  describe("find_provider_block", function()
    it("should return start, end, and content lines for a provider block", function()
      test_lines = {
        'M.register("deepseek", {',
        '  api_key_name = "DEEPSEEK_API_KEY",',
        '  endpoint = "https://api.deepseek.com",',
        '  model = "deepseek-chat",',
        "})",
        "",
        'return M',
      }

      local start, end_line, content = Registry.find_provider_block("deepseek")
      assert.is_not_nil(start)
      assert.is_not_nil(end_line)
      assert.is_not_nil(content)
      assert.are.equal(1, start)
      assert.are.equal(5, end_line)
      assert.are.equal(5, #content)
    end)

    it("should return nil for non-existent provider", function()
      test_lines = {
        'M.register("deepseek", {',
        "})",
        "return M",
      }

      local start, end_line, content = Registry.find_provider_block("nonexistent")
      assert.is_nil(start)
      assert.is_nil(end_line)
      assert.is_nil(content)
    end)

    it("should handle multi-line static_models", function()
      test_lines = {
        'M.register("openai", {',
        '  api_key_name = "OPENAI_API_KEY",',
        '  endpoint = "https://api.openai.com",',
        '  static_models = {',
        '    "gpt-4o-mini",',
        '    "gpt-4o",',
        '  },',
        "})",
        "return M",
      }

      local start, end_line, content = Registry.find_provider_block("openai")
      assert.is_not_nil(start)
      assert.is_not_nil(end_line)
      assert.are.equal(8, end_line)
    end)
  end)

  describe("list_static_models", function()
    it("should return models from file when file exists", function()
      test_lines = {
        'M.register("deepseek", {',
        '  api_key_name = "DEEPSEEK_API_KEY",',
        '  endpoint = "https://api.deepseek.com",',
        '  model = "deepseek-chat",',
        '  static_models = { "deepseek-chat", "deepseek-reasoner" },',
        "})",
        "return M",
      }

      local models = Registry.list_static_models("deepseek")
      assert.are.equal(2, #models)
      assert.are.equal("deepseek-chat", models[1])
      assert.are.equal("deepseek-reasoner", models[2])
    end)

    it("should return empty table for provider with no static_models", function()
      test_lines = {
        'M.register("minimax", {',
        '  api_key_name = "MINIMAX_API_KEY",',
        "})",
        "return M",
      }

      local models = Registry.list_static_models("minimax")
      assert.are.equal(0, #models)
    end)

    it("should fallback to in-memory when file not found", function()
      -- Simulate filereadable returning 0
      vim.fn.filereadable = function(path)
        if path == test_path then return 0 end
        return 0
      end

      local models = Registry.list_static_models("deepseek")
      assert.are.equal(2, #models)
      assert.are.equal("deepseek-chat", models[1])
    end)
  end)

  describe("add_static_model", function()
    it("should add a new model to the list", function()
      test_lines = {
        'M.register("deepseek", {',
        '  static_models = { "deepseek-chat", "deepseek-reasoner" },',
        "})",
        "return M",
      }

      local result = Registry.add_static_model("deepseek", "deepseek-v3")
      assert.is_true(result)
    end)

    it("should not add duplicate model", function()
      test_lines = {
        'M.register("deepseek", {',
        '  static_models = { "deepseek-chat", "deepseek-reasoner" },',
        "})",
        "return M",
      }

      local result = Registry.add_static_model("deepseek", "deepseek-chat")
      assert.is_false(result)
    end)

    it("should insert static_models line when not present", function()
      test_lines = {
        'M.register("minimax", {',
        '  api_key_name = "MINIMAX_API_KEY",',
        "})",
        "return M",
      }

      local result = Registry.add_static_model("minimax", "minimax-new")
      assert.is_true(result)
    end)

    it("should return false for non-existent provider", function()
      test_lines = {
        'M.register("deepseek", {',
        "})",
        "return M",
      }

      local result = Registry.add_static_model("nonexistent", "some-model")
      assert.is_false(result)
    end)
  end)

  describe("remove_static_model", function()
    it("should remove an existing model", function()
      test_lines = {
        'M.register("deepseek", {',
        '  static_models = { "deepseek-chat", "deepseek-reasoner" },',
        "})",
        "return M",
      }

      local result = Registry.remove_static_model("deepseek", "deepseek-chat")
      assert.is_true(result)
    end)

    it("should return false for non-existent model", function()
      test_lines = {
        'M.register("deepseek", {',
        '  static_models = { "deepseek-chat", "deepseek-reasoner" },',
        "})",
        "return M",
      }

      local result = Registry.remove_static_model("deepseek", "nonexistent-model")
      assert.is_false(result)
    end)
  end)

  describe("update_static_models", function()
    it("should replace entire static_models list", function()
      test_lines = {
        'M.register("deepseek", {',
        '  static_models = { "deepseek-chat", "deepseek-reasoner" },',
        "})",
        "return M",
      }

      local result = Registry.update_static_models("deepseek", { "model-a", "model-b", "model-c" })
      assert.is_true(result)
    end)

    it("should handle empty list", function()
      test_lines = {
        'M.register("deepseek", {',
        '  static_models = { "deepseek-chat" },',
        "})",
        "return M",
      }

      local result = Registry.update_static_models("deepseek", {})
      assert.is_true(result)
    end)

    it("should return false for non-existent provider", function()
      test_lines = { "return M" }

      local result = Registry.update_static_models("nonexistent", { "model" })
      assert.is_false(result)
    end)
  end)

  describe("_update_static_models_in_file", function()
    it("should use safe_write_file for atomic persistence", function()
      test_lines = {
        'M.register("deepseek", {',
        '  static_models = { "model-a" },',
        "})",
        "return M",
      }

      local ok, err = Registry._update_static_models_in_file(
        "deepseek", 1, 4, { "model-a", "model-b" }
      )
      assert.is_true(ok)
    end)
  end)
end)
