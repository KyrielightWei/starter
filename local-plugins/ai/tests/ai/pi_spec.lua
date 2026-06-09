-- tests/ai/pi_spec.lua
-- Pi 配置同步模块测试

local assert = require("luassert")

local function project_root()
  -- 测试文件在 local-plugins/ai/tests/ai/ 下，需要上溯 5 级到 starter 根目录
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h:h:h")
end

local function temp_dir(name)
  local dir = vim.fn.tempname() .. "-" .. name
  vim.fn.mkdir(dir, "p")
  return dir
end

local function read_json(path)
  local content = table.concat(vim.fn.readfile(path), "\n")
  return vim.json.decode(content)
end

local function write_json(path, value)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local JsonUtil = require("ai.json_util")
  vim.fn.writefile(vim.split(JsonUtil.format_json(value), "\n"), path)
end

describe("Pi sync module", function()
  local Pi

  before_each(function()
    package.loaded["ai.pi"] = nil
    Pi = require("ai.pi")
  end)

  it("resolves versioned Pi template before legacy fallback", function()
    local config_dir = temp_dir("pi-config")
    local repo_root = project_root()
    local versioned_dir = config_dir .. "/templates/pi"
    vim.fn.mkdir(versioned_dir, "p")
    vim.fn.writefile({ [[{ "defaultModel": "from-versioned" }]] }, versioned_dir .. "/default.template.jsonc")

    local settings = Pi.generate_settings({ config_dir = config_dir, repo_root = repo_root, version = "default" })

    assert.are.equal("from-versioned", settings.defaultModel)
  end)

  it("conservatively preserves user settings and unions package arrays", function()
    local pi_dir = temp_dir("pi-home")
    write_json(pi_dir .. "/settings.json", {
      customUserField = "keep-me",
      packages = { "npm:user-package", "npm:pi-subagents" },
      nested = { user = true },
    })

    local ok = Pi.write_config({
      pi_dir = pi_dir,
      config_dir = temp_dir("pi-config"),
      repo_root = project_root(),
      silent = true,
    })
    assert.is_true(ok)

    local written = read_json(pi_dir .. "/settings.json")
    assert.are.equal("keep-me", written.customUserField)
    assert.is_true(vim.tbl_contains(written.packages, "npm:user-package"))
    assert.is_true(vim.tbl_contains(written.packages, "npm:pi-subagents"))
  end)

  it("backs up invalid existing JSON before writing", function()
    local pi_dir = temp_dir("pi-home")
    vim.fn.mkdir(pi_dir, "p")
    vim.fn.writefile({ "{ invalid json" }, pi_dir .. "/settings.json")

    local ok = Pi.write_config({
      pi_dir = pi_dir,
      config_dir = temp_dir("pi-config"),
      repo_root = project_root(),
      silent = true,
      now = "123",
    })
    assert.is_true(ok)

    assert.are.equal(1, vim.fn.filereadable(pi_dir .. "/settings.json.bak.123"))
    assert.is_table(read_json(pi_dir .. "/settings.json"))
  end)

  it("generates models from provider registry without raw API key values", function()
    local models = Pi.generate_models({ repo_root = project_root() })

    assert.is_table(models.providers)
    assert.is_table(models.providers.bailian_coding)
    assert.are.equal("https://coding.dashscope.aliyuncs.com/v1", models.providers.bailian_coding.baseUrl)
    assert.are.equal("BAILIAN_CODING_API_KEY", models.providers.bailian_coding.apiKey)
    assert.is_table(models.providers.bailian_coding.models)
  end)

  it("uses manifest hashes to back up user-modified managed resources", function()
    local pi_dir = temp_dir("pi-home")
    local opts =
      { pi_dir = pi_dir, config_dir = temp_dir("pi-config"), repo_root = project_root(), silent = true, now = "456" }

    assert.is_true(Pi.write_config(opts))
    local ext_path = pi_dir .. "/extensions/notify.ts"
    assert.are.equal(1, vim.fn.filereadable(ext_path))

    vim.fn.writefile({ "user modified" }, ext_path)
    assert.is_true(Pi.write_config(opts))

    assert.are.equal(1, vim.fn.filereadable(ext_path .. ".bak.456"))
    local manifest = read_json(pi_dir .. "/.starter-sync-manifest.json")
    assert.is_table(manifest.files["extensions/notify.ts"])
  end)

  it("syncs only the local openspec skill by default", function()
    local resources = Pi.collect_resource_mappings({ repo_root = project_root(), pi_dir = temp_dir("pi-home") })
    local targets = vim.tbl_map(function(item)
      return item.relative
    end, resources)

    assert.is_true(vim.tbl_contains(targets, "skills/openspec/SKILL.md"))
    assert.is_false(vim.tbl_contains(targets, "skills/test-driven-development/SKILL.md"))
  end)

  it("reports missing Pi CLI and missing packages without failing status", function()
    local status =
      Pi.get_status({ pi_dir = temp_dir("pi-home"), repo_root = project_root(), pi_executable = "definitely-not-pi" })

    assert.is_false(status.installed)
    assert.is_table(status.missing_packages)
  end)
end)
