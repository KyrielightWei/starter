-- lua/ai/skill_studio/ui.lua
-- Floating window UI for skill studio

local M = {}

local config = {}
local state = {
  buf = nil,
  win = nil,
  mode = nil,
  data = {},
  cursor_pos = {},
}

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------
function M.setup(opts)
  config = opts or {}
end

----------------------------------------------------------------------
-- Create Floating Window
----------------------------------------------------------------------
local function create_float_win(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)
  local row = opts.row or math.floor((vim.o.lines - height) / 2)
  local col = opts.col or math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", opts.filetype or "skill-studio")

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = opts.title or "Skill Studio",
    title_pos = "center",
  })

  vim.api.nvim_win_set_option(win, "wrap", false)
  vim.api.nvim_win_set_option(win, "cursorline", true)

  return buf, win
end

----------------------------------------------------------------------
-- Close Window
----------------------------------------------------------------------
local function close_win()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.mode = nil
end

----------------------------------------------------------------------
-- Draw Box
----------------------------------------------------------------------
local function draw_box(buf, start_row, start_col, width, height, title)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local top = "┌" .. string.rep("─", width - 2) .. "┐"
  local mid = "│" .. string.rep(" ", width - 2) .. "│"
  local bot = "└" .. string.rep("─", width - 2) .. "┘"

  if title then
    local title_str = " " .. title .. " "
    local pad_left = math.floor((width - 2 - #title_str) / 2)
    top = "┌"
      .. string.rep("─", pad_left)
      .. title_str
      .. string.rep("─", width - 2 - pad_left - #title_str)
      .. "┐"
  end

  for i = 0, height - 1 do
    local row = start_row + i
    if row < #lines then
      local line = lines[row + 1] or ""
      if i == 0 then
        line = line:sub(1, start_col) .. top .. line:sub(start_col + width + 1)
      elseif i == height - 1 then
        line = line:sub(1, start_col) .. bot .. line:sub(start_col + width + 1)
      else
        line = line:sub(1, start_col) .. mid .. line:sub(start_col + width + 1)
      end
      lines[row + 1] = line
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

----------------------------------------------------------------------
-- Creator UI
----------------------------------------------------------------------
function M.open_creator(opts)
  opts = opts or {}
  state.mode = "creator"
  state.data = {
    type = opts.type or "skill",
    target = opts.target or "claude",
    level = opts.level or "project",
    frontmatter = {},
    body = "",
  }

  local buf, win = create_float_win({
    title = string.format("Create %s (%s/%s)", opts.type, opts.target, opts.level),
    filetype = "skill-studio-creator",
  })

  state.buf = buf
  state.win = win

  local lines = {
    "# Skill Studio - Create New " .. opts.type:gsub("^%l", string.upper),
    "",
    "## Settings",
    string.format("Type: %s  |  Target: %s  |  Level: %s", opts.type, opts.target, opts.level),
    "",
    "## Frontmatter",
  }

  local templates = opts.templates or {}
  local template = templates[opts.type] and templates[opts.type][opts.target] or {}

  if template.frontmatter then
    for key, value in pairs(template.frontmatter) do
      if type(value) == "table" then
        state.data.frontmatter[key] = value[1] or ""
        table.insert(lines, string.format("%s: [%s]", key, table.concat(value, ", ")))
      else
        state.data.frontmatter[key] = value
        table.insert(lines, string.format("%s: %s", key, value))
      end
    end
  end

  table.insert(lines, "")
  table.insert(lines, "## Body")
  table.insert(lines, "")

  if template.body then
    for line in template.body:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    state.data.body = template.body
  end

  table.insert(lines, "")
  table.insert(lines, "──" .. string.rep("─", 60) .. "──")
  table.insert(lines, "Press <C-s> to save  |  Press <C-c> to cancel  |  Press <Tab> for autocomplete")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)

  M.setup_creator_keymaps(buf, opts.on_save)
  M.setup_autocomplete(buf, opts.type)
  M.setup_diagnostics(buf)
end

----------------------------------------------------------------------
-- Setup Autocomplete
----------------------------------------------------------------------
function M.setup_autocomplete(buf, item_type)
  local Validator = require("ai.skill_studio.validator")

  local frontmatter_fields = {
    skill = {
      { word = "name", menu = "Skill identifier", info = "Lowercase, hyphens, 1-64 chars" },
      { word = "description", menu = "When to use", info = "Describe trigger conditions" },
      { word = "version", menu = "Semver", info = "e.g., 1.0.0" },
      { word = "license", menu = "License", info = "MIT, Apache-2.0, etc." },
      { word = "allowed-tools", menu = "Tools list", info = "[Read, Write, Bash, ...]" },
    },
    command = {
      { word = "description", menu = "Command description", info = "Shown in /help" },
      { word = "argument-hint", menu = "Args hint", info = "<required> [optional]" },
      { word = "allowed-tools", menu = "Tools list", info = "[Read, Write, Bash, ...]" },
    },
    mcp = {
      { word = "type", menu = "Server type", info = "stdio, http, sse, ws, local, remote" },
      { word = "command", menu = "Command", info = "Command to start server" },
      { word = "url", menu = "URL", info = "Remote server URL" },
      { word = "env", menu = "Environment", info = '{ KEY = "value" }' },
      { word = "headers", menu = "HTTP headers", info = '{ Authorization = "Bearer ..." }' },
    },
  }

  local section_headers = {
    "## When This Skill Applies",
    "## Instructions",
    "## Examples",
    "## Prerequisites",
    "## Output Format",
    "## Steps",
    "## What I do",
    "## When to use me",
  }

  local trigger_phrases = {
    'Use this skill when the user asks to "',
    "This skill activates when:",
    "Use when task involves:",
    "Trigger conditions:",
  }

  vim.api.nvim_create_autocmd("InsertCompletePre", {
    buffer = buf,
    callback = function()
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
      local before_cursor = line:sub(1, col)

      local matches = {}

      if before_cursor:match("^%s*$") then
        local prev_line = vim.api.nvim_buf_get_lines(buf, math.max(0, row - 2), row - 1, false)[1] or ""
        if prev_line:match("^##") then
          for _, phrase in ipairs(trigger_phrases) do
            table.insert(matches, {
              word = phrase,
              menu = "trigger",
              kind = "Text",
            })
          end
        end
      end

      if before_cursor:match("^##%s*$") then
        for _, header in ipairs(section_headers) do
          table.insert(matches, {
            word = header:gsub("^##%s*", ""),
            menu = "section",
            kind = "Text",
            abbr = header,
          })
        end
      end

      local field_match = before_cursor:match("^(%w+):%s*$")
      if field_match then
        local fields = frontmatter_fields[item_type] or {}
        for _, field in ipairs(fields) do
          if field.word == field_match then
            local hints = Validator.get_hints(item_type, "frontmatter_fields")
            local hint = hints and hints[field.word] or field.info
            table.insert(matches, {
              word = hint or "",
              menu = field.menu,
              kind = "Value",
            })
          end
        end
      end

      if #matches > 0 then
        vim.fn.complete(col + 1, matches)
      end
    end,
  })

  local omnifunc = function(findstart, base)
    if findstart == 1 then
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
      local start = line:sub(1, col):find("[%w-]*$")
      return start and start - 1 or col
    end

    local matches = {}
    local fields = frontmatter_fields[item_type] or {}
    for _, field in ipairs(fields) do
      if field.word:lower():find(base:lower(), 1, true) then
        table.insert(matches, {
          word = field.word,
          menu = field.menu,
          info = field.info,
          kind = "Property",
        })
      end
    end

    for _, header in ipairs(section_headers) do
      local h = header:gsub("^##%s*", "")
      if h:lower():find(base:lower(), 1, true) then
        table.insert(matches, {
          word = h,
          menu = "section",
          kind = "Text",
        })
      end
    end

    return matches
  end

  vim.api.nvim_buf_set_option(buf, "omnifunc", "v:lua." .. vim.inspect(omnifunc):gsub("%s+", " "))
end

----------------------------------------------------------------------
-- Setup Diagnostics
----------------------------------------------------------------------
function M.setup_diagnostics(buf)
  local Validator = require("ai.skill_studio.validator")
  local ns = vim.api.nvim_create_namespace("skill_studio_diagnostics")

  local function validate_buffer()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local data = M.parse_buffer(lines)

    local result = Validator.validate(data)
    local diagnostics = {}

    for _, err in ipairs(result.errors) do
      local field = err:match("^([%w-]+):")
      local lnum = M.find_field_line(lines, field)
      if lnum then
        table.insert(diagnostics, {
          lnum = lnum,
          col = 0,
          message = err,
          severity = vim.diagnostic.severity.ERROR,
          source = "skill-studio",
        })
      end
    end

    for _, warn in ipairs(result.warnings) do
      table.insert(diagnostics, {
        lnum = 0,
        col = 0,
        message = warn,
        severity = vim.diagnostic.severity.WARN,
        source = "skill-studio",
      })
    end

    vim.diagnostic.set(ns, buf, diagnostics, {})
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    buffer = buf,
    callback = vim.schedule_wrap(validate_buffer),
  })

  validate_buffer()
end

----------------------------------------------------------------------
-- Parse Buffer
----------------------------------------------------------------------
function M.parse_buffer(lines)
  local data = {
    type = state.data.type,
    frontmatter = {},
    body = "",
  }

  local in_frontmatter = false
  local in_body = false
  local body_lines = {}

  for _, line in ipairs(lines) do
    if line:match("^## Frontmatter") then
      in_frontmatter = true
      in_body = false
    elseif line:match("^## Body") then
      in_frontmatter = false
      in_body = true
    elseif line:match("^──") then
      break
    elseif in_frontmatter and line:match("^%w+:") then
      local key, value = line:match("^(%w+):%s*(.*)$")
      if key and value then
        if value:match("^%[") then
          local items = {}
          for item in value:gmatch("[%w_-]+") do
            table.insert(items, item)
          end
          data.frontmatter[key] = items
        else
          data.frontmatter[key] = value
        end
      end
    elseif in_body then
      table.insert(body_lines, line)
    end
  end

  data.body = table.concat(body_lines, "\n")
  return data
end

----------------------------------------------------------------------
-- Find Field Line
----------------------------------------------------------------------
function M.find_field_line(lines, field)
  if not field then
    return nil
  end
  for i, line in ipairs(lines) do
    if line:match("^" .. field .. ":") then
      return i - 1
    end
  end
  return nil
end

----------------------------------------------------------------------
-- Setup Creator Keymaps
----------------------------------------------------------------------
function M.setup_creator_keymaps(buf, on_save)
  local function save()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local data = M.parse_buffer(lines)
    state.data.frontmatter = data.frontmatter
    state.data.body = data.body

    if on_save then
      local success = on_save(state.data)
      if success then
        close_win()
      end
    end
  end

  local function cancel()
    close_win()
  end

  local function show_help()
    local help_text = {
      "╔══════════════════════════════════════════════════════════════╗",
      "║                    Skill Studio Help                         ║",
      "╚══════════════════════════════════════════════════════════════╝",
      "",
      "Keymaps:",
      "  <C-s>     Save and close",
      "  <C-c>     Cancel and close",
      "  <Tab>     Trigger completion",
      "  <C-x><C-o> Omni completion (field names, sections)",
      "",
      "Frontmatter fields:",
      "  name:           Skill identifier (lowercase, hyphens)",
      "  description:    When to trigger (include 'when' or 'use')",
      "  version:        Semantic version (e.g., 1.0.0)",
      "",
      "Body sections (type ## to autocomplete):",
      "  ## When This Skill Applies  - Trigger conditions",
      "  ## Instructions             - Step-by-step guide",
      "  ## Examples                 - Usage examples",
      "",
      "Press any key to close this help",
    }
    local help_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_text)
    vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
    vim.api.nvim_buf_set_option(help_buf, "bufhidden", "wipe")

    local width = 70
    local height = #help_text
    vim.api.nvim_open_win(help_buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal",
      border = "rounded",
    })

    vim.api.nvim_buf_set_keymap(help_buf, "n", "<Esc>", "<cmd>close<cr>", { noremap = true })
    vim.api.nvim_buf_set_keymap(help_buf, "n", "q", "<cmd>close<cr>", { noremap = true })
    vim.api.nvim_buf_set_keymap(help_buf, "n", "<CR>", "<cmd>close<cr>", { noremap = true })
  end

  vim.api.nvim_buf_set_keymap(buf, "i", "<C-s>", "", { callback = save, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<C-s>", "", { callback = save, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<C-c>", "", { callback = cancel, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "i", "<C-c>", "", { callback = cancel, noremap = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "?", "", { callback = show_help, noremap = true, desc = "Show help" })
end

----------------------------------------------------------------------
-- Editor UI
----------------------------------------------------------------------
function M.open_editor(opts)
  opts = opts or {}
  local item = opts.item

  if not item then
    vim.notify("No item to edit", vim.log.levels.ERROR)
    return
  end

  state.mode = "editor"
  state.data = item

  local buf, win = create_float_win({
    title = string.format("Edit: %s", item.frontmatter and item.frontmatter.name or item.id or "unnamed"),
    filetype = "skill-studio-editor",
  })

  state.buf = buf
  state.win = win

  local lines = {
    "# Edit " .. item.type:gsub("^%l", string.upper),
    "",
    "## Metadata",
    string.format("ID: %s", item.id or "N/A"),
    string.format("Type: %s  |  Target: %s  |  Level: %s", item.type, item.target, item.level),
    "",
    "## Frontmatter",
  }

  if item.frontmatter then
    for key, value in pairs(item.frontmatter) do
      if type(value) == "table" then
        table.insert(lines, string.format("%s: [%s]", key, table.concat(value, ", ")))
      else
        table.insert(lines, string.format("%s: %s", key, value))
      end
    end
  end

  table.insert(lines, "")
  table.insert(lines, "## Body")
  table.insert(lines, "")

  if item.body then
    for line in item.body:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
  end

  table.insert(lines, "")
  table.insert(lines, "──" .. string.rep("─", 60) .. "──")
  table.insert(lines, "Press <C-s> to save  |  Press <C-c> to cancel")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)

  M.setup_creator_keymaps(buf, opts.on_save)
end

----------------------------------------------------------------------
-- Backup List UI
----------------------------------------------------------------------
function M.show_backup_list(backups, callbacks)
  callbacks = callbacks or {}

  local buf, win = create_float_win({
    title = "Skill Studio - Saved Items",
    width = math.floor(vim.o.columns * 0.95),
    height = math.floor(vim.o.lines * 0.75),
    filetype = "skill-studio-list",
  })

  state.buf = buf
  state.win = win
  state.mode = "list"
  state.data.backups = backups

  local lines = {
    "# Saved Items",
    "",
    "  Name                Type      Target    Level     Description",
    "  " .. string.rep("─", 90),
  }

  for _, backup in ipairs(backups) do
    local desc = backup.description or ""
    if #desc > 40 then
      desc = desc:sub(1, 37) .. "..."
    end
    local line = string.format(
      "  %-18s  %-8s  %-8s  %-8s  %s",
      backup.name:sub(1, 18),
      backup.type,
      backup.target,
      backup.level,
      desc
    )
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "──" .. string.rep("─", 90) .. "──")
  table.insert(lines, "<Enter> Edit  |  <D> Delete  |  <C> Convert  |  <L> Change Level  |  <q> Close")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = close_win,
    noremap = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    callback = function()
      local row = unpack(vim.api.nvim_win_get_cursor(0))
      if row > 4 and row <= 4 + #backups then
        local backup = backups[row - 4]
        if callbacks.on_select then
          close_win()
          callbacks.on_select(backup.id)
        end
      end
    end,
    noremap = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "D", "", {
    callback = function()
      local row = unpack(vim.api.nvim_win_get_cursor(0))
      if row > 4 and row <= 4 + #backups then
        local backup = backups[row - 4]
        if callbacks.on_delete then
          callbacks.on_delete(backup.id)
          M.refresh_list(buf, callbacks)
        end
      end
    end,
    noremap = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "C", "", {
    callback = function()
      local row = unpack(vim.api.nvim_win_get_cursor(0))
      if row > 4 and row <= 4 + #backups then
        local backup = backups[row - 4]
        vim.ui.select({ "claude", "opencode" }, { prompt = "Convert to:" }, function(choice)
          if choice and callbacks.on_convert then
            callbacks.on_convert(backup.id, choice)
          end
        end)
      end
    end,
    noremap = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "L", "", {
    callback = function()
      local row = unpack(vim.api.nvim_win_get_cursor(0))
      if row > 4 and row <= 4 + #backups then
        local backup = backups[row - 4]
        vim.ui.select({ "project", "global" }, { prompt = "Change level to:" }, function(choice)
          if choice and callbacks.on_change_level then
            callbacks.on_change_level(backup.id, choice)
          end
        end)
      end
    end,
    noremap = true,
  })
end

----------------------------------------------------------------------
-- Refresh List
----------------------------------------------------------------------
function M.refresh_list(buf, callbacks)
  local Backup = require("ai.skill_studio.backup")
  local backups = Backup.list()
  state.data.backups = backups

  local lines = {
    "# Saved Items",
    "",
    "  Name                Type      Target    Level     Description",
    "  " .. string.rep("─", 90),
  }

  for _, backup in ipairs(backups) do
    local desc = backup.description or ""
    if #desc > 40 then
      desc = desc:sub(1, 37) .. "..."
    end
    local line = string.format(
      "  %-18s  %-8s  %-8s  %-8s  %s",
      backup.name:sub(1, 18),
      backup.type,
      backup.target,
      backup.level,
      desc
    )
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "──" .. string.rep("─", 90) .. "──")
  table.insert(lines, "<Enter> Edit  |  <D> Delete  |  <C> Convert  |  <L> Change Level  |  <q> Close")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

----------------------------------------------------------------------
-- Show Review
----------------------------------------------------------------------
function M.show_review(review_result)
  local buf, win = create_float_win({
    title = "Skill Studio - Review",
    filetype = "skill-studio-review",
  })

  state.buf = buf
  state.win = win

  local lines = {
    "# Review Results",
    "",
    "## Status: " .. (review_result.valid and "✅ Valid" or "❌ Invalid"),
    "",
  }

  if #review_result.errors > 0 then
    table.insert(lines, "## Errors")
    for _, err in ipairs(review_result.errors) do
      table.insert(lines, "  ❌ " .. err)
    end
    table.insert(lines, "")
  end

  if #review_result.warnings > 0 then
    table.insert(lines, "## Warnings")
    for _, warn in ipairs(review_result.warnings) do
      table.insert(lines, "  ⚠️  " .. warn)
    end
    table.insert(lines, "")
  end

  if #review_result.suggestions > 0 then
    table.insert(lines, "## Suggestions")
    for _, sug in ipairs(review_result.suggestions) do
      table.insert(lines, "  💡 " .. sug)
    end
    table.insert(lines, "")
  end

  table.insert(lines, "──" .. string.rep("─", 60) .. "──")
  table.insert(lines, "Press <q> to close")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = close_win,
    noremap = true,
  })
end

----------------------------------------------------------------------
-- Show Conversion Preview
----------------------------------------------------------------------
function M.show_conversion_preview(preview_content, on_confirm)
  local buf, win = create_float_win({
    title = "Conversion Preview",
    filetype = "skill-studio-preview",
  })

  state.buf = buf
  state.win = win

  local lines = {}
  for line in preview_content:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "──" .. string.rep("─", 60) .. "──")
  table.insert(lines, "<Y> Confirm  |  <N> Cancel")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  vim.api.nvim_buf_set_keymap(buf, "n", "Y", "", {
    callback = function()
      close_win()
      if on_confirm then
        on_confirm(true)
      end
    end,
    noremap = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "N", "", {
    callback = function()
      close_win()
      if on_confirm then
        on_confirm(false)
      end
    end,
    noremap = true,
  })
end

return M
