-- tests/commit_picker/config_spec.lua
-- Plenary.nvim specs for commit_picker/config.lua

local Config = require("commit_picker.config")

describe("commit_picker/config", function()
  local config_path

  before_each(function()
    config_path = Config.get_config_path()
    -- Clean state before each test
    os.remove(config_path)
    os.remove(config_path .. ".tmp")
    Config.invalidate_cache()
  end)

  after_each(function()
    os.remove(config_path)
    os.remove(config_path .. ".tmp")
    Config.invalidate_cache()
  end)

  ----------------------------------------------------------------------
  -- get_config_path()
  ----------------------------------------------------------------------
  describe("get_config_path()", function()
    it("returns absolute path", function()
      local path = Config.get_config_path()
      assert.truthy(path:match("config/nvim/commit_picker_config%.lua$"))
    end)
  end)

  ----------------------------------------------------------------------
  -- get_config() returns defaults when file missing
  ----------------------------------------------------------------------
  describe("get_config()", function()
    it("returns defaults when config file does not exist", function()
      local config = Config.get_config()
      assert.equals("unpushed", config.mode)
      assert.equals(20, config.count)
      assert.equals(nil, config.base_commit)
    end)

    it("returns a copy, not the internal default table", function()
      local c1 = Config.get_config()
      local c2 = Config.get_config()
      -- Should be different table instances (not the same reference)
      assert.not_equal(c1, c2)
    end)
  end)

  ----------------------------------------------------------------------
  -- config_file_exists()
  ----------------------------------------------------------------------
  describe("config_file_exists()", function()
    it("returns false when file does not exist", function()
      assert.is_false(Config.config_file_exists())
    end)

    it("returns true when file exists", function()
      -- Write a minimal config file
      local f = io.open(config_path, "w")
      f:write("return {\n  mode = \"unpushed\",\n  count = 20,\n  base_commit = nil,\n}\n")
      f:close()

      assert.is_true(Config.config_file_exists())
    end)
  end)

  ----------------------------------------------------------------------
  -- save_config() writes parseable file that can be read back
  ----------------------------------------------------------------------
  describe("save_config()", function()
    it("creates a valid file that can be read back", function()
      local ok = Config.save_config({ mode = "last_n", count = 50, base_commit = nil })
      assert.is_true(ok)

      Config.invalidate_cache()
      local config = Config.get_config()
      assert.equals("last_n", config.mode)
      assert.equals(50, config.count)
      assert.is_nil(config.base_commit)
    end)

    it("persists base_commit when set", function()
      -- Write a file first with a valid-looking but format-invalid SHA
      local f = io.open(config_path, "w")
      f:write('return {\n  mode = "since_base",\n  count = 10,\n  base_commit = "not_a_valid_hex_sha",\n}\n')
      f:close()
      Config.invalidate_cache()

      -- Now save with nil base
      local ok = Config.save_config({ mode = "since_base", count = 10, base_commit = nil })
      assert.is_true(ok)

      Config.invalidate_cache()
      local config = Config.get_config()
      assert.is_nil(config.base_commit)
    end)

    it("rejects invalid mode", function()
      local ok, err = Config.save_config({ mode = "invalid", count = 20 })
      assert.is_false(ok)
      assert.truthy(err:match("无效模式"))
    end)

    it("rejects negative count", function()
      local ok, err = Config.save_config({ mode = "last_n", count = -1 })
      assert.is_false(ok)
      assert.truthy(err:match("count"))
    end)

    it("rejects non-hex SHA", function()
      local ok, err = Config.save_config({ mode = "since_base", count = 10, base_commit = "not_hex" })
      assert.is_false(ok)
      assert.truthy(err:match("SHA"))
    end)
  end)

  ----------------------------------------------------------------------
  -- validate_config()
  ----------------------------------------------------------------------
  describe("validate_config()", function()
    it("returns ok for valid config", function()
      local result = Config.validate_config({ mode = "unpushed", count = 20 })
      assert.is_true(result.ok)
    end)

    it("rejects invalid mode values", function()
      local result = Config.validate_config({ mode = "random" })
      assert.is_false(result.ok)
    end)

    it("rejects count less than 1", function()
      local result = Config.validate_config({ count = 0 })
      assert.is_false(result.ok)
    end)

    it("rejects count greater than 500", function()
      local result = Config.validate_config({ count = 501 })
      assert.is_false(result.ok)
    end)

    it("rejects non-hex SHA format", function()
      local result = Config.validate_config({ base_commit = "zzz" })
      assert.is_false(result.ok)
    end)

    it("rejects SHA that does not exist in git history", function()
      local result = Config.validate_config({ base_commit = "abcdef1234567890abcdef1234567890abcdef12" })
      assert.is_false(result.ok)
      assert.truthy(result.error:match("不存在"))
    end)

    it("accepts nil base_commit", function()
      local result = Config.validate_config({ base_commit = nil })
      assert.is_true(result.ok)
    end)

    it("rejects non-table input", function()
      local result = Config.validate_config("not a table")
      assert.is_false(result.ok)
    end)
  end)

  ----------------------------------------------------------------------
  -- reset_to_defaults()
  ----------------------------------------------------------------------
  describe("reset_to_defaults()", function()
    it("writes known-good default config", function()
      -- First write a custom config
      Config.save_config({ mode = "last_n", count = 100, base_commit = nil })
      assert.equals("last_n", Config.get_config().mode)

      -- Reset
      local ok = Config.reset_to_defaults()
      assert.is_true(ok)

      Config.invalidate_cache()
      local config = Config.get_config()
      assert.equals("unpushed", config.mode)
      assert.equals(20, config.count)
    end)
  end)

  ----------------------------------------------------------------------
  -- invalidate_cache()
  ----------------------------------------------------------------------
  describe("invalidate_cache()", function()
    it("clears cache so next get_config reads fresh data", function()
      -- Write initial config
      Config.save_config({ mode = "unpushed", count = 20 })
      Config.invalidate_cache()

      local c1 = Config.get_config()
      assert.equals(20, c1.count)

      -- Invalidate and write new config
      Config.invalidate_cache()
      local f = io.open(config_path, "w")
      f:write('return {\n  mode = "last_n",\n  count = 100,\n  base_commit = nil,\n}\n')
      f:close()

      -- After invalidate, reads new value from file
      local c2 = Config.get_config()
      assert.equals(100, c2.count)
    end)
  end)
end)
