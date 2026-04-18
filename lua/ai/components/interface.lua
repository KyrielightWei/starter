-- lua/ai/components/interface.lua
-- 组件接口规范定义

local M = {}

--- 组件必需字段列表
M.required_fields = {
  "name",
  "setup",
  "is_installed",
  "get_status",
}

--- 组件必需方法列表（带类型验证）
M.required_methods = {
  { name = "setup", type = "function" },
  { name = "is_installed", type = "function" },
  { name = "get_status", type = "function" },
  { name = "get_version_info", type = "function" },
  { name = "check_dependencies", type = "function" },
  { name = "install", type = "function" },
  { name = "uninstall", type = "function" },
  { name = "update", type = "function" },
  { name = "health_check", type = "function" },
}

--- 组件可选字段列表
M.optional_fields = {
  "display_name",
  "version",
  "category",
  "description",
  "repo_url",
  "npm_package",
  "dependencies",
  "icon",
  "supported_targets",
}

---@class AIComponent
---@field name string 组件唯一标识
---@field display_name string|nil 显示名称
---@field version string|nil 组件版本
---@field category string|nil 类别: "framework" | "tool" | "integration" | "extension"
---@field description string|nil 简短描述
---@field repo_url string|nil 仓库 URL
---@field npm_package string|nil npm 包名（可选）
---@field dependencies string[]|nil 依赖列表
---@field icon string|nil 显示图标
---@field supported_targets string[]|nil 支持的目标工具

---@class AIComponentInterface
---@field setup function(opts: table): boolean
---@field is_installed function(): boolean
---@field get_status function(): table|nil
---@field get_version_info function(): VersionInfo
---@field check_dependencies function(): DependencyStatus[]
---@field install function(opts: table, callback: function|nil): boolean, string
---@field uninstall function(opts: table): boolean, string
---@field update function(opts: table): boolean, string
---@field health_check function(): HealthStatus
---@field get_config_dir function(): string|nil

---@class VersionInfo
---@field current string|nil 当前版本
---@field latest string|nil 最新版本
---@field status string 状态: "current" | "outdated" | "newer" | "unknown" | "not_installed"

---@class DependencyStatus
---@field name string 依赖名称
---@field installed boolean 是否已安装
---@field required boolean 是否必需
---@field version string|nil 当前版本
---@field install_hint string 安装提示

---@class HealthStatus
---@field status string 状态: "ok" | "warn" | "error"
---@field message string 消息

--- 验证组件是否实现了必需接口
---@param component table 待验证的组件
---@return boolean, string|nil valid, error_message
function M.validate_component(component)
  if type(component) ~= "table" then
    return false, "Component must be a table"
  end

  -- 验证必需字段
  for _, field in ipairs(M.required_fields) do
    if component[field] == nil then
      return false, string.format("Component missing required field: %s", field)
    end
  end

  -- 非空 name
  if component.name == "" then
    return false, "Component name cannot be empty"
  end

  -- 验证必需方法类型
  for _, method in ipairs(M.required_methods) do
    local value = component[method.name]
    if value == nil then
      return false, string.format("Component missing required method: %s", method.name)
    end
    if type(value) ~= method.type then
      return false, string.format("Component method '%s' must be %s, got %s", method.name, method.type, type(value))
    end
  end

  -- 验证可选字段的类型（如果存在）
  if component.dependencies ~= nil and type(component.dependencies) ~= "table" then
    return false, "Component 'dependencies' must be a table (array)"
  end

  if component.supported_targets ~= nil and type(component.supported_targets) ~= "table" then
    return false, "Component 'supported_targets' must be a table (array)"
  end

  return true, nil
end

--- 获取组件接口规范摘要
---@return string[]
function M.get_interface_summary()
  local lines = {
    "AIComponent Interface Summary:",
    "",
    "Required Fields:",
  }

  for _, field in ipairs(M.required_fields) do
    table.insert(lines, "  - " .. field)
  end

  table.insert(lines, "")
  table.insert(lines, "Required Methods:")

  for _, method in ipairs(M.required_methods) do
    table.insert(lines, string.format("  - %s: %s", method.name, method.type))
  end

  table.insert(lines, "")
  table.insert(lines, "Optional Fields:")

  for _, field in ipairs(M.optional_fields) do
    table.insert(lines, "  - " .. field)
  end

  return lines
end

return M
