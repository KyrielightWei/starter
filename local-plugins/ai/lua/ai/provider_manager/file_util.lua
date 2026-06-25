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
  local lines = vim.split(content, "\n")
  local ok, err = pcall(vim.fn.writefile, lines, tmp_path)

  if not ok then
    vim.notify("Failed to write temp file: " .. tostring(err), vim.log.levels.ERROR)
    -- Clean up .tmp if it exists
    if vim.fn.filereadable(tmp_path) == 1 then
      pcall(vim.fn.delete, tmp_path)
    end
    return false, tostring(err)
  end

  -- Step 2: Rename .tmp → target (atomic on most filesystems)
  local rename_success = false
  local rename_error = nil

  local uv = vim.uv or vim.loop
  if uv and uv.fs_rename then
    -- M-08 修复：uv.fs_rename 成功返回 true，失败返回 nil, err
    local result, rename_err = uv.fs_rename(tmp_path, path)
    if result then
      rename_success = true
    else
      rename_error = rename_err or "unknown error"
    end
  end

  if not rename_success then
    -- Fallback 1: Try os.rename (portable but less atomic)
    local ok_os = os.rename(tmp_path, path)
    if ok_os then
      rename_success = true
    else
      -- Fallback 2: Direct write (non-atomic, last resort)
      -- FIX: Use the ORIGINAL lines/content, NOT readfile(tmp_path) which may fail
      local write_ok = pcall(vim.fn.writefile, lines, path)
      if write_ok then
        rename_success = true
        -- Clean up .tmp since we wrote directly
        pcall(vim.fn.delete, tmp_path)
      else
        rename_error = "all rename methods failed"
      end
    end
  end

  -- Clean up .tmp file (if still exists after successful rename)
  if vim.fn.filereadable(tmp_path) == 1 then
    pcall(vim.fn.delete, tmp_path)
  end

  if not rename_success then
    vim.notify("Failed to rename temp file: " .. tostring(rename_error), vim.log.levels.ERROR)
    return false, rename_error
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
  local cwd = vim.fn.getcwd()
  local project_ai_dir = cwd .. "/local-plugins/ai/lua/ai/"
  local config_dir = vim.fn.stdpath("config") .. "/local-plugins/ai/lua/ai/"
  local abs_path = vim.fn.fnamemodify(path, ":p")
  local abs_project_dir = vim.fn.fnamemodify(project_ai_dir, ":p")
  local abs_config_dir = vim.fn.fnamemodify(config_dir, ":p")

  -- Use exact directory containment check (not prefix match)
  -- Prevents bypass via sibling directories like ai_evil/
  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(abs_path)
  if not stat or stat.type ~= "file" then
    return nil, "Path is not a regular file: " .. path
  end
  local path_dir = vim.fn.fnamemodify(abs_path, ":h") .. "/"
  if path_dir ~= abs_project_dir and path_dir ~= abs_config_dir then
    -- Check subdirectory containment
    if not path_dir:find("^" .. vim.pesc(abs_project_dir)) and not path_dir:find("^" .. vim.pesc(abs_config_dir)) then
      return nil, "Refusing to load file outside ai/ directory"
    end
  end

  -- C-01 修复：使用沙箱 load 替代 dofile，防止任意代码执行
  -- 即使目录检查和模式扫描被绕过，沙箱环境也能阻止危险操作
  local content_lines = vim.fn.readfile(path)
  local content = table.concat(content_lines, "\n")

  -- 预扫描危险模式（纵深防御）
  local dangerous_patterns = {
    "os%.execute",
    "os%.spawn",
    "io%.popen",
    "loadstring",
    "loadfile",
    "debug%.sethook",
    "jit%.ffi",
  }
  for _, pattern in ipairs(dangerous_patterns) do
    if content:match(pattern) then
      return nil, "File contains potentially dangerous code pattern: " .. pattern
    end
  end

  -- 沙箱执行：空环境表阻止访问全局变量（require, os, io 等）
  local func, load_err = load(content, path, "t", {})
  if not func then
    return nil, "Failed to load Lua file: " .. tostring(load_err)
  end
  local ok, result = pcall(func)
  if not ok then
    return nil, "Failed to execute Lua file: " .. tostring(result)
  end
  if type(result) ~= "table" then
    return nil, "Lua file must return a table, got: " .. type(result)
  end
  return result, nil
end

return M
