-- lua/ai/skill_studio/converter.lua
-- Skill format converter for OpenCode and QoderCLI

local M = {}

----------------------------------------------------------------------
-- Parse frontmatter from skill content
----------------------------------------------------------------------
function M.parse_frontmatter(content)
  local result = {}
  local frontmatter = content:match("^%-%-%-\n(.-)\n%-%-%-")
  if not frontmatter then
    return result
  end

  -- Extract name
  local name = frontmatter:match("name:%s*[\"']?([^\"'\n]+)[\"']?")
  if name then
    result.name = vim.trim(name)
  end

  -- Extract description
  local description = frontmatter:match("description:%s*[\"']?([^\"'\n]+)[\"']?")
  if description then
    result.description = vim.trim(description)
  end

  -- Extract version
  local version = frontmatter:match("version:%s*[\"']?([^\"'\n]+)[\"']?")
  if version then
    result.version = vim.trim(version)
  end

  return result
end

----------------------------------------------------------------------
-- Extract body (content after frontmatter)
----------------------------------------------------------------------
function M.extract_body(content)
  local body = content:match("%-%-%-\n.*\n%-%-%-\n(.*)")
  if body then
    return vim.trim(body)
  end
  return content
end

----------------------------------------------------------------------
-- Convert to OpenCode skills format
-- OpenCode 完全兼容 Claude skill 格式！
-- 只需复制到 .opencode/skills/ 目录
-- 参考: https://opencode.ai/docs/skills/
----------------------------------------------------------------------
function M.to_opencode(name, content)
  -- OpenCode 自动发现 .opencode/skills/<name>/SKILL.md
  -- 格式与 Claude skill 完全相同，无需转换
  local opencode_dir = vim.fn.getcwd() .. "/.opencode/skills/" .. name
  vim.fn.mkdir(opencode_dir, "p")
  vim.fn.writefile(vim.split(content, "\n"), opencode_dir .. "/SKILL.md")

  return true, nil
end

----------------------------------------------------------------------
-- Convert to QoderCLI format (same as Claude, just copy)
----------------------------------------------------------------------
function M.to_qoder(name, content)
  -- QoderCLI uses same SKILL.md format, just copy to different location
  local qoder_dir = vim.fn.getcwd() .. "/.qoder/skills/" .. name
  vim.fn.mkdir(qoder_dir, "p")
  vim.fn.writefile(vim.split(content, "\n"), qoder_dir .. "/SKILL.md")

  return true, nil
end

----------------------------------------------------------------------
-- Convert to Cursor rules format
----------------------------------------------------------------------
function M.to_cursor(name, content)
  local body = M.extract_body(content)
  local cursor_dir = vim.fn.getcwd() .. "/.cursor/rules"
  vim.fn.mkdir(cursor_dir, "p")

  -- Cursor uses .mdc files
  local cursor_content = string.format(
    [[---
description: %s
globs: ["*"]
---

%s
]],
    name,
    body
  )

  vim.fn.writefile(vim.split(cursor_content, "\n"), cursor_dir .. "/" .. name .. ".mdc")
  return true, nil
end

----------------------------------------------------------------------
-- Batch convert all skills
----------------------------------------------------------------------
function M.batch_convert(target)
  local skills = require("ai.skill_studio").list_all()
  local results = { success = {}, failed = {} }

  for name, info in pairs(skills) do
    local content = table.concat(vim.fn.readfile(info.path), "\n")
    local ok, err

    if target == "opencode" then
      ok, err = M.to_opencode(name, content)
    elseif target == "qoder" then
      ok, err = M.to_qoder(name, content)
    elseif target == "cursor" then
      ok, err = M.to_cursor(name, content)
    else
      err = "Unknown target: " .. target
    end

    if ok then
      results.success[name] = true
    else
      results.failed[name] = err
    end
  end

  return results
end

return M
