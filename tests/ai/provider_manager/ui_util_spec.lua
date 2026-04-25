-- tests/ai/provider_manager/ui_util_spec.lua
-- Unit tests for ui_util.lua — status icons, labels, and format functions

local function get_project_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
end

local project_root = get_project_root()
if project_root and #project_root > 0 then
  vim.opt.runtimepath:prepend(project_root)
end

package.loaded["ai.provider_manager.ui_util"] = nil

local UIUtil = require("ai.provider_manager.ui_util")

----------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------
describe("ai.provider_manager.ui_util", function()
  describe("get_status_icon()", function()
    it("returns correct icon for 'available'", function()
      local icon = UIUtil.get_status_icon("available")
      assert.are.equal("✓", icon)
    end)

    it("returns correct icon for 'unavailable'", function()
      local icon = UIUtil.get_status_icon("unavailable")
      assert.are.equal("✗", icon)
    end)

    it("returns correct icon for 'timeout'", function()
      local icon = UIUtil.get_status_icon("timeout")
      assert.are.equal("⏱", icon)
    end)

    it("returns correct icon for 'error'", function()
      local icon = UIUtil.get_status_icon("error")
      assert.are.equal("⚠", icon)
    end)

    it("returns correct icon for 'unchecked'", function()
      local icon = UIUtil.get_status_icon("unchecked")
      assert.are.equal("○", icon)
    end)

    it("returns status_unchecked for unknown status strings", function()
      local icon = UIUtil.get_status_icon("some_unknown_status")
      assert.are.equal("○", icon)
    end)

    it("returns status_unchecked for nil", function()
      local icon = UIUtil.get_status_icon(nil)
      assert.are.equal("○", icon)
    end)
  end)

  describe("get_status_label()", function()
    it("returns 'success' for available", function()
      assert.are.equal("success", UIUtil.get_status_label("available"))
    end)

    it("returns 'error' for unavailable", function()
      assert.are.equal("error", UIUtil.get_status_label("unavailable"))
    end)

    it("returns 'warn' for timeout", function()
      assert.are.equal("warn", UIUtil.get_status_label("timeout"))
    end)

    it("returns 'error' for error", function()
      assert.are.equal("error", UIUtil.get_status_label("error"))
    end)

    it("returns 'comment' for unchecked", function()
      assert.are.equal("comment", UIUtil.get_status_label("unchecked"))
    end)

    it("returns 'comment' for unknown status", function()
      assert.are.equal("comment", UIUtil.get_status_label("unknown"))
    end)
  end)

  describe("format_provider_display() — backward compatibility", function()
    it("without status: output matches original format", function()
      local result = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      })
      assert.are.equal("• test-prov  https://test.api.com/v1  test-model", result)
    end)

    it("with nil status: output identical to no-status call", function()
      local result_with_nil = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      }, nil)
      local result_without = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      })
      assert.are.equal(result_without, result_with_nil)
    end)

    it("with empty nil def: uses defaults", function()
      local result = UIUtil.format_provider_display("test-prov", nil)
      assert.are.equal("• test-prov  unknown  unknown", result)
    end)
  end)

  describe("format_provider_display() — with status", function()
    it("with 'available' status: output starts with '✓ '", function()
      local result = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      }, "available")
      assert.is_true(result:match("^✓ ") ~= nil)
    end)

    it("with 'unavailable' status: output starts with '✗ '", function()
      local result = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      }, "unavailable")
      assert.is_true(result:match("^✗ ") ~= nil)
    end)

    it("with 'timeout' status: output starts with '⏱ '", function()
      local result = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      }, "timeout")
      assert.is_true(result:match("^⏱ ") ~= nil)
    end)

    it("with 'error' status: output starts with '⚠ '", function()
      local result = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      }, "error")
      assert.is_true(result:match("^⚠ ") ~= nil)
    end)

    it("with 'unchecked' status: output identical to no-status (no icon)", function()
      local result_with_unchecked = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      }, "unchecked")
      local result_without = UIUtil.format_provider_display("test-prov", {
        endpoint = "https://test.api.com/v1",
        model = "test-model",
      })
      assert.are.equal(result_without, result_with_unchecked)
    end)
  end)

  describe("format_model_display() — backward compatibility", function()
    it("without status: output matches original format", function()
      local result = UIUtil.format_model_display("gpt-4", true, nil)
      assert.are.equal("★ gpt-4 ", result)
    end)

    it("with nil metadata and nil status: no crash", function()
      local result = UIUtil.format_model_display("gpt-4", true, nil, nil)
      assert.are.equal("★ gpt-4 ", result)
    end)

    it("with context_length: includes context", function()
      local result = UIUtil.format_model_display("gpt-4", false, { context_length = "128k" })
      assert.are.equal("◦ gpt-4 [128k]", result)
    end)
  end)

  describe("format_model_display() — with status", function()
    it("with 'timeout' status: output starts with '⏱ '", function()
      local result = UIUtil.format_model_display("gpt-4", true, nil, "timeout")
      assert.is_true(result:match("^⏱ ") ~= nil)
    end)

    it("with 'available' status: output starts with '✓ '", function()
      local result = UIUtil.format_model_display("gpt-4", false, nil, "available")
      assert.is_true(result:match("^✓ ") ~= nil)
    end)

    it("with nil metadata and 'error' status: no crash", function()
      local result = UIUtil.format_model_display("gpt-4", false, nil, "error")
      assert.is_true(result:match("^⚠ ") ~= nil)
    end)

    it("with 'unchecked' status: output identical to no-status", function()
      local result_with_unchecked = UIUtil.format_model_display("gpt-4", true, nil, "unchecked")
      local result_without = UIUtil.format_model_display("gpt-4", true, nil)
      assert.are.equal(result_without, result_with_unchecked)
    end)
  end)
end)
