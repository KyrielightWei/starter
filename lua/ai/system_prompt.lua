-- lua/ai/system_prompt.lua
-- 统一的 System Prompt 配置，供所有 AI 工具使用
--
-- ============================================================================
-- 如何使用
-- ============================================================================
--
-- 1. Prompt 文件位置
--    默认目录：~/.config/nvim/prompts/
--    
--    文件结构：
--    ~/.config/nvim/prompts/
--    ├── todo_workflow.md     # 基础模版（TODO 工作流）
--    ├── code_style.md         # 可选：代码风格
--    └── custom.md             # 用户自定义
--
-- 2. 为不同工具配置 prompt
--    修改 M.tool_files 配置：
--    
--    M.tool_files = {
--      opencode = {"todo_workflow.md", "code_style.md"},
--      claude_code = {"todo_workflow.md"},
--      avante = {"todo_workflow.md"},
--    }
--
-- 3. 添加新的 prompt 文件
--    a) 在 ~/.config/nvim/prompts/ 目录创建新的 .md 文件
--    b) 在 M.tool_files 中添加文件名
--    c) 运行 :AISyncAll 重新生成配置
--
-- 4. 命令
--    :AIEditPrompts     - 打开 prompts 目录
--    :AIListPrompts     - 列出所有可用的 prompt 文件
--
-- ============================================================================

local M = {}

----------------------------------------------------------------------
-- Prompt 文件目录
----------------------------------------------------------------------
local function get_prompts_dir()
  return vim.fn.stdpath("config") .. "/prompts"
end

----------------------------------------------------------------------
-- 各工具的 prompt 文件配置
-- 按顺序读取并合并，文件名相对于 prompts 目录
-- 空文件会自动跳过，只有有内容的文件才会合并
----------------------------------------------------------------------
M.tool_files = {
  opencode = {"todo_workflow.md", "code_style.md", "custom.md"},
  claude_code = {"todo_workflow.md", "code_style.md", "custom.md"},
  avante = {"todo_workflow.md", "code_style.md", "custom.md"},
}

----------------------------------------------------------------------
-- 从单个文件读取 prompt
-- @param filename string: 文件名（相对于 prompts 目录）
-- @return string|nil: 文件内容
----------------------------------------------------------------------
function M.read_file(filename)
  local filepath = get_prompts_dir() .. "/" .. filename
  
  if vim.fn.filereadable(filepath) == 0 then
    return nil
  end
  
  local lines = vim.fn.readfile(filepath)
  return table.concat(lines, "\n")
end

----------------------------------------------------------------------
-- 从多个文件读取并合并 prompt
-- @param filenames table: 文件名列表
-- @param separator string: 分隔符，默认 "\n\n"
-- @return string: 合并后的内容
----------------------------------------------------------------------
function M.from_files(filenames, separator)
  filenames = filenames or {}
  separator = separator or "\n\n"
  
  local parts = {}
  for _, filename in ipairs(filenames) do
    local content = M.read_file(filename)
    if content and content ~= "" then
      table.insert(parts, content)
    end
  end
  
  return table.concat(parts, separator)
end

----------------------------------------------------------------------
-- 获取工具特定的 prompt
-- @param tool string: 工具名称 (opencode/claude_code/avante)
-- @return string: 该工具使用的 prompt
----------------------------------------------------------------------
function M.for_tool(tool)
  local files = M.tool_files[tool]
  if not files or #files == 0 then
    files = M.tool_files.opencode or {}
  end
  return M.from_files(files)
end

----------------------------------------------------------------------
-- 列出所有可用的 prompt 文件
-- @return table: 文件名列表
----------------------------------------------------------------------
function M.list_files()
  local dir = get_prompts_dir()
  local files = {}
  
  if vim.fn.isdirectory(dir) == 0 then
    return files
  end
  
  local all_files = vim.fn.glob(dir .. "/*.md", false, true)
  for _, filepath in ipairs(all_files) do
    local filename = vim.fn.fnamemodify(filepath, ":t")
    table.insert(files, filename)
  end
  
  table.sort(files)
  return files
end

----------------------------------------------------------------------
-- 创建默认 prompt 文件
----------------------------------------------------------------------
function M.ensure_default_files()
  local dir = get_prompts_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  
  -- todo_workflow.md - 基础模版
  local todo_file = dir .. "/todo_workflow.md"
  if vim.fn.filereadable(todo_file) == 0 then
    local content = [[# 任务执行规范

当你接到一个复杂任务时，请严格遵循以下流程：

## 1. 生成 TODO 清单

首先分析任务，拆解为具体步骤，使用以下格式展示：

```markdown
## TODO 清单

- [ ] 步骤1: 具体描述
- [ ] 步骤2: 具体描述
- [ ] 步骤3: 具体描述
```

## 2. 逐步执行

- 按顺序完成每个步骤
- 完成后更新状态：`- [x] 已完成`
- 正在进行的步骤标记：`- [>] 进行中`
- 遇到问题及时说明原因

## 3. 总结反馈

任务完成后提供简要总结：
- 做了哪些修改
- 创建/删除了哪些文件
- 需要注意的事项

---

**重要提示**：即使任务看起来很简单，也请先展示计划，让用户了解你的工作思路。]]
    vim.fn.writefile(vim.split(content, "\n"), todo_file)
  end
  
  -- code_style.md - 代码风格（默认为空，用户可自定义）
  local code_style_file = dir .. "/code_style.md"
  if vim.fn.filereadable(code_style_file) == 0 then
    vim.fn.writefile({}, code_style_file)
  end
  
  -- custom.md - 用户自定义 prompt（默认为空）
  local custom_file = dir .. "/custom.md"
  if vim.fn.filereadable(custom_file) == 0 then
    vim.fn.writefile({}, custom_file)
  end
end

----------------------------------------------------------------------
-- 打开 prompts 目录进行编辑
----------------------------------------------------------------------
function M.edit_prompts()
  M.ensure_default_files()
  local dir = get_prompts_dir()
  vim.cmd("edit " .. dir)
end

----------------------------------------------------------------------
-- 显示所有 prompt 文件状态
----------------------------------------------------------------------
function M.show_status()
  local files = M.list_files()
  local lines = {"Prompt 文件目录: " .. get_prompts_dir(), ""}
  
  if #files == 0 then
    table.insert(lines, "  暂无 prompt 文件")
  else
    table.insert(lines, "可用的 prompt 文件:")
    for _, f in ipairs(files) do
      local content = M.read_file(f) or ""
      local has_content = content ~= "" and "✓ 有内容" or "○ 空文件"
      local in_use = false
      for tool, tool_files in pairs(M.tool_files) do
        for _, tf in ipairs(tool_files) do
          if tf == f then
            in_use = true
            break
          end
        end
      end
      local status = in_use and "●" or "○"
      table.insert(lines, string.format("  %s %-20s %s", status, f, has_content))
    end
  end
  
  table.insert(lines, "")
  table.insert(lines, "各工具配置 (按顺序合并):")
  for tool, tool_files in pairs(M.tool_files) do
    table.insert(lines, string.format("  %s: %s", tool, table.concat(tool_files, " → ")))
  end
  
  table.insert(lines, "")
  table.insert(lines, "提示: 编辑 .md 文件后运行 :AISyncAll 重新生成配置")
  
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

----------------------------------------------------------------------
-- 初始化：确保默认文件存在
----------------------------------------------------------------------
M.ensure_default_files()

return M