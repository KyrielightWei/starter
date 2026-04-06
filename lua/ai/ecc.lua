-- lua/ai/ecc.lua
-- ECC (Everything Claude Code) 框架安装管理

local M = {}

-- ECC 安装状态文件路径
local ECC_STATE_PATH = "~/.claude/ecc/install-state.json"
-- ECC 源仓库
local ECC_REPO = "https://github.com/affaan-m/everything-claude-code.git"
-- 临时克隆目录
local ECC_TEMP_DIR = "/tmp/ecc-install"
-- 有效的安装目标和 profile
local VALID_TARGETS = { claude = true, opencode = true }
local VALID_PROFILES = { core = true, developer = true, security = true, research = true, full = true }

--- 获取 ECC 安装状态
--- @return table|nil 安装状态信息，未安装时返回 nil
function M.get_status()
  local state_path = vim.fn.expand(ECC_STATE_PATH)
  if vim.fn.filereadable(state_path) == 0 then
    return nil
  end

  local ok, content = pcall(vim.fn.readfile, state_path)
  if not ok then
    return nil
  end

  local json_str = table.concat(content, "\n")
  local ok2, state = pcall(vim.json.decode, json_str)
  if not ok2 then
    return nil
  end

  return {
    installed_at = state.installedAt,
    modules = (state.resolution or {}).selectedModules or {},
    schema_version = state.schemaVersion,
    repo_version = (state.source or {}).repoVersion,
  }
end

--- 检测 ECC 是否已安装
--- @return boolean
function M.is_installed()
  local state_path = vim.fn.expand(ECC_STATE_PATH)
  return vim.fn.filereadable(state_path) == 1
end

--- 获取安装命令提示
--- @return string
function M.install_hint()
  return "git clone "
    .. ECC_REPO
    .. " /tmp/ecc --depth=1 && cd /tmp/ecc && npm install && node scripts/install-apply.js --profile developer"
end

--- 获取 ECC 状态路径
--- @return string
function M.state_path()
  return vim.fn.expand(ECC_STATE_PATH)
end

--- 格式化 ECC 状态通知行
--- @param ecc table|nil ECC 状态（来自 get_status()）
--- @return string[] 通知行列表
function M.format_notification(ecc)
  local lines = {}

  if ecc then
    table.insert(lines, "🔧 ECC Framework:")
    if ecc.repo_version then
      table.insert(lines, "  版本: " .. ecc.repo_version)
    end
    if #ecc.modules > 0 then
      table.insert(lines, "  模块: " .. table.concat(ecc.modules, ", "))
    end
  else
    table.insert(lines, "⚠️  ECC 未安装")
    table.insert(lines, "  安装: " .. M.install_hint())
  end

  return lines
end

--- 执行 shell 命令并返回输出
--- @param cmd string 命令
--- @param opts table|nil 选项 { timeout: number, cwd: string }
--- @return boolean, string success, output
local function run_cmd(cmd, opts)
  opts = opts or {}
  local timeout = opts.timeout or 120000
  local cwd = opts.cwd or nil

  local output = {}
  local job_id
  local success = false

  local co = coroutine.running()

  job_id = vim.fn.jobstart(cmd, {
    cwd = cwd,
    timeout = timeout,
    on_stdout = function(_, data)
      vim.list_extend(output, data)
    end,
    on_stderr = function(_, data)
      vim.list_extend(output, data)
    end,
    on_exit = function(_, code)
      success = code == 0
      if co then
        coroutine.resume(co)
      end
    end,
  })

  if job_id <= 0 then
    return false, "Failed to start command"
  end

  if co then
    coroutine.yield()
  end

  return success, table.concat(output, "\n")
end

--- 同步执行命令（用于非交互式安装）
--- @param cmd string 命令
--- @param opts table|nil 选项
--- @return boolean, string
local function run_cmd_sync(cmd, opts)
  opts = opts or {}
  local timeout = opts.timeout or 300000

  local result = vim.fn.systemlist(cmd)
  local exit_code = vim.v.shell_error

  return exit_code == 0, table.concat(result, "\n")
end

--- 克隆 ECC 仓库
--- @param on_progress function|nil 进度回调
--- @return boolean, string success, message
local function clone_repo(on_progress)
  if on_progress then
    on_progress("📥 克隆 ECC 仓库...")
  end

  -- 清理旧的临时目录
  if vim.fn.isdirectory(ECC_TEMP_DIR) == 1 then
    vim.fn.delete(ECC_TEMP_DIR, "rf")
  end

  local cmd = string.format("git clone %s %s --depth=1", ECC_REPO, ECC_TEMP_DIR)
  local ok, output = run_cmd_sync(cmd, { timeout = 120000 })

  if not ok then
    return false, "克隆失败: " .. output
  end

  return true, "克隆成功"
end

--- 安装 npm 依赖
--- @param on_progress function|nil 进度回调
--- @return boolean, string
local function install_deps(on_progress)
  if on_progress then
    on_progress("📦 安装依赖...")
  end

  local cmd = "npm install --no-audit --no-fund --loglevel=error"
  local ok, output = run_cmd_sync(cmd, { timeout = 180000 })

  if not ok then
    return false, "依赖安装失败: " .. output
  end

  return true, "依赖安装成功"
end

--- 运行 ECC 安装脚本
--- @param target string "claude" 或 "opencode"
--- @param profile string 安装 profile
--- @param on_progress function|nil 进度回调
--- @return boolean, string
local function run_install(target, profile, on_progress)
  -- 参数验证（防止注入）
  if not VALID_TARGETS[target] then
    return false, "无效的安装目标: " .. tostring(target)
  end
  if not VALID_PROFILES[profile] then
    return false, "无效的安装 profile: " .. tostring(profile)
  end

  if on_progress then
    on_progress(string.format("🔧 安装 ECC 到 %s (profile: %s)...", target, profile))
  end

  local cmd = string.format("node scripts/install-apply.js --target %s --profile %s", target, profile)
  local ok, output = run_cmd_sync(cmd, { timeout = 120000 })

  if not ok then
    return false, "安装失败: " .. output
  end

  return true, "安装成功"
end

--- 安装 ECC
--- @param opts table|nil { target: string, profile: string, force: boolean }
--- @param on_progress function|nil 进度回调 (message: string) -> void
--- @return boolean, string success, message
function M.install(opts, on_progress)
  opts = opts or {}
  local target = opts.target or "claude"
  local profile = opts.profile or "developer"
  local force = opts.force or false

  -- 检查是否已安装
  if not force and M.is_installed() then
    return true, "ECC 已安装"
  end

  -- 检查必要工具
  if vim.fn.executable("git") ~= 1 then
    return false, "需要安装 git"
  end
  if vim.fn.executable("node") ~= 1 then
    return false, "需要安装 Node.js"
  end
  if vim.fn.executable("npm") ~= 1 then
    return false, "需要安装 npm"
  end

  -- 克隆仓库
  local ok, msg = clone_repo(on_progress)
  if not ok then
    return false, msg
  end

  -- 安装依赖
  ok, msg = install_deps(on_progress)
  if not ok then
    return false, msg
  end

  -- 运行安装脚本
  ok, msg = run_install(target, profile, on_progress)
  if not ok then
    return false, msg
  end

  -- 清理临时目录
  vim.fn.delete(ECC_TEMP_DIR, "rf")

  return true, "✅ ECC 安装成功！"
end

--- 异步安装 ECC（使用浮动窗口显示进度）
--- @param opts table|nil { target: string, profile: string, force: boolean }
--- @param callback function|nil 完成回调 (success: boolean, message: string) -> void
function M.install_async(opts, callback)
  opts = opts or {}

  -- 创建浮动窗口
  local buf = vim.api.nvim_create_buf(false, true)
  local width = 60
  local height = 10
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " ECC Installation ",
    title_pos = "center",
  })

  local lines = { "准备安装 ECC...", "" }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local function update(msg)
    table.insert(lines, msg)
    if #lines > height - 2 then
      table.remove(lines, 1)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  -- 在后台运行安装
  vim.defer_fn(function()
    local ok, msg = M.install(opts, update)
    table.insert(lines, "")
    table.insert(lines, msg)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- 3秒后关闭窗口
    vim.defer_fn(function()
      pcall(vim.api.nvim_win_close, win, true)
      if callback then
        callback(ok, msg)
      end
    end, 3000)
  end, 100)
end

--- 确保已安装 ECC（用于配置生成前检查）
--- 同时为 Claude Code 和 OpenCode 安装
--- @param opts table|nil { profile: string }
--- @return boolean 是否已安装（或刚安装成功）
function M.ensure_installed(opts)
  opts = opts or {}

  if M.is_installed() then
    return true
  end

  -- 询问用户是否安装
  local choice = vim.fn.confirm("ECC 未安装。是否为 Claude Code 和 OpenCode 安装 ECC？", "&Yes\n&No", 1)

  if choice ~= 1 then
    return false
  end

  local profile = opts.profile or "developer"

  -- 同步安装到两个目标
  local ok, msg = M.install({ target = "claude", profile = profile }, function(m)
    vim.notify("[Claude Code] " .. m, vim.log.levels.INFO)
  end)

  if not ok then
    vim.notify("ECC 安装失败: " .. msg, vim.log.levels.ERROR)
    return false
  end

  ok, msg = M.install({ target = "opencode", profile = profile, force = false }, function(m)
    vim.notify("[OpenCode] " .. m, vim.log.levels.INFO)
  end)

  vim.notify("✅ ECC 安装完成", vim.log.levels.INFO)
  return true
end

--- 显示 ECC 状态
function M.show_status()
  local ecc = M.get_status()
  local lines = { "━━━ ECC Framework Status ━━━", "" }

  if ecc then
    table.insert(lines, "✅ 已安装")
    if ecc.repo_version then
      table.insert(lines, "  版本: " .. ecc.repo_version)
    end
    if ecc.installed_at then
      table.insert(lines, "  安装时间: " .. ecc.installed_at)
    end
    if #ecc.modules > 0 then
      table.insert(lines, "  模块 (" .. #ecc.modules .. "):")
      for _, m in ipairs(ecc.modules) do
        table.insert(lines, "    • " .. m)
      end
    end

    -- 检查安装目录
    table.insert(lines, "")
    table.insert(lines, "安装目录:")
    local dirs = { "rules", "commands", "agents", "skills", "hooks" }
    for _, dir in ipairs(dirs) do
      local claude_dir = vim.fn.expand("~/.claude/" .. dir)
      local opencode_dir = vim.fn.expand("~/.opencode/" .. dir)
      local claude_count = vim.fn.isdirectory(claude_dir) == 1
          and vim.fn.len(vim.fn.glob(claude_dir .. "/*", false, true))
        or 0
      local opencode_count = vim.fn.isdirectory(opencode_dir) == 1
          and vim.fn.len(vim.fn.glob(opencode_dir .. "/*", false, true))
        or 0
      table.insert(lines, string.format("  %-12s  Claude: %3d  OpenCode: %3d", dir, claude_count, opencode_count))
    end
  else
    table.insert(lines, "⚠️  未安装")
    table.insert(lines, "")
    table.insert(lines, "运行 :ECCInstall 来安装")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

--- 打开 ECC 安装 UI
function M.open_installer()
  local targets = { "claude", "opencode", "both (claude + opencode)" }
  local profiles = { "core", "developer", "security", "research", "full" }

  -- 使用 vim.ui.select 让用户选择
  vim.ui.select(targets, {
    prompt = "选择安装目标:",
  }, function(target)
    if not target then
      return
    end

    vim.ui.select(profiles, {
      prompt = "选择安装 profile:",
    }, function(profile)
      if not profile then
        return
      end

      local force = M.is_installed()
      if force then
        local choice = vim.fn.confirm("ECC 已安装。是否重新安装？", "&Yes\n&No", 2)
        if choice ~= 1 then
          return
        end
      end

      -- 处理 "both" 目标
      if target:match("both") then
        M.install_async({
          target = "claude",
          profile = profile,
          force = force,
        }, function(ok, msg)
          if ok then
            -- 安装完 claude 后安装 opencode
            M.install_async({
              target = "opencode",
              profile = profile,
              force = force,
            }, function(ok2, msg2)
              if ok2 then
                vim.notify("✅ ECC 已安装到 Claude Code 和 OpenCode", vim.log.levels.INFO)
              else
                vim.notify("OpenCode 安装: " .. msg2, vim.log.levels.WARN)
              end
            end)
          else
            vim.notify(msg, vim.log.levels.ERROR)
          end
        end)
      else
        M.install_async({
          target = target,
          profile = profile,
          force = force,
        }, function(ok, msg)
          if ok then
            vim.notify(msg, vim.log.levels.INFO)
          end
        end)
      end
    end)
  end)
end

--- 为所有目标安装 ECC (Claude Code + OpenCode)
--- @param opts table|nil { profile: string, force: boolean }
--- @param callback function|nil 完成回调
function M.install_all(opts, callback)
  opts = opts or {}
  local profile = opts.profile or "developer"
  local force = opts.force or false

  -- 安装到 Claude Code
  M.install({ target = "claude", profile = profile, force = force }, function(msg)
    vim.notify("[Claude Code] " .. msg, vim.log.levels.INFO)
  end)

  -- 安装到 OpenCode
  M.install({ target = "opencode", profile = profile, force = force }, function(msg)
    vim.notify("[OpenCode] " .. msg, vim.log.levels.INFO)
  end)

  if callback then
    callback(true, "ECC 安装完成")
  end
end

return M
