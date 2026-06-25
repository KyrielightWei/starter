-- lua/ai_review/config.lua
-- AI Review 配置模块
-- 管理文件过滤、默认行为等可配置项

local M = {}

----------------------------------------------------------------------
-- 默认排除的文件/目录模式（Lua pattern 语法）
-- 用户可通过 M.set_exclude_patterns() 完全覆盖
-- 或通过 M.add_exclude_pattern() / M.remove_exclude_pattern() 增删
----------------------------------------------------------------------
M.default_exclude_patterns = {
  -- AI 工具配置目录
  ".claude",
  ".pi",
  ".codex",
  ".qoder",
  ".opencode",
  ".agents",
  ".ai-review",

  -- 规划/文档目录
  "openspec",
  ".planning",
  "docs",
  "reviews",

  -- 基础设施/配置
  "docker_file",
  "shell_config",
  "prompts",
  "skill",

  -- 锁文件/元数据
  "lazy-lock.json",
  "lazyvim.json",
  ".neoconf.json",

  -- 文档文件
  "AGENTS.md",
  "CLAUDE.md",
  "ECC_GUIDE.md",
  "OPENCODE_BEAUTIFICATION.md",
  "progress.md",
  "README.md",

  -- 测试脚本
  "test_*.js",
  "test_*.sh",
  "start-*.sh",

  -- AI 工具生成的临时文件
  "review_snippet_*.cpp",
  "review_snippet_*.h",
}

-- 当前生效的排除模式（初始为默认值的副本）
M._exclude_patterns = vim.deepcopy(M.default_exclude_patterns)

----------------------------------------------------------------------
-- get_exclude_patterns(): 获取当前排除模式列表
----------------------------------------------------------------------
function M.get_exclude_patterns()
  return M._exclude_patterns
end

----------------------------------------------------------------------
-- set_exclude_patterns(patterns): 完全覆盖排除模式
-- @param patterns table: 新的模式列表
----------------------------------------------------------------------
function M.set_exclude_patterns(patterns)
  if type(patterns) ~= "table" then
    vim.notify("exclude_patterns must be a table", vim.log.levels.ERROR)
    return
  end
  M._exclude_patterns = vim.deepcopy(patterns)
end

----------------------------------------------------------------------
-- add_exclude_pattern(pattern): 添加单个排除模式
-- @param pattern string: Lua pattern
----------------------------------------------------------------------
function M.add_exclude_pattern(pattern)
  if type(pattern) ~= "string" or pattern == "" then
    vim.notify("pattern must be a non-empty string", vim.log.levels.ERROR)
    return
  end
  -- #5 修复: 验证模式不包含危险字符（防止 shell 注入）
  if pattern:match("[';|&`$%(%){}!<>%c]") then
    vim.notify("排除模式包含不安全字符: " .. pattern, vim.log.levels.ERROR)
    return
  end
  -- 验证转换后的 pattern 是否为合法 Lua pattern
  local test_pattern = pattern:gsub("([%.%+%-%?%[%]%(%)%^%$%%])", "%%%1"):gsub("%*", ".*")
  local ok, err = pcall(string.match, "test", "^" .. test_pattern .. "$")
  if not ok then
    vim.notify("排除模式无效 (" .. tostring(err) .. "): " .. pattern, vim.log.levels.ERROR)
    return
  end
  -- 避免重复
  for _, p in ipairs(M._exclude_patterns) do
    if p == pattern then
      return
    end
  end
  table.insert(M._exclude_patterns, pattern)
end

----------------------------------------------------------------------
-- remove_exclude_pattern(pattern): 移除单个排除模式
-- @param pattern string: 要移除的模式
-- @return boolean: 是否成功移除
----------------------------------------------------------------------
function M.remove_exclude_pattern(pattern)
  for i, p in ipairs(M._exclude_patterns) do
    if p == pattern then
      table.remove(M._exclude_patterns, i)
      return true
    end
  end
  return false
end

----------------------------------------------------------------------
-- reset_exclude_patterns(): 重置为默认模式
----------------------------------------------------------------------
function M.reset_exclude_patterns()
  M._exclude_patterns = vim.deepcopy(M.default_exclude_patterns)
end

----------------------------------------------------------------------
-- is_excluded(file_path): 判断文件是否应被排除
-- @param file_path string: 文件路径（相对于仓库根目录）
-- @return boolean
--
-- Pattern 语法说明:
--   - 使用 Lua pattern 语法，非 glob
--   - `*` 会被转换为 `.*`（匹配任意字符序列）
--   - 不支持 `**`（递归目录匹配）
--   - 精确匹配文件名（如 `CLAUDE.md`）
--   - 目录前缀匹配（如 `.claude` 匹配 `.claude/settings.json`）
--   - 特殊字符 `. + - ? [ ] ( ) ^ $ %` 会自动转义
----------------------------------------------------------------------
function M.is_excluded(file_path)
  if not file_path or file_path == "" then
    return false
  end
  for _, pattern in ipairs(M._exclude_patterns) do
    -- 转换为 Lua pattern：转义特殊字符，* -> .*
    local lua_pattern = pattern:gsub("([%.%+%-%?%[%]%(%)%^%$%%])", "%%%1"):gsub("%*", ".*")
    -- 精确匹配文件名（如 CLAUDE.md）
    if file_path:match("^" .. lua_pattern .. "$") then
      return true
    end
    -- 目录前缀匹配（如 .claude → 匹配 .claude/settings.json）
    if file_path:match("^" .. lua_pattern .. "/") then
      return true
    end
  end
  return false
end

return M
