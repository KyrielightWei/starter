-- lua/ai/terminal.lua
-- 统一终端管理：管理 OpenCode、Claude Code 等 CLI AI 工具

local M = {}

local terminals = {}

M.tools = {
  opencode = {
    cmd = "opencode",
    name = "OpenCode",
    description = "OpenCode AI Assistant",
    check = function()
      return vim.fn.executable("opencode") == 1
    end,
    config_dir = function()
      return vim.fn.stdpath("config")
    end,
  },
  claude = {
    cmd = "claude",
    name = "Claude Code",
    description = "Claude Code CLI",
    check = function()
      return vim.fn.executable("claude") == 1
    end,
    config_dir = function()
      return vim.fn.expand("~/.claude")
    end,
  },
  aider = {
    cmd = "aider",
    name = "Aider",
    description = "Aider AI Pair Programming",
    check = function()
      return vim.fn.executable("aider") == 1
    end,
    config_dir = function()
      return vim.fn.expand("~/.aider")
    end,
  },
}

local function get_toggleterm()
  local ok, term_module = pcall(require, "toggleterm.terminal")
  if not ok then
    return nil
  end
  return term_module
end

local function build_cmd(tool_name, opts)
  opts = opts or {}
  local tool = M.tools[tool_name]
  if not tool then
    return nil
  end

  local cmd = tool.cmd

  if opts.args then
    cmd = cmd .. " " .. opts.args
  end

  return cmd
end

local function get_float_opts(opts)
  local width = opts.width or function()
    return math.floor(vim.o.columns * 0.85)
  end
  local height = opts.height or function()
    return math.floor(vim.o.lines * 0.85)
  end

  return {
    border = opts.border or "curved",
    winblend = opts.winblend or 0,
    width = width,
    height = height,
    row = opts.row or function()
      return math.floor((vim.o.lines - (type(height) == "function" and height() or height)) / 2)
    end,
    col = opts.col or function()
      return math.floor((vim.o.columns - (type(width) == "function" and width() or width)) / 2)
    end,
  }
end

local function create_terminal(tool_name, opts)
  opts = opts or {}
  local tool = M.tools[tool_name]
  local term_module = get_toggleterm()

  if not term_module then
    vim.notify("toggleterm.nvim not installed", vim.log.levels.ERROR)
    return nil
  end

  local cmd = build_cmd(tool_name, opts)
  if not cmd then
    vim.notify("Unknown tool: " .. tool_name, vim.log.levels.ERROR)
    return nil
  end

  local direction = opts.direction or "float"
  local term_opts = {
    cmd = cmd,
    direction = direction,
    float_opts = get_float_opts(opts),
    on_open = function(term)
      vim.cmd("startinsert!")
      if opts.on_open then
        opts.on_open(term)
      end
    end,
    on_exit = function(term, job, exit_code)
      if exit_code ~= 0 and exit_code ~= 130 then
        vim.notify(tool.name .. " exited with code: " .. exit_code, vim.log.levels.WARN)
      end
      if opts.on_exit then
        opts.on_exit(term, job, exit_code)
      end
    end,
  }

  local terminal = term_module.Terminal:new(term_opts)
  terminals[tool_name] = terminal

  return terminal
end

function M.toggle(tool_name, opts)
  opts = opts or {}
  local tool = M.tools[tool_name]

  if not tool then
    vim.notify("Unknown tool: " .. tool_name, vim.log.levels.ERROR)
    return
  end

  if not tool.check() then
    vim.notify(tool.name .. " not found. Please install it first.", vim.log.levels.ERROR)
    return
  end

  local terminal = terminals[tool_name]
  if not terminal then
    terminal = create_terminal(tool_name, opts)
  end

  if terminal then
    terminal:toggle()
  end
end

function M.open(tool_name, opts)
  M.toggle(tool_name, opts)
end

function M.close(tool_name)
  tool_name = tool_name or "opencode"
  local terminal = terminals[tool_name]
  if terminal and terminal:is_open() then
    terminal:close()
  end
end

function M.close_all()
  for name, terminal in pairs(terminals) do
    if terminal:is_open() then
      terminal:close()
    end
  end
end

function M.is_open(tool_name)
  tool_name = tool_name or "opencode"
  local terminal = terminals[tool_name]
  return terminal and terminal:is_open()
end

function M.run_in_terminal(tool_name, command)
  tool_name = tool_name or "opencode"
  local terminal = terminals[tool_name]
  if not terminal or not terminal:is_open() then
    M.toggle(tool_name)
    vim.defer_fn(function()
      M.send_to_terminal(tool_name, command)
    end, 500)
  else
    M.send_to_terminal(tool_name, command)
  end
end

function M.send_to_terminal(tool_name, command)
  tool_name = tool_name or "opencode"
  local terminal = terminals[tool_name]
  if terminal and terminal:is_open() then
    terminal:send(command, false)
  end
end

function M.list_available()
  local available = {}
  for name, tool in pairs(M.tools) do
    if tool.check() then
      table.insert(available, {
        name = name,
        display = tool.name,
        description = tool.description,
      })
    end
  end
  return available
end

function M.select_and_open(opts)
  opts = opts or {}

  local available = M.list_available()
  if #available == 0 then
    vim.notify("No AI CLI tools found. Please install one of: opencode, claude, aider", vim.log.levels.WARN)
    return
  end

  if #available == 1 then
    M.toggle(available[1].name, opts)
    return
  end

  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not installed, using first available tool", vim.log.levels.WARN)
    M.toggle(available[1].name, opts)
    return
  end

  local items = {}
  for _, tool in ipairs(available) do
    table.insert(items, string.format("%-15s │ %s", tool.display, tool.description))
  end

  fzf.fzf_exec(items, {
    prompt = "Select AI Tool> ",
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          local name = selected[1]:match("^(%S+)")
          for _, tool in ipairs(available) do
            if tool.display == name then
              M.toggle(tool.name, opts)
              break
            end
          end
        end
      end,
    },
  })
end

function M.register_tool(name, config)
  M.tools[name] = vim.tbl_deep_extend("force", {
    cmd = name,
    name = name,
    description = name,
    check = function()
      return vim.fn.executable(name) == 1
    end,
  }, config or {})
end

function M.toggle_opencode(opts)
  M.toggle("opencode", opts)
end

function M.toggle_claude(opts)
  M.toggle("claude", opts)
end

function M.toggle_aider(opts)
  M.toggle("aider", opts)
end

return M
