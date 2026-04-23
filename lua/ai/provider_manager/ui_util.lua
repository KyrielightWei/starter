-- lua/ai/provider_manager/ui_util.lua
-- UI utilities for Provider Manager — icons, formatting
-- Performance-optimized: all functions use simple string ops
-- Note: Input dialogs use vim.ui.input (Neovim built-in) for reliable insert mode

local M = {}

----------------------------------------------------------------------
-- Icons - Softer style (Unicode symbols, not large emoji)
-- More subtle and professional appearance
----------------------------------------------------------------------
local ICONS = {
  -- Provider/Model markers (smaller, cleaner)
  provider = "•",      -- Bullet point
  model = "◦",         -- White bullet
  default = "★",       -- Star for default (subtle)
  
  -- Action indicators (minimal)
  add = "[+]",
  delete = "[-]",
  edit = "[e]",
  rename = "[r]",
  help = "?",
  
  -- Status markers
  check = "✔",
  cross = "✘",
  clock = "…",
  success = "✓",
  warn = "!",
  error = "✗",
}

----------------------------------------------------------------------
-- Get Icons (public accessor for external use)
----------------------------------------------------------------------
function M.get_icons()
  return ICONS
end

----------------------------------------------------------------------
-- Format Provider Display (performance: single string.format call)
----------------------------------------------------------------------
function M.format_provider_display(name, def)
  def = def or {}
  local model = def.model or "unknown"
  local endpoint = def.endpoint or "unknown"

  -- Truncate long endpoints for readability
  if #endpoint > 40 then
    endpoint = endpoint:sub(1, 37) .. "..."
  end

  return string.format("%s %s  %s  %s", ICONS.provider, name, endpoint, model)
end

----------------------------------------------------------------------
-- Format Model Display (performance: single string.format call)
----------------------------------------------------------------------
function M.format_model_display(model_id, is_default, metadata)
  metadata = metadata or {}
  local icon = is_default and ICONS.default or ICONS.model
  local context = metadata.context_length or ""

  if context and #context > 0 then
    context = string.format("[%s]", context)
  else
    context = ""
  end

  return string.format("%s %s %s", icon, model_id, context)
end

----------------------------------------------------------------------
-- Notify with icon
----------------------------------------------------------------------
function M.notify_with_icon(message, level, icon_key)
  icon_key = icon_key or "success"
  local icon = ICONS[icon_key] or ""
  vim.notify(icon .. " " .. message, level)
end

return M