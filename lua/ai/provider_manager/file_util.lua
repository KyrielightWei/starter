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
      local result = uv.fs_rename(tmp_path, path)
      if result then
        error("fs_rename failed: " .. tostring(result))
      end
    else
      -- Fallback: delete old, copy new
      if vim.fn.filereadable(path) == 1 then
        pcall(vim.fn.delete, path)
      end
      local lines = vim.fn.readfile(tmp_path)
      vim.fn.writefile(lines, path)
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
  local ok, result = pcall(dofile, path)
  if not ok then
    return nil, "Failed to parse Lua file: " .. tostring(result)
  end
  return result, nil
end

return M
