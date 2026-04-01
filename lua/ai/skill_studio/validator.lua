-- lua/ai/skill_studio/validator.lua
-- Validator for skill/command/MCP configurations with autocomplete hints

local M = {}

----------------------------------------------------------------------
-- Validation Rules
----------------------------------------------------------------------
local rules = {
  skill = {
    name = {
      required = true,
      pattern = "^[a-z0-9][a-z0-9%-]*[a-z0-9]$",
      single_word_pattern = "^[a-z0-9]+$",
      min_length = 1,
      max_length = 64,
      error = "Name must be lowercase alphanumeric with hyphens, 1-64 chars",
      hint = "Use lowercase letters, numbers, and hyphens (e.g., 'my-skill-name')",
    },
    description = {
      required = true,
      min_length = 1,
      max_length = 1024,
      error = "Description must be 1-1024 characters",
      hint = "Describe when this skill should be used and what it does",
    },
    version = {
      required = false,
      pattern = "^%d+%.%d+%.%d+$",
      error = "Version must be semver format (e.g., '1.0.0')",
      hint = "Use semantic versioning: MAJOR.MINOR.PATCH",
    },
    body = {
      required = true,
      min_length = 10,
      error = "Skill body must have at least 10 characters",
      hint = "Include clear instructions for when and how to use this skill",
    },
  },
  rule = {
    description = {
      required = true,
      min_length = 1,
      max_length = 500,
      error = "Description must be 1-500 characters",
      hint = "Brief description of the rule's purpose",
    },
    globs = {
      required = true,
      pattern = "^%*%.[a-z]+$",
      valid_values = { "*.lua", "*.js", "*.ts", "*.go", "*.py", "*.rs", "*.md", "*.json", "*.yaml", "*.yml" },
      error = "Globs must be file patterns like '*.lua'",
      hint = "Specify file patterns this rule applies to (e.g., '*.lua')",
    },
    body = {
      required = true,
      min_length = 10,
      error = "Rule body must have at least 10 characters",
      hint = "Include the rule content with rationale and examples",
    },
  },
  command = {
    description = {
      required = true,
      min_length = 1,
      max_length = 256,
      error = "Description is required",
      hint = "Brief description shown in /help",
    },
    argument_hint = {
      required = false,
      max_length = 64,
      error = "Argument hint too long",
      hint = "Format: <required> [optional]",
    },
    allowed_tools = {
      required = false,
      valid_values = { "Read", "Write", "Edit", "Bash", "Glob", "Grep", "WebFetch", "WebSearch" },
      error = "Invalid tool name",
      hint = "Allowed: Read, Write, Edit, Bash, Glob, Grep, WebFetch, WebSearch",
    },
    body = {
      required = true,
      min_length = 10,
      error = "Command body must have at least 10 characters",
      hint = "Include clear instructions for the command",
    },
  },
  mcp = {
    type = {
      required = true,
      valid_values = { "stdio", "http", "sse", "ws", "local", "remote" },
      error = "Invalid MCP server type",
      hint = "Types: stdio (local command), http, sse, ws (remote)",
    },
    command = {
      required_for = { "stdio", "local" },
      error = "Command required for stdio/local type",
      hint = "Command to start the MCP server (e.g., 'npx -y @modelcontextprotocol/server-filesystem')",
    },
    url = {
      required_for = { "http", "sse", "ws", "remote" },
      pattern = "^https?://",
      error = "Valid URL required for remote types",
      hint = "Full URL to MCP server endpoint",
    },
  },
}

----------------------------------------------------------------------
-- Hints Database
----------------------------------------------------------------------
local hints = {
  skill = {
    triggers = {
      "When user mentions",
      "When task involves",
      "Use when",
      "Activates when",
    },
    sections = {
      "## When This Skill Applies",
      "## Instructions",
      "## Examples",
      "## Prerequisites",
      "## Output Format",
    },
    frontmatter_fields = {
      name = "Skill identifier (lowercase, hyphens, 1-64 chars)",
      description = "When to trigger and what the skill does",
      version = "Semantic version (1.0.0)",
      license = "License identifier (MIT, Apache-2.0, etc.)",
      ["disable-model-invocation"] = "Set true to only allow manual invocation",
      ["user-invocable"] = "Set false to hide from / menu",
      ["allowed-tools"] = "Tools Claude can use without permission",
    },
  },
  rule = {
    sections = {
      "## Rationale",
      "## Good Examples",
      "## Bad Examples",
      "## Exceptions",
    },
    frontmatter_fields = {
      description = "Brief description of the rule",
      globs = "File patterns this rule applies to",
    },
    common_rules = {
      "No hardcoded secrets",
      "Always validate input",
      "Use parameterized queries",
      "Follow naming conventions",
      "Keep functions small",
    },
  },
  command = {
    frontmatter_fields = {
      description = "Brief description for /help",
      ["argument-hint"] = "Hint for arguments shown to user",
      ["allowed-tools"] = "Pre-approved tools for this command",
      model = "Override model (haiku, sonnet, opus)",
    },
    special_variables = {
      ["$ARGUMENTS"] = "All arguments passed to command",
      ["$1, $2, ..."] = "Individual arguments by position",
    },
  },
  mcp = {
    transport_types = {
      stdio = "Local process communication via stdin/stdout",
      http = "HTTP-based MCP server",
      sse = "Server-Sent Events",
      ws = "WebSocket connection",
      ["local"] = "OpenCode local MCP",
      remote = "OpenCode remote MCP",
    },
    fields = {
      command = "Command array to start local MCP",
      args = "Arguments for the command",
      url = "URL for remote MCP server",
      env = "Environment variables",
      environment = "Environment variables (OpenCode)",
      headers = "HTTP headers for remote MCP",
      oauth = "OAuth configuration",
      enabled = "Enable/disable the server",
      timeout = "Timeout in milliseconds",
    },
  },
}

----------------------------------------------------------------------
-- Validate
----------------------------------------------------------------------
function M.validate(item)
  local errors = {}
  local warnings = {}
  local suggestions = {}

  local item_type = item.type
  local type_rules = rules[item_type]

  if not type_rules then
    return {
      valid = false,
      errors = { "Unknown item type: " .. item_type },
      warnings = {},
      suggestions = {},
    }
  end

  if item_type == "skill" or item_type == "command" then
    M.validate_frontmatter(item, type_rules, errors, warnings, suggestions)
    M.validate_body(item, type_rules, errors, warnings, suggestions)
  elseif item_type == "rule" then
    M.validate_rule(item, type_rules, errors, warnings, suggestions)
  elseif item_type == "mcp" then
    M.validate_mcp(item, type_rules, errors, warnings, suggestions)
  end

  M.check_best_practices(item, warnings, suggestions)

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
    suggestions = suggestions,
  }
end

----------------------------------------------------------------------
-- Validate Frontmatter
----------------------------------------------------------------------
function M.validate_frontmatter(item, type_rules, errors, warnings, suggestions)
  local frontmatter = item.frontmatter or {}

  for field, rule in pairs(type_rules) do
    if field == "body" then
      goto continue
    end

    local value = frontmatter[field]

    if rule.required and (not value or value == "") then
      table.insert(errors, string.format("Missing required field: %s", field))
      if rule.hint then
        table.insert(suggestions, string.format("%s: %s", field, rule.hint))
      end
    elseif value then
      if rule.pattern then
        local match_single = rule.single_word_pattern and value:match(rule.single_word_pattern)
        local match_multi = value:match(rule.pattern)
        if not match_single and not match_multi then
          table.insert(errors, string.format("%s: %s", field, rule.error))
        end
      end

      if rule.min_length and #value < rule.min_length then
        table.insert(errors, string.format("%s: Must be at least %d characters", field, rule.min_length))
      end

      if rule.max_length and #value > rule.max_length then
        table.insert(errors, string.format("%s: Must be at most %d characters", field, rule.max_length))
      end

      if rule.valid_values then
        local valid = false
        for _, v in ipairs(rule.valid_values) do
          if value == v then
            valid = true
            break
          end
        end
        if not valid then
          table.insert(errors, string.format("%s: %s", field, rule.error))
        end
      end
    end

    ::continue::
  end
end

----------------------------------------------------------------------
-- Validate Body
----------------------------------------------------------------------
function M.validate_body(item, type_rules, errors, warnings, suggestions)
  local body = item.body or ""
  local rule = type_rules.body

  if rule then
    if rule.required and #body < rule.min_length then
      table.insert(errors, rule.error)
      if rule.hint then
        table.insert(suggestions, rule.hint)
      end
    end
  end

  if item.type == "skill" and #body > 0 then
    local has_when_section = body:find("## When") or body:find("## when") or body:find("When to use")
    if not has_when_section then
      table.insert(warnings, "Consider adding a 'When to use' section to clarify trigger conditions")
    end

    local has_instruction = body:find("## Instruction") or body:find("## instruction") or body:find("What I do")
    if not has_instruction then
      table.insert(suggestions, "Add an 'Instructions' section to describe the skill's behavior")
    end
  end
end

----------------------------------------------------------------------
-- Validate Rule
----------------------------------------------------------------------
function M.validate_rule(item, type_rules, errors, warnings, suggestions)
  local frontmatter = item.frontmatter or {}
  local body = item.body or ""

  -- Validate frontmatter
  for field, rule in pairs(type_rules) do
    if field == "body" then
      goto continue
    end

    local value = frontmatter[field]

    if rule.required and (not value or value == "") then
      table.insert(errors, string.format("Missing required field: %s", field))
      if rule.hint then
        table.insert(suggestions, string.format("%s: %s", field, rule.hint))
      end
    elseif value then
      if rule.max_length and #value > rule.max_length then
        table.insert(errors, string.format("%s: Must be at most %d characters", field, rule.max_length))
      end
    end

    ::continue::
  end

  -- Validate body
  local body_rule = type_rules.body
  if body_rule then
    if body_rule.required and #body < body_rule.min_length then
      table.insert(errors, body_rule.error)
      if body_rule.hint then
        table.insert(suggestions, body_rule.hint)
      end
    end
  end

  -- Check best practices for rules
  if #body > 0 then
    local has_rationale = body:find("## Rationale") or body:find("## rationale") or body:find("Why")
    if not has_rationale then
      table.insert(warnings, "Consider adding a 'Rationale' section to explain why this rule exists")
    end

    local has_good_examples = body:find("## Good") or body:find("## Correct") or body:find("Good Examples")
    local has_bad_examples = body:find("## Bad") or body:find("## Wrong") or body:find("Bad Examples")
    if not has_good_examples and not has_bad_examples then
      table.insert(suggestions, "Add 'Good Examples' and 'Bad Examples' sections for clarity")
    end
  end
end

----------------------------------------------------------------------
-- Validate MCP
----------------------------------------------------------------------
function M.validate_mcp(item, type_rules, errors, warnings, suggestions)
  local config = item.config or {}

  for server_name, server_config in pairs(config) do
    local server_type = server_config.type

    if not server_type then
      table.insert(errors, string.format("Server '%s': missing type field", server_name))
      goto continue
    end

    local type_rule = type_rules.type
    local valid_type = false
    for _, v in ipairs(type_rule.valid_values) do
      if server_type == v then
        valid_type = true
        break
      end
    end
    if not valid_type then
      table.insert(errors, string.format("Server '%s': %s", server_name, type_rule.error))
    end

    if server_type == "stdio" or server_type == "local" then
      if not server_config.command then
        table.insert(errors, string.format("Server '%s': command required for %s type", server_name, server_type))
      end
    else
      if not server_config.url then
        table.insert(errors, string.format("Server '%s': url required for %s type", server_name, server_type))
      elseif not server_config.url:match("^https?://") then
        table.insert(errors, string.format("Server '%s': invalid URL format", server_name))
      end
    end

    ::continue::
  end
end

----------------------------------------------------------------------
-- Check Best Practices
----------------------------------------------------------------------
function M.check_best_practices(item, warnings, suggestions)
  if item.type == "skill" then
    local desc = item.frontmatter and item.frontmatter.description or ""
    if #desc < 50 then
      table.insert(suggestions, "Consider a more detailed description (50+ chars) for better auto-discovery")
    end

    if not desc:lower():find("when") and not desc:lower():find("use") then
      table.insert(warnings, "Description should indicate when this skill should be triggered")
    end
  end

  if item.type == "mcp" then
    for name, config in pairs(item.config or {}) do
      if config.env or config.environment then
        local env = config.env or config.environment
        for key, value in pairs(env) do
          if not value:find("${") and not value:find("{env:") then
            table.insert(warnings, string.format("Consider using env var substitution for %s in %s", key, name))
          end
        end
      end
    end
  end
end

----------------------------------------------------------------------
-- Get Hints
----------------------------------------------------------------------
function M.get_hints(item_type, field)
  if not hints[item_type] then
    return {}
  end

  if field then
    return hints[item_type][field] or {}
  end

  return hints[item_type]
end

----------------------------------------------------------------------
-- Autocomplete
----------------------------------------------------------------------
function M.autocomplete(item_type, field, prefix)
  prefix = prefix or ""

  if item_type == "skill" and field == "allowed-tools" then
    local tools = { "Read", "Write", "Edit", "Bash", "Glob", "Grep", "WebFetch", "WebSearch" }
    return vim.tbl_filter(function(t)
      return t:lower():find(prefix:lower(), 1, true)
    end, tools)
  end

  if item_type == "mcp" and field == "type" then
    local types = { "stdio", "http", "sse", "ws", "local", "remote" }
    return vim.tbl_filter(function(t)
      return t:lower():find(prefix:lower(), 1, true)
    end, types)
  end

  if item_type == "skill" and field == "sections" then
    local sections = hints.skill.sections or {}
    return vim.tbl_filter(function(s)
      return s:lower():find(prefix:lower(), 1, true)
    end, sections)
  end

  return {}
end

return M