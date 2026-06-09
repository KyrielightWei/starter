-- lua/commit_picker/selection.lua
-- Selection state management — stores array of selected SHAs

local M = {}

-- Module-local state (not persisted to disk)
local current_selection = {} -- Array of SHA strings

----------------------------------------------------------------------
-- M.get_selected()
-- Returns a copy of the current selection
----------------------------------------------------------------------
function M.get_selected()
  local copy = {}
  for _, sha in ipairs(current_selection) do
    table.insert(copy, sha)
  end
  return copy
end

----------------------------------------------------------------------
-- M.set_selected(shas)
-- Sets the selection array. Validates and truncates to max 2 SHAs.
----------------------------------------------------------------------
function M.set_selected(shas)
  if type(shas) ~= "table" then
    current_selection = {}
    return
  end

  local Diff = require("commit_picker.diff")
  local max_count = 2
  current_selection = {}
  for i = 1, math.min(#shas, max_count) do
    local sha = tostring(shas[i])
    if Diff.is_valid_sha(sha) then
      table.insert(current_selection, sha)
    end
  end
end

----------------------------------------------------------------------
-- M.clear()
-- Resets selection to empty
----------------------------------------------------------------------
function M.clear()
  current_selection = {}
end

----------------------------------------------------------------------
-- M.has_selection()
-- Returns true if any commits are selected
----------------------------------------------------------------------
function M.has_selection()
  return #current_selection > 0
end

return M
