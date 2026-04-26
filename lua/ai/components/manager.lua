-- lua/ai/components/manager.lua
-- Cache + Deploy Lifecycle Manager
--
-- Provides unified cache management (install_to_cache, update_cache)
-- and deployment (deploy_to, deploy_all, undeploy_from, rollback_partial)
-- that components use without implementing their own symlink logic.
--
-- Key decisions:
-- - D-01: Cache at ~/.local/share/nvim/ai_components/cache/
-- - D-07: update_cache() only updates cache, does NOT deploy
-- - D-08: Prompt user for redeploy AFTER update
-- - D-15: Version from git rev-parse HEAD
-- - D-16: deploy_all returns { success[], failed[] }, rollback_partial available

local M = {}

--- Cache base directory (per D-01, D-02)
local CACHE_BASE = vim.fn.expand("~/.local/share/nvim/ai_components/cache")

--- Module dependencies
local Deployments = require("ai.components.deployments")
local Syncer = require("ai.components.syncer")
local Registry = require("ai.components.registry")

--- Get cache path for a component
---@param component_name string Component name
---@return string Full path to cache directory
function M.get_cache_path(component_name)
  -- EXT-WR-03: Use strict alphanumeric validation instead of simple regex
  -- The previous regex [../] was too simple and missed encoded sequences like ..%2f
  assert(component_name:match("^[a-zA-Z0-9_-]+$"), "Invalid component name: must be alphanumeric with underscores/hyphens only")
  return CACHE_BASE .. "/" .. component_name
end

--- Ensure cache base directory exists
---@return string Cache base directory path
function M.ensure_cache_dir()
  if vim.fn.isdirectory(CACHE_BASE) == 0 then
    vim.fn.mkdir(CACHE_BASE, "p")
  end
  return CACHE_BASE
end

--- Get git version hash from cache directory (per D-15)
---@param cache_path string Path to cached component
---@return string|nil Git commit hash or nil if not a git repo
local function _get_git_version(cache_path)
  if vim.fn.isdirectory(cache_path .. "/.git") == 1 then
    -- Security: Use shellescape to prevent command injection (CR-02 fix)
    local safe_path = vim.fn.shellescape(cache_path)
    local cmd = string.format("git -C %s rev-parse HEAD", safe_path)
    local hash = vim.fn.system(cmd)
    if vim.v.shell_error == 0 then
      return vim.trim(hash)
    end
  end
  return nil
end

--- Check if component is cached
--- Checks: 1) Registry registration, 2) Cache directory, 3) Deployments state
---@param component_name string Component name
---@return boolean
function M.is_cached(component_name)
  -- Check component exists in registry
  local comp = Registry.get(component_name)
  if not comp then
    return false
  end

  -- Check if component implements is_cached
  if comp.is_cached and type(comp.is_cached) == "function" then
    return comp.is_cached()
  end

  -- Check cache directory exists
  local cache_path = M.get_cache_path(component_name)
  if vim.fn.isdirectory(cache_path) ~= 1 then
    return false
  end

  -- Check deployments state for cache record
  local status = Deployments.get_deployment_status(component_name)
  if status and status.cached_at then
    return true
  end

  -- If cache directory exists but no state record, still consider cached
  return vim.fn.isdirectory(cache_path) == 1
end

--- Get cached component version
---@param component_name string Component name
---@return string|nil Version string or nil if not cached
function M.get_cache_version(component_name)
  local comp = Registry.get(component_name)
  if not comp then
    return nil
  end

  -- Check if component implements get_cache_version
  if comp.get_cache_version and type(comp.get_cache_version) == "function" then
    return comp.get_cache_version()
  end

  -- Fallback: check deployments state
  local status = Deployments.get_deployment_status(component_name)
  if status and status.cache_version then
    return status.cache_version
  end

  -- Fallback: get from git hash
  local cache_path = M.get_cache_path(component_name)
  return _get_git_version(cache_path)
end

--- Install component to cache directory
--- Calls component.install() and records version in deployments state
---@param component_name string Component name
---@param opts table|nil Options: { force = boolean, ... }
---@return boolean, string success, message
function M.install_to_cache(component_name, opts)
  opts = opts or {}

  -- Get component from registry
  local comp = Registry.get(component_name)
  if not comp then
    return false, string.format("Component '%s' not registered", component_name)
  end

  -- Ensure cache directory exists
  M.ensure_cache_dir()

  -- Get cache path
  local cache_path = M.get_cache_path(component_name)

  -- Check if already cached
  if M.is_cached(component_name) and not opts.force then
    return true, string.format("Component '%s' already cached at %s", component_name, cache_path)
  end

  -- Notify progress
  vim.notify(string.format("Installing %s to cache...", component_name), vim.log.levels.INFO)

  -- Call component.install with cache_path
  -- Component handles git clone/npm install logic
  local install_opts = vim.tbl_deep_extend("force", opts, {
    cache_path = cache_path,
  })

  local ok, msg
  if comp.install and type(comp.install) == "function" then
    -- WR-03: Add pcall wrapper for consistent error handling
    local call_ok, call_result = pcall(function()
      return comp.install(install_opts, function(progress)
        vim.notify(progress, vim.log.levels.INFO)
      end)
    end)

    if not call_ok then
      vim.notify(string.format("Failed to cache %s: %s", component_name, tostring(call_result)), vim.log.levels.ERROR)
      return false, tostring(call_result)
    end
    ok, msg = call_result
  else
    return false, string.format("Component '%s' does not implement install()", component_name)
  end

  if not ok then
    vim.notify(string.format("Failed to cache %s: %s", component_name, msg), vim.log.levels.ERROR)
    return false, msg
  end

  -- Per D-15: Get version from git rev-parse HEAD
  local version = _get_git_version(cache_path)
  if not version then
    -- Fallback for non-git components (Phase 3 will handle)
    version = "unknown"
  end

  -- Record in deployments state
  Deployments.record_cache(component_name, version)

  vim.notify(
    string.format("Component '%s' cached successfully (version: %s)", component_name, version),
    vim.log.levels.INFO
  )

  return true, string.format("Installed to cache: %s", cache_path)
end

--- Deploy cached component to a specific target tool
--- Uses syncer.link_or_copy for symlink/copy and deployments.record_deployment
---@param component_name string Component name
---@param target string Target tool name (e.g., "claude", "opencode")
---@return boolean, string success, message
function M.deploy_to(component_name, target)
  -- Get component from registry
  local comp = Registry.get(component_name)
  if not comp then
    return false, string.format("Component '%s' not registered", component_name)
  end

  -- Check if cached
  if not M.is_cached(component_name) then
    return false, string.format("Component '%s' not in cache. Run install_to_cache first.", component_name)
  end

  -- Get deploy paths from component
  local paths = {}
  if comp.get_deploy_paths and type(comp.get_deploy_paths) == "function" then
    paths = comp.get_deploy_paths(target)
  else
    return false, string.format("Component '%s' does not define get_deploy_paths(target)", component_name)
  end

  if #paths == 0 then
    return false, string.format("No deploy paths defined for '%s' to '%s'", component_name, target)
  end

  -- Call pre_deploy hook if exists
  if comp.pre_deploy and type(comp.pre_deploy) == "function" then
    local pre_ok, pre_msg = comp.pre_deploy(target)
    if not pre_ok then
      return false, string.format("pre_deploy failed: %s", pre_msg or "unknown")
    end
  end

  -- Deploy each path via syncer
  local last_method = "symlink"
  local deploy_errors = {}

  for _, path_info in ipairs(paths) do
    local source = path_info.source
    local target_path = path_info.target

    if not source or not target_path then
      table.insert(deploy_errors, "Invalid path mapping: missing source or target")
      goto continue
    end

    -- Ensure paths are expanded
    source = vim.fn.expand(source)
    target_path = vim.fn.expand(target_path)

    -- Verify source exists in cache
    if vim.fn.isdirectory(source) ~= 1 and vim.fn.filereadable(source) ~= 1 then
      table.insert(deploy_errors, string.format("Source not found: %s", source))
      goto continue
    end

    -- Deploy via syncer.link_or_copy
    local ok, method_or_err = Syncer.link_or_copy(source, target_path)
    if ok then
      last_method = method_or_err -- "symlink" or "copy"
    else
      table.insert(deploy_errors, string.format("%s -> %s: %s", source, target_path, method_or_err))
    end

    ::continue::
  end

  if #deploy_errors > 0 then
    vim.notify(
      string.format("Deployment errors for %s:\n%s", component_name, table.concat(deploy_errors, "\n")),
      vim.log.levels.ERROR
    )
    return false, table.concat(deploy_errors, "; ")
  end

  -- Record deployment
  Deployments.record_deployment(component_name, target, last_method)

  -- Call post_deploy hook if exists
  if comp.post_deploy and type(comp.post_deploy) == "function" then
    comp.post_deploy(target)
  end

  vim.notify(
    string.format("Deployed '%s' to '%s' (method: %s)", component_name, target, last_method),
    vim.log.levels.INFO
  )

  return true, string.format("Deployed to %s via %s", target, last_method)
end

--- Deploy component to all supported target tools
--- Per D-16: Returns structured result { success[], failed[] }
---@param component_name string Component name
---@return table { success = { { target, method }[] }, failed = { { target, error }[] } }
function M.deploy_all(component_name)
  -- Get component from registry
  local comp = Registry.get(component_name)
  if not comp then
    return {
      success = {},
      failed = { { target = "none", error = string.format("Component '%s' not registered", component_name) } },
    }
  end

  -- Get supported targets
  local targets = comp.supported_targets or {}

  if #targets == 0 then
    return {
      success = {},
      failed = { { target = "none", error = "No supported_targets defined" } },
    }
  end

  -- Initialize result structure (per D-16)
  local result = {
    success = {},
    failed = {},
  }

  -- Deploy to each target
  for _, target in ipairs(targets) do
    local ok, msg = M.deploy_to(component_name, target)
    if ok then
      table.insert(result.success, { target = target, method = msg })
    else
      table.insert(result.failed, { target = target, error = msg })
    end
  end

  -- Per D-08: Prompt user if partial failure
  if #result.failed > 0 and #result.success > 0 then
    vim.notify(
      string.format("Deployment partial: %d succeeded, %d failed. Consider rollback_partial() if needed.", #result.success, #result.failed),
      vim.log.levels.WARN
    )
  end

  return result
end

--- Rollback partial deployments on failure
--- Per D-16: Undeploy from successfully deployed targets
---@param component_name string Component name
---@param deployed_targets table[] Array of { target = string } from result.success
---@return boolean, string success, message
function M.rollback_partial(component_name, deployed_targets)
  if not deployed_targets or #deployed_targets == 0 then
    return true, "No targets to roll back"
  end

  local rollback_errors = {}

  for _, target_info in ipairs(deployed_targets) do
    local target = target_info.target
    local ok, msg = M.undeploy_from(component_name, target)
    if not ok then
      table.insert(rollback_errors, string.format("%s: %s", target, msg))
    end
  end

  if #rollback_errors > 0 then
    return false, string.format("Rollback errors: %s", table.concat(rollback_errors, "; "))
  end

  vim.notify(
    string.format("Rolled back %d deployments for '%s'", #deployed_targets, component_name),
    vim.log.levels.INFO
  )

  return true, string.format("Rolled back %d deployments", #deployed_targets)
end

--- Undeploy component from a specific target tool
--- Uses syncer.remove_link and deployments.clear_deployment
---@param component_name string Component name
---@param target string Target tool name
---@return boolean, string success, message
function M.undeploy_from(component_name, target)
  -- Get component from registry
  local comp = Registry.get(component_name)
  if not comp then
    return false, string.format("Component '%s' not registered", component_name)
  end

  -- Get deploy paths from component
  local paths = {}
  if comp.get_deploy_paths and type(comp.get_deploy_paths) == "function" then
    paths = comp.get_deploy_paths(target)
  else
    return false, string.format("Component '%s' does not define get_deploy_paths(target)", component_name)
  end

  if #paths == 0 then
    -- No paths to undeploy, but still clear deployment record
    Deployments.clear_deployment(component_name, target)
    return true, string.format("No paths to undeploy, cleared deployment record for %s", target)
  end

  -- Remove each deployed path
  local removal_errors = {}

  for _, path_info in ipairs(paths) do
    local target_path = path_info.target
    if not target_path then
      goto continue
    end

    target_path = vim.fn.expand(target_path)

    -- Remove via syncer.remove_link
    local ok, msg = Syncer.remove_link(target_path)
    if not ok then
      table.insert(removal_errors, string.format("%s: %s", target_path, msg))
    end

    ::continue::
  end

  if #removal_errors > 0 then
    vim.notify(
      string.format("Undeploy errors for %s:\n%s", component_name, table.concat(removal_errors, "\n")),
      vim.log.levels.WARN
    )
  end

  -- Clear deployment record
  Deployments.clear_deployment(component_name, target)

  vim.notify(string.format("Undeployed '%s' from '%s'", component_name, target), vim.log.levels.INFO)

  return true, string.format("Undeployed from %s", target)
end

--- Update component cache only (per D-07)
--- Does NOT touch deployed targets - prompts user for redeploy decision after update
---@param component_name string Component name
---@param opts table|nil Options: { force = boolean, ... }
---@return boolean, string success, message
function M.update_cache(component_name, opts)
  opts = opts or {}

  -- Get component from registry
  local comp = Registry.get(component_name)
  if not comp then
    return false, string.format("Component '%s' not registered", component_name)
  end

  -- Check if cached
  if not M.is_cached(component_name) then
    return false, string.format("Component '%s' not in cache. Run install_to_cache first.", component_name)
  end

  local cache_path = M.get_cache_path(component_name)

  -- Notify progress
  vim.notify(string.format("Updating cache for %s...", component_name), vim.log.levels.INFO)

  -- Call component.update with cache_path
  -- Per D-07: Only update cache, NOT deployed targets
  local update_opts = vim.tbl_deep_extend("force", opts, {
    cache_path = cache_path,
  })

  local ok, msg
  if comp.update and type(comp.update) == "function" then
    ok, msg = comp.update(update_opts)
  else
    return false, string.format("Component '%s' does not implement update()", component_name)
  end

  if not ok then
    vim.notify(string.format("Failed to update cache for %s: %s", component_name, msg), vim.log.levels.ERROR)
    return false, msg
  end

  -- Per D-15: Get new version from git hash
  local new_version = _get_git_version(cache_path)
  if not new_version then
    new_version = "unknown"
  end

  -- Record new version
  Deployments.record_cache(component_name, new_version)

  vim.notify(
    string.format("Cache updated for '%s' (version: %s)", component_name, new_version),
    vim.log.levels.INFO
  )

  -- Per D-08: Prompt user for redeploy AFTER update
  local deployed_to = Deployments.get_deployment_status(component_name)
  if deployed_to and deployed_to.deployed_to and #vim.tbl_keys(deployed_to.deployed_to) > 0 then
    vim.notify(
      string.format("Cache updated. Previously deployed to: %s. Redeploy to update deployments?", table.concat(vim.tbl_keys(deployed_to.deployed_to), ", ")),
      vim.log.levels.WARN
    )
  end

  return true, string.format("Cache updated: %s (version: %s)", cache_path, new_version)
end

return M