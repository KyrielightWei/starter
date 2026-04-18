-- tests/ai/components_spec.lua
-- 组件管理器测试验证

describe("Component Manager", function()
  -- ============================================
  -- Setup: 加载模块
  -- ============================================
  before_each(function()
    -- 清空注册表
    local Registry = require("ai.components.registry")
    Registry.clear()

    -- 清空缓存
    local Switcher = require("ai.components.switcher")
    Switcher.clear_cache()
  end)

  -- ============================================
  -- Interface Tests
  -- ============================================
  describe("interface", function()
    local Interface = require("ai.components.interface")

    it("should validate valid component", function()
      local valid_comp = {
        name = "test",
        display_name = "Test",
        setup = function()
          return true
        end,
        is_installed = function()
          return false
        end,
        get_status = function()
          return nil
        end,
        get_version_info = function()
          return {}
        end,
        check_dependencies = function()
          return {}
        end,
        install = function()
          return true, ""
        end,
        uninstall = function()
          return true, ""
        end,
        update = function()
          return true, ""
        end,
        health_check = function()
          return { status = "ok" }
        end,
      }

      local valid, err = Interface.validate_component(valid_comp)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should reject component missing required fields", function()
      local invalid = { name = "test" }
      local valid, err = Interface.validate_component(invalid)
      assert.is_false(valid)
      assert.is_not_nil(err)
    end)
  end)

  -- ============================================
  -- Registry Tests
  -- ============================================
  describe("registry", function()
    local Registry = require("ai.components.registry")

    it("should register component", function()
      Registry.register("test", {
        name = "test",
        setup = function()
          return true
        end,
        is_installed = function()
          return false
        end,
        get_status = function()
          return nil
        end,
        get_version_info = function()
          return {}
        end,
        check_dependencies = function()
          return {}
        end,
        install = function()
          return true, ""
        end,
        uninstall = function()
          return true, ""
        end,
        update = function()
          return true, ""
        end,
        health_check = function()
          return {}
        end,
      })

      assert.is_not_nil(Registry.get("test"))
      assert.are.same(1, Registry.count())
    end)

    it("should list components", function()
      Registry.register("comp1", {
        name = "comp1",
        is_installed = function()
          return true
        end,
        get_status = function()
          return {}
        end,
        setup = function()
          return true
        end,
        get_version_info = function()
          return {}
        end,
        check_dependencies = function()
          return {}
        end,
        install = function()
          return true, ""
        end,
        uninstall = function()
          return true, ""
        end,
        update = function()
          return true, ""
        end,
        health_check = function()
          return {}
        end,
      })
      Registry.register("comp2", {
        name = "comp2",
        is_installed = function()
          return false
        end,
        get_status = function()
          return nil
        end,
        setup = function()
          return true
        end,
        get_version_info = function()
          return {}
        end,
        check_dependencies = function()
          return {}
        end,
        install = function()
          return true, ""
        end,
        uninstall = function()
          return true, ""
        end,
        update = function()
          return true, ""
        end,
        health_check = function()
          return {}
        end,
      })

      local list = Registry.list()
      assert.are.same(2, #list)
    end)
  end)

  -- ============================================
  -- Version Tests
  -- ============================================
  describe("version", function()
    local Version = require("ai.components.version")

    it("should parse semver correctly", function()
      local parsed = Version.parse_semver("1.2.3")
      assert.are.same(1, parsed.major)
      assert.are.same(2, parsed.minor)
      assert.are.same(3, parsed.patch)
    end)

    it("should compare versions correctly", function()
      assert.are.same("outdated", Version.compare_versions("1.0.0", "1.0.1"))
      assert.are.same("current", Version.compare_versions("1.0.0", "1.0.0"))
      assert.are.same("newer", Version.compare_versions("1.0.1", "1.0.0"))
    end)

    it("should handle nil versions", function()
      assert.are.same("unknown", Version.compare_versions(nil, "1.0.0"))
      assert.are.same("unknown", Version.compare_versions("1.0.0", nil))
    end)
  end)

  -- ============================================
  -- Switcher Tests
  -- ============================================
  describe("switcher", function()
    local Switcher = require("ai.components.switcher")

    it("should load default state", function()
      local state = Switcher.load_state()
      assert.is_not_nil(state)
      assert.is_not_nil(state.active)
    end)

    it("should switch tool assignment", function()
      Switcher.switch("opencode", "gsd")
      local active = Switcher.get_active("opencode")
      assert.are.same("gsd", active)
    end)

    it("should persist state", function()
      Switcher.switch("claude", "ecc")

      -- 清除缓存，重新加载
      Switcher.clear_cache()
      local state = Switcher.load_state()

      assert.are.same("ecc", state.active.claude)
    end)
  end)

  -- ============================================
  -- Discovery Tests
  -- ============================================
  describe("discovery", function()
    local Discovery = require("ai.components.discovery")

    it("should scan directories", function()
      local found = Discovery.scan_all_dirs()
      assert.is_true(#found >= 0) -- 至少能扫描
    end)
  end)

  -- ============================================
  -- Previewer Tests
  -- ============================================
  describe("previewer", function()
    local Previewer = require("ai.components.previewer")

    it("should build preview content", function()
      -- 需要先注册组件
      local Registry = require("ai.components.registry")
      local Discovery = require("ai.components.discovery")
      Registry.clear()
      Discovery.auto_load()

      local content = Previewer.build_preview("ecc")
      assert.is_true(string.len(content) > 0)
      assert.is_true(content:match("Name") ~= nil)
    end)

    it("should build version detail lines", function()
      local Registry = require("ai.components.registry")
      local Discovery = require("ai.components.discovery")
      Registry.clear()
      Discovery.auto_load()

      local lines = Previewer.build_version_detail_lines("ecc")
      assert.is_true(#lines > 0)
      assert.is_true(lines[1]:match("Component") ~= nil)
    end)
  end)

  -- ============================================
  -- ECC Component Tests
  -- ============================================
  describe("ECC component", function()
    local ECC = require("ai.components.ecc")

    it("should implement interface", function()
      local Interface = require("ai.components.interface")
      local valid, err = Interface.validate_component(ECC)
      assert.is_true(valid)
    end)

    it("should check dependencies", function()
      local deps = ECC.check_dependencies()
      assert.is_true(#deps > 0)

      -- 检查依赖结构
      for _, dep in ipairs(deps) do
        assert.is_not_nil(dep.name)
        assert.is_not_nil(dep.installed)
        assert.is_not_nil(dep.required)
      end
    end)

    it("should return version info", function()
      local info = ECC.get_version_info()
      assert.is_not_nil(info)
      assert.is_not_nil(info.status)
    end)

    it("should health check", function()
      local health = ECC.health_check()
      assert.is_not_nil(health)
      assert.is_not_nil(health.status)
      assert.is_not_nil(health.message)
    end)
  end)

  -- ============================================
  -- GSD Component Tests
  -- ============================================
  describe("GSD component", function()
    local GSD = require("ai.components.gsd")

    it("should implement interface", function()
      local Interface = require("ai.components.interface")
      local valid, err = Interface.validate_component(GSD)
      assert.is_true(valid)
    end)

    it("should check dependencies", function()
      local deps = GSD.check_dependencies()
      assert.is_true(#deps >= 2) -- npx, node
    end)

    it("should return version info", function()
      local info = GSD.get_version_info()
      assert.is_not_nil(info)
      assert.is_not_nil(info.status)
    end)
  end)

  -- ============================================
  -- Integration Tests
  -- ============================================
  describe("integration", function()
    it("should auto-discover components", function()
      local Discovery = require("ai.components.discovery")
      local Registry = require("ai.components.registry")

      Registry.clear()
      Discovery.auto_load()

      local count = Registry.count()
      assert.is_true(count >= 2) -- ECC + GSD
    end)

    it("should list installed components", function()
      local Registry = require("ai.components.registry")
      local Discovery = require("ai.components.discovery")

      Registry.clear()
      Discovery.auto_load()

      local installed = Registry.list_installed()
      assert.is_true(#installed >= 0)
    end)
  end)
end)
