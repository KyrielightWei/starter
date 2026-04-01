-- lua/ai/skill_studio/registry.lua
-- 需求注册表管理：索引、同步、部署

local M = {}

-- 本地缓存
local index_cache = nil

----------------------------------------------------------------------
-- 路径配置
----------------------------------------------------------------------
M.paths = {
  base = vim.fn.stdpath("data") .. "/skill_studio",
  requirements = vim.fn.stdpath("data") .. "/skill_studio/requirements",
  generated = vim.fn.stdpath("data") .. "/skill_studio/generated",
  index = vim.fn.stdpath("data") .. "/skill_studio/index.json",
}

-- 同步目标路径
M.sync_targets = {
  project = {
    claude_skills = function()
      return vim.fn.getcwd() .. "/.claude/skills"
    end,
    claude_rules = function()
      return vim.fn.getcwd() .. "/.claude/rules"
    end,
    claude_mcps = function()
      return vim.fn.getcwd() .. "/.claude"
    end,
    opencode = function()
      return vim.fn.getcwd() .. "/.opencode"
    end,
  },
  global = {
    claude_skills = function()
      return vim.fn.expand("~/.claude/skills")
    end,
    claude_rules = function()
      return vim.fn.expand("~/.claude/rules")
    end,
    claude_mcps = function()
      return vim.fn.expand("~/.claude")
    end,
    opencode = function()
      return vim.fn.expand("~/.config/opencode")
    end,
  },
}

----------------------------------------------------------------------
-- 初始化
----------------------------------------------------------------------
---Sanitize name to prevent path traversal
---@param name string
---@return string|nil, string|nil error
local function sanitize_name(name)
  if not name or name == "" then
    return nil, "Name is required"
  end
  if not name:match("^[a-z][a-z0-9-]*$") then
    return nil, "Invalid name format: must be lowercase alphanumeric with hyphens"
  end
  if #name > 64 then
    return nil, "Name too long: max 64 characters"
  end
  -- Check for path traversal attempts
  if name:find("%.%.") or name:find("/") or name:find("\\") then
    return nil, "Invalid characters in name"
  end
  return name
end

function M.setup()
  -- 确保目录存在
  vim.fn.mkdir(M.paths.base, "p")
  vim.fn.mkdir(M.paths.requirements, "p")
  vim.fn.mkdir(M.paths.generated .. "/claude/skills", "p")
  vim.fn.mkdir(M.paths.generated .. "/claude/rules", "p")
  vim.fn.mkdir(M.paths.generated .. "/claude/mcps", "p")
  vim.fn.mkdir(M.paths.generated .. "/opencode/agents", "p")

  -- 加载或初始化索引
  if vim.fn.filereadable(M.paths.index) == 0 then
    M.save_index({ requirements = {} })
  end

  return M
end

----------------------------------------------------------------------
-- 索引操作
----------------------------------------------------------------------
---加载索引
---@return table
function M.load_index()
  if index_cache then
    return index_cache
  end

  if vim.fn.filereadable(M.paths.index) == 0 then
    index_cache = { requirements = {} }
    return index_cache
  end

  local content = table.concat(vim.fn.readfile(M.paths.index), "\n")
  local ok, data = pcall(vim.json.decode, content)
  if ok and type(data) == "table" then
    index_cache = data
    return index_cache
  end

  index_cache = { requirements = {} }
  return index_cache
end

---保存索引
---@param index table
function M.save_index(index)
  index_cache = index
  local content = vim.json.encode(index)
  vim.fn.writefile(vim.split(content, "\n"), M.paths.index)
end

---获取单个需求
---@param name string
---@return table|nil
function M.get_requirement(name)
  local index = M.load_index()
  return index.requirements[name]
end

---设置需求
---@param name string
---@param data table
function M.set_requirement(name, data)
  local index = M.load_index()
  index.requirements[name] = data
  M.save_index(index)
end

---删除需求
---@param name string
function M.delete_requirement(name)
  local sanitized = sanitize_name(name)
  if not sanitized then
    vim.notify("Invalid name: " .. name, vim.log.levels.ERROR)
    return
  end

  local index = M.load_index()
  index.requirements[sanitized] = nil
  M.save_index(index)

  -- 删除需求文件
  local req_file = M.paths.requirements .. "/" .. sanitized .. ".req.md"
  if vim.fn.filereadable(req_file) == 1 then
    vim.fn.delete(req_file)
  end
end

---列出所有需求
---@return table
function M.list_requirements()
  local index = M.load_index()
  local result = {}

  for name, data in pairs(index.requirements) do
    table.insert(result, vim.tbl_extend("force", { name = name }, data))
  end

  -- 按更新时间排序
  table.sort(result, function(a, b)
    return (a.updated_at or "") > (b.updated_at or "")
  end)

  return result
end

----------------------------------------------------------------------
-- 需求文件操作
----------------------------------------------------------------------
---读取需求文件内容
---@param name string
---@return string|nil
function M.read_requirement_file(name)
  local sanitized = sanitize_name(name)
  if not sanitized then
    return nil
  end
  local req_file = M.paths.requirements .. "/" .. sanitized .. ".req.md"
  if vim.fn.filereadable(req_file) == 0 then
    return nil
  end
  return table.concat(vim.fn.readfile(req_file), "\n")
end

---写入需求文件
---@param name string
---@param content string
function M.write_requirement_file(name, content)
  local sanitized = sanitize_name(name)
  if not sanitized then
    vim.notify("Invalid name: " .. name, vim.log.levels.ERROR)
    return
  end
  local req_file = M.paths.requirements .. "/" .. sanitized .. ".req.md"
  vim.fn.writefile(vim.split(content, "\n"), req_file)
end

---创建新需求
---@param name string
---@param opts table
---@return boolean
function M.create_requirement(name, opts)
  opts = opts or {}

  -- 验证名称
  local sanitized = sanitize_name(name)
  if not sanitized then
    vim.notify("Invalid name: " .. name, vim.log.levels.ERROR)
    return false
  end

  -- 检查是否已存在
  if M.get_requirement(sanitized) then
    vim.notify("Requirement already exists: " .. sanitized, vim.log.levels.WARN)
    return false
  end

  local now = os.date("%Y-%m-%dT%H:%M:%S")
  local data = {
    file = "requirements/" .. sanitized .. ".req.md",
    type = opts.type or "skill",
    created_at = now,
    updated_at = now,
    sync = {
      enabled = false,
      target = nil,
      path = nil,
    },
    versions = {
      claude = {
        generated = false,
        path = nil,
        deployed = false,
        last_validated = nil,
      },
      opencode = {
        generated = false,
        path = nil,
        deployed = false,
      },
    },
  }

  M.set_requirement(name, data)
  return true
end

----------------------------------------------------------------------
-- 同步操作
----------------------------------------------------------------------
---启用同步
---@param name string
---@param target string "project" | "global"
---@return boolean
function M.enable_sync(name, target)
  local req = M.get_requirement(name)
  if not req then
    vim.notify("Requirement not found: " .. name, vim.log.levels.ERROR)
    return false
  end

  req.sync = {
    enabled = true,
    target = target,
    path = M.get_sync_path(name, req.type, target),
  }
  req.updated_at = os.date("%Y-%m-%dT%H:%M:%S")
  M.set_requirement(name, req)

  -- 如果已有生成版本，执行同步
  if req.versions.claude.generated then
    M.sync_to_target(name, "claude")
  end
  if req.versions.opencode.generated then
    M.sync_to_target(name, "opencode")
  end

  return true
end

---禁用同步
---@param name string
---@return boolean
function M.disable_sync(name)
  local req = M.get_requirement(name)
  if not req then
    return false
  end

  req.sync.enabled = false
  req.sync.target = nil
  req.updated_at = os.date("%Y-%m-%dT%H:%M:%S")
  M.set_requirement(name, req)
  return true
end

---获取同步路径
---@param name string
---@param type string
---@param target string
---@return string
function M.get_sync_path(name, type, target)
  local target_paths = M.sync_targets[target]
  if not target_paths then
    return nil
  end

  if type == "skill" then
    return target_paths.claude_skills() .. "/" .. name
  elseif type == "rule" then
    return target_paths.claude_rules() .. "/" .. name
  elseif type == "mcp" then
    return target_paths.claude_mcps()
  elseif type == "command" then
    return target_paths.claude_skills() .. "/" .. name
  end

  return nil
end

---同步到目标
---@param name string
---@param platform string "claude" | "opencode"
---@return boolean
function M.sync_to_target(name, platform)
  local req = M.get_requirement(name)
  if not req or not req.sync.enabled then
    return false
  end

  local version = req.versions[platform]
  if not version or not version.generated then
    vim.notify("No generated version for " .. platform, vim.log.levels.WARN)
    return false
  end

  local source_path = M.paths.generated .. "/" .. version.path
  if vim.fn.filereadable(source_path) == 0 then
    vim.notify("Generated file not found: " .. source_path, vim.log.levels.ERROR)
    return false
  end

  -- 确定目标路径
  local target_path
  if platform == "claude" then
    target_path = M.get_sync_path(name, req.type, req.sync.target)
  else
    target_path = M.sync_targets[req.sync.target].opencode()
  end

  if not target_path then
    return false
  end

  -- 确保目标目录存在
  local target_dir = vim.fn.fnamemodify(target_path, ":h")
  vim.fn.mkdir(target_dir, "p")

  -- 复制文件
  if req.type == "skill" then
    vim.fn.mkdir(target_path, "p")
    vim.fn.system("cp " .. vim.fn.shellescape(source_path) .. " " .. vim.fn.shellescape(target_path .. "/SKILL.md"))
  elseif req.type == "rule" then
    vim.fn.mkdir(target_path, "p")
    vim.fn.system("cp " .. vim.fn.shellescape(source_path) .. " " .. vim.fn.shellescape(target_path .. "/RULE.md"))
  elseif req.type == "mcp" then
    -- MCP 合并到 .mcp.json
    M.merge_mcp_config(target_path, source_path)
  else
    vim.fn.system("cp " .. vim.fn.shellescape(source_path) .. " " .. vim.fn.shellescape(target_path))
  end

  -- 更新状态
  version.deployed = true
  M.set_requirement(name, req)

  vim.notify("Synced " .. name .. " to " .. req.sync.target, vim.log.levels.INFO)
  return true
end

---合并 MCP 配置
---@param target_path string
---@param source_path string
function M.merge_mcp_config(target_path, source_path)
  local mcp_file = target_path .. "/.mcp.json"

  -- 读取源配置
  local source_content = table.concat(vim.fn.readfile(source_path), "\n")
  local ok, source_config = pcall(vim.json.decode, source_content)
  if not ok then
    source_config = {}
  end

  -- 读取目标配置
  local target_config = {}
  if vim.fn.filereadable(mcp_file) == 1 then
    local target_content = table.concat(vim.fn.readfile(mcp_file), "\n")
    local ok2, decoded = pcall(vim.json.decode, target_content)
    if ok2 then
      target_config = decoded
    end
  end

  -- 合并 mcpServers
  target_config.mcpServers = target_config.mcpServers or {}
  for name, config in pairs(source_config.mcpServers or {}) do
    target_config.mcpServers[name] = config
  end

  -- 写入
  local content = vim.json.encode(target_config)
  vim.fn.writefile(vim.split(content, "\n"), mcp_file)
end

----------------------------------------------------------------------
-- 版本管理
----------------------------------------------------------------------
---更新版本状态
---@param name string
---@param platform string
---@param status table
function M.update_version_status(name, platform, status)
  local req = M.get_requirement(name)
  if not req then
    return
  end

  req.versions[platform] = vim.tbl_extend("force", req.versions[platform] or {}, status)
  req.updated_at = os.date("%Y-%m-%dT%H:%M:%S")
  M.set_requirement(name, req)
end

---获取生成的文件路径
---@param name string
---@param type string
---@param platform string
---@return string
function M.get_generated_path(name, type, platform)
  if platform == "claude" then
    if type == "skill" then
      return "claude/skills/" .. name .. "/SKILL.md"
    elseif type == "rule" then
      return "claude/rules/" .. name .. "/RULE.md"
    elseif type == "mcp" then
      return "claude/mcps/" .. name .. ".json"
    elseif type == "command" then
      return "claude/commands/" .. name .. ".md"
    end
  elseif platform == "opencode" then
    return "opencode/agents/" .. name .. ".md"
  end
  return nil
end

----------------------------------------------------------------------
-- 扫描已部署的内容
----------------------------------------------------------------------
---扫描 Claude 已部署的 skills
---@return table
function M.scan_claude_skills()
  local result = {}
  local paths = {
    { path = vim.fn.getcwd() .. "/.claude/skills", scope = "project" },
    { path = vim.fn.expand("~/.claude/skills"), scope = "global" },
  }

  for _, p in ipairs(paths) do
    if vim.fn.isdirectory(p.path) == 1 then
      local dirs = vim.fn.readdir(p.path)
      for _, dir in ipairs(dirs) do
        local skill_file = p.path .. "/" .. dir .. "/SKILL.md"
        if vim.fn.filereadable(skill_file) == 1 then
          table.insert(result, {
            name = dir,
            type = "skill",
            platform = "claude",
            scope = p.scope,
            path = skill_file,
          })
        end
      end
    end
  end

  return result
end

---扫描 Claude 已部署的 rules
---@return table
function M.scan_claude_rules()
  local result = {}
  local paths = {
    { path = vim.fn.getcwd() .. "/.claude/rules", scope = "project" },
    { path = vim.fn.expand("~/.claude/rules"), scope = "global" },
  }

  for _, p in ipairs(paths) do
    if vim.fn.isdirectory(p.path) == 1 then
      local files = vim.fn.readdir(p.path)
      for _, file in ipairs(files) do
        if file:match("%.md$") then
          table.insert(result, {
            name = file:gsub("%.md$", ""),
            type = "rule",
            platform = "claude",
            scope = p.scope,
            path = p.path .. "/" .. file,
          })
        end
      end
    end
  end

  return result
end

---扫描 Claude 已配置的 MCPs
---@return table
function M.scan_claude_mcps()
  local result = {}
  local paths = {
    { path = vim.fn.getcwd() .. "/.claude/.mcp.json", scope = "project" },
    { path = vim.fn.expand("~/.claude/.mcp.json"), scope = "global" },
  }

  for _, p in ipairs(paths) do
    if vim.fn.filereadable(p.path) == 1 then
      local content = table.concat(vim.fn.readfile(p.path), "\n")
      local ok, config = pcall(vim.json.decode, content)
      if ok and config.mcpServers then
        for name, server_config in pairs(config.mcpServers) do
          table.insert(result, {
            name = name,
            type = "mcp",
            platform = "claude",
            scope = p.scope,
            path = p.path,
            config = server_config,
          })
        end
      end
    end
  end

  return result
end

---扫描 OpenCode 已配置的 agents
---@return table
function M.scan_opencode_agents()
  local result = {}
  local paths = {
    { path = vim.fn.getcwd() .. "/.opencode/opencode.json", scope = "project" },
    { path = vim.fn.expand("~/.config/opencode/opencode.json"), scope = "global" },
  }

  for _, p in ipairs(paths) do
    if vim.fn.filereadable(p.path) == 1 then
      local content = table.concat(vim.fn.readfile(p.path), "\n")
      local ok, config = pcall(vim.json.decode, content)
      if ok and config.agents then
        for name, agent_config in pairs(config.agents) do
          table.insert(result, {
            name = name,
            type = "agent",
            platform = "opencode",
            scope = p.scope,
            path = p.path,
            config = agent_config,
          })
        end
      end
    end
  end

  return result
end

---获取所有已部署的内容
---@return table
function M.get_all_deployed()
  local result = {}

  vim.list_extend(result, M.scan_claude_skills())
  vim.list_extend(result, M.scan_claude_rules())
  vim.list_extend(result, M.scan_claude_mcps())
  vim.list_extend(result, M.scan_opencode_agents())

  return result
end

return M
