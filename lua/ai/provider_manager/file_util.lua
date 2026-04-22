-- lua/ai/provider_manager/file_util.lua
-- Safe file operations: atomic writes (.tmp → rename), Lua table parsing
-- Addresses review concern: HIGH — file persistence without backup/atomic write

local M = {}

----------------------------------------------------------------------
-- Write content to path via atomic .tmp → rename pattern
-- Returns: ok (bool), error_msg (string|nil)
----------------------------------------------------------------------
function M.safe_write_file(path, content)
  local tmp_path = path .. ".tmp"

  -- Step 1: Write to .tmp file
  local ok, err = pcall(function()
    local lines = vim.split(content, "\n")
    vim.fn.writefile(lines, tmp_path)
  end)

  if not ok then
    vim.notify("Failed to write temp file: " .. tostring(err), vim.log.levels.ERROR)
    -- Clean up .tmp if it exists
    if vim.fn.filereadable(tmp_path) == 1 then
      pcall(vim.fn.delete, tmp_path)
    end
    return false, tostring(err)
  end

  -- Step 2: Rename .tmp → target (atomic on most filesystems)
  local ok2, err2 = pcall(function()
    local uv = vim.loop or vim.uv
    if uv and uv.fs_rename then
      local ok_rename, result = pcall(uv.fs_rename, uv, tmp_path, path)
      if not ok_rename or result then
        -- fs_rename failed or threw error, fallback to copy
        local lines = vim.fn.readfile(tmp_path)
        vim.fn.writefile(lines, path)
        -- Try to clean up .tmp
        pcall(vim.fn.delete, tmp_path)
      end
    else
      -- Fallback: copy then delete (more reliable than delete-then-copy)
      local lines = vim.fn.readfile(tmp_path)
      vim.fn.writefile(lines, path)
      pcall(vim.fn.delete, tmp_path)
    end
  end)

  if not ok2 then
    vim.notify("Failed to rename temp file: " .. tostring(err2), vim.log.levels.ERROR)
    return false, tostring(err2)
  end

  return true, nil
end

----------------------------------------------------------------------
-- Read and parse a Lua file returning its table
-- Returns: table or nil on error
----------------------------------------------------------------------
function M.read_lua_table(path)
  if vim.fn.filereadable(path) == 0 then
    return nil, "File not found: " .. path
  end
  -- Validate path is within expected directory to prevent arbitrary code execution
  local config_dir = vim.fn.stdpath("config") .. "/lua/ai/"
  local abs_path = vim.fn.fnamemodify(path, ":p")
  local abs_config_dir = vim.fn.fnamemodify(config_dir, ":p")
  if abs_path:sub(1, #abs_config_dir) ~= abs_config_dir then
    return nil, "Refusing to load file outside ai/ directory"
  end
  local ok, result = pcall(dofile, path)
  if not ok then
    return nil, "Failed to parse Lua file: " .. tostring(result)
  end
  return result, nil
end

return M
