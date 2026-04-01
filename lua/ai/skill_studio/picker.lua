-- lua/ai/skill_studio/picker.lua
-- FZF Pickers：需求列表、已部署内容列表

local M = {}

local Registry = require("ai.skill_studio.registry")
local Generator = require("ai.skill_studio.generator")
local Templates = require("ai.skill_studio.templates")
local Extractor = require("ai.skill_studio.extractor")

----------------------------------------------------------------------
-- 状态图标定义
----------------------------------------------------------------------
M.icons = {
  sync_enabled = "✓",
  sync_disabled = "✗",
  generated = "✓",
  not_generated = "✗",
  deployed = "✓",
  not_deployed = "✗",

  types = {
    skill = "⚡",
    rule = "📜",
    mcp = "🔌",
    command = "⌨",
    agent = "🤖",
  },

  platforms = {
    claude = "C",
    opencode = "O",
  },

  scopes = {
    project = "P",
    global = "G",
  },
}

----------------------------------------------------------------------
-- 格式化函数
----------------------------------------------------------------------
---格式化需求列表项
---@param req table
---@return string display, string ordinal
function M.format_requirement_item(req)
  local sync_icon = req.sync and req.sync.enabled and M.icons.sync_enabled or M.icons.sync_disabled

  local type_icon = M.icons.types[req.type] or M.icons.types.skill

  -- Claude 版本状态
  local claude_icon = M.icons.not_generated
  if req.versions and req.versions.claude then
    if req.versions.claude.generated then
      claude_icon = req.versions.claude.deployed and M.icons.deployed or M.icons.generated
    end
  end

  -- OpenCode 版本状态
  local opencode_icon = M.icons.not_generated
  if req.versions and req.versions.opencode then
    if req.versions.opencode.generated then
      opencode_icon = req.versions.opencode.deployed and M.icons.deployed or M.icons.generated
    end
  end

  local display = string.format("[%s] %s %s [C:%s] [O:%s]", sync_icon, type_icon, req.name, claude_icon, opencode_icon)

  -- 用于排序的字符串
  local ordinal = req.name

  return display, ordinal
end

---格式化已部署内容列表项
---@param item table
---@return string display, string ordinal
function M.format_deployed_item(item)
  local platform_icon = M.icons.platforms[item.platform] or "?"
  local scope_icon = M.icons.scopes[item.scope] or "?"
  local type_icon = M.icons.types[item.type] or "?"

  local display = string.format("[%s/%s] %s: %s", platform_icon, scope_icon, type_icon, item.name)
  local ordinal = item.name

  return display, ordinal
end

----------------------------------------------------------------------
-- 需求 Picker
----------------------------------------------------------------------
---打开需求列表 Picker
function M.open_requirements_picker()
  -- 检查 fzf 是否可用
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not available", vim.log.levels.ERROR)
    return
  end

  -- 加载需求列表
  local requirements = Registry.list_requirements()

  -- 构建显示列表
  local items = {}
  for _, req in ipairs(requirements) do
    local display, ordinal = M.format_requirement_item(req)
    items[display] = req
  end

  -- 显示 picker
  fzf.fzf_contents("Skill Studio - Requirements", function(fzf_cb)
    for display, req in pairs(items) do
      fzf_cb(display)
    end
    fzf_cb()
  end, {
    actions = {
      -- <CR> 编辑
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local req = items[selected[1]]
        M.edit_requirement(req.name)
      end,

      -- <C-s> 切换同步
      ["ctrl-s"] = function(selected)
        if not selected then
          return
        end
        local req = items[selected[1]]
        M.toggle_sync(req.name)
      end,

      -- <C-g> 生成
      ["ctrl-g"] = function(selected)
        if not selected then
          return
        end
        local req = items[selected[1]]
        M.generate_requirement(req.name)
      end,

      -- <C-d> 部署
      ["ctrl-d"] = function(selected)
        if not selected then
          return
        end
        local req = items[selected[1]]
        M.deploy_requirement(req.name)
      end,

      -- <C-v> 查看生成
      ["ctrl-v"] = function(selected)
        if not selected then
          return
        end
        local req = items[selected[1]]
        M.view_generated(req.name)
      end,

      -- <C-x> 删除
      ["ctrl-x"] = function(selected)
        if not selected then
          return
        end
        local req = items[selected[1]]
        M.delete_requirement(req.name)
      end,

      -- <C-n> 新建
      ["ctrl-n"] = function()
        M.new_requirement_picker()
      end,

      -- <C-e> 从已部署提取
      ["ctrl-e"] = function()
        M.extract_from_deployed_picker()
      end,

      -- <C-?> 帮助
      ["ctrl-/"] = function()
        M.show_requirements_help()
      end,
    },

    -- 显示帮助信息
    fzf_opts = {
      ["--header"] = "Actions: <CR>编辑 <C-s>同步 <C-g>生成 <C-d>部署 <C-v>查看 <C-x>删除 <C-n>新建 <C-e>提取 <C-?>帮助",
    },
  })
end

----------------------------------------------------------------------
-- 已部署 Picker
----------------------------------------------------------------------
---打开已部署内容 Picker
function M.open_deployed_picker()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not available", vim.log.levels.ERROR)
    return
  end

  -- 加载已部署内容
  local deployed = Registry.get_all_deployed()

  -- 构建显示列表
  local items = {}
  for _, item in ipairs(deployed) do
    local display, ordinal = M.format_deployed_item(item)
    items[display] = item
  end

  -- 显示 picker
  fzf.fzf_contents("Skill Studio - Deployed", function(fzf_cb)
    for display, item in pairs(items) do
      fzf_cb(display)
    end
    fzf_cb()
  end, {
    actions = {
      -- <CR> 查看
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        M.view_deployed(item.path)
      end,

      -- <C-e> 编辑
      ["ctrl-e"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        M.edit_deployed(item.path)
      end,

      -- <C-r> 重新生成
      ["ctrl-r"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        -- 查找对应需求并重新生成
        local req = Registry.get_requirement(item.name)
        if req then
          M.generate_requirement(item.name)
        else
          vim.notify("No requirement found for: " .. item.name, vim.log.levels.WARN)
        end
      end,

      -- <C-u> 更新需求（提取）
      ["ctrl-u"] = function(selected)
        if not selected then
          return
        end
        local item = items[selected[1]]
        M.extract_and_update_requirement(item)
      end,

      -- <C-?> 帮助
      ["ctrl-/"] = function()
        M.show_deployed_help()
      end,
    },

    fzf_opts = {
      ["--header"] = "Actions: <CR>查看 <C-e>编辑 <C-r>重新生成 <C-u>更新需求 <C-?>帮助",
    },
  })
end

----------------------------------------------------------------------
-- 新建需求 Picker
----------------------------------------------------------------------
---打开新建需求类型选择
function M.new_requirement_picker()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not available", vim.log.levels.ERROR)
    return
  end

  local types = { "skill", "rule", "command", "mcp" }
  local targets = { "claude", "opencode" }

  -- 先选择类型
  fzf.fzf_contents("New Requirement - Type", function(fzf_cb)
    for _, t in ipairs(types) do
      local icon = M.icons.types[t] or "?"
      fzf_cb(icon .. " " .. t)
    end
    fzf_cb()
  end, {
    actions = {
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local type = vim.trim(selected[1]:gsub("[^a-z]", ""))

        -- 选择目标平台
        M.select_target_picker(type)
      end,
    },
  })
end

---选择目标平台
---@param type string
function M.select_target_picker(type)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return
  end

  local targets = { "claude", "opencode" }

  fzf.fzf_contents("New Requirement - Target", function(fzf_cb)
    for _, t in ipairs(targets) do
      local icon = M.icons.platforms[t] or "?"
      fzf_cb(icon .. " " .. t)
    end
    fzf_cb()
  end, {
    actions = {
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local target = vim.trim(selected[1]:gsub("[^a-z]", ""))

        -- 输入名称
        M.input_name_picker(type, target)
      end,
    },
  })
end

---输入需求名称
---@param type string
---@param target string
function M.input_name_picker(type, target)
  vim.ui.input({ prompt = "Requirement name: " }, function(name)
    if not name or name == "" then
      return
    end

    -- 验证名称格式
    if not name:match("^[a-z][a-z0-9-]*$") then
      vim.notify("Name must be kebab-case (lowercase, numbers, dashes)", vim.log.levels.ERROR)
      return
    end

    -- 创建需求
    M.create_new_requirement(name, type, target)
  end)
end

---创建新需求
---@param name string
---@param type string
---@param target string
function M.create_new_requirement(name, type, target)
  -- 创建需求记录
  local ok = Registry.create_requirement(name, { type = type })
  if not ok then
    vim.notify("Requirement already exists: " .. name, vim.log.levels.WARN)
    return
  end

  -- 获取空模板
  local template = Templates.get_empty_requirement(type, target)
  template.name = name

  -- 保存模板内容
  local content = Templates.format_requirement_markdown(template)
  Registry.write_requirement_file(name, content)

  -- 打开编辑
  M.edit_requirement(name)

  vim.notify("Created new requirement: " .. name, vim.log.levels.INFO)
end

----------------------------------------------------------------------
-- 提取 Picker
----------------------------------------------------------------------
---从已部署内容提取需求 Picker
function M.extract_from_deployed_picker()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return
  end

  local scopes = { "project", "global", "all" }

  fzf.fzf_contents("Extract from Deployed - Scope", function(fzf_cb)
    for _, scope in ipairs(scopes) do
      local icon = M.icons.scopes[scope] or "?"
      fzf_cb(icon .. " " .. scope)
    end
    fzf_cb()
  end, {
    actions = {
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local scope = vim.trim(selected[1]:gsub("[^a-z]", ""))

        -- 执行提取
        local extracted = Extractor.extract_all_from_deployed(scope ~= "all" and scope or nil)

        if #extracted == 0 then
          vim.notify("No items extracted", vim.log.levels.WARN)
          return
        end

        -- 保存提取的需求
        for _, req in ipairs(extracted) do
          local ok2, err = Extractor.save_extracted_requirement(req)
          if not ok2 then
            vim.notify("Save error: " .. err, vim.log.levels.WARN)
          end
        end

        vim.notify("Extracted " .. #extracted .. " requirements", vim.log.levels.INFO)

        -- 刷新需求列表
        M.open_requirements_picker()
      end,
    },
  })
end

----------------------------------------------------------------------
-- 操作函数
----------------------------------------------------------------------
---编辑需求
---@param name string
function M.edit_requirement(name)
  local content = Registry.read_requirement_file(name)
  if not content then
    vim.notify("Requirement file not found: " .. name, vim.log.levels.ERROR)
    return
  end

  -- 在新 buffer 中打开
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.api.nvim_buf_set_name(buf, name .. ".req.md")
  vim.api.nvim_win_set_buf(0, buf)

  -- 设置为 markdown
  vim.bo[buf].filetype = "markdown"

  -- 保存回调
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local new_content = table.concat(lines, "\n")
      Registry.write_requirement_file(name, new_content)

      -- 更新时间戳
      local req = Registry.get_requirement(name)
      req.updated_at = os.date("%Y-%m-%dT%H:%M:%S")
      Registry.set_requirement(name, req)

      vim.notify("Saved requirement: " .. name, vim.log.levels.INFO)
    end,
  })
end

---切换同步状态
---@param name string
function M.toggle_sync(name)
  local req = Registry.get_requirement(name)
  if not req then
    return
  end

  if req.sync and req.sync.enabled then
    -- 禁用同步
    Registry.disable_sync(name)
    vim.notify("Sync disabled for: " .. name, vim.log.levels.INFO)
  else
    -- 选择同步目标
    local ok, fzf = pcall(require, "fzf-lua")
    if not ok then
      return
    end

    fzf.fzf_contents("Sync Target", function(fzf_cb)
      fzf_cb("project")
      fzf_cb("global")
      fzf_cb()
    end, {
      actions = {
        ["enter"] = function(selected)
          if not selected then
            return
          end
          local target = selected[1]
          Registry.enable_sync(name, target)
          vim.notify("Sync enabled for " .. name .. " to " .. target, vim.log.levels.INFO)
        end,
      },
    })
  end
end

---生成需求
---@param name string
function M.generate_requirement(name)
  local req = Registry.get_requirement(name)
  if not req then
    return
  end

  -- 选择平台
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return
  end

  fzf.fzf_contents("Generate for Platform", function(fzf_cb)
    fzf_cb(M.icons.platforms.claude .. " claude")
    fzf_cb(M.icons.platforms.opencode .. " opencode")
    fzf_cb()
  end, {
    actions = {
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local platform = vim.trim(selected[1]:gsub("[^a-z]", ""))

        -- 选择后端
        M.select_backend_picker(name, platform)
      end,
    },
  })
end

---选择 AI 后端
---@param name string
---@param platform string
function M.select_backend_picker(name, platform)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return
  end

  local backends = { "avante", "opencode", "claude" }

  fzf.fzf_contents("Select AI Backend", function(fzf_cb)
    for _, backend in ipairs(backends) do
      fzf_cb(backend)
    end
    fzf_cb()
  end, {
    actions = {
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local backend = selected[1]

        -- 执行生成
        local ok2, result = Generator.generate(name, {
          platform = platform,
          backend = backend,
        })

        if not ok2 then
          vim.notify("Generate failed: " .. result, vim.log.levels.ERROR)
        else
          vim.notify("Generated: " .. result, vim.log.levels.INFO)
        end
      end,
    },
  })
end

---部署需求
---@param name string
function M.deploy_requirement(name)
  local req = Registry.get_requirement(name)
  if not req then
    return
  end

  -- 选择平台
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return
  end

  fzf.fzf_contents("Deploy to Platform", function(fzf_cb)
    fzf_cb(M.icons.platforms.claude .. " claude")
    if req.type ~= "mcp" then
      fzf_cb(M.icons.platforms.opencode .. " opencode")
    end
    fzf_cb()
  end, {
    actions = {
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local platform = vim.trim(selected[1]:gsub("[^a-z]", ""))

        local ok2 = Registry.sync_to_target(name, platform)
        if ok2 then
          vim.notify("Deployed " .. name .. " to " .. platform, vim.log.levels.INFO)
        else
          vim.notify("Deploy failed", vim.log.levels.ERROR)
        end
      end,
    },
  })
end

---查看生成的文件
---@param name string
function M.view_generated(name)
  local req = Registry.get_requirement(name)
  if not req then
    return
  end

  -- 选择版本查看
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return
  end

  fzf.fzf_contents("View Generated Version", function(fzf_cb)
    if req.versions.claude and req.versions.claude.generated then
      fzf_cb(M.icons.platforms.claude .. " claude")
    end
    if req.versions.opencode and req.versions.opencode.generated then
      fzf_cb(M.icons.platforms.opencode .. " opencode")
    end
    fzf_cb()
  end, {
    actions = {
      ["enter"] = function(selected)
        if not selected then
          return
        end
        local platform = vim.trim(selected[1]:gsub("[^a-z]", ""))

        local version = req.versions[platform]
        if not version or not version.path then
          vim.notify("No generated version for " .. platform, vim.log.levels.WARN)
          return
        end

        local path = Registry.paths.generated .. "/" .. version.path
        if vim.fn.filereadable(path) == 0 then
          vim.notify("File not found: " .. path, vim.log.levels.ERROR)
          return
        end

        vim.cmd("edit " .. vim.fn.fnameescape(path))
      end,
    },
  })
end

---删除需求
---@param name string
function M.delete_requirement(name)
  vim.ui.input({ prompt = "Delete requirement " .. name .. "? (y/n): " }, function(answer)
    if answer == "y" then
      Registry.delete_requirement(name)
      vim.notify("Deleted requirement: " .. name, vim.log.levels.INFO)
    end
  end)
end

---查看已部署文件
---@param path string
function M.view_deployed(path)
  if vim.fn.filereadable(path) == 0 then
    vim.notify("File not found: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

---编辑已部署文件
---@param path string
function M.edit_deployed(path)
  M.view_deployed(path)
end

---提取并更新需求
---@param item table
function M.extract_and_update_requirement(item)
  local requirement, err = Extractor.extract(item.path)
  if err then
    vim.notify("Extract failed: " .. err, vim.log.levels.ERROR)
    return
  end

  if requirement then
    requirement.name = item.name
    local ok2, err2 = Extractor.save_extracted_requirement(requirement)
    if ok2 then
      vim.notify("Updated requirement: " .. item.name, vim.log.levels.INFO)
    else
      vim.notify("Save failed: " .. err2, vim.log.levels.ERROR)
    end
  end
end

----------------------------------------------------------------------
-- 帮助屏幕
----------------------------------------------------------------------
---显示需求 Picker 帮助
function M.show_requirements_help()
  local help_text = [[
Skill Studio - Requirements Picker Help

Keymaps:
  <CR>      Edit requirement file
  <C-s>     Toggle sync (enable/disable)
  <C-g>     Generate for platform (select AI backend)
  <C-d>     Deploy to platform
  <C-v>     View generated version
  <C-x>     Delete requirement
  <C-n>     Create new requirement
  <C-e>     Extract from deployed content
  <C-?>     Show this help

Status Icons:
  ✓ = Enabled/Generated/Deployed
  ✗ = Disabled/Not Generated

Type Icons:
  ⚡ = Skill
  📜 = Rule
  🔌 = MCP
  ⌨ = Command

Platform Icons:
  C = Claude
  O = OpenCode
]]

  -- 显示在浮动窗口
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(help_text, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "help")

  local width = 60
  local height = 30
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- 按 q 关闭
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

---显示已部署 Picker 帮助
function M.show_deployed_help()
  local help_text = [[
Skill Studio - Deployed Picker Help

Keymaps:
  <CR>      View deployed file
  <C-e>     Edit deployed file
  <C-r>     Regenerate from requirement
  <C-u>     Extract and update requirement
  <C-?>     Show this help

Status Icons:
  [P/G] = Project/Global scope
  [C/O] = Claude/OpenCode platform

Type Icons:
  ⚡ = Skill
  📜 = Rule
  🔌 = MCP
  🤖 = Agent
]]

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(help_text, "\n"))
  vim.api.nvim_buf_set_option(buf, "filetype", "help")

  local width = 50
  local height = 20
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

----------------------------------------------------------------------
-- 配置
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}
  M.icons = vim.tbl_extend("force", M.icons, opts.icons or {})
  return M
end

return M
