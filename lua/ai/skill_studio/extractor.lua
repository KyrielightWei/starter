-- lua/ai/skill_studio/extractor.lua
-- 需求提取模块：从已存在的 skill/rule/mcp 提取需求

local M = {}

local Templates = require("ai.skill_studio.templates")
local Registry = require("ai.skill_studio.registry")

----------------------------------------------------------------------
-- 解析辅助函数
----------------------------------------------------------------------
---解析 YAML frontmatter
---@param content string
---@return table
local function parse_frontmatter(content)
  local result = {}
  local frontmatter = content:match("^%-%-%-\n(.-)\n%-%-%-")
  if not frontmatter then
    return result
  end

  local name = frontmatter:match("name:%s*[\"']?([^\"'\n]+)[\"']?")
  if name then
    result.name = vim.trim(name)
  end

  local description = frontmatter:match("description:%s*[\"']?([^\"'\n]+)[\"']?")
  if description then
    result.description = vim.trim(description)
  end

  local version = frontmatter:match("version:%s*[\"']?([^\"'\n]+)[\"']?")
  if version then
    result.version = vim.trim(version)
  end

  return result
end

---解析触发条件部分
---@param content string
---@return table|nil
local function parse_triggers_section(content)
  local when_section = content:match("## When This Skill Applies\n(.-)\n##")
  if not when_section then
    return nil
  end

  local triggers = {}

  -- 提取关键词
  local keywords = {}
  for keyword in when_section:gmatch("[A-Za-z]+") do
    if #keyword > 3 then
      table.insert(keywords, keyword:lower())
    end
  end
  if #keywords > 0 then
    triggers.keywords = keywords
  end

  -- 提取文件模式
  local file_patterns = {}
  for pattern in when_section:gmatch("%*%.[a-z]+") do
    table.insert(file_patterns, pattern)
  end
  if #file_patterns > 0 then
    triggers.file_patterns = file_patterns
  end

  return next(triggers) and triggers or nil
end

---解析指令部分
---@param content string
---@return table|nil
local function parse_instructions_section(content)
  local instructions_section = content:match("## Instructions\n(.-)\n##")
  if not instructions_section then
    return nil
  end

  local instructions = { steps = {} }

  -- 提取步骤
  for step in instructions_section:gmatch("%d+%.%s*([^\n]+)") do
    table.insert(instructions.steps, vim.trim(step))
  end

  -- 如果没有数字步骤，提取段落
  if #instructions.steps == 0 then
    for line in instructions_section:gmatch("([^\n]+)") do
      line = vim.trim(line)
      if line ~= "" and not line:match("^%*") and not line:match("^-") then
        table.insert(instructions.steps, line)
      end
    end
  end

  return #instructions.steps > 0 and instructions or nil
end

---解析示例部分
---@param content string
---@return table|nil
local function parse_examples_section(content)
  local examples_section = content:match("## Examples\n(.-)$")
  if not examples_section then
    return nil
  end

  local examples = {}
  for example_content in examples_section:gmatch("Example[^:]*:([^\n]+)") do
    table.insert(examples, {
      input = vim.trim(example_content),
      output = "",
      explanation = "",
    })
  end

  return #examples > 0 and examples or nil
end

---解析约束部分
---@param content string
---@return table|nil
local function parse_constraints_section(content)
  local constraints_section = content:match("## Constraints\n(.-)\n##")
  if not constraints_section then
    return nil
  end

  local constraints = {}

  -- 提取允许的工具
  local tools_line = constraints_section:match("Allowed Tools:([^\n]+)")
  if tools_line then
    constraints.allowed_tools = {}
    for tool in tools_line:gmatch("[A-Za-z]+") do
      table.insert(constraints.allowed_tools, tool)
    end
  end

  -- 提取禁止操作
  local forbidden_line = constraints_section:match("Forbidden:([^\n]+)")
  if forbidden_line then
    constraints.forbidden_actions = {}
    for action in forbidden_line:gmatch("[A-Za-z]+") do
      table.insert(constraints.forbidden_actions, action)
    end
  end

  return next(constraints) and constraints or nil
end

---解析目的部分
---@param content string
---@param description string|nil
---@return string|nil
local function parse_purpose_section(content, description)
  local purpose_section = content:match("## Purpose\n(.-)\n##")
  if purpose_section then
    return vim.trim(purpose_section)
  elseif description then
    return "Auto-extracted from: " .. description
  end
  return nil
end

----------------------------------------------------------------------
-- 解析 Skill 内容
----------------------------------------------------------------------
---解析 Claude skill 文件内容
---@param content string
---@return table
function M.parse_skill_content(content)
  local result = {
    type = "skill",
    target = "claude",
  }

  -- 解析 frontmatter
  local frontmatter = parse_frontmatter(content)
  result.name = frontmatter.name
  result.description = frontmatter.description
  result.version = frontmatter.version

  -- 解析各部分
  local triggers = parse_triggers_section(content)
  if triggers then
    result.triggers = triggers
  end

  local instructions = parse_instructions_section(content)
  if instructions then
    result.instructions = instructions
  end

  local examples = parse_examples_section(content)
  if examples then
    result.examples = examples
  end

  local constraints = parse_constraints_section(content)
  if constraints then
    result.constraints = constraints
  end

  local purpose = parse_purpose_section(content, result.description)
  if purpose then
    result.purpose = purpose
  end

  return result
end

---解析 OpenCode agent 配置
---@param config table
---@param name string
---@return table
function M.parse_opencode_agent(config, name)
  local result = {
    type = "skill",
    target = "opencode",
    name = name,
    description = "Agent: " .. name,
  }

  -- 提取 prompt 内容
  if config.prompt then
    result.instructions = { steps = {} }

    -- 从 prompt 中提取步骤
    for step in config.prompt:gmatch("%d+%.%s*([^\n]+)") do
      table.insert(result.instructions.steps, vim.trim(step))
    end

    -- 提取关键词触发
    result.triggers = { keywords = {} }
    for keyword in config.prompt:gmatch("When[^:]*:([^\n]+)") do
      table.insert(result.triggers.keywords, vim.trim(keyword:lower()))
    end
  end

  -- 提取模型信息
  if config.model then
    result.model = config.model
  end

  return result
end

----------------------------------------------------------------------
-- 解析 Rule 内容
----------------------------------------------------------------------
---解析 Claude rule 文件内容
---@param content string
---@return table
function M.parse_rule_content(content)
  local result = {
    type = "rule",
    target = "claude",
  }

  -- 解析 frontmatter
  local frontmatter = content:match("^%-%-%-\n(.-)\n%-%-%-")
  if frontmatter then
    local description = frontmatter:match("description:%s*[\"']?([^\"'\n]+)[\"']?")
    if description then
      result.description = vim.trim(description)
      result.name = result.description:gsub("[^a-z0-9]", "-"):lower()
    end

    local globs = frontmatter:match("globs:%s*%[(.-)%]")
    if globs then
      result.globs = {}
      for glob in globs:gmatch("[\"']([^\"']+)[\"']") do
        table.insert(result.globs, glob)
      end
    end
  end

  -- 解析规则标题
  local title = content:match("^# ([^\n]+)")
  if title then
    result.name = vim.trim(title:gsub("[^a-z0-9]", "-"):lower())
    if not result.description then
      result.description = vim.trim(title)
    end
  end

  -- 解析规则内容
  local rule_content = content:match("%-%-%-\n.*\n%-%-%-\n(.*)")
  if rule_content then
    result.rule_content = vim.trim(rule_content)

    -- 提取 rationale
    local rationale = rule_content:match("## Rationale\n(.-)\n##")
    if rationale then
      result.rationale = vim.trim(rationale)
    end

    -- 提取示例
    local good_examples = rule_content:match("## Good Examples\n(.-)\n##")
    if good_examples then
      result.good_examples = {}
      for line in good_examples:gmatch("```[^\n]*\n(.-)```") do
        table.insert(result.good_examples, vim.trim(line))
      end
    end

    local bad_examples = rule_content:match("## Bad Examples\n(.-)\n##")
    if bad_examples then
      result.bad_examples = {}
      for line in bad_examples:gmatch("```[^\n]*\n(.-)```") do
        table.insert(result.bad_examples, vim.trim(line))
      end
    end
  end

  -- 提取优先级（默认）
  result.priority = "medium"

  -- 提取目的
  result.purpose = result.rationale or "Auto-extracted rule for: " .. (result.description or "unknown")

  return result
end

----------------------------------------------------------------------
-- 解析 MCP 配置
----------------------------------------------------------------------
---解析 MCP 服务器配置
---@param config table
---@param name string
---@return table
function M.parse_mcp_config(config, name)
  local result = {
    type = "mcp",
    name = name,
    server_type = config.type or "stdio",
  }

  -- 描述
  result.description = "MCP Server: " .. name

  -- stdio 类型配置
  if config.type == "stdio" or not config.type then
    result.server_type = "stdio"
    if config.command then
      result.command = config.command
    end
    if config.args then
      result.args = config.args
    end
    if config.env then
      result.env = config.env
    end
  end

  -- http 类型配置
  if config.type == "http" then
    result.server_type = "http"
    if config.url then
      result.url = config.url
    end
    if config.headers then
      result.headers = config.headers
    end
  end

  -- sse 类型配置
  if config.type == "sse" then
    result.server_type = "sse"
    if config.url then
      result.url = config.url
    end
  end

  -- 安全注意事项（默认）
  result.safety_notes = {
    "Review server permissions before deployment",
    "Validate configuration parameters",
  }

  -- 提供的工具（需要从配置推断）
  result.tools_provided = {}
  if name:find("filesystem") then
    result.tools_provided = { "read_file", "write_file", "list_directory", "search_files" }
    result.description = "Filesystem access MCP server"
  elseif name:find("github") then
    result.tools_provided = { "create_issue", "create_pull_request", "search_repositories", "get_file_contents" }
    result.description = "GitHub API MCP server"
  elseif name:find("memory") then
    result.tools_provided = { "store", "retrieve", "search" }
    result.description = "Memory/knowledge graph MCP server"
  end

  return result
end

----------------------------------------------------------------------
-- 从文件路径提取需求
----------------------------------------------------------------------
---从 skill 文件提取需求
---@param skill_path string
---@return table|nil, string|nil error
function M.extract_from_skill(skill_path)
  if vim.fn.filereadable(skill_path) == 0 then
    return nil, "File not readable: " .. skill_path
  end

  local content = table.concat(vim.fn.readfile(skill_path), "\n")
  local parsed = M.parse_skill_content(content)

  -- 验证提取结果
  if not parsed.name then
    -- 从文件名推断名称
    local filename = vim.fn.fnamemodify(skill_path, ":t:r")
    parsed.name = filename:gsub("[^a-z0-9]", "-"):lower()
  end

  -- 转换为需求格式
  local requirement = M.to_requirement(parsed, "skill")

  return requirement, nil
end

---从 rule 文件提取需求
---@param rule_path string
---@return table|nil, string|nil error
function M.extract_from_rule(rule_path)
  if vim.fn.filereadable(rule_path) == 0 then
    return nil, "File not readable: " .. rule_path
  end

  local content = table.concat(vim.fn.readfile(rule_path), "\n")
  local parsed = M.parse_rule_content(content)

  -- 验证提取结果
  if not parsed.name then
    local filename = vim.fn.fnamemodify(rule_path, ":t:r")
    parsed.name = filename:gsub("[^a-z0-9]", "-"):lower()
  end

  -- 转换为需求格式
  local requirement = M.to_requirement(parsed, "rule")

  return requirement, nil
end

---从 MCP 配置提取需求
---@param mcp_path string
---@param server_name string|nil
---@return table|nil, string|nil error
function M.extract_from_mcp(mcp_path, server_name)
  if vim.fn.filereadable(mcp_path) == 0 then
    return nil, "File not readable: " .. mcp_path
  end

  local content = table.concat(vim.fn.readfile(mcp_path), "\n")
  local ok, config = pcall(vim.json.decode, content)
  if not ok then
    return nil, "Invalid JSON: " .. mcp_path
  end

  if not config.mcpServers then
    return nil, "No mcpServers in config"
  end

  -- 如果指定服务器名称，提取单个
  if server_name then
    local server_config = config.mcpServers[server_name]
    if not server_config then
      return nil, "Server not found: " .. server_name
    end
    local parsed = M.parse_mcp_config(server_config, server_name)
    return M.to_requirement(parsed, "mcp"), nil
  end

  -- 否则提取所有
  local requirements = {}
  for name, server_config in pairs(config.mcpServers) do
    local parsed = M.parse_mcp_config(server_config, name)
    table.insert(requirements, M.to_requirement(parsed, "mcp"))
  end

  return requirements, nil
end

---从 OpenCode agent 配置提取需求
---@param opencode_path string
---@param agent_name string|nil
---@return table|nil, string|nil error
function M.extract_from_opencode(opencode_path, agent_name)
  if vim.fn.filereadable(opencode_path) == 0 then
    return nil, "File not readable: " .. opencode_path
  end

  local content = table.concat(vim.fn.readfile(opencode_path), "\n")
  local ok, config = pcall(vim.json.decode, content)
  if not ok then
    return nil, "Invalid JSON: " .. opencode_path
  end

  if not config.agents then
    return nil, "No agents in config"
  end

  -- 如果指定 agent 名称，提取单个
  if agent_name then
    local agent_config = config.agents[agent_name]
    if not agent_config then
      return nil, "Agent not found: " .. agent_name
    end
    local parsed = M.parse_opencode_agent(agent_config, agent_name)
    return M.to_requirement(parsed, "skill"), nil
  end

  -- 否则提取所有
  local requirements = {}
  for name, agent_config in pairs(config.agents) do
    local parsed = M.parse_opencode_agent(agent_config, name)
    table.insert(requirements, M.to_requirement(parsed, "skill"))
  end

  return requirements, nil
end

----------------------------------------------------------------------
-- 转换为需求格式
----------------------------------------------------------------------
---将解析结果转换为需求格式
---@param parsed table
---@param type string
---@return table
function M.to_requirement(parsed, type)
  local requirement = {
    type = type,
    name = parsed.name,
    description = parsed.description or "Auto-extracted " .. type,
    purpose = parsed.purpose or "Extracted from existing " .. type,
    extracted = true, -- 标记为提取的
    extraction_source = parsed.source_path or "unknown",
  }

  -- 复制其他字段
  if parsed.triggers then
    requirement.triggers = parsed.triggers
  end
  if parsed.instructions then
    requirement.instructions = parsed.instructions
  end
  if parsed.examples then
    requirement.examples = parsed.examples
  end
  if parsed.constraints then
    requirement.constraints = parsed.constraints
  end

  -- Rule 特有字段
  if type == "rule" then
    if parsed.rationale then
      requirement.rationale = parsed.rationale
    end
    if parsed.good_examples then
      requirement.good_examples = parsed.good_examples
    end
    if parsed.bad_examples then
      requirement.bad_examples = parsed.bad_examples
    end
    if parsed.globs then
      requirement.triggers = requirement.triggers or {}
      requirement.triggers.file_patterns = parsed.globs
    end
    if parsed.priority then
      requirement.priority = parsed.priority
    end
  end

  -- MCP 特有字段
  if type == "mcp" then
    requirement.server_type = parsed.server_type
    if parsed.command then
      requirement.command = parsed.command
    end
    if parsed.args then
      requirement.args = parsed.args
    end
    if parsed.env then
      requirement.env = parsed.env
    end
    if parsed.url then
      requirement.url = parsed.url
    end
    if parsed.headers then
      requirement.headers = parsed.headers
    end
    if parsed.tools_provided then
      requirement.tools_provided = parsed.tools_provided
    end
    if parsed.safety_notes then
      requirement.safety_notes = parsed.safety_notes
    end
  end

  -- 验证需求
  local validation = Templates.validate_requirement(requirement)
  if not validation.valid then
    requirement.validation_errors = validation.errors
  end

  return requirement
end

----------------------------------------------------------------------
-- 批量提取和保存
----------------------------------------------------------------------
---从部署目录批量提取需求
---@param scope string "project" | "global"
---@return table extracted_requirements
function M.extract_all_from_deployed(scope)
  local results = {}

  -- 获取已部署内容
  local deployed = Registry.get_all_deployed()

  -- 过滤指定 scope
  if scope then
    deployed = vim.tbl_filter(function(item)
      return item.scope == scope
    end, deployed)
  end

  for _, item in ipairs(deployed) do
    local requirement, err

    if item.type == "skill" then
      requirement, err = M.extract_from_skill(item.path)
    elseif item.type == "rule" then
      requirement, err = M.extract_from_rule(item.path)
    elseif item.type == "mcp" then
      requirement, err = M.extract_from_mcp(item.path, item.name)
    elseif item.type == "agent" then
      requirement, err = M.extract_from_opencode(item.path, item.name)
    end

    if err then
      vim.notify("Extract error: " .. err, vim.log.levels.WARN)
    elseif requirement then
      if type(requirement) == "table" and requirement.name then
        table.insert(results, requirement)
      elseif type(requirement) == "table" and #requirement > 0 then
        vim.list_extend(results, requirement)
      end
    end
  end

  return results
end

---保存提取的需求到注册表
---@param requirement table
---@return boolean, string
function M.save_extracted_requirement(requirement)
  if not requirement.name then
    return false, "Requirement has no name"
  end

  -- 检查是否已存在
  local existing = Registry.get_requirement(requirement.name)
  if existing and not existing.extracted then
    return false, "Requirement already exists and is not extracted: " .. requirement.name
  end

  -- 创建需求记录
  local ok = Registry.create_requirement(requirement.name, {
    type = requirement.type,
  })

  if not ok then
    return false, "Failed to create requirement: " .. requirement.name
  end

  -- 更新需求数据
  local req = Registry.get_requirement(requirement.name)
  req.extracted = true
  req.extraction_source = requirement.extraction_source
  req.updated_at = os.date("%Y-%m-%dT%H:%M:%S")

  Registry.set_requirement(requirement.name, req)

  -- 保存需求文件
  local content = Templates.format_requirement_markdown(requirement)
  Registry.write_requirement_file(requirement.name, content)

  return true, requirement.name
end

----------------------------------------------------------------------
-- 通用提取入口
----------------------------------------------------------------------
---从任意路径提取需求
---@param path string
---@return table|nil, string|nil error
function M.extract(path)
  -- 判断路径类型
  local basename = vim.fn.fnamemodify(path, ":t")
  local dirname = vim.fn.fnamemodify(path, ":h")

  -- Skill 文件
  if basename == "SKILL.md" or path:match("/skills/[^/]+/SKILL%.md$") then
    return M.extract_from_skill(path)
  end

  -- Rule 文件
  if path:match("/rules/[^/]+%.md$") then
    return M.extract_from_rule(path)
  end

  -- MCP 配置
  if basename == ".mcp.json" then
    return M.extract_from_mcp(path)
  end

  -- OpenCode 配置
  if basename == "opencode.json" then
    return M.extract_from_opencode(path)
  end

  -- 单个 skill markdown 文件
  if basename:match("%.md$") then
    -- 尝试作为 skill 解析
    local content = table.concat(vim.fn.readfile(path), "\n")
    if content:find("^%-%-%-") and content:find("name:") then
      return M.extract_from_skill(path)
    end
  end

  return nil, "Unknown file type: " .. path
end

----------------------------------------------------------------------
-- 配置
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}
  return M
end

return M
