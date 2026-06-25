-- lua/ai/template_version.lua
-- Template Version Manager - CRUD operations for config templates

local M = {}

local Paths = require("ai.paths")

----------------------------------------------------------------------
-- Private helpers for path construction
----------------------------------------------------------------------

-- 验证名称安全（只允许字母、数字、下划线、连字符）
local function is_safe_name(name)
  if type(name) ~= "string" or name == "" then
    return false
  end
  return name:match("^[%w_-]+$") ~= nil
end

local function get_tool_templates_dir(tool)
  if not is_safe_name(tool) then
    error("Invalid tool name: " .. tostring(tool))
  end
  return Paths.templates_dir(tool)
end

----------------------------------------------------------------------
-- get_template_path(tool, version): 返回模版文件完整路径
-- @param tool string: 工具名称 (opencode, claude_code)
-- @param version string: 版本名称
-- @return string: 模版文件路径
----------------------------------------------------------------------
function M.get_template_path(tool, version)
  if not is_safe_name(tool) then
    error("Invalid tool name: " .. tostring(tool))
  end
  if not is_safe_name(version) then
    error("Invalid version name: " .. tostring(version))
  end
  return get_tool_templates_dir(tool) .. "/" .. version .. ".template.jsonc"
end

----------------------------------------------------------------------
-- Public directory accessors
----------------------------------------------------------------------
function M.get_templates_dir()
  return Paths.templates_dir()
end

function M.get_tool_templates_dir(tool)
  return get_tool_templates_dir(tool)
end

----------------------------------------------------------------------
-- list(tool): 发现工具的所有模版版本
-- @param tool string: 工具名称
-- @return table: 版本名称数组
----------------------------------------------------------------------
function M.list(tool)
  local dir = get_tool_templates_dir(tool)
  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end

  local versions = {}
  local files = vim.fn.glob(dir .. "/*.template.jsonc", false, true) or {}
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r:r") -- Remove .template.jsonc
    table.insert(versions, name)
  end
  table.sort(versions)
  return versions
end

----------------------------------------------------------------------
-- exists(tool, version): 检查模版版本是否存在
-- @param tool string: 工具名称
-- @param version string: 版本名称
-- @return boolean: 是否存在
----------------------------------------------------------------------
function M.exists(tool, version)
  local path = M.get_template_path(tool, version)
  return vim.fn.filereadable(path) == 1
end

----------------------------------------------------------------------
-- create(tool, name, source): 创建新模版版本
-- @param tool string: 工具名称
-- @param name string: 新版本名称
-- @param source string|nil: 源版本名称（可选，用于复制）
-- @return boolean, string: 成功状态, 结果路径或错误消息
----------------------------------------------------------------------
function M.create(tool, name, source)
  if M.exists(tool, name) then
    return false, "Version '" .. name .. "' already exists"
  end

  local dir = get_tool_templates_dir(tool)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local target_path = M.get_template_path(tool, name)

  if source and M.exists(tool, source) then
    -- Copy from source
    local source_path = M.get_template_path(tool, source)
    vim.fn.writefile(vim.fn.readfile(source_path), target_path)
  else
    -- Create minimal template（根据工具类型选择默认 schema）
    local schemas = {
      opencode = "https://opencode.ai/config.json",
      claude_code = "https://json.schemastore.org/claude-code-settings.json",
      pi = "https://pi.dev/settings.json",
    }
    local schema = schemas[tool] or "https://json.schemastore.org/settings.json"
    local minimal = [[{
  "$schema": "]] .. schema .. [[",
  // Template: ]] .. name .. [[
}]]
    vim.fn.writefile(vim.split(minimal, "\n"), target_path)
  end

  return true, target_path
end

----------------------------------------------------------------------
-- delete(tool, name): 删除模版版本
-- @param tool string: 工具名称
-- @param name string: 版本名称
-- @return boolean, string: 成功状态, 结果消息
----------------------------------------------------------------------
function M.delete(tool, name)
  if name == "default" then
    return false, "Cannot delete default template"
  end

  if not M.exists(tool, name) then
    return false, "Version '" .. name .. "' not found"
  end

  local path = M.get_template_path(tool, name)
  vim.fn.delete(path)

  -- Reset state if this was current version
  local State = require("ai.state")
  if State.get_template_version(tool) == name then
    State.set_template_version(tool, "default")
  end

  return true, "Deleted version '" .. name .. "'"
end

----------------------------------------------------------------------
-- rename(tool, old_name, new_name): 重命名模版版本
-- @param tool string: 工具名称
-- @param old_name string: 旧版本名称
-- @param new_name string: 新版本名称
-- @return boolean, string: 成功状态, 结果消息
----------------------------------------------------------------------
function M.rename(tool, old_name, new_name)
  if M.exists(tool, new_name) then
    return false, "Version '" .. new_name .. "' already exists"
  end

  if not M.exists(tool, old_name) then
    return false, "Version '" .. old_name .. "' not found"
  end

  local old_path = M.get_template_path(tool, old_name)
  local new_path = M.get_template_path(tool, new_name)
  vim.fn.rename(old_path, new_path)

  -- Update state if renaming current version
  local State = require("ai.state")
  if State.get_template_version(tool) == old_name then
    State.set_template_version(tool, new_name)
  end

  return true, "Renamed '" .. old_name .. "' to '" .. new_name .. "'"
end

----------------------------------------------------------------------
-- copy(tool, source, target): 复制模版版本
-- @param tool string: 工具名称
-- @param source string: 源版本名称
-- @param target string: 目标版本名称
-- @return boolean, string: 成功状态, 结果消息
----------------------------------------------------------------------
function M.copy(tool, source, target)
  if M.exists(tool, target) then
    return false, "Version '" .. target .. "' already exists"
  end

  if not M.exists(tool, source) then
    return false, "Version '" .. source .. "' not found"
  end

  return M.create(tool, target, source)
end

----------------------------------------------------------------------
-- Security validation patterns
----------------------------------------------------------------------
-- M-10 修复: 收窄敏感模式，减少误报（git SHA、颜色代码等）
local SENSITIVE_PATTERNS = {
  "api[_-]?key%s*[:=]",
  "secret%s*[:=]",
  "password%s*[:=]",
  "token%s*[:=]",
  "credential%s*[:=]",
  "sk%-[a-zA-Z0-9]{20,}", -- OpenAI key pattern (至少 20 字符)
}

----------------------------------------------------------------------
-- validate_security(content): 检查模版是否包含敏感数据
-- @param content string: 模版文件内容
-- @return boolean, table: 是否安全, 警告列表
----------------------------------------------------------------------
function M.validate_security(content)
  local warnings = {}

  for _, pattern in ipairs(SENSITIVE_PATTERNS) do
    if content:lower():match(pattern) then
      table.insert(warnings, "Template may contain sensitive data matching: " .. pattern)
    end
  end

  return #warnings == 0, warnings
end

----------------------------------------------------------------------
-- migrate_legacy(tool): 迁移旧版单文件模版到多版本结构
-- @param tool string: 工具名称
-- @return boolean, string: 成功状态, 结果消息
----------------------------------------------------------------------
function M.migrate_legacy(tool)
  local legacy_path = Paths.legacy_template(tool)
  local templates_dir = get_tool_templates_dir(tool)

  -- Check if migration needed
  if vim.fn.filereadable(legacy_path) == 0 then
    return false, "No legacy template to migrate"
  end

  if vim.fn.isdirectory(templates_dir) == 1 then
    return false, "Templates directory already exists"
  end

  -- Create directory and migrate
  vim.fn.mkdir(templates_dir, "p")
  local target_path = M.get_template_path(tool, "default")
  vim.fn.writefile(vim.fn.readfile(legacy_path), target_path)

  -- Create migration marker
  vim.fn.writefile({ "migrated" }, templates_dir .. "/.migration_done")

  return true, "Migrated to " .. target_path
end

----------------------------------------------------------------------
-- check_migration_needed(tool): 检查是否需要迁移
-- @param tool string: 工具名称
-- @return boolean: 是否需要迁移
----------------------------------------------------------------------
function M.check_migration_needed(tool)
  local legacy_path = Paths.legacy_template(tool)
  local templates_dir = get_tool_templates_dir(tool)
  local marker = templates_dir .. "/.migration_done"

  return vim.fn.filereadable(legacy_path) == 1
    and vim.fn.isdirectory(templates_dir) == 0
    and vim.fn.filereadable(marker) == 0
end

return M
