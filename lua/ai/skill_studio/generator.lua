-- lua/ai/skill_studio/generator.lua
-- AI 生成模块：从需求生成 skill/rule/mcp

local M = {}

local Registry = require("ai.skill_studio.registry")
local Templates = require("ai.skill_studio.templates")
local Validator = require("ai.skill_studio.validator")

----------------------------------------------------------------------
-- 配置
----------------------------------------------------------------------
local AI_GENERATION_TIMEOUT_MS = 120000 -- 2 minutes for AI response

M.config = {
  default_backend = "avante", -- avante | opencode | claude
  timeout = AI_GENERATION_TIMEOUT_MS,
}

----------------------------------------------------------------------
-- Prompt 构建辅助函数
----------------------------------------------------------------------
---构建基本信息部分
---@param requirement table
---@param target string
---@return string[]
local function build_basic_info(requirement, target)
  local type = requirement.type or "skill"
  return {
    "# Task: Generate a " .. type .. " for " .. target,
    "",
    "## Requirement",
    "",
    "Please generate a " .. type .. " based on the following requirement specification.",
    "The generated content should be complete, correct, and ready to use.",
    "",
    "### Basic Information",
    "- **Name**: " .. (requirement.name or "unnamed"),
    "- **Type**: " .. type,
    "- **Target Platform**: " .. target,
    "",
  }
end

---构建描述部分
---@param requirement table
---@return string[]
local function build_description(requirement)
  local parts = {}

  if requirement.description then
    table.insert(parts, "### Description")
    table.insert(parts, requirement.description)
    table.insert(parts, "")
  end

  if requirement.purpose then
    table.insert(parts, "### Purpose")
    table.insert(parts, requirement.purpose)
    table.insert(parts, "")
  end

  return parts
end

---构建触发条件部分
---@param requirement table
---@return string[]
local function build_triggers(requirement)
  if not requirement.triggers then
    return {}
  end

  local parts = { "### Trigger Conditions" }

  if requirement.triggers.keywords then
    table.insert(parts, "**Keywords**: " .. table.concat(requirement.triggers.keywords, ", "))
  end

  if requirement.triggers.file_patterns then
    table.insert(parts, "**File Patterns**: " .. table.concat(requirement.triggers.file_patterns, ", "))
  end

  table.insert(parts, "")
  return parts
end

---构建执行指令部分
---@param requirement table
---@return string[]
local function build_instructions(requirement)
  if not requirement.instructions then
    return {}
  end

  local parts = { "### Instructions" }

  if requirement.instructions.steps then
    table.insert(parts, "Execute the following steps:")
    for _, step in ipairs(requirement.instructions.steps) do
      table.insert(parts, step)
    end
  end

  if requirement.instructions.validation then
    table.insert(parts, "")
    table.insert(parts, "**Validation Checkpoints**:")
    for _, check in ipairs(requirement.instructions.validation) do
      table.insert(parts, "- [ ] " .. check)
    end
  end

  table.insert(parts, "")
  return parts
end

---构建示例部分
---@param requirement table
---@return string[]
local function build_examples(requirement)
  if not requirement.examples or #requirement.examples == 0 then
    return {}
  end

  local parts = { "### Examples" }

  for i, example in ipairs(requirement.examples) do
    table.insert(parts, "")
    table.insert(parts, "**Example " .. i .. "**:")
    if example.input then
      table.insert(parts, "Input: " .. example.input)
    end
    if example.output then
      table.insert(parts, "Output: " .. example.output)
    end
    if example.explanation then
      table.insert(parts, "Explanation: " .. example.explanation)
    end
  end

  table.insert(parts, "")
  return parts
end

---构建约束部分
---@param requirement table
---@return string[]
local function build_constraints(requirement)
  if not requirement.constraints then
    return {}
  end

  local parts = { "### Constraints" }

  if requirement.constraints.allowed_tools then
    table.insert(parts, "**Allowed Tools**: " .. table.concat(requirement.constraints.allowed_tools, ", "))
  end

  if requirement.constraints.forbidden_actions then
    table.insert(parts, "**Forbidden Actions**: " .. table.concat(requirement.constraints.forbidden_actions, ", "))
  end

  if requirement.constraints.safety_rules then
    table.insert(parts, "**Safety Rules**:")
    for _, rule in ipairs(requirement.constraints.safety_rules) do
      table.insert(parts, "- " .. rule)
    end
  end

  table.insert(parts, "")
  return parts
end

---构建输出格式部分
---@param type string
---@param target string
---@return string[]
local function build_output_format(type, target)
  local parts = { "## Output Format", "" }

  if type == "skill" then
    if target == "claude" then
      table.insert(
        parts,
        [[Generate a Claude Code skill in the following format:

```markdown
---
name: <skill-name>
description: <brief description>
version: "1.0.0"
---

# <Skill Title>

## When This Skill Applies

<conditions for activation>

## Instructions

<step-by-step instructions>

## Examples

<usage examples>
```

Ensure:
1. The frontmatter is valid YAML
2. The instructions are clear and actionable
3. Examples demonstrate typical usage
4. No placeholder text - use real, working content]]
      )
    elseif target == "opencode" then
      table.insert(
        parts,
        [[Generate an OpenCode agent configuration in JSON format.

The agent will be added to opencode.json under "agents" key.

Return ONLY a JSON object with:
- model: recommended model (or "default")
- prompt: the full agent system prompt

Example:
```json
{
  "model": "claude-sonnet-4-6",
  "prompt": "You are a code reviewer..."
}
```]]
      )
    end
  elseif type == "rule" then
    table.insert(
      parts,
      [[Generate a Claude Code rule in the following format:

```markdown
---
description: <rule description>
globs: ["<file patterns>"]
---

# <Rule Title>

<rule content with rationale and examples>
```

Ensure the rule is:
1. Clear and unambiguous
2. Includes rationale
3. Has concrete examples
4. Applicable to the specified file patterns]]
    )
  elseif type == "mcp" then
    table.insert(
      parts,
      [[Generate an MCP server configuration in JSON format.

Return a JSON object that can be merged into .mcp.json:

```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "stdio",
      "command": "<command>",
      "args": ["<args>"],
      "env": {
        "<ENV_VAR>": "${VALUE}"
      }
    }
  }
}
```

OR for HTTP type:
```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "http",
      "url": "<endpoint>",
      "headers": {
        "Authorization": "Bearer ${TOKEN}"
      }
    }
  }
}
```]]
    )
  elseif type == "command" then
    table.insert(
      parts,
      [[Generate a Claude Code command in the following format:

```markdown
---
description: <command description>
argument-hint: "<args hint>"
allowed-tools: [Read, Write, Bash, Edit, Grep, Glob]
---

# <Command Name>

## Arguments

$ARGUMENTS

## Instructions

<step-by-step instructions for executing this command>
```

Ensure:
1. The argument-hint clearly shows expected arguments
2. Instructions handle argument parsing
3. Error handling is included]]
    )
  end

  return parts
end

----------------------------------------------------------------------
-- 构建 AI Prompt
----------------------------------------------------------------------
---构建生成 skill 的 prompt
---@param requirement table
---@param target string "claude" | "opencode"
---@return string
function M.build_prompt(requirement, target)
  local type = requirement.type or "skill"

  -- 组装各部分
  local sections = {
    build_basic_info(requirement, target),
    build_description(requirement),
    build_triggers(requirement),
    build_instructions(requirement),
    build_examples(requirement),
    build_constraints(requirement),
    build_output_format(type, target),
  }

  -- 合并所有部分
  local prompt_parts = {}
  for _, section in ipairs(sections) do
    vim.list_extend(prompt_parts, section)
  end

  return table.concat(prompt_parts, "\n")
end

----------------------------------------------------------------------
-- AI 后端调用
----------------------------------------------------------------------
---调用 Avante
---@param prompt string
---@return string|nil, string|nil error
function M.call_avante(prompt)
  local ok, avante = pcall(require, "avante")
  if not ok then
    return nil, "Avante not available"
  end

  -- 使用 Avante 的 API
  -- 注意：这需要 Avante 有暴露的 API
  -- 如果没有，我们需要通过其他方式调用

  -- 尝试使用 Avante 的 sidebar
  local sidebar = require("avante.sidebar")
  if sidebar and sidebar.is_open then
    -- 如果 sidebar 已打开，发送消息
    -- 这是一个简化的实现
    vim.notify("Please use Avante sidebar to generate the skill", vim.log.levels.INFO)
    vim.fn.setreg("+", prompt)
    return nil, "Prompt copied to clipboard. Paste in Avante sidebar."
  end

  -- 将 prompt 复制到剪贴板
  vim.fn.setreg("+", prompt)
  return nil, "Prompt copied to clipboard. Open Avante and paste."
end

---调用 OpenCode（通过终端）
---@param prompt string
---@return string|nil, string|nil error
function M.call_opencode(prompt)
  local Terminal = require("ai.terminal")

  -- 将 prompt 保存到临时文件 (vim.fn.tempname() files are auto-deleted on Vim exit)
  local tmp_file = vim.fn.tempname() .. ".txt"
  vim.fn.writefile(vim.split(prompt, "\n"), tmp_file)

  -- 打开 OpenCode 终端
  Terminal.toggle("opencode", {
    args = "--prompt-file " .. tmp_file,
  })

  return nil, "OpenCode terminal opened with prompt"
end

---调用 Claude Code（通过终端）
---@param prompt string
---@return string|nil, string|nil error
function M.call_claude_code(prompt)
  local Terminal = require("ai.terminal")

  -- 将 prompt 保存到临时文件 (vim.fn.tempname() files are auto-deleted on Vim exit)
  local tmp_file = vim.fn.tempname() .. ".txt"
  vim.fn.writefile(vim.split(prompt, "\n"), tmp_file)

  -- 打开 Claude Code 终端
  Terminal.toggle("claude", {
    args = "--prompt-file " .. tmp_file,
  })

  return nil, "Claude Code terminal opened with prompt"
end

---调用 AI（统一入口）
---@param prompt string
---@param backend string|nil
---@return string|nil, string|nil error
function M.call_ai(prompt, backend)
  backend = backend or M.config.default_backend

  if backend == "avante" then
    return M.call_avante(prompt)
  elseif backend == "opencode" then
    return M.call_opencode(prompt)
  elseif backend == "claude" then
    return M.call_claude_code(prompt)
  else
    return nil, "Unknown backend: " .. backend
  end
end

----------------------------------------------------------------------
-- 生成和保存
----------------------------------------------------------------------
---保存生成的内容
---@param name string
---@param content string
---@param type string
---@param platform string
---@return string path
function M.save_generated(name, content, type, platform)
  local path = Registry.get_generated_path(name, type, platform)
  if not path then
    return nil
  end

  local full_path = Registry.paths.generated .. "/" .. path
  local dir = vim.fn.fnamemodify(full_path, ":h")
  vim.fn.mkdir(dir, "p")

  vim.fn.writefile(vim.split(content, "\n"), full_path)

  return path
end

---生成 skill/rule/mcp
---@param name string
---@param opts table
---@return boolean, string
function M.generate(name, opts)
  opts = opts or {}
  local platform = opts.platform or "claude"
  local backend = opts.backend or M.config.default_backend

  -- 获取需求
  local requirement = Registry.get_requirement(name)
  if not requirement then
    -- 尝试从文件加载
    local content = Registry.read_requirement_file(name)
    if content then
      requirement = Templates.parse_requirement_markdown(content)
      requirement.name = name
    end
  end

  if not requirement then
    return false, "Requirement not found: " .. name
  end

  -- 验证需求
  local validation = Templates.validate_requirement(requirement)
  if not validation.valid then
    return false, "Invalid requirement:\n" .. table.concat(validation.errors, "\n")
  end

  -- 构建 prompt
  local prompt = M.build_prompt(requirement, platform)

  -- 调用 AI
  vim.notify("Generating " .. requirement.type .. " for " .. platform .. "...", vim.log.levels.INFO)

  local result, err = M.call_ai(prompt, backend)

  if err then
    -- 如果是剪贴板模式，提示用户
    if err:find("clipboard") then
      vim.notify(err, vim.log.levels.INFO)
      return true, "Prompt ready. Paste in AI interface."
    end
    return false, err
  end

  if not result then
    return false, "No result from AI"
  end

  -- 保存结果
  local path = M.save_generated(name, result, requirement.type, platform)
  if not path then
    return false, "Failed to save generated content"
  end

  -- 更新索引
  Registry.update_version_status(name, platform, {
    generated = true,
    path = path,
    deployed = false,
    last_validated = os.date("%Y-%m-%dT%H:%M:%S"),
  })

  vim.notify("Generated " .. requirement.type .. " for " .. platform .. ": " .. path, vim.log.levels.INFO)
  return true, path
end

---从剪贴板导入生成结果
---@param name string
---@param platform string
---@return boolean, string
function M.import_from_clipboard(name, platform)
  local content = vim.fn.getreg("+")
  if not content or content == "" then
    return false, "Clipboard is empty"
  end

  local requirement = Registry.get_requirement(name)
  if not requirement then
    return false, "Requirement not found: " .. name
  end

  -- 清理 markdown 代码块标记
  content = content:gsub("```markdown\n", ""):gsub("```json\n", ""):gsub("```\n", ""):gsub("```", "")

  -- 保存
  local path = M.save_generated(name, content, requirement.type, platform)
  if not path then
    return false, "Failed to save"
  end

  -- 更新索引
  Registry.update_version_status(name, platform, {
    generated = true,
    path = path,
    deployed = false,
    last_validated = os.date("%Y-%m-%dT%H:%M:%S"),
  })

  return true, path
end

----------------------------------------------------------------------
-- 验证和测试
----------------------------------------------------------------------
---验证生成的内容
---@param content string
---@param type string
---@return table { valid: boolean, errors: string[] }
function M.validate_generated(content, type)
  local errors = {}

  if not content or content == "" then
    return { valid = false, errors = { "Content is empty" } }
  end

  if type == "skill" then
    -- 检查 frontmatter
    if not content:find("^%-%-%-") then
      table.insert(errors, "Missing frontmatter (---)")
    end

    -- 检查必要字段
    if not content:find("name:") then
      table.insert(errors, "Missing 'name' in frontmatter")
    end
    if not content:find("description:") then
      table.insert(errors, "Missing 'description' in frontmatter")
    end

    -- 检查内容结构
    if not content:find("## Instructions") and not content:find("## 步骤") then
      table.insert(errors, "Missing 'Instructions' section")
    end
  elseif type == "rule" then
    if not content:find("description:") then
      table.insert(errors, "Missing 'description'")
    end
  elseif type == "mcp" then
    -- 验证 JSON
    local ok, decoded = pcall(vim.json.decode, content)
    if not ok then
      table.insert(errors, "Invalid JSON: " .. tostring(decoded))
    elseif not decoded.mcpServers then
      table.insert(errors, "Missing 'mcpServers' key")
    end
  end

  return {
    valid = #errors == 0,
    errors = errors,
  }
end

---测试生成的 skill
---@param name string
---@param platform string
---@return boolean, string
function M.test_generated_skill(name, platform)
  local requirement = Registry.get_requirement(name)
  if not requirement then
    return false, "Requirement not found"
  end

  local version = requirement.versions[platform]
  if not version or not version.generated then
    return false, "No generated version for " .. platform
  end

  local path = Registry.paths.generated .. "/" .. version.path
  if vim.fn.filereadable(path) == 0 then
    return false, "Generated file not found: " .. path
  end

  local content = table.concat(vim.fn.readfile(path), "\n")

  -- 验证格式
  local validation = M.validate_generated(content, requirement.type)
  if not validation.valid then
    return false, "Validation failed:\n" .. table.concat(validation.errors, "\n")
  end

  -- 更新验证时间
  version.last_validated = os.date("%Y-%m-%dT%H:%M:%S")
  Registry.set_requirement(name, requirement)

  return true, "Validation passed"
end

----------------------------------------------------------------------
-- 配置
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_extend("force", M.config, opts)
  return M
end

return M
