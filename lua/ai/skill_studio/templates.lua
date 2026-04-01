-- lua/ai/skill_studio/templates.lua
-- 需求模板定义：确保 AI 生成的内容一次性可用

local M = {}

----------------------------------------------------------------------
-- Skill 需求模板
----------------------------------------------------------------------
M.skill = {
  -- 模板元数据
  meta = {
    type = "skill",
    description = "技能模板：定义特定的任务执行能力",
  },

  -- 需求结构定义
  schema = {
    -- 基本信息
    name = {
      required = true,
      type = "string",
      pattern = "^[a-z][a-z0-9-]*$",
      description = "技能名称（kebab-case，唯一标识）",
      example = "code-review",
    },
    type = {
      required = true,
      type = "string",
      enum = { "skill" },
      default = "skill",
    },
    target = {
      required = true,
      type = "string",
      enum = { "claude", "opencode" },
      description = "目标平台",
    },

    -- 触发条件
    triggers = {
      required = true,
      type = "table",
      description = "触发条件定义",
      fields = {
        keywords = {
          required = true,
          type = "table",
          description = "触发关键词列表（用户输入包含这些词时激活）",
          example = { "review", "代码审查", "检查代码" },
        },
        file_patterns = {
          required = false,
          type = "table",
          description = "适用的文件模式",
          example = { "*.lua", "*.ts", "*.go" },
        },
        context_conditions = {
          required = false,
          type = "table",
          description = "其他上下文触发条件",
          example = { "git diff exists", "test file open" },
        },
      },
    },

    -- 核心描述
    description = {
      required = true,
      type = "string",
      min_length = 10,
      max_length = 200,
      description = "简短描述（用于 UI 显示）",
      example = "执行全面的代码审查，检查质量、安全和性能",
    },
    purpose = {
      required = true,
      type = "string",
      min_length = 50,
      description = "详细目的说明（为什么需要这个技能）",
    },
    scope = {
      required = false,
      type = "string",
      description = "适用范围",
      example = "适用于所有代码文件的审查",
    },

    -- 执行指令
    instructions = {
      required = true,
      type = "table",
      description = "详细的执行步骤",
      fields = {
        prerequisites = {
          required = false,
          type = "table",
          description = "前置条件检查",
          example = { "确保在 Git 仓库中", "确保有可审查的改动" },
        },
        steps = {
          required = true,
          type = "table",
          description = "详细执行步骤（每一步都要具体可执行）",
          example = {
            "1. 获取当前文件或选区的代码",
            "2. 分析代码结构和逻辑",
            "3. 检查命名规范和代码风格",
            "4. 识别潜在的安全问题",
            "5. 检查性能瓶颈",
            "6. 生成审查报告和改进建议",
          },
        },
        validation = {
          required = false,
          type = "table",
          description = "验证检查点",
          example = { "检查报告是否完整", "确认建议是否可执行" },
        },
        error_handling = {
          required = false,
          type = "table",
          description = "错误处理策略",
          example = {
            { condition = "文件过大", action = "分段审查" },
            { condition = "无法解析", action = "报告错误并跳过" },
          },
        },
      },
    },

    -- 示例
    examples = {
      required = true,
      type = "table",
      min_items = 2,
      description = "使用示例（至少 2 个）",
      example = {
        {
          input = "review this function",
          output = "生成包含命名、逻辑、安全、性能的审查报告",
          explanation = "标准审查流程",
        },
        {
          input = "检查这段代码的安全性",
          output = "专注于安全问题的审查报告",
          explanation = "安全导向审查",
        },
      },
    },

    -- 约束
    constraints = {
      required = false,
      type = "table",
      description = "约束条件",
      fields = {
        allowed_tools = {
          required = false,
          type = "table",
          description = "允许使用的工具",
          example = { "Read", "Write", "Bash", "Edit", "Grep", "Glob" },
        },
        forbidden_actions = {
          required = false,
          type = "table",
          description = "禁止的操作",
          example = { "删除文件", "执行危险命令", "修改配置" },
        },
        safety_rules = {
          required = false,
          type = "table",
          description = "安全规则",
          example = { "不执行用户提供的代码", "不泄露敏感信息" },
        },
      },
    },

    -- 测试用例
    test_cases = {
      required = false,
      type = "table",
      description = "测试用例（推荐提供）",
      example = {
        {
          description = "审查简单函数",
          input = "function add(a, b) return a + b end",
          expected_output = "检查命名、参数验证、返回值处理",
        },
      },
    },
  },

  -- Markdown 模板
  markdown_template = [[# {name} - Skill Requirement

## 基本信息

- **名称**: {name}
- **类型**: skill
- **目标平台**: {target}

## 触发条件

### 关键词
{triggers_keywords}

### 文件模式
{triggers_file_patterns}

### 上下文条件
{triggers_context_conditions}

## 描述

### 简短描述
{description}

### 详细目的
{purpose}

### 适用范围
{scope}

## 执行指令

### 前置条件
{instructions_prerequisites}

### 执行步骤
{instructions_steps}

### 验证检查点
{instructions_validation}

### 错误处理
{instructions_error_handling}

## 示例

{examples}

## 约束条件

### 允许的工具
{constraints_allowed_tools}

### 禁止的操作
{constraints_forbidden_actions}

### 安全规则
{constraints_safety_rules}

## 测试用例

{test_cases}
]],
}

----------------------------------------------------------------------
-- Rule 需求模板
----------------------------------------------------------------------
M.rule = {
  meta = {
    type = "rule",
    description = "规则模板：定义编码规范和工作流程约束",
  },

  schema = {
    name = {
      required = true,
      type = "string",
      pattern = "^[a-z][a-z0-9-]*$",
      description = "规则名称",
      example = "coding-standards",
    },
    type = {
      required = true,
      type = "string",
      default = "rule",
    },
    target = {
      required = true,
      type = "string",
      enum = { "claude", "opencode" },
    },
    priority = {
      required = false,
      type = "string",
      enum = { "high", "medium", "low" },
      default = "medium",
      description = "规则优先级",
    },

    description = {
      required = true,
      type = "string",
      description = "规则描述（简洁明确）",
    },
    scope = {
      required = false,
      type = "string",
      description = "适用场景",
      example = "所有 Python 文件",
    },

    rule_content = {
      required = true,
      type = "string",
      description = "规则详细内容",
    },
    rationale = {
      required = true,
      type = "string",
      description = "规则存在的原因",
    },

    good_examples = {
      required = true,
      type = "table",
      description = "符合规则的示例",
    },
    bad_examples = {
      required = true,
      type = "table",
      description = "违反规则的示例",
    },
    exceptions = {
      required = false,
      type = "table",
      description = "例外情况",
    },
  },

  markdown_template = [[# {name} - Rule Requirement

## 基本信息

- **名称**: {name}
- **类型**: rule
- **目标平台**: {target}
- **优先级**: {priority}

## 规则描述

{description}

## 适用场景

{scope}

## 规则内容

{rule_content}

## 存在原因

{rationale}

## 正确示例

{good_examples}

## 错误示例

{bad_examples}

## 例外情况

{exceptions}
]],
}

----------------------------------------------------------------------
-- Command 需求模板
----------------------------------------------------------------------
M.command = {
  meta = {
    type = "command",
    description = "命令模板：定义用户可调用的命令",
  },

  schema = {
    name = {
      required = true,
      type = "string",
      pattern = "^[a-z][a-z0-9-]*$",
      description = "命令名称",
      example = "test-coverage",
    },
    type = {
      required = true,
      type = "string",
      default = "command",
    },
    target = {
      required = true,
      type = "string",
      enum = { "claude", "opencode" },
    },

    description = {
      required = true,
      type = "string",
      description = "命令描述",
    },
    argument_hint = {
      required = false,
      type = "string",
      description = "参数提示",
      example = "<file_pattern> [--verbose]",
    },
    allowed_tools = {
      required = false,
      type = "table",
      description = "允许的工具",
      example = { "Read", "Bash", "Grep", "Glob" },
    },

    instructions = {
      required = true,
      type = "string",
      description = "执行指令",
    },
    examples = {
      required = true,
      type = "table",
      description = "使用示例",
    },
  },

  markdown_template = [[# {name} - Command Requirement

## 基本信息

- **名称**: {name}
- **类型**: command
- **目标平台**: {target}

## 命令描述

{description}

## 参数提示

{argument_hint}

## 允许的工具

{allowed_tools}

## 执行指令

$ARGUMENTS

{instructions}

## 使用示例

{examples}
]],
}

----------------------------------------------------------------------
-- MCP 需求模板
----------------------------------------------------------------------
M.mcp = {
  meta = {
    type = "mcp",
    description = "MCP 模板：定义 MCP 服务器配置",
  },

  schema = {
    name = {
      required = true,
      type = "string",
      description = "服务器名称",
      example = "filesystem",
    },
    type = {
      required = true,
      type = "string",
      default = "mcp",
    },
    server_type = {
      required = true,
      type = "string",
      enum = { "stdio", "http", "sse" },
      description = "服务器类型",
    },

    description = {
      required = true,
      type = "string",
      description = "功能描述",
    },

    -- stdio 类型配置
    command = {
      required = false,
      type = "string",
      description = "启动命令（stdio 类型）",
      example = "npx",
    },
    args = {
      required = false,
      type = "table",
      description = "命令行参数",
      example = { "-y", "@modelcontextprotocol/server-filesystem" },
    },
    env = {
      required = false,
      type = "table",
      description = "环境变量",
      example = { API_KEY = "${YOUR_API_KEY}" },
    },

    -- http 类型配置
    url = {
      required = false,
      type = "string",
      description = "API 端点（http 类型）",
    },
    headers = {
      required = false,
      type = "table",
      description = "请求头",
    },

    tools_provided = {
      required = true,
      type = "table",
      description = "提供的工具列表",
    },
    safety_notes = {
      required = true,
      type = "table",
      description = "安全注意事项",
    },
  },

  markdown_template = [[# {name} - MCP Requirement

## 基本信息

- **名称**: {name}
- **类型**: mcp
- **服务器类型**: {server_type}

## 功能描述

{description}

## 连接配置

{connection_config}

## 提供的工具

{tools_provided}

## 使用示例

{usage_examples}

## 安全注意事项

{safety_notes}
]],
}

----------------------------------------------------------------------
-- 辅助函数
----------------------------------------------------------------------
---获取模板
---@param type string "skill" | "rule" | "command" | "mcp"
---@return table|nil
function M.get_template(type)
  return M[type]
end

---获取 Markdown 模板
---@param type string
---@return string|nil
function M.get_markdown_template(type)
  local template = M[type]
  return template and template.markdown_template
end

---验证需求
---@param requirement table
---@return table { valid: boolean, errors: string[] }
function M.validate_requirement(requirement)
  local errors = {}
  local type = requirement.type or "skill"
  local template = M[type]

  if not template then
    return { valid = false, errors = { "Unknown type: " .. type } }
  end

  local schema = template.schema

  for field_name, field_spec in pairs(schema) do
    if field_spec.required then
      local value = requirement[field_name]
      if value == nil then
        table.insert(errors, string.format("Missing required field: %s", field_name))
      elseif field_spec.type == "string" and type(value) ~= "string" then
        table.insert(errors, string.format("Field %s must be a string", field_name))
      elseif field_spec.type == "table" and type(value) ~= "table" then
        table.insert(errors, string.format("Field %s must be a table", field_name))
      elseif field_spec.enum and not vim.tbl_contains(field_spec.enum, value) then
        table.insert(
          errors,
          string.format("Field %s must be one of: %s", field_name, table.concat(field_spec.enum, ", "))
        )
      elseif field_spec.pattern and type(value) == "string" and not value:match(field_spec.pattern) then
        table.insert(errors, string.format("Field %s does not match pattern: %s", field_name, field_spec.pattern))
      end
    end
  end

  return {
    valid = #errors == 0,
    errors = errors,
  }
end

---格式化需求为 Markdown
---@param requirement table
---@return string
function M.format_requirement_markdown(requirement)
  local type = requirement.type or "skill"
  local template = M.get_markdown_template(type)

  if not template then
    return ""
  end

  -- 简单的字符串替换
  local result = template

  -- 替换基本信息
  for key, value in pairs(requirement) do
    if type(value) == "string" then
      result = result:gsub("{" .. key .. "}", value)
    elseif type(value) == "table" then
      -- 处理嵌套字段
      for sub_key, sub_value in pairs(value) do
        local placeholder = key .. "_" .. sub_key
        if type(sub_value) == "table" then
          local formatted = table.concat(
            vim.tbl_map(function(v)
              return "- " .. tostring(v)
            end, sub_value),
            "\n"
          )
          result = result:gsub("{" .. placeholder .. "}", formatted)
        else
          result = result:gsub("{" .. placeholder .. "}", tostring(sub_value))
        end
      end

      -- 处理数组类型
      if vim.tbl_islist(value) then
        local formatted = table.concat(
          vim.tbl_map(function(v)
            if type(v) == "table" and v.input then
              return string.format(
                "### 示例\n**输入**: %s\n**输出**: %s\n**说明**: %s",
                v.input or "",
                v.output or "",
                v.explanation or ""
              )
            end
            return "- " .. tostring(v)
          end, value),
          "\n\n"
        )
        result = result:gsub("{" .. key .. "}", formatted)
      end
    end
  end

  -- 清理未替换的占位符
  result = result:gsub("{[a-z_]+}", "")

  return result
end

---从 Markdown 解析需求
---@param content string
---@return table
function M.parse_requirement_markdown(content)
  local result = {}

  -- 解析基本信息
  local name = content:match("%*%*名称%*%*:%s*([^\n]+)")
  if name then
    result.name = vim.trim(name)
  end

  local req_type = content:match("%*%*类型%*%*:%s*([^\n]+)")
  if req_type then
    result.type = vim.trim(req_type)
  end

  local target = content:match("%*%*目标平台%*%*:%s*([^\n]+)")
  if target then
    result.target = vim.trim(target)
  end

  -- 解析描述
  local description = content:match("### 简短描述\n(.-)\n###")
  if description then
    result.description = vim.trim(description)
  end

  local purpose = content:match("### 详细目的\n(.-)\n###")
  if purpose then
    result.purpose = vim.trim(purpose)
  end

  -- 解析关键词
  local keywords_section = content:match("### 关键词\n(.-)\n###")
  if keywords_section then
    result.triggers = result.triggers or {}
    result.triggers.keywords = {}
    for keyword in keywords_section:gmatch("%- ([^\n]+)") do
      table.insert(result.triggers.keywords, vim.trim(keyword))
    end
  end

  -- 解析执行步骤
  local steps_section = content:match("### 执行步骤\n(.-)\n###")
  if steps_section then
    result.instructions = result.instructions or {}
    result.instructions.steps = {}
    for step in steps_section:gmatch("(%d+%. [^\n]+)") do
      table.insert(result.instructions.steps, vim.trim(step))
    end
  end

  return result
end

---获取空需求模板（用于创建新需求）
---@param type string
---@param target string
---@return table
function M.get_empty_requirement(type, target)
  local result = {
    type = type or "skill",
    target = target or "claude",
  }

  local template = M[type]
  if not template then
    return result
  end

  local schema = template.schema
  for field_name, field_spec in pairs(schema) do
    if field_spec.default then
      result[field_name] = field_spec.default
    elseif field_spec.type == "table" then
      result[field_name] = {}
    elseif field_spec.type == "string" then
      result[field_name] = ""
    end
  end

  return result
end

return M
