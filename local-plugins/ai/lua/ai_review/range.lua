local M = {}

local SHA_PATTERN = "^%x%x%x%x%x%x%x[%x]*$"

local function now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function M.is_sha(value)
  return type(value) == "string" and #value >= 7 and #value <= 40 and value:match(SHA_PATTERN) ~= nil
end

function M.single_commit(sha)
  return { type = "single_commit", sha = sha, created_at = now() }
end

function M.commit_range(base, head, selected_commits)
  return {
    type = "commit_range",
    base = base,
    head = head,
    selected_commits = selected_commits or { base, head },
    created_at = now(),
  }
end

function M.since_base(base, head)
  return { type = "since_base", base = base, head = head or "HEAD", created_at = now() }
end

function M.worktree(opts)
  opts = opts or {}
  return {
    type = "worktree",
    include_staged = opts.include_staged ~= false,
    include_unstaged = opts.include_unstaged ~= false,
    include_untracked = opts.include_untracked ~= false,
    created_at = now(),
  }
end

function M.temporary()
  return { type = "temporary", created_at = now() }
end

function M.validate(range)
  if type(range) ~= "table" then
    return { ok = false, error = "range must be table" }
  end
  if range.type == "single_commit" then
    return M.is_sha(range.sha) and { ok = true } or { ok = false, error = "invalid sha" }
  end
  if range.type == "commit_range" then
    if not M.is_sha(range.base) then
      return { ok = false, error = "invalid base sha" }
    end
    if not M.is_sha(range.head) then
      return { ok = false, error = "invalid head sha" }
    end
    return { ok = true }
  end
  if range.type == "since_base" then
    if not M.is_sha(range.base) then
      return { ok = false, error = "invalid base sha" }
    end
    if range.head ~= nil and range.head ~= "HEAD" and not M.is_sha(range.head) then
      return { ok = false, error = "invalid head" }
    end
    return { ok = true }
  end
  if range.type == "worktree" or range.type == "temporary" then
    return { ok = true }
  end
  return { ok = false, error = "unknown range type: " .. tostring(range.type) }
end

function M.validate_in_repo(range)
  local basic = M.validate(range)
  if not basic.ok then
    return basic
  end
  local shas = {}
  if range.sha then
    table.insert(shas, range.sha)
  end
  if range.base then
    table.insert(shas, range.base)
  end
  if range.head and range.head ~= "HEAD" then
    table.insert(shas, range.head)
  end
  for _, sha in ipairs(shas) do
    local result = vim.system({ "git", "cat-file", "-t", sha }):wait()
    if result.code ~= 0 then
      return { ok = false, error = "commit not found: " .. sha }
    end
  end
  return { ok = true }
end

function M.to_diffview_args(range)
  if range.type == "single_commit" then
    return range.sha .. "^.." .. range.sha
  end
  if range.type == "commit_range" then
    return range.base .. ".." .. range.head
  end
  if range.type == "since_base" then
    return range.base .. ".." .. (range.head or "HEAD")
  end
  if range.type == "worktree" then
    return range.include_untracked and "--untracked-files=all" or "--untracked-files=no"
  end
  return ""
end

function M.describe(range)
  if not range then
    return "unknown"
  end
  if range.type == "single_commit" then
    return range.sha:sub(1, 7) .. "^.." .. range.sha:sub(1, 7)
  end
  if range.type == "commit_range" then
    return range.base:sub(1, 7) .. ".." .. range.head:sub(1, 7)
  end
  if range.type == "since_base" then
    return range.base:sub(1, 7) .. ".." .. (range.head or "HEAD")
  end
  if range.type == "worktree" then
    return "worktree"
  end
  return range.type or "unknown"
end

return M
