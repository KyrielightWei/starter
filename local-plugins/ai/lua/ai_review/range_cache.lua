local Store = require("ai_review.store")
local Range = require("ai_review.range")

local M = {}

local function now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function M.last_path()
  return Store.join(Store.ranges_dir(), "last.json")
end

function M.history_path()
  return Store.join(Store.ranges_dir(), "ranges.json")
end

function M.save(range)
  local valid = Range.validate(range)
  if not valid.ok then
    return false, valid.error
  end
  local item = vim.deepcopy(range)
  item.id = item.id or ("range-" .. os.date("%Y-%m-%d-%H%M%S"))
  item.repo = Store.repo_root()
  item.updated_at = now()
  local ok, err = Store.write_json(M.last_path(), item)
  if not ok then
    return false, err
  end
  local history = Store.read_json(M.history_path()) or { ranges = {} }
  history.ranges = history.ranges or {}
  table.insert(history.ranges, 1, item)
  Store.write_json(M.history_path(), history)
  return true, item
end

function M.load_last(opts)
  opts = opts or {}
  local range = Store.read_json(M.last_path())
  if not range then
    return nil
  end
  local valid = opts.validate_repo and Range.validate_in_repo(range) or Range.validate(range)
  if not valid.ok then
    return nil, valid.error
  end
  return range
end

return M
