local M = {}

local VALID_SEVERITIES = {
  note = true,
  ["must-fix"] = true,
  suggestion = true,
  question = true,
}

local function now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function next_id(session)
  session.comments = session.comments or {}
  if not session.next_comment_id then
    local max_id = 0
    for _, comment in ipairs(session.comments) do
      local n = tonumber((comment.id or ""):match("^comment%-(%d+)$"))
      if n and n > max_id then
        max_id = n
      end
    end
    session.next_comment_id = max_id + 1
  end
  local id = string.format("comment-%03d", session.next_comment_id)
  session.next_comment_id = session.next_comment_id + 1
  return id
end

local function find_index(session, id)
  for i, comment in ipairs(session.comments or {}) do
    if comment.id == id then
      return i, comment
    end
  end
end

function M.create(session, opts)
  opts = opts or {}
  session.comments = session.comments or {}
  local severity = opts.severity or "note"
  if not VALID_SEVERITIES[severity] then
    severity = "note"
  end
  local ts = now()
  local comment = {
    id = opts.id or next_id(session),
    created_at = ts,
    updated_at = ts,
    severity = severity,
    status = opts.status or "open",
    message = opts.message or "",
    anchor = opts.anchor or { partial = true },
  }
  if comment.anchor.partial == nil then
    comment.anchor.partial = false
  end
  table.insert(session.comments, comment)
  return comment
end

function M.list(session)
  return session.comments or {}
end

function M.edit(session, id, patch)
  local _, comment = find_index(session, id)
  if not comment then
    return false
  end
  if patch.message ~= nil then
    comment.message = patch.message
  end
  if patch.severity ~= nil and VALID_SEVERITIES[patch.severity] then
    comment.severity = patch.severity
  end
  comment.updated_at = now()
  return true, comment
end

function M.delete(session, id)
  local idx = find_index(session, id)
  if not idx then
    return false
  end
  table.remove(session.comments, idx)
  return true
end

function M.resolve(session, id)
  local _, comment = find_index(session, id)
  if not comment then
    return false
  end
  comment.status = "resolved"
  comment.updated_at = now()
  return true, comment
end

function M.for_anchor(session, anchor)
  local out = {}
  if not session or not anchor then
    return out
  end
  for _, comment in ipairs(session.comments or {}) do
    local a = comment.anchor or {}
    if a.file == anchor.file and a.line == anchor.line and (a.side or "right") == (anchor.side or "right") then
      table.insert(out, comment)
    end
  end
  return out
end

return M
