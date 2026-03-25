-- lua/ai/terminal_picker.lua
-- 基于 fzf-lua 的终端选择器 UI

local M = {}

local SEPARATOR =
  "──────────────────────────────────────────────"
local ACTION_PRESET = "  [+] 预设命令终端"
local ACTION_FREE = "  [+] 自由终端 (shell)"

--- 格式化终端条目为显示行
---@param entry TerminalEntry
---@return string
local function format_entry(entry)
  local dir_display = vim.fn.fnamemodify(entry.dir, ":~:.")
  if #dir_display > 20 then
    dir_display = vim.fn.fnamemodify(entry.dir, ":t")
  end
  return string.format(
    "#%-4d  [%-12s]  %-20s  %-20s  %s",
    entry.id,
    entry.label,
    dir_display,
    entry.cmd,
    entry.direction
  )
end

--- 从 fzf 选中项解析终端 ID
---@param selected string
---@return number|nil
local function parse_id(selected)
  local id_str = selected:match("^#(%d+)")
  return id_str and tonumber(id_str) or nil
end

--- 打开/聚焦终端（支持指定方向）
---@param selected string
---@param direction? string
local function action_open(selected, direction)
  if not selected then
    return
  end

  if selected == ACTION_PRESET then
    vim.schedule(function()
      M.open_preset_picker(direction)
    end)
    return
  end

  if selected == ACTION_FREE then
    vim.schedule(function()
      require("ai.terminal").create_free({ direction = direction or "float" })
    end)
    return
  end

  -- 忽略分隔线
  if selected:match("^──") then
    return
  end

  local id = parse_id(selected)
  if id then
    require("ai.terminal").focus(id)
  end
end

--- 处理预设/SSH 选中
---@param selected string
---@param direction string
local function handle_preset_select(selected, direction)
  local Terminal = require("ai.terminal")

  -- 忽略分隔线
  if selected:match("^──") then
    return
  end

  -- SSH host
  local ssh_host = selected:match("^%s+(%S+)%s+ssh%s+")
  if ssh_host then
    Terminal.create_ssh(ssh_host, { direction = direction })
    return
  end

  -- 预设命令
  local preset_name = selected:match("^%[..%]%s+(%S+)")
  if preset_name then
    -- 检查是否未安装
    if selected:find("not installed") then
      vim.notify(preset_name .. " 未安装", vim.log.levels.WARN)
      return
    end
    Terminal.create_preset(preset_name, { direction = direction })
  end
end

--- 预设命令子选择器（含 SSH hosts）
---@param direction? string 默认方向
function M.open_preset_picker(direction)
  local Terminal = require("ai.terminal")
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua 未安装", vim.log.levels.ERROR)
    return
  end

  direction = direction or "float"
  local items = {}

  -- 预设命令（标注安装状态）
  for _, preset in ipairs(Terminal.presets) do
    local installed = vim.fn.executable(preset.cmd) == 1
    local icon = installed and "[OK]" or "[--]"
    local suffix = installed and "" or " (not installed)"
    table.insert(items, string.format("%-5s %-12s %s%s", icon, preset.name, preset.description, suffix))
  end

  -- SSH hosts
  local ssh_hosts = Terminal.get_ssh_hosts()
  if #ssh_hosts > 0 then
    table.insert(items, "── SSH ──")
    for _, host in ipairs(ssh_hosts) do
      table.insert(items, string.format("      %-12s ssh %s", host, host))
    end
  end

  fzf.fzf_exec(items, {
    prompt = "Preset> ",
    fzf_opts = {
      ["--header"] = "CR:open  C-v:vertical  C-s:horizontal  C-f:float",
      ["--no-sort"] = "",
    },
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          handle_preset_select(selected[1], direction)
        end
      end,
      ["ctrl-v"] = function(selected)
        if selected and selected[1] then
          handle_preset_select(selected[1], "vertical")
        end
      end,
      ["ctrl-s"] = function(selected)
        if selected and selected[1] then
          handle_preset_select(selected[1], "horizontal")
        end
      end,
      ["ctrl-f"] = function(selected)
        if selected and selected[1] then
          handle_preset_select(selected[1], "float")
        end
      end,
    },
  })
end

--- 主选择器
function M.open()
  local Terminal = require("ai.terminal")
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua 未安装", vim.log.levels.ERROR)
    return
  end

  local items = {}

  -- 已有终端
  local entries = Terminal.get_all()
  for _, entry in ipairs(entries) do
    table.insert(items, format_entry(entry))
  end

  -- 分隔线和操作项
  if #entries > 0 then
    table.insert(items, SEPARATOR)
  end
  table.insert(items, ACTION_PRESET)
  table.insert(items, ACTION_FREE)

  fzf.fzf_exec(items, {
    prompt = "Terminals> ",
    fzf_opts = {
      ["--header"] = "CR:open  C-v:vertical  C-s:horizontal  C-f:float  C-d:kill",
      ["--no-sort"] = "",
    },
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          action_open(selected[1])
        end
      end,
      ["ctrl-v"] = function(selected)
        if selected and selected[1] then
          action_open(selected[1], "vertical")
        end
      end,
      ["ctrl-s"] = function(selected)
        if selected and selected[1] then
          action_open(selected[1], "horizontal")
        end
      end,
      ["ctrl-f"] = function(selected)
        if selected and selected[1] then
          action_open(selected[1], "float")
        end
      end,
      ["ctrl-d"] = function(selected)
        if selected and selected[1] then
          local id = parse_id(selected[1])
          if id then
            Terminal.kill(id)
            -- 重新打开选择器
            vim.schedule(function()
              M.open()
            end)
          end
        end
      end,
    },
  })
end

return M
