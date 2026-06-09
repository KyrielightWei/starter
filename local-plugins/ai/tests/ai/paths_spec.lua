-- tests/ai/paths_spec.lua
-- 路径解析模块测试

local assert = require("luassert")

local function temp_dir(name)
  local dir = vim.fn.tempname() .. "-" .. name
  vim.fn.mkdir(dir, "p")
  return dir
end

describe("ai.paths", function()
  local Paths

  before_each(function()
    package.loaded["ai.paths"] = nil
    Paths = require("ai.paths")
  end)

  it("defaults config_dir to stdpath('config')", function()
    Paths.setup()
    assert.are.equal(vim.fn.stdpath("config"), Paths.config_dir())
  end)

  it("accepts custom template_dir", function()
    local custom = temp_dir("paths-test")
    Paths.setup({ template_dir = custom })
    assert.are.equal(custom, Paths.config_dir())
  end)

  it("resolves settings_template with default version", function()
    local base = temp_dir("paths-test")
    Paths.setup({ template_dir = base })
    assert.are.equal(base .. "/templates/pi/default.template.jsonc", Paths.settings_template("pi"))
  end)

  it("resolves settings_template with custom version", function()
    local base = temp_dir("paths-test")
    Paths.setup({ template_dir = base })
    assert.are.equal(base .. "/templates/opencode/core.template.jsonc", Paths.settings_template("opencode", "core"))
  end)

  it("resolves legacy_template", function()
    local base = temp_dir("paths-test")
    Paths.setup({ template_dir = base })
    assert.are.equal(base .. "/opencode.template.jsonc", Paths.legacy_template("opencode"))
    assert.are.equal(base .. "/claude_code.template.jsonc", Paths.legacy_template("claude_code"))
  end)

  it("resolves resource paths", function()
    local base = temp_dir("paths-test")
    Paths.setup({ template_dir = base })
    assert.are.equal(base .. "/pi/AGENTS.template.md", Paths.resource("pi/AGENTS.template.md"))
    assert.are.equal(
      base .. "/pi/extensions/statusbar.template.ts",
      Paths.resource("pi/extensions/statusbar.template.ts")
    )
  end)

  it("resolves ccstatusline_template", function()
    local base = temp_dir("paths-test")
    Paths.setup({ template_dir = base })
    assert.are.equal(base .. "/ccstatusline.template.jsonc", Paths.ccstatusline_template())
  end)

  it("resolves templates_dir with and without tool", function()
    local base = temp_dir("paths-test")
    Paths.setup({ template_dir = base })
    assert.are.equal(base .. "/templates", Paths.templates_dir())
    assert.are.equal(base .. "/templates/pi", Paths.templates_dir("pi"))
  end)

  it("normalizes double slashes in paths", function()
    local base = temp_dir("paths-test")
    Paths.setup({ template_dir = base })
    local path = Paths.resource("pi//AGENTS.template.md")
    assert.is_nil(path:find("//"))
  end)
end)
