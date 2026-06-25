local M = {}

local test_root = nil

local function normalize(path)
  return (path:gsub("/+$", ""))
end

function M._set_root_for_tests(root)
  test_root = root and normalize(root) or nil
end

function M.repo_root()
  if test_root then
    return test_root
  end
  local result = vim.system({ "git", "rev-parse", "--show-toplevel" }):wait()
  if result.code == 0 and result.stdout and result.stdout ~= "" then
    return normalize(vim.trim(result.stdout))
  end
  return normalize(vim.uv.cwd())
end

function M.join(...)
  local parts = { ... }
  local out = table.concat(parts, "/")
  out = out:gsub("//+", "/")
  return out
end

function M.review_dir()
  return M.join(M.repo_root(), ".ai-review")
end

function M.current_path()
  return M.join(M.review_dir(), "current.json")
end

function M.ranges_dir()
  return M.join(M.review_dir(), "ranges")
end

function M.sessions_dir()
  return M.join(M.review_dir(), "sessions")
end

function M.session_dir(session_id)
  return M.join(M.sessions_dir(), session_id)
end

function M.session_path(session_id)
  return M.join(M.session_dir(session_id), "session.json")
end

function M.state_export_dir()
  local repo = M.repo_root():gsub("[^%w%._%-]+", "-"):gsub("^-+", "")
  return M.join(vim.fn.stdpath("state"), "ai-review", repo)
end

function M.ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

-- #17 修复: 临时文件权限设置带错误处理
local function safe_chmod(path, mode)
  local ok = pcall(vim.uv.fs_chmod, path, mode)
  if not ok then
    vim.notify("无法设置临时文件权限: " .. path, vim.log.levels.WARN)
  end
end

-- #4 修复: 更准确的数组判断函数
-- 注意: 空 table {} 返回 false，走 map 分支。
-- 这是有意为之：空 table 在 JSON 中可能表示 {} 或 []，
-- strip_internal_fields 对空 table 无论走哪个分支都返回 {}，结果正确。
local function is_array(t)
  if type(t) ~= "table" then
    return false
  end
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count == #t and count > 0
end

local function strip_internal_fields(tbl)
  if type(tbl) ~= "table" then
    return tbl
  end
  local out = {}
  for k, v in pairs(tbl) do
    if type(k) == "string" and k:sub(1, 1) == "_" then
      -- skip internal fields like _sign_id
    elseif type(v) == "table" then
      if is_array(v) then
        local arr = {}
        for _, item in ipairs(v) do
          table.insert(arr, strip_internal_fields(item))
        end
        out[k] = arr
      else
        out[k] = strip_internal_fields(v)
      end
    else
      out[k] = v
    end
  end
  return out
end

function M.write_json(path, data)
  M.ensure_dir(vim.fn.fnamemodify(path, ":h"))
  local encoded = vim.json.encode(strip_internal_fields(data))
  local tmp = path .. ".tmp"
  local ok, err = pcall(vim.fn.writefile, vim.split(encoded, "\n", { plain = true }), tmp)
  if not ok then
    return false, tostring(err)
  end
  -- #17 修复: 使用 safe_chmod 设置权限
  safe_chmod(tmp, 384) -- 0600
  -- M-11 修复: uv.fs_rename 成功返回 true，失败返回 nil, err
  local renamed, rename_err = vim.uv.fs_rename(tmp, path)
  if not renamed then
    os.remove(tmp)
    return false, "failed to rename temporary json file: " .. tostring(rename_err)
  end
  return true
end

function M.read_json(path, opts)
  opts = opts or {}
  if vim.fn.filereadable(path) ~= 1 then
    return nil, "file not found: " .. path
  end
  local content = table.concat(vim.fn.readfile(path), "\n")
  local ok, data = pcall(vim.json.decode, content)
  if ok and type(data) == "table" then
    return data
  end
  if opts.backup_malformed then
    local backup = path .. ".bak-" .. os.date("%Y%m%d%H%M%S")
    pcall(vim.fn.writefile, vim.fn.readfile(path), backup)
  end
  return nil, "invalid json: " .. path
end

return M
