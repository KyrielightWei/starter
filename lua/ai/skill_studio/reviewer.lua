-- lua/ai/skill_studio/reviewer.lua
-- Review functionality for skill/command/MCP configurations

local M = {}

----------------------------------------------------------------------
-- Review Criteria
----------------------------------------------------------------------
local criteria = {
  skill = {
    {
      id = "name_format",
      check = function(item)
        local name = item.frontmatter and item.frontmatter.name
        if not name then
          return false, "Missing skill name"
        end
        if not name:match("^[a-z0-9]+(-[a-z0-9]+)*$") then
          return false, "Name must be lowercase alphanumeric with hyphens"
        end
        if #name > 64 then
          return false, "Name must be 64 characters or less"
        end
        return true, "Name format is valid"
      end,
      weight = 10,
    },
    {
      id = "description_quality",
      check = function(item)
        local desc = item.frontmatter and item.frontmatter.description or ""
        if #desc < 20 then
          return false, "Description too short (min 20 chars for good auto-discovery)"
        end
        if not desc:lower():find("when") and not desc:lower():find("use") then
          return false, "Description should indicate when to trigger"
        end
        return true, "Description quality is good"
      end,
      weight = 15,
    },
    {
      id = "body_structure",
      check = function(item)
        local body = item.body or ""
        if #body < 50 then
          return false, "Body content is too short"
        end
        local has_when = body:find("## When") or body:find("## when") or body:lower():find("when to use")
        if not has_when then
          return false, "Missing 'When to use' section"
        end
        return true, "Body structure is adequate"
      end,
      weight = 10,
    },
    {
      id = "has_examples",
      check = function(item)
        local body = item.body or ""
        if body:find("## Example") or body:find("Example:") then
          return true, "Has examples"
        end
        return false, "Consider adding examples"
      end,
      weight = 5,
    },
    {
      id = "has_instructions",
      check = function(item)
        local body = item.body or ""
        if body:find("## Instruction") or body:find("## Steps") or body:find("1%.") then
          return true, "Has clear instructions"
        end
        return false, "Consider adding numbered instructions"
      end,
      weight = 10,
    },
  },
  command = {
    {
      id = "description_present",
      check = function(item)
        local desc = item.frontmatter and item.frontmatter.description
        if not desc or #desc < 5 then
          return false, "Description is too short or missing"
        end
        return true, "Description is present"
      end,
      weight = 15,
    },
    {
      id = "argument_usage",
      check = function(item)
        local body = item.body or ""
        if body:find("$ARGUMENTS") or body:find("$1") then
          return true, "Uses arguments correctly"
        end
        return false, "Consider using $ARGUMENTS or $1, $2 for arguments"
      end,
      weight = 10,
    },
    {
      id = "clear_instructions",
      check = function(item)
        local body = item.body or ""
        if body:find("## Instruction") or body:find("## Steps") then
          return true, "Has clear instruction section"
        end
        return false, "Add clear instructions section"
      end,
      weight = 10,
    },
  },
  mcp = {
    {
      id = "valid_type",
      check = function(item)
        for name, config in pairs(item.config or {}) do
          if not config.type then
            return false, string.format("Server '%s' missing type", name)
          end
        end
        return true, "All servers have valid types"
      end,
      weight = 20,
    },
    {
      id = "command_or_url",
      check = function(item)
        for name, config in pairs(item.config or {}) do
          if config.type == "stdio" or config.type == "local" then
            if not config.command then
              return false, string.format("Server '%s' missing command", name)
            end
          else
            if not config.url then
              return false, string.format("Server '%s' missing URL", name)
            end
          end
        end
        return true, "All servers have required fields"
      end,
      weight = 20,
    },
    {
      id = "env_security",
      check = function(item)
        local warnings = {}
        for name, config in pairs(item.config or {}) do
          local env = config.env or config.environment or {}
          for key, value in pairs(env) do
            if type(value) == "string" and not value:find("${") and not value:find("{env:") then
              table.insert(warnings, string.format("Server '%s' has hardcoded env %s", name, key))
            end
          end
        end
        if #warnings > 0 then
          return false, table.concat(warnings, "; ")
        end
        return true, "Environment variables use secure substitution"
      end,
      weight = 15,
    },
  },
}

----------------------------------------------------------------------
-- Review Item
----------------------------------------------------------------------
function M.review(item)
  local item_type = item.type
  local type_criteria = criteria[item_type]

  if not type_criteria then
    return {
      valid = false,
      score = 0,
      max_score = 100,
      checks = {},
      errors = { "Unknown item type" },
      warnings = {},
      suggestions = {},
    }
  end

  local checks = {}
  local errors = {}
  local warnings = {}
  local suggestions = {}
  local total_weight = 0
  local earned_weight = 0

  for _, criterion in ipairs(type_criteria) do
    local passed, message = criterion.check(item)
    total_weight = total_weight + criterion.weight
    if passed then
      earned_weight = earned_weight + criterion.weight
    end

    table.insert(checks, {
      id = criterion.id,
      passed = passed,
      message = message,
      weight = criterion.weight,
    })

    if not passed then
      if criterion.weight >= 15 then
        table.insert(errors, message)
      elseif criterion.weight >= 10 then
        table.insert(warnings, message)
      else
        table.insert(suggestions, message)
      end
    end
  end

  local score = total_weight > 0 and math.floor((earned_weight / total_weight) * 100) or 0

  return {
    valid = #errors == 0,
    score = score,
    max_score = 100,
    checks = checks,
    errors = errors,
    warnings = warnings,
    suggestions = suggestions,
  }
end

----------------------------------------------------------------------
-- Compare Two Items
----------------------------------------------------------------------
function M.compare(item_a, item_b)
  local review_a = M.review(item_a)
  local review_b = M.review(item_b)

  return {
    winner = review_a.score >= review_b.score and "a" or "b",
    scores = {
      a = review_a.score,
      b = review_b.score,
    },
    details = {
      a = review_a,
      b = review_b,
    },
  }
end

----------------------------------------------------------------------
-- Get Improvement Suggestions
----------------------------------------------------------------------
function M.get_improvements(item)
  local review_result = M.review(item)
  local improvements = {}

  for _, check in ipairs(review_result.checks) do
    if not check.passed then
      table.insert(improvements, {
        priority = check.weight >= 15 and "high" or (check.weight >= 10 and "medium" or "low"),
        issue = check.id,
        suggestion = check.message,
      })
    end
  end

  table.sort(improvements, function(a, b)
    local priority_order = { high = 1, medium = 2, low = 3 }
    return priority_order[a.priority] < priority_order[b.priority]
  end)

  return improvements
end

----------------------------------------------------------------------
-- Generate Review Report
----------------------------------------------------------------------
function M.generate_report(item)
  local review_result = M.review(item)
  local lines = {}

  local name = item.frontmatter and item.frontmatter.name or item.id or "unnamed"

  table.insert(lines, string.format("# Review Report: %s", name))
  table.insert(lines, "")
  table.insert(lines, string.format("**Score**: %d/100", review_result.score))
  table.insert(lines, string.format("**Status**: %s", review_result.valid and "✅ Valid" or "❌ Invalid"))
  table.insert(lines, "")

  table.insert(lines, "## Checks")
  table.insert(lines, "")
  table.insert(lines, "| Check | Status | Message |")
  table.insert(lines, "|-------|--------|---------|")

  for _, check in ipairs(review_result.checks) do
    local status = check.passed and "✅" or "❌"
    table.insert(lines, string.format("| %s | %s | %s |", check.id, status, check.message))
  end

  if #review_result.errors > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Errors")
    for _, err in ipairs(review_result.errors) do
      table.insert(lines, "- " .. err)
    end
  end

  if #review_result.warnings > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Warnings")
    for _, warn in ipairs(review_result.warnings) do
      table.insert(lines, "- " .. warn)
    end
  end

  if #review_result.suggestions > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Suggestions")
    for _, sug in ipairs(review_result.suggestions) do
      table.insert(lines, "- " .. sug)
    end
  end

  return table.concat(lines, "\n")
end

return M