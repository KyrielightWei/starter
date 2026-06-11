local Store = require("ai_review.store")
local Range = require("ai_review.range")

local M = {}

local active = nil

local function now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function make_id(prefix)
  return string.format("%s-%s", os.date("%Y-%m-%d-%H%M%S"), prefix or "ai-review")
end

function M._reset_for_tests()
  active = nil
end

function M.create(range, opts)
  opts = opts or {}
  range = range or Range.temporary()
  local ts = now()
  local session = {
    id = opts.id or make_id(opts.temporary and "temporary-review" or "ai-review"),
    created_at = ts,
    updated_at = ts,
    repo = Store.repo_root(),
    range = range,
    temporary = opts.temporary or range.type == "temporary" or nil,
    comments = {},
  }
  local ok, err = M.save(session)
  if not ok then
    vim.notify("AI Review session 写入失败: " .. tostring(err), vim.log.levels.ERROR)
  end
  M.set_active(session)
  return session
end

function M.save(session)
  if not session or not session.id then
    return false, "invalid session"
  end
  session.updated_at = now()
  return Store.write_json(Store.session_path(session.id), session)
end

function M.set_active(session)
  active = session
  if session and session.id then
    Store.write_json(Store.current_path(), { active_session = session.id })
  end
end

function M.get_active()
  if active then
    return active
  end
  local current = Store.read_json(Store.current_path())
  if current and current.active_session then
    return M.resume(current.active_session)
  end
  return nil
end

function M.resume(session_id)
  local session, err = Store.read_json(Store.session_path(session_id), { backup_malformed = true })
  if not session then
    vim.notify("AI Review session 读取失败: " .. tostring(err), vim.log.levels.ERROR)
    return nil, err
  end
  active = session
  Store.write_json(Store.current_path(), { active_session = session.id })
  return session
end

function M.ensure_active()
  local session = M.get_active()
  if session then
    return session
  end
  return M.create(Range.temporary(), { temporary = true })
end

function M.close()
  active = nil
  os.remove(Store.current_path())
end

function M.status()
  local session = M.get_active()
  if not session then
    return { active = false }
  end
  return {
    active = true,
    id = session.id,
    range = session.range,
    comments = #(session.comments or {}),
    path = Store.session_path(session.id),
  }
end

return M
