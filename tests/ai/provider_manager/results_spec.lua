-- tests/ai/provider_manager/results_spec.lua
-- Unit tests for detection results display module

local Results = require("ai.provider_manager.results")

describe("ai.provider_manager.results module", function()
  after_each(function()
    Results.close_results()
  end)

  describe("show_results()", function()
    it("opens a floating window", function()
      local sample_results = {
        { provider = "openai", model = "gpt-4", status = "available", response_time = 150, error_msg = "" },
        { provider = "deepseek", model = "deepseek-chat", status = "timeout", response_time = 5000, error_msg = "request timed out" },
      }

      Results.show_results(sample_results, "Detection Results")

      assert.is_not_nil(Results._win)
      assert.is_true(vim.api.nvim_win_is_valid(Results._win))
    end)

    it("closes window with close_results()", function()
      local sample_results = {
        { provider = "openai", model = "gpt-4", status = "available", response_time = 150, error_msg = "" },
      }

      Results.show_results(sample_results, "Detection Results")
      local win = Results._win
      assert.is_true(vim.api.nvim_win_is_valid(win))

      Results.close_results()
      assert.is_false(vim.api.nvim_win_is_valid(win))
    end)

    it("displays results as table with columns", function()
      local sample_results = {
        { provider = "openai", model = "gpt-4", status = "available", response_time = 150, error_msg = "" },
        { provider = "deepseek", model = "deepseek-chat", status = "unavailable", response_time = 50, error_msg = "401 Unauthorized" },
        { provider = "qwen", model = "qwen-max", status = "error", response_time = 200, error_msg = "500 Internal Server Error" },
        { provider = "kimi", model = "kimi-k2", status = "warning", response_time = 300, error_msg = "429 rate limited" },
      }

      Results.show_results(sample_results, "Detection Results")

      local lines = vim.api.nvim_buf_get_lines(Results._buf, 0, -1, false)
      assert.is_true(#lines >= 6)

      -- Verify header row contains columns
      local header = lines[1]
      assert.is_not_nil(header:match("Provider") or header:match("provider"))
      assert.is_not_nil(header:match("Model") or header:match("model"))
      assert.is_not_nil(header:match("Status") or header:match("status"))
    end)

    it("truncates long values to 16 chars per column", function()
      local sample_results = {
        {
          provider = "this_is_a_very_long_provider_name",
          model = "this_is_a_very_long_model_name",
          status = "available",
          response_time = 150,
          error_msg = "this is a very long error message that should be truncated",
        },
      }

      Results.show_results(sample_results, "Detection Results")

      local lines = vim.api.nvim_buf_get_lines(Results._buf, 0, -1, false)

      -- Check that data lines (not header, not separator) have truncated values
      local data_line = lines[3]
      assert.is_true(#data_line <= 100, "Data line too long: " .. data_line)
      -- Verify long provider name is truncated
      assert.is_nil(data_line:match("this_is_a_very_long_provider_name"))
    end)

    it("renders status symbols correctly", function()
      local sample_results = {
        { provider = "p1", model = "m1", status = "available", response_time = 100, error_msg = "" },
        { provider = "p2", model = "m2", status = "unavailable", response_time = 50, error_msg = "err" },
        { provider = "p3", model = "m3", status = "timeout", response_time = 5000, error_msg = "timeout" },
        { provider = "p4", model = "m4", status = "warning", response_time = 200, error_msg = "429" },
      }

      Results.show_results(sample_results, "Detection Results")

      local lines = vim.api.nvim_buf_get_lines(Results._buf, 0, -1, false)
      local all_text = table.concat(lines, "\n")

      assert.is_not_nil(all_text:match("✓"))
      assert.is_not_nil(all_text:match("✗"))
      assert.is_not_nil(all_text:match("⏱"))
      assert.is_not_nil(all_text:match("⚠"))
    end)

    it("makes buffer scrollable when results > 15 rows", function()
      local sample_results = {}
      for i = 1, 20 do
        table.insert(sample_results, {
          provider = "provider" .. i,
          model = "model" .. i,
          status = "available",
          response_time = 100,
          error_msg = "",
        })
      end

      Results.show_results(sample_results, "Detection Results")

      local buf_lines = vim.api.nvim_buf_get_lines(Results._buf, 0, -1, false)
      -- Buffer should contain all rows (20 results + header + separator >= 22 lines)
      assert.is_true(#buf_lines >= 22)
    end)

    it("has q keymap to close window", function()
      local sample_results = {
        { provider = "openai", model = "gpt-4", status = "available", response_time = 150, error_msg = "" },
      }

      Results.show_results(sample_results, "Detection Results")

      local keymaps = vim.api.nvim_buf_get_keymap(Results._buf, "n")
      local has_q = false
      for _, km in ipairs(keymaps) do
        if km.lhs == "q" then
          has_q = true
          break
        end
      end
      assert.is_true(has_q)
    end)
  end)

  describe("show_single_result()", function()
    it("opens a floating window for single result", function()
      Results.close_results()

      local sample_result = {
        provider = "openai",
        model = "gpt-4",
        status = "available",
        response_time = 150,
        error_msg = "",
      }

      Results.show_single_result(sample_result, "Single Check")

      assert.is_not_nil(Results._win)
      assert.is_true(vim.api.nvim_win_is_valid(Results._win))
    end)

    it("shows compact format with status symbol", function()
      Results.close_results()

      local sample_result = {
        provider = "openai",
        model = "gpt-4",
        status = "available",
        response_time = 150,
        error_msg = "",
      }

      Results.show_single_result(sample_result, "Single Check")

      local lines = vim.api.nvim_buf_get_lines(Results._buf, 0, -1, false)
      local all_text = table.concat(lines, "\n")

      assert.is_not_nil(all_text:match("✓"))
      assert.is_not_nil(all_text:match("openai"))
      assert.is_not_nil(all_text:match("gpt%-4"))
      assert.is_not_nil(all_text:match("150"))
    end)

    it("shows full error message for failed result", function()
      Results.close_results()

      local sample_result = {
        provider = "deepseek",
        model = "deepseek-chat",
        status = "error",
        response_time = 5000,
        error_msg = "Connection refused to https://api.deepseek.com",
      }

      Results.show_single_result(sample_result, "Single Check")

      local lines = vim.api.nvim_buf_get_lines(Results._buf, 0, -1, false)
      local all_text = table.concat(lines, "\n")

      assert.is_not_nil(all_text:match("Connection refused"))
    end)

    it("closes with close_results()", function()
      Results.close_results()

      local sample_result = {
        provider = "openai",
        model = "gpt-4",
        status = "available",
        response_time = 150,
        error_msg = "",
      }

      Results.show_single_result(sample_result, "Single Check")
      local win = Results._win

      Results.close_results()
      assert.is_false(vim.api.nvim_win_is_valid(win))
    end)
  end)
end)
