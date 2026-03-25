-- lua/ai/terminal.lua
-- 统一终端管理器：管理所有终端实例（预设 + 自由 + SSH）

local M = {}

---@class TerminalEntry
---@field id number toggleterm 终端 ID
---@field term table toggleterm Terminal 实例
---@field kind "preset"|"free"|"ssh" 终端类型
---@field label string 显示名称
---@field cmd string 执行的命令
---@field dir string 工作目录
---@field direction "float"|"horizontal"|"vertical" 打开方向

local managed = {} -- id -> TerminalEntry
local next_id = 100 -- 从 100 开始，避免与 toggleterm 默认编号冲突

-- 预设命令注册表
M.presets = {
  { name = "opencode", cmd = "opencode", label = "OpenCode", description = "OpenCode AI Assistant" },
  { name = "claude", cmd = "claude", label = "Claude Code", description = "Claude Code CLI" },
  { name = "cfuse", cmd = "cfuse", label = "CFuse", description = "CFuse Tool" },
}

-- ========== 内部工具函数 ==========

local function get_toggleterm()
  local ok, term_module = pcall(require, "toggleterm.terminal")
  if not ok then
    vim.notify("toggleterm.nvim not installed", vim.log.levels.ERROR)
    return nil
  end
  return term_module
end

local function alloc_id()
  local id = next_id
  next_id = next_id + 1
  return id
end

local function get_float_opts()
  return {
    border = "curved",
    winblend = 0,
    width = function()
      return math.floor(vim.o.columns * 0.85)
    end,
    height = function()
      return math.floor(vim.o.lines * 0.85)
    end,
    row = function()
      return math.floor(vim.o.lines * 0.075)
    end,
    col = function()
      return math.floor(vim.o.columns * 0.075)
    end,
  }
end

--- 获取按 ID 排序的 entries 列表（内部用）
---@return TerminalEntry[]
local function sorted_entries()
  local list = {}
  for _, entry in pairs(managed) do
    table.insert(list, entry)
  end
  table.sort(list, function(a, b)
    return a.id < b.id
  end)
  return list
end

--- 根据序号（1-based index）获取终端 entry
---@param index number
---@return TerminalEntry|nil
local function get_by_index(index)
  local entries = sorted_entries()
  return entries[index]
end

--- 构建浮动终端 border title（标签栏 + 切换快捷键）
--- 格式: M-1:OpenCode │「M-2:Shell」│ M-3:Claude
---@param current_id number 当前终端 ID
---@return string
local function build_tab_title(current_id)
  local parts = {}
  local entries = sorted_entries()

  for i, entry in ipairs(entries) do
    local short_label = entry.label:sub(1, 12)
    if entry.id == current_id then
      table.insert(parts, string.format("「%d:%s」", i, short_label))
    else
      table.insert(parts, string.format(" %d:%s ", i, short_label))
    end
  end

  if #parts == 0 then
    return ""
  end
  return table.concat(parts, "│")
end

--- 构建状态栏文本（当前终端名称 + 标签列表）
--- 格式: [2/3] Shell  ← OpenCode │ Shell │ Claude
---@param current_id number
---@return string
local function build_statusline_text(current_id)
  local entries = sorted_entries()
  if #entries == 0 then
    return "Terminal"
  end

  local current_index = 0
  local current_label = "Terminal"
  local tab_parts = {}

  for i, entry in ipairs(entries) do
    local short_label = entry.label:sub(1, 12)
    if entry.id == current_id then
      current_index = i
      current_label = short_label
      table.insert(tab_parts, "[" .. short_label .. "]")
    else
      table.insert(tab_parts, short_label)
    end
  end

  return string.format("[%d/%d] %s  %s", current_index, #entries, current_label, table.concat(tab_parts, " │ "))
end

--- 更新浮动终端的 border title
---@param entry TerminalEntry
---@param current_id number
local function update_float_title(entry, current_id)
  if entry.direction ~= "float" then
    return
  end
  local win = entry.term.window
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local title = build_tab_title(current_id)
  if title == "" then
    return
  end
  -- 直接设置一次
  pcall(vim.api.nvim_win_set_config, win, { title = title, title_pos = "center" })
  -- 延迟再设置一次，防止被 toggleterm 内部重置
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_config, win, { title = title, title_pos = "center" })
    end
  end, 50)
end

--- 更新所有 managed 终端的 buffer 变量（供 lualine 读取）
local function update_all_buf_vars()
  local entries = sorted_entries()
  local total = #entries
  for i, entry in ipairs(entries) do
    local bufnr = entry.term and entry.term.bufnr
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.b[bufnr].managed_term_id = entry.id
      vim.b[bufnr].managed_term_label = entry.label
      vim.b[bufnr].managed_term_index = i
      vim.b[bufnr].managed_term_total = total
    end
  end
end

--- 刷新所有可见终端的标题和状态栏
---@param current_id number 当前活跃的终端 ID
local function refresh_all(current_id)
  for _, entry in pairs(managed) do
    if entry.term and entry.term:is_open() then
      update_float_title(entry, current_id)
    end
  end
  -- 触发 lualine 刷新状态栏
  local ok, lualine = pcall(require, "lualine")
  if ok then
    lualine.refresh()
  end
end

--- 为终端 buffer 设置 M-n 切换快捷键（terminal + normal 模式）
---@param bufnr number
local function set_switch_keymaps(bufnr)
  local kopts = { noremap = true, silent = true, buffer = bufnr }
  -- M-1 到 M-9 切换到对应序号的终端
  for i = 1, 9 do
    local switch_fn = function()
      local target = get_by_index(i)
      if target then
        M.focus(target.id)
      end
    end
    local desc = "Switch to Terminal " .. i
    vim.keymap.set("t", string.format("<M-%d>", i), switch_fn, vim.tbl_extend("force", kopts, { desc = desc }))
    vim.keymap.set("n", string.format("<M-%d>", i), switch_fn, vim.tbl_extend("force", kopts, { desc = desc }))
  end
end

--- 打开终端选择器（在任意模式下）
local function open_picker()
  vim.cmd([[stopinsert]])
  vim.schedule(function()
    require("ai.terminal_picker").open()
  end)
end

--- 关闭当前终端
local function kill_current()
  local bufnr_cur = vim.api.nvim_get_current_buf()
  for id, entry in pairs(managed) do
    if entry.term and entry.term.bufnr == bufnr_cur then
      M.kill(id)
      return
    end
  end
  vim.cmd([[stopinsert]])
  vim.cmd("close")
end

--- 为终端 buffer 设置局部快捷键
---@param bufnr number
---@param term_id number
local function set_term_keymaps(bufnr, term_id)
  local kopts = { noremap = true, silent = true, buffer = bufnr }

  -- 终端选择器：normal 模式（terminal 模式先 C-q 退到 normal 再 <leader>tt）
  vim.keymap.set("n", "<leader>tt", open_picker, vim.tbl_extend("force", kopts, { desc = "Terminal Picker" }))

  -- 关闭当前终端：terminal + normal 模式
  vim.keymap.set("t", [[<C-\><C-q>]], kill_current, vim.tbl_extend("force", kopts, { desc = "Kill Terminal" }))
  vim.keymap.set("n", "<leader>tq", kill_current, vim.tbl_extend("force", kopts, { desc = "Kill Terminal" }))

  -- <C-q> 退出到 Normal 模式（仅 terminal 模式）
  vim.keymap.set("t", "<C-q>", [[<C-\><C-n>]], vim.tbl_extend("force", kopts, { desc = "Terminal Normal Mode" }))

  -- M-n 切换快捷键（terminal + normal 模式）
  set_switch_keymaps(bufnr)
end

--- 创建终端并注册到 managed 表
---@param kind "preset"|"free"|"ssh"
---@param label string
---@param cmd string
---@param opts table
---@return TerminalEntry|nil
local function create_entry(kind, label, cmd, opts)
  opts = opts or {}
  local term_module = get_toggleterm()
  if not term_module then
    return nil
  end

  local id = alloc_id()
  local direction = opts.direction or "float"
  local dir = opts.dir or vim.fn.getcwd()

  local term_opts = {
    cmd = cmd,
    dir = dir,
    direction = direction,
    count = id,
    float_opts = get_float_opts(),
    on_open = function(term)
      vim.cmd("startinsert!")
      set_term_keymaps(term.bufnr, id)
      -- 写入 buffer 变量，供 lualine 读取
      vim.b[term.bufnr].managed_term_id = id
      -- 更新标题和状态栏
      vim.schedule(function()
        -- 刷新 buffer 变量（多终端时需要更新所有终端的 statusline 文本）
        update_all_buf_vars()
        refresh_all(id)
      end)
    end,
    on_exit = function(_, _, exit_code)
      -- 进程退出后从 managed 中清理
      managed[id] = nil
      if exit_code ~= 0 and exit_code ~= 130 then
        vim.notify(label .. " exited with code: " .. exit_code, vim.log.levels.WARN)
      end
    end,
  }

  local terminal = term_module.Terminal:new(term_opts)

  local entry = {
    id = id,
    term = terminal,
    kind = kind,
    label = label,
    cmd = cmd,
    dir = dir,
    direction = direction,
  }

  managed[id] = entry
  return entry
end

-- ========== 公共 API ==========

--- 创建预设命令终端
---@param name string 预设名称（如 "opencode", "claude"）
---@param opts? table { direction?, dir?, args? }
---@return TerminalEntry|nil
function M.create_preset(name, opts)
  opts = opts or {}

  local preset = nil
  for _, p in ipairs(M.presets) do
    if p.name == name then
      preset = p
      break
    end
  end

  if not preset then
    vim.notify("未知预设: " .. name, vim.log.levels.ERROR)
    return nil
  end

  if vim.fn.executable(preset.cmd) ~= 1 then
    vim.notify(preset.label .. " 未安装", vim.log.levels.ERROR)
    return nil
  end

  local cmd = preset.cmd
  if opts.args then
    cmd = cmd .. " " .. opts.args
  end

  local entry = create_entry("preset", preset.label, cmd, opts)
  if entry then
    entry.term:toggle()
  end
  return entry
end

--- 创建自由终端（shell）
---@param opts? table { direction?, dir? }
---@return TerminalEntry|nil
function M.create_free(opts)
  opts = opts or {}
  local shell = vim.o.shell or "/bin/zsh"
  local entry = create_entry("free", "Shell", shell, opts)
  if entry then
    entry.term:toggle()
  end
  return entry
end

--- 创建 SSH 连接终端
---@param host string SSH host 名称
---@param opts? table { direction?, dir? }
---@return TerminalEntry|nil
function M.create_ssh(host, opts)
  opts = opts or {}
  local cmd = "ssh " .. vim.fn.shellescape(host)
  local label = "SSH: " .. host
  local entry = create_entry("ssh", label, cmd, opts)
  if entry then
    entry.term:toggle()
  end
  return entry
end

--- 聚焦到指定 ID 的终端（如果隐藏则重新打开）
---@param id number
function M.focus(id)
  local entry = managed[id]
  if not entry then
    vim.notify("终端 #" .. id .. " 不存在", vim.log.levels.WARN)
    return
  end

  if entry.term:is_open() then
    local win = entry.term.window
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      vim.cmd("startinsert!")
    end
  else
    entry.term:open()
    vim.cmd("startinsert!")
  end

  -- 刷新所有终端的标题和状态栏
  vim.schedule(function()
    refresh_all(id)
  end)
end

--- Toggle 指定终端的显示/隐藏
---@param id number
function M.toggle(id)
  local entry = managed[id]
  if not entry then
    vim.notify("终端 #" .. id .. " 不存在", vim.log.levels.WARN)
    return
  end
  entry.term:toggle()
end

--- 隐藏/显示所有终端
function M.toggle_all()
  local entries = sorted_entries()
  if #entries == 0 then
    vim.notify("没有已打开的终端", vim.log.levels.INFO)
    return
  end
  -- 检查是否有任意终端可见
  local any_open = false
  for _, entry in ipairs(entries) do
    if entry.term:is_open() then
      any_open = true
      break
    end
  end
  -- 全部隐藏或全部显示
  for _, entry in ipairs(entries) do
    if any_open then
      if entry.term:is_open() then
        entry.term:close()
      end
    else
      entry.term:open()
    end
  end
end

--- 关闭并销毁终端
---@param id number
function M.kill(id)
  local entry = managed[id]
  if not entry then
    return
  end
  entry.term:shutdown()
  managed[id] = nil
end

--- 关闭所有终端
function M.kill_all()
  for _, entry in pairs(managed) do
    entry.term:shutdown()
  end
  managed = {}
end

--- 返回所有 managed entries 列表
---@return TerminalEntry[]
function M.get_all()
  return sorted_entries()
end

--- 解析 ~/.ssh/config 返回 Host 列表（排除通配符 *）
---@return string[]
function M.get_ssh_hosts()
  local hosts = {}
  local ssh_config = vim.fn.expand("~/.ssh/config")
  if vim.fn.filereadable(ssh_config) ~= 1 then
    return hosts
  end

  local lines = vim.fn.readfile(ssh_config)
  for _, line in ipairs(lines) do
    local host = line:match("^%s*Host%s+(.+)%s*$")
    if host then
      for h in host:gmatch("%S+") do
        if not h:find("*") then
          table.insert(hosts, h)
        end
      end
    end
  end

  return hosts
end

--- 检测预设命令是否已安装
---@param name string
---@return boolean
function M.is_preset_installed(name)
  for _, p in ipairs(M.presets) do
    if p.name == name then
      return vim.fn.executable(p.cmd) == 1
    end
  end
  return false
end

--- 获取预设信息
---@param name string
---@return table|nil
function M.get_preset(name)
  for _, p in ipairs(M.presets) do
    if p.name == name then
      return p
    end
  end
  return nil
end

--- 发送文本到指定终端
---@param id number
---@param text string
function M.send(id, text)
  local entry = managed[id]
  if not entry or not entry.term:is_open() then
    vim.notify("终端 #" .. id .. " 未打开", vim.log.levels.WARN)
    return
  end
  entry.term:send(text, false)
end

--- 带上下文创建预设终端
---@param name string
---@param opts? table
function M.create_preset_with_context(name, opts)
  opts = vim.deepcopy(opts or {})
  local ok, Context = pcall(require, "ai.context")
  if ok then
    local context = Context.get_context({ selection = false, git_diff = false })
    if context.file and context.file.exists and context.file.path then
      local extra = vim.fn.shellescape(context.file.path)
      opts.args = opts.args and (opts.args .. " " .. extra) or extra
    end
  end
  return M.create_preset(name, opts)
end

--- 获取当前 buffer 对应的终端 statusline 文本（供 lualine 等调用）
--- 优先从 buffer 变量读取（最可靠），回退到 managed 表匹配
---@return string|nil
function M.get_current_statusline()
  -- 方式 1：直接读 buffer 变量（on_open 时写入，最可靠）
  local term_id = vim.b.managed_term_id
  if term_id and managed[term_id] then
    return build_statusline_text(term_id)
  end

  -- 方式 2：通过 bufnr 匹配 managed 表
  local bufnr = vim.api.nvim_get_current_buf()
  for id, entry in pairs(managed) do
    if entry.term and entry.term.bufnr == bufnr then
      return build_statusline_text(id)
    end
  end

  -- 方式 3：非 managed 终端，显示 buffer 变量或基本信息
  local label = vim.b.managed_term_label
  if label then
    local idx = vim.b.managed_term_index or 0
    local total = vim.b.managed_term_total or 0
    return string.format("[%d/%d] %s", idx, total, label)
  end

  return nil
end

return M
