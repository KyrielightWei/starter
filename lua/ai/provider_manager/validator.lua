-- lua/ai/provider_manager/validator.lua
-- Input validation for Provider Manager

local Providers = require("ai.providers")

local M = {}

----------------------------------------------------------------------
-- Validate provider name
-- Returns: valid (bool), error_msg (string|nil)
----------------------------------------------------------------------
function M.validate_provider_name(name)
  if not name or name == "" then
    return false, "Provider name cannot be empty"
  end
  if not name:match("^[a-z]") then
    return false, "Provider name must start with a letter and be lowercase with dashes/underscores"
  end
  if not name:match("^[a-z][a-z0-9_-]*$") then
    return false, "Provider name must be lowercase with dashes/underscores, starting with a letter"
  end
  if Providers.get(name) then
    return false, "Provider already exists: " .. name
  end
  return true, nil
end

return M
