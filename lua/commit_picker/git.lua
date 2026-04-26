-- lua/commit_picker/git.lua
-- Git commit data fetching with fallback and error handling

local M = {}

----------------------------------------------------------------------
-- Run git command synchronously using vim.system() (Neovim 0.10+)
-- Returns { ok = true, stdout = "...", stderr = "..." }
--      or { ok = false, error = "..." }
----------------------------------------------------------------------
local function run_git(args, opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.uv.cwd()  -- vim.uv is forward-compatible (IN-03 fix)

  -- Wrap vim.system in pcall to handle case where git is not on PATH (CR-02 fix)
  local ok, result = pcall(function()
    return vim.system({ "git", unpack(args) }):wait()
  end)

  if not ok then
    -- vim.system() threw — likely git not found on PATH
    return { ok = false, error = "git 命令不可用: " .. tostring(result) }
  end

  if result.code ~= 0 then
    local err = result.stderr or result.stdout or "unknown error"
    -- Redact any sensitive data that might leak in error output
    err = err:gsub("(sk-)[%w]+", "%1***")
    return { ok = false, error = err }
  end

  return { ok = true, stdout = result.stdout or "", stderr = result.stderr or "" }
end

----------------------------------------------------------------------
-- M.get_commit_list(base, head, opts)
-- base: optional range base (e.g. "origin/HEAD")
-- head: optional range head (e.g. "HEAD")
-- opts: { count = 20 } for fallback mode
-- Returns: array of { sha, short_sha, subject, date, refs }
----------------------------------------------------------------------
function M.get_commit_list(base, head, opts)
  opts = opts or {}
  local count = opts.count or 20

  local args = { "log", "--format=%H%x00%h%x00%s%x00%cr%x00%d" }

  if base and head then
    table.insert(args, base .. ".." .. head)
  elseif head then
    table.insert(args, "--max-count=" .. tostring(count))
    table.insert(args, head)
  else
    table.insert(args, "--max-count=" .. tostring(count))
    table.insert(args, "HEAD")
  end

  local result = run_git(args)

  if not result.ok then
    -- Return empty if not a git repo or no remote origin
    if result.error:match("not a git repository") or
       result.error:match("bad revision") then
      return {}
    end
    return { error = true, output = result.error }
  end

  local output = result.stdout
  if not output or output == "" then
    return {}
  end

  -- Parse commit data (NUL-separated fields, newlines between commits)
  local commits = {}
  for line in output:gmatch("[^\r\n]+") do
    local parts = vim.split(line, "\0")
    if #parts >= 5 then
      local sha = parts[1]
      local short_sha = parts[2]
      local subject = parts[3]
      local date = parts[4]
      local refs = parts[5]

      -- Clean up refs string (remove surrounding parens and trim)
      refs = refs:gsub("^%s*%(%s*", ""):gsub("%s*%)%s*$", "")
      if refs == "" then refs = "" end

      -- Ensure short_sha is available
      if short_sha == "" then short_sha = sha:sub(1, 7) end

      table.insert(commits, {
        sha = sha,
        short_sha = short_sha,
        subject = subject,
        date = date,
        refs = refs,
      })
    end
  end

  return commits
end

----------------------------------------------------------------------
-- M.get_unpushed()
-- Returns unpushed commits (origin/HEAD..HEAD)
-- Empty if none exist or git error
----------------------------------------------------------------------
function M.get_unpushed()
  local commits = M.get_commit_list("origin/HEAD", "HEAD")
  if type(commits) ~= "table" or commits.error then
    return {}
  end
  return commits
end

----------------------------------------------------------------------
-- M.get_ahead_behind()
-- Returns { ahead = N, behind = M }
----------------------------------------------------------------------
function M.get_ahead_behind()
  local result = run_git({ "rev-list", "--left-right", "--count", "origin/HEAD...HEAD" })

  if not result.ok then
    return { ahead = 0, behind = 0 }
  end

  local behind, ahead = result.stdout:match("(%d+)%s+(%d+)")
  if behind and ahead then
    return { ahead = tonumber(ahead), behind = tonumber(behind) }
  end

  return { ahead = 0, behind = 0 }
end

----------------------------------------------------------------------
-- M.get_commits_for_mode()
-- High-level function that reads config mode and returns commits
-- Handles fallback when configured mode fails
----------------------------------------------------------------------
function M.get_commits_for_mode()
  local ok, Config = pcall(require, "commit_picker.config")
  local config = ok and Config.get_config() or { mode = "unpushed", count = 20, base_commit = nil }

  if config.mode == "unpushed" then
    local commits = M.get_unpushed()
    if #commits > 0 then
      return commits, nil
    end
    -- Fallback: no unpushed commits, use last N with diagnostic info
    local ok_ab, ab = pcall(M.get_ahead_behind)
    local count = config.count or 20
    if ok_ab and ab then
      vim.notify(
        string.format("未找到远程提交 (ahead %d, behind %d)，回退到最近 %d 条",
          ab.ahead, ab.behind, count),
        vim.log.levels.WARN
      )
    else
      vim.notify(
        string.format("无法获取远程状态，回退到最近 %d 条", count),
        vim.log.levels.WARN
      )
    end
    return M.get_commit_list(nil, nil, { count = count }), nil
  end

  if config.mode == "last_n" then
    local count = config.count or 20
    return M.get_commit_list(nil, nil, { count = count }), nil
  end

  if config.mode == "since_base" and config.base_commit then
    -- Validate SHA format before using (WR-03 fix: guard nil access)
    if type(config.base_commit) == "string" and config.base_commit:match("^%x%x%x%x%x%x%x[%x]*$") then
      local commits = M.get_commit_list(config.base_commit, "HEAD")
      if type(commits) == "table" and not commits.error and #commits > 0 then
        return commits, config.base_commit
      end
    end
    -- Fallback: invalid base, use last N (WR-03 fix: consistent return with nil base)
    local count = config.count or 20
    local short = (config.base_commit and config.base_commit:sub(1, 7)) or "?"
    vim.notify(
      string.format("基础提交不可用 (%s)，回退到最近 %d 条", short, count),
      vim.log.levels.WARN
    )
    return M.get_commit_list(nil, nil, { count = count }), nil
  end

  -- Default fallback (WR-03 fix: consistent return with nil base)
  local count = config.count or 20
  return M.get_commit_list(nil, nil, { count = count }), nil
end

return M
