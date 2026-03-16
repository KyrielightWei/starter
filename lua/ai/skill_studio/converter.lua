-- lua/ai/skill_studio/converter.lua
-- Format converter between Claude Code and OpenCode

local M = {}

----------------------------------------------------------------------
-- Skill Name Conversion
----------------------------------------------------------------------
local function to_opencode_name(name)
  return name:lower():gsub("[^a-z0-9-]", "-"):gsub("-+", "-"):gsub("^-", ""):gsub("-$", "")
end

local function to_claude_name(name)
  return name:lower():gsub("[^a-z0-9-]", "-"):gsub("-+", "-")
end

----------------------------------------------------------------------
-- Claude Code -> OpenCode
----------------------------------------------------------------------
function M.claude_to_opencode_skill(item)
  local frontmatter = item.frontmatter or {}

  return {
    type = "skill",
    target = "opencode",
    level = item.level,
    frontmatter = {
      name = to_opencode_name(frontmatter.name or "unnamed-skill"),
      description = frontmatter.description or "",
      version = frontmatter.version or "1.0.0",
      license = frontmatter.license,
      compatibility = "opencode",
    },
    body = item.body or "",
  }
end

function M.claude_to_opencode_mcp(item)
  local opencode_mcp = {}

  for server_name, server_config in pairs(item.config or {}) do
    local new_config = {}

    if server_config.type == "stdio" then
      new_config.type = "local"
      new_config.command = server_config.command
      if server_config.args then
        new_config.command = type(server_config.command) == "table"
            and server_config.command
            or { server_config.command }
        for _, arg in ipairs(server_config.args) do
          table.insert(new_config.command, arg)
        end
      end
    else
      new_config.type = "remote"
      new_config.url = server_config.url
      new_config.headers = server_config.headers
    end

    new_config.environment = server_config.env or server_config.environment
    new_config.enabled = server_config.enabled ~= false
    new_config.timeout = server_config.timeout or 5000

    opencode_mcp[server_name] = new_config
  end

  return {
    type = "mcp",
    target = "opencode",
    level = item.level,
    config = opencode_mcp,
  }
end

----------------------------------------------------------------------
-- OpenCode -> Claude Code
----------------------------------------------------------------------
function M.opencode_to_claude_skill(item)
  local frontmatter = item.frontmatter or {}

  return {
    type = "skill",
    target = "claude",
    level = item.level,
    frontmatter = {
      name = to_claude_name(frontmatter.name or "unnamed-skill"),
      description = frontmatter.description or "",
      version = frontmatter.version or "1.0.0",
      license = frontmatter.license,
    },
    body = item.body or "",
  }
end

function M.opencode_to_claude_mcp(item)
  local claude_mcp = {}

  for server_name, server_config in pairs(item.config or {}) do
    local new_config = {}

    if server_config.type == "local" then
      new_config.type = "stdio"
      if type(server_config.command) == "table" then
        new_config.command = server_config.command[1]
        new_config.args = {}
        for i = 2, #server_config.command do
          table.insert(new_config.args, server_config.command[i])
        end
      else
        new_config.command = server_config.command
      end
    else
      new_config.type = server_config.type or "http"
      new_config.url = server_config.url
      new_config.headers = server_config.headers
    end

    new_config.env = server_config.environment or server_config.env

    claude_mcp[server_name] = new_config
  end

  return {
    type = "mcp",
    target = "claude",
    level = item.level,
    config = claude_mcp,
  }
end

----------------------------------------------------------------------
-- Main Convert Function
----------------------------------------------------------------------
function M.convert(item, new_target)
  local current_target = item.target
  local item_type = item.type

  if current_target == new_target then
    return item
  end

  if item_type == "skill" then
    if new_target == "opencode" then
      return M.claude_to_opencode_skill(item)
    else
      return M.opencode_to_claude_skill(item)
    end
  elseif item_type == "mcp" then
    if new_target == "opencode" then
      return M.claude_to_opencode_mcp(item)
    else
      return M.opencode_to_claude_mcp(item)
    end
  elseif item_type == "command" then
    return nil, "Commands are Claude Code specific and cannot be converted to OpenCode"
  end

  return nil, "Unknown item type"
end

----------------------------------------------------------------------
-- Batch Convert
----------------------------------------------------------------------
function M.batch_convert(items, new_target)
  local results = {}
  local errors = {}

  for i, item in ipairs(items) do
    local converted, err = M.convert(item, new_target)
    if converted then
      table.insert(results, converted)
    else
      table.insert(errors, { index = i, error = err })
    end
  end

  return results, errors
end

----------------------------------------------------------------------
-- Preview Conversion
----------------------------------------------------------------------
function M.preview(item, new_target)
  local converted, err = M.convert(item, new_target)
  if not converted then
    return nil, err
  end

  local preview_lines = {}

  table.insert(preview_lines, string.format("# Conversion: %s -> %s", item.target, new_target))
  table.insert(preview_lines, "")
  table.insert(preview_lines, "## Before")
  table.insert(preview_lines, "```")
  table.insert(preview_lines, vim.inspect(item))
  table.insert(preview_lines, "```")
  table.insert(preview_lines, "")
  table.insert(preview_lines, "## After")
  table.insert(preview_lines, "```")
  table.insert(preview_lines, vim.inspect(converted))
  table.insert(preview_lines, "```")

  return table.concat(preview_lines, "\n"), converted
end

----------------------------------------------------------------------
-- Detect Format
----------------------------------------------------------------------
function M.detect_format(content)
  if type(content) == "string" then
    if content:match("^%s*%-%-%-") then
      local frontmatter = content:match("^%-%-%-(.-)%-%-%-")
      if frontmatter then
        if frontmatter:match("compatibility:%s*opencode") then
          return "opencode"
        end
        return "claude"
      end
    end

    if content:match("^%s*{") then
      return "json"
    end
  end

  if type(content) == "table" then
    if content.frontmatter then
      if content.frontmatter.compatibility == "opencode" then
        return "opencode"
      end
      return "claude"
    end

    if content.config then
      return "mcp"
    end
  end

  return "unknown"
end

return M