-- lua/ai/components/syncer.lua
-- Symlink/copy engine for deploying cached components to tool directories
--
-- Provides reliable file system operations for cache-to-target deployment
-- with automatic symlink→copy fallback on failure or Windows.
--
-- Key decisions:
-- - D-04: Prefer symlinks, automatically fallback to copy on failure
-- - D-05: Verify symlink validity after creation
-- - D-06: Windows uses copy mode automatically
-- - D-17: Create parent directory automatically before symlink/copy

local M = {}

-- Platform detection for Windows
-- Windows requires elevated permissions for symlink creation
M.IS_WINDOWS = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

--- EXT-WR-01: Allowed path prefixes for deletion (whitelist)
--- Only allow deletion within known tool directories to prevent accidental data loss
local ALLOWED_DELETE_PREFIXES = {
  vim.fn.expand("~/.claude"),
  vim.fn.expand("~/.config/opencode"),
  vim.fn.expand("~/.config/claude-code"),
  vim.fn.expand("~/.local/share/nvim/ai_components"),
  vim.fn.expand("~/.local/state/nvim/ai_components"),
}

--- EXT-WR-01: Validate path is within allowed directories before deletion
---@param path string Path to validate
---@return boolean true if path is within allowed prefixes
local function is_safe_delete_path(path)
  local normalized = vim.fs.normalize(path)
  for _, prefix in ipairs(ALLOWED_DELETE_PREFIXES) do
    local norm_prefix = vim.fs.normalize(prefix)
    if normalized:find(norm_prefix, 1, true) == 1 then
      return true
    end
  end
  return false
end

--- Create symlink with copy fallback
--- Per D-17: Creates parent directory automatically before operation
---@param source string Source path (cache)
---@param target string Target path (tool directory)
---@return boolean, string success, method_used_or_error
function M.link_or_copy(source, target)
  -- Expand paths to handle ~ and environment variables
  source = vim.fn.expand(source)
  target = vim.fn.expand(target)

  -- Validate source exists
  if vim.fn.isdirectory(source) ~= 1 and vim.fn.filereadable(source) ~= 1 then
    return false, "Source does not exist: " .. source
  end

  -- Windows: always use copy (D-06)
  if M.IS_WINDOWS then
    return M.copy_recursive(source, target)
  end

  -- Linux/macOS: symlink with fallback

  -- D-17: Ensure target parent directory exists FIRST
  local target_dir = vim.fn.fnamemodify(target, ":h")
  if vim.fn.isdirectory(target_dir) == 0 then
    local mkdir_ok = vim.fn.mkdir(target_dir, "p")
    if mkdir_ok ~= 1 then
      return false, "Failed to create parent directory: " .. target_dir
    end
  end

  -- Remove existing target (file, dir, symlink) to allow symlink creation
  -- EXT-WR-01: Validate path before deletion
  if vim.fn.isdirectory(target) == 1 or vim.fn.filereadable(target) == 1 then
    if is_safe_delete_path(target) then
      vim.fn.delete(target, "rf")
    else
      return false, "Refusing to delete path outside allowed directories: " .. target
    end
  end

  -- Attempt symlink with ln -sfn (force, no-dereference)
  -- Security: Use shellescape to properly escape paths (CR-01 fix)
  local safe_source = vim.fn.shellescape(source)
  local safe_target = vim.fn.shellescape(target)
  local cmd = string.format("ln -sfn %s %s", safe_source, safe_target)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    -- Symlink failed, fallback to copy (D-04)
    vim.notify("Symlink failed, using copy: " .. result, vim.log.levels.WARN)
    return M.copy_recursive(source, target)
  end

  -- D-05: Verify symlink validity
  if M.verify_link(source, target) then
    return true, "symlink"
  else
    -- Invalid symlink, delete and use copy
    vim.notify("Symlink verification failed, using copy", vim.log.levels.WARN)
    -- EXT-WR-01: Validate path before deletion
    if is_safe_delete_path(target) then
      vim.fn.delete(target, "rf")
    end
    return M.copy_recursive(source, target)
  end
end

--- Verify symlink points to correct target
---@param expected_source string Expected source path
---@param link_path string Path to check
---@return boolean true if valid symlink pointing to expected source
function M.verify_link(expected_source, link_path)
  -- Expand paths
  expected_source = vim.fn.expand(expected_source)
  link_path = vim.fn.expand(link_path)

  -- Check if link path exists
  if vim.fn.isdirectory(link_path) ~= 1 and vim.fn.filereadable(link_path) ~= 1 then
    return false
  end

  -- Resolve symlink to get actual target
  local resolved = vim.fn.resolve(link_path)

  -- Verify resolved matches expected AND source exists (handles broken symlinks)
  if resolved == expected_source then
    -- For directory sources, check with isdirectory
    -- For file sources, check with filereadable
    if vim.fn.isdirectory(expected_source) == 1 then
      return true
    elseif vim.fn.filereadable(expected_source) == 1 then
      return true
    end
  end

  return false
end

--- Recursive copy (platform-specific)
--- Security: Quote paths with single quotes (T-02-02)
---@param source string Source path
---@param target string Target path
---@return boolean, string success, "copy" or error message
function M.copy_recursive(source, target)
  -- Expand paths
  source = vim.fn.expand(source)
  target = vim.fn.expand(target)

  -- Validate source exists
  if vim.fn.isdirectory(source) ~= 1 and vim.fn.filereadable(source) ~= 1 then
    return false, "Source does not exist: " .. source
  end

  -- D-17: Ensure target parent directory exists
  local target_dir = vim.fn.fnamemodify(target, ":h")
  if vim.fn.isdirectory(target_dir) == 0 then
    local mkdir_ok = vim.fn.mkdir(target_dir, "p")
    if mkdir_ok ~= 1 then
      return false, "Failed to create parent directory: " .. target_dir
    end
  end

  -- Remove existing target
  -- EXT-WR-01: Validate path before deletion
  if vim.fn.isdirectory(target) == 1 or vim.fn.filereadable(target) == 1 then
    if is_safe_delete_path(target) then
      vim.fn.delete(target, "rf")
    else
      return false, "Refusing to delete path outside allowed directories: " .. target
    end
  end

  -- Platform-specific copy command (security: shellescape for proper escaping - CR-01 fix)
  local safe_source = vim.fn.shellescape(source)
  local safe_target = vim.fn.shellescape(target)
  local cmd
  if M.IS_WINDOWS then
    -- Windows: xcopy with recursive, assume directory, no prompt
    cmd = string.format("xcopy /E /I /Y %s %s", safe_source, safe_target)
  else
    -- Linux/macOS: cp -r (recursive)
    cmd = string.format("cp -r %s %s", safe_source, safe_target)
  end

  vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return false, "Copy failed for: " .. source .. " -> " .. target
  end

  return true, "copy"
end

--- Remove symlink or directory safely
--- EXT-WR-01: Validate path before deletion
---@param target string Path to remove
---@return boolean, string success, "removed" or error message
function M.remove_link(target)
  -- Expand path
  target = vim.fn.expand(target)

  -- Check if target exists
  if vim.fn.isdirectory(target) ~= 1 and vim.fn.filereadable(target) ~= 1 then
    -- Nothing to remove, still success
    return true, "removed"
  end

  -- EXT-WR-01: Validate path before deletion
  if not is_safe_delete_path(target) then
    return false, "Refusing to delete path outside allowed directories: " .. target
  end

  -- Remove with recursive force
  vim.fn.delete(target, "rf")

  -- Verify removal
  if vim.fn.isdirectory(target) == 1 or vim.fn.filereadable(target) == 1 then
    return false, "Failed to remove: " .. target
  end

  return true, "removed"
end

return M