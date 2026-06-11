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

function M.write_json(path, data)
  M.ensure_dir(vim.fn.fnamemodify(path, ":h"))
  local encoded = vim.json.encode(data)
  local tmp = path .. ".tmp"
  local ok, err = pcall(vim.fn.writefile, vim.split(encoded, "\n", { plain = true }), tmp)
  if not ok then
    return false, tostring(err)
  end
  local renamed = vim.uv.fs_rename(tmp, path)
  if not renamed then
    os.remove(tmp)
    return false, "failed to rename temporary json file"
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
