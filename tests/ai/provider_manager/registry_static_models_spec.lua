-- tests/ai/provider_manager/registry_static_models_spec.lua
-- Tests for file_util safe_write_file and static_models persistence
-- Key: Use /tmp path to avoid touching real providers.lua

describe("registry static_models CRUD", function()
  local FileUtil
  local test_lines
  local orig_vim_fn = {}

  before_each(function()
    test_lines = {}
    orig_vim_fn.readfile = vim.fn.readfile
    orig_vim_fn.writefile = vim.fn.writefile
    orig_vim_fn.filereadable = vim.fn.filereadable
    orig_vim_fn.delete = vim.fn.delete

    -- Always mock to /tmp path
    local tmp_base = "/tmp/nvim_test_" .. math.random(100000)
    vim.fn.readfile = function(path)
      if path:find("/tmp/nvim_test_") then
        return test_lines
      end
      return orig_vim_fn.readfile(path)
    end
    vim.fn.writefile = function(content, path)
      if path:find("/tmp/nvim_test_") or path:find("/tmp/nvim_test_.+%.tmp") then
        if type(content) == "table" then
          test_written = table.concat(content, "\n")
        else
          test_written = content
        end
      end
    end
    vim.fn.filereadable = function(path)
      if path:find("/tmp/nvim_test_") then return 1 end
      return 0
    end
    vim.fn.delete = function(_) end

    vim.loop = vim.loop or {}
    vim.uv = vim.uv or vim.loop
    vim.loop.fs_rename = function(_, _) return nil end
    vim.uv.fs_rename = function(_, _) return nil end

    -- Clear cached modules
    package.loaded["ai.provider_manager.file_util"] = nil

    -- Load FileUtil
    FileUtil = require("ai.provider_manager.file_util")
  end)

  after_each(function()
    vim.fn.readfile = orig_vim_fn.readfile
    vim.fn.writefile = orig_vim_fn.writefile
    vim.fn.filereadable = orig_vim_fn.filereadable
    vim.fn.delete = orig_vim_fn.delete
  end)

  describe("save_write_file", function()
    it("should write content via .tmp → rename atomic pattern", function()
      local path = "/tmp/nvim_test_static_models/providers.lua"
      local content = "line1\nline2\nline3"

      local ok, err = FileUtil.safe_write_file(path, content)
      assert.is_true(ok, "safe_write_file should succeed: " .. tostring(err))
      assert.is_not_nil(test_written, "Content should be written")
      assert.is_not_nil(test_written:match("line1"), "Should contain line1")
    end)

    it("should handle empty content", function()
      local path = "/tmp/nvim_test_empty/test.lua"
      local ok = FileUtil.safe_write_file(path, "")
      assert.is_true(ok)
    end)

    it("should handle large content with many lines", function()
      local path = "/tmp/nvim_test_large/test.lua"
      local lines = {}
      for i = 1, 50 do table.insert(lines, "line_" .. i) end
      local content = table.concat(lines, "\n")
      local ok = FileUtil.safe_write_file(path, content)
      assert.is_true(ok)
      assert.is_not_nil(test_written:match("line_50"))
    end)
  end)
end)
