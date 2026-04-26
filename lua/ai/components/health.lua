-- lua/ai/components/health.lua
-- Health check module for AI Component Manager
-- Implements :checkhealth ai_components
-- Per HC-01, HC-02, HC-03

local M = {}

----------------------------------------------------------------------
-- Check Component Manager Infrastructure
----------------------------------------------------------------------
local function check_component_manager()
  vim.health.start("ai.components.manager")

  local Manager = require("ai.components.manager")
  local Deployments = require("ai.components.deployments")
  local Registry = require("ai.components.registry")

  -- HC-01: Check cache directory
  local cache_base = Manager.ensure_cache_dir()
  if vim.fn.isdirectory(cache_base) == 1 then
    vim.health.ok("Cache directory exists: " .. cache_base)
  else
    vim.health.warn("Cache directory missing: " .. cache_base)
    vim.health.info("Run :lua require('ai.components.manager').ensure_cache_dir()")
  end

  -- Check state file
  local state_path = Deployments.state_path()
  if vim.fn.filereadable(state_path) == 1 then
    vim.health.ok("Deployments state file exists: " .. state_path)

    -- Try to load and validate state
    local ok, state = pcall(Deployments.load_state)
    if ok and state then
      local deployment_count = state.deployments and vim.tbl_count(state.deployments) or 0
      vim.health.ok("Deployments tracked: " .. deployment_count)
    else
      vim.health.warn("State file may be corrupted")
      vim.health.info("Run :lua require('ai.components.deployments').clear_cache() to reset")
    end
  else
    vim.health.info("Deployments state file not found (will be created on first deploy)")
  end

  -- HC-03: State consistency check
  local consistency = Registry.validate_state_consistency()
  if consistency and consistency.consistent then
    vim.health.ok("State consistency: valid")
  else
    vim.health.warn("State consistency: issues found")
    if consistency and consistency.issues then
      for _, issue in ipairs(consistency.issues) do
        vim.health.warn("  - " .. issue)
      end
    end
    vim.health.info("Run :AIComponents to review and fix")
  end

  -- Registry status
  local components = Registry.list()
  if #components > 0 then
    vim.health.ok("Components registered: " .. #components)
  else
    vim.health.info("No components registered yet")
    vim.health.info("Run :AIComponents to discover and register")
  end
end

----------------------------------------------------------------------
-- Check Cached Components
----------------------------------------------------------------------
local function check_cached_components()
  vim.health.start("ai.components.cache")

  local Manager = require("ai.components.manager")
  local Registry = require("ai.components.registry")
  local Discovery = require("ai.components.discovery")

  -- Ensure components are discovered
  Discovery.auto_load()

  -- Get cached components
  local cached_list = Registry.list_cached()

  if #cached_list == 0 then
    vim.health.info("No components cached")
    vim.health.info("Run :AIComponents → [i] Install to cache a component")
    return
  end

  vim.health.ok("Cached components: " .. #cached_list)

  for _, comp in ipairs(cached_list) do
    local version = Manager.get_cache_version(comp.name)
    local version_str = version and version:sub(1, 8) or "unknown"
    vim.health.ok(string.format("  %s: cached (v%s)", comp.display_name or comp.name, version_str))
  end
end

----------------------------------------------------------------------
-- Check Deployment Status
----------------------------------------------------------------------
local function check_deployments()
  vim.health.start("ai.components.deployments")

  local Deployments = require("ai.components.deployments")
  local Registry = require("ai.components.registry")
  local Switcher = require("ai.components.switcher")

  local state = Deployments.load_state()

  if not state or not state.deployments or vim.tbl_isempty(state.deployments) then
    vim.health.info("No deployments recorded")
    vim.health.info("Run :AIComponents → [d] Deploy to deploy a cached component")
    return
  end

  -- Report deployment records
  local deployment_count = vim.tbl_count(state.deployments)
  vim.health.ok("Components deployed: " .. deployment_count)

  for comp_name, comp_state in pairs(state.deployments) do
    if comp_state.deployed_to then
      for target, info in pairs(comp_state.deployed_to) do
        local method = info.method or "symlink"
        vim.health.ok(string.format("  %s → %s (%s)", comp_name, target, method))

        -- Verify deployment path exists
        local comp = Registry.get(comp_name)
        if comp and comp.get_deploy_paths then
          local paths = comp.get_deploy_paths(target)
          for _, path_info in ipairs(paths) do
            local target_path = vim.fn.expand(path_info.target)
            if vim.fn.isdirectory(target_path) == 1 or vim.fn.filereadable(target_path) == 1 then
              -- Path exists, ok
            else
              vim.health.warn("    Missing path: " .. target_path)
            end
          end
        end
      end
    end
  end

  -- Report tool assignments from Switcher
  vim.health.info("Tool assignments:")
  local assignments = Switcher.get_all()
  if vim.tbl_isempty(assignments) then
    vim.health.info("  No tools assigned to components")
  else
    for tool, comp_name in pairs(assignments) do
      vim.health.info(string.format("  %s → %s", tool, comp_name))
    end
  end

  -- Check for stale cache
  for comp_name in pairs(state.deployments) do
    if Deployments.is_cache_stale(comp_name) then
      vim.health.warn("Cache may be stale for: " .. comp_name)
      vim.health.info("Consider running update_cache for " .. comp_name)
    end
  end
end

----------------------------------------------------------------------
-- Main check function
----------------------------------------------------------------------
function M.check()
  -- Run all checks
  check_component_manager()
  check_cached_components()
  check_deployments()
end

return M