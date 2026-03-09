-- lua/ai/context.lua
-- 上下文感知模块：收集当前文件、选区、项目信息等上下文

local M = {}

local function get_current_file_info()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" then
    return {
      exists = false,
      path = "[No File]",
      filename = "[No File]",
      filetype = vim.bo.filetype,
      lines = 0,
    }
  end

  local lines = vim.api.nvim_buf_line_count(bufnr)
  local filename = vim.fn.fnamemodify(filepath, ":t")
  local relative_path = vim.fn.fnamemodify(filepath, ":~:.")

  return {
    exists = true,
    path = filepath,
    relative_path = relative_path,
    filename = filename,
    filetype = vim.bo.filetype,
    lines = lines,
    modified = vim.bo.modified,
    readonly = vim.bo.readonly,
  }
end

local function get_visual_selection()
  local bufnr = vim.api.nvim_get_current_buf()

  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    local ok, pos = pcall(vim.fn.getpos, "'<")
    if ok and pos then
      vim.fn.setpos(".", pos)
    end
    return nil
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local start_col = start_pos[3]
  local end_col = end_pos[3]

  if start_line > end_line then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  if #lines == 0 then
    return nil
  end

  if #lines == 1 then
    lines[1] = lines[1]:sub(start_col, end_col)
  else
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
  end

  local selection = table.concat(lines, "\n")

  return {
    text = selection,
    start_line = start_line,
    end_line = end_line,
    start_col = start_col,
    end_col = end_col,
    lines = lines,
  }
end

local function get_project_root()
  local bufname = vim.api.nvim_buf_get_name(0)
  local start_dir = ""

  if bufname ~= "" then
    start_dir = vim.fs.dirname(bufname)
  else
    start_dir = vim.loop.cwd()
  end

  local root_markers = {
    ".git",
    "package.json",
    "pyproject.toml",
    "Cargo.toml",
    "go.mod",
    "Makefile",
    "README.md",
    ".opencode.json",
  }

  local match = vim.fs.find(root_markers, { path = start_dir, upward = true })[1]
  if match then
    return vim.fs.dirname(match)
  end

  return vim.loop.cwd()
end

local function get_project_summary()
  local root = get_project_root()
  local summary = {
    root = root,
    name = vim.fn.fnamemodify(root, ":t"),
    git = false,
    git_branch = nil,
    git_status = nil,
    structure = {},
  }

  local git_dir = root .. "/.git"
  if vim.fn.isdirectory(git_dir) == 1 then
    summary.git = true

    local branch = vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " branch --show-current 2>/dev/null")
    if vim.v.shell_error == 0 then
      summary.git_branch = vim.trim(branch)
    end

    local status = vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " status --porcelain 2>/dev/null")
    if vim.v.shell_error == 0 and status ~= "" then
      local changes = {}
      for line in status:gmatch("[^\r\n]+") do
        table.insert(changes, line)
      end
      summary.git_status = changes
    end
  end

  return summary
end

local function get_lsp_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(bufnr)

  if #diagnostics == 0 then
    return nil
  end

  local result = {
    errors = {},
    warnings = {},
    hints = {},
    info = {},
  }

  for _, diag in ipairs(diagnostics) do
    local item = {
      lnum = diag.lnum + 1,
      col = diag.col + 1,
      message = diag.message,
      source = diag.source,
      code = diag.code,
    }

    if diag.severity == 1 then
      table.insert(result.errors, item)
    elseif diag.severity == 2 then
      table.insert(result.warnings, item)
    elseif diag.severity == 3 then
      table.insert(result.info, item)
    elseif diag.severity == 4 then
      table.insert(result.hints, item)
    end
  end

  return result
end

local function get_git_diff()
  local ok, result = pcall(vim.fn.system, "git diff --stat 2>/dev/null")
  if not ok or vim.v.shell_error ~= 0 then
    return nil
  end

  if result == "" then
    return nil
  end

  return result
end

local function get_cursor_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""

  local filetype = vim.bo.filetype

  local surrounding_lines = vim.api.nvim_buf_get_lines(
    bufnr,
    math.max(0, line - 10),
    math.min(vim.api.nvim_buf_line_count(bufnr), line + 10),
    false
  )

  return {
    line = line,
    col = col,
    line_content = line_content,
    surrounding_context = table.concat(surrounding_lines, "\n"),
    filetype = filetype,
  }
end

local function get_symbol_at_cursor()
  local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
  if not ok then
    return nil
  end

  local node = ts_utils.get_node_at_cursor()
  if not node then
    return nil
  end

  return {
    type = node:type(),
    text = ts_utils.get_node_text(node)[1],
  }
end

function M.get_context(opts)
  opts = opts or {}

  local context = {}

  if opts.file ~= false then
    context.file = get_current_file_info()
  end

  if opts.selection ~= false then
    context.selection = get_visual_selection()
  end

  if opts.project ~= false then
    context.project = get_project_summary()
  end

  if opts.diagnostics ~= false then
    context.diagnostics = get_lsp_diagnostics()
  end

  if opts.cursor ~= false then
    context.cursor = get_cursor_context()
  end

  if opts.symbol then
    context.symbol = get_symbol_at_cursor()
  end

  if opts.git_diff then
    context.git_diff = get_git_diff()
  end

  return context
end

function M.format_context_for_prompt(context, opts)
  opts = opts or {}
  local parts = {}

  if context.file then
    table.insert(parts, string.format("File: %s (%s)", context.file.relative_path, context.file.filetype))
    table.insert(parts, string.format("Lines: %d", context.file.lines))
  end

  if context.project then
    table.insert(parts, string.format("Project: %s", context.project.name))
    if context.project.git then
      table.insert(parts, string.format("Branch: %s", context.project.git_branch or "unknown"))
    end
  end

  if context.selection and context.selection.text then
    table.insert(parts, "Selected Code:")
    table.insert(parts, "```" .. (context.file and context.file.filetype or ""))
    table.insert(parts, context.selection.text)
    table.insert(parts, "```")
  end

  if context.diagnostics and #context.diagnostics.errors > 0 then
    table.insert(parts, "Errors:")
    for _, err in ipairs(context.diagnostics.errors) do
      table.insert(parts, string.format("  Line %d: %s", err.lnum, err.message))
    end
  end

  return table.concat(parts, "\n")
end

function M.copy_to_clipboard(opts)
  opts = opts or {}
  local context = M.get_context(opts)
  local formatted = M.format_context_for_prompt(context, opts)

  vim.fn.setreg("+", formatted)
  vim.notify("Context copied to clipboard", vim.log.levels.INFO)

  return formatted
end

function M.get_file_content()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

function M.get_function_at_cursor()
  local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
  if not ok then
    return nil
  end

  local node = ts_utils.get_node_at_cursor()
  if not node then
    return nil
  end

  local function_node = node
  local function_types = {
    "function_declaration",
    "function_definition",
    "method_definition",
    "arrow_function",
    "function_expression",
  }

  while function_node do
    for _, t in ipairs(function_types) do
      if function_node:type() == t then
        return {
          type = t,
          text = ts_utils.get_node_text(function_node)[1],
          start_row = function_node:start(),
          end_row = function_node:end_(),
        }
      end
    end
    function_node = function_node:parent()
  end

  return nil
end

M.get_project_root = get_project_root
M.get_current_file_info = get_current_file_info
M.get_visual_selection = get_visual_selection
M.get_lsp_diagnostics = get_lsp_diagnostics

return M