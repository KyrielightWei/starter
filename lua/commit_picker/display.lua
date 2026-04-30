-- lua/commit_picker/display.lua
-- fzf-lua commit picker with colored SHA, multi-select, and preview
-- Phase 5: adds base_commit highlighting
-- Phase 6+: adds inline Set Base / Config actions

local M = {}

-- Guard: check fzf-lua availability
local ok, fzf = pcall(require, "fzf-lua")
if not ok then
  vim.notify("[commit_picker] fzf-lua not installed", vim.log.levels.ERROR)
  return {
    show_picker = function() vim.notify("fzf-lua 未安装，无法显示 picker", vim.log.levels.ERROR) end,
    close = function() end,
  }
end

-- ANSI color codes embedded in display strings for colored SHA (D-05)
-- fzf-lua renders ANSI escapes in display lines
local SHA_COLOR = "\27[38;5;111m"
local BASE_COLOR = "\27[38;5;220m"  -- Yellow for base commit marker
local RESET       = "\27[0m"
local DIM         = "\27[2m"
local GREEN       = "\27[38;5;114m"
local CYAN        = "\27[38;5;111m"

----------------------------------------------------------------------
-- Internal: open base commit picker → saves selection & returns
----------------------------------------------------------------------
local function open_base_picker(on_refresh)
  local ok, Git = pcall(require, "commit_picker.git")
  if not ok then return end

  local commits = Git.get_commit_list(nil, "HEAD", { count = 100 })
  if not commits or #commits == 0 then
    vim.notify("没有找到提交，无法选择基础提交", vim.log.levels.WARN)
    return
  end

  local cfg_ok, Config = pcall(require, "commit_picker.config")

  local items = {}
  local sha_map = {}

  -- Clear option
  local clear_display = DIM .. "⟳  清除基础提交 (设为 nil)" .. RESET
  table.insert(items, clear_display)
  sha_map[clear_display] = "__CLEAR__"

  for _, c in ipairs(commits) do
    local display = string.format("[%s]  %s  (%s)", c.short_sha, c.subject, c.date)
    table.insert(items, display)
    sha_map[display] = c.sha
  end

  fzf.fzf_exec(items, {
    prompt = " Select Base Commit > ",
    winopts = {
      width = 0.6,
      height = 0.4,
      preview = { layout = "vertical", vertical = "down:40%" },
    },
    fzf_opts = { ["--header"] = string.format("%s <Enter> Select  %s <Esc> Cancel", "<Enter>", "<Esc>") },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local sha = sha_map[selected[1]]
        if sha == "__CLEAR__" then
          if cfg_ok and Config then
            local raw = Config.get_config()
            local new_cfg = {}
            for k, v in pairs(raw) do new_cfg[k] = v end
            new_cfg.base_commit = nil
            new_cfg.mode = "unpushed"
            Config.save_config(new_cfg)
            Config.invalidate_cache()
          end
          vim.notify("基础提交已清除", vim.log.levels.INFO)
        elseif sha and sha:match("^%x%x%x%x%x%x%x[%x]*$") then
          if cfg_ok and Config then
            local raw = Config.get_config()
            local new_cfg = {}
            for k, v in pairs(raw) do new_cfg[k] = v end
            new_cfg.base_commit = sha
            new_cfg.mode = "since_base"
            Config.save_config(new_cfg)
            Config.invalidate_cache()
          end
          vim.notify(string.format("基础提交已设置为 %s", sha:sub(1, 7)), vim.log.levels.INFO)
        end

        -- Refresh the main picker to reflect the new base
        if on_refresh then vim.schedule(on_refresh) end
      end,
    },
    preview = function(selected)
      if not selected then return "" end
      local line = type(selected) == "table" and selected[1] or selected
      local sh = line:match("^%[([%x]+)%]")
      if not sh then return "" end
      local result = vim.system({ "git", "show", sh, "--stat" }):wait()
      return result.stdout or ""
    end,
  })
end

----------------------------------------------------------------------
-- M.show_picker(commits, opts)
-- commits: array of { sha, short_sha, subject, date, refs }
-- opts: {
--   prompt, on_select, base_commit,
--   on_action,        -- callback(action_name) for Set Base, Config, Help
--   refresh_picker,   -- function() → reopen picker after base/settings change
-- }
----------------------------------------------------------------------
function M.show_picker(commits, opts)
  opts = opts or {}

  -- Empty state: show notification, do not open empty picker
  if not commits or #commits == 0 then
    vim.notify("没有可显示的提交", vim.log.levels.WARN)
    return
  end

  -- Preview cache: scoped to show_picker call to avoid stale data across invocations
  local preview_cache = {}
  local PREVIEW_CACHE_MAX = 100

  -- Shortcut hints header (Ctrl+B/C/? are custom fzf-lua actions in addition to visible rows)
  local hints = string.format(
    "<Enter>: Diff  <Ctrl+Space>: Select  <Ctrl+B>: Base  <Ctrl+C>: Config  <Ctrl+?>: Help"
  )

  -- Visible action items at the top
  local display_lines = {
    string.format("%s⚡%s  %s [b]%s  设为基础提交 (Set Base)",        GREEN, RESET, DIM, RESET),
    string.format("%s⚙%s  %s [c]%s  打开配置面板 (Config)",           CYAN,  RESET, DIM, RESET),
    string.format("%s❓%s  %s [?]%s  帮助 (Help)",                      DIM,   RESET, DIM, RESET),
    string.format("%s──────────────────────────────────────────────%s",  DIM,   RESET),
  }
  local sha_map = {}
  sha_map[display_lines[1]] = "__ACTION_BASE__"
  sha_map[display_lines[2]] = "__ACTION_CONFIG__"
  sha_map[display_lines[3]] = "__ACTION_HELP__"

  -- Build commit display lines with formatted SHA, subject, date
  for _, c in ipairs(commits) do
    local sha_colored = SHA_COLOR .. "[" .. c.short_sha .. "]" .. RESET
    local refs_part = c.refs ~= "" and string.format(", %s", c.refs) or ""
    local display

    if opts.base_commit and c.sha == opts.base_commit then
      display = string.format(
        "%s base %s | %s  %s  (%s%s)",
        BASE_COLOR, RESET, sha_colored, c.subject, c.date, refs_part
      )
    else
      display = string.format(
        "%s  %s  (%s%s)",
        sha_colored, c.subject, c.date, refs_part
      )
    end

    table.insert(display_lines, display)
    sha_map[display] = c.sha
    local plain = string.format("[%s]  %s  (%s%s)", c.short_sha, c.subject, c.date, refs_part)
    if plain ~= display then sha_map[plain] = c.sha end
  end

  -- fzf-lua picker with multi-select and preview
  fzf.fzf_exec(display_lines, {
    prompt = opts.prompt or " Commit Picker > ",
    winopts = {
      width  = 0.6, -- D-12
      height = 0.4, -- D-12
      preview = { layout = "vertical", vertical = "down:40%" },
    },
    fzf_opts = {
      -- Only fzf built-in bindings here; custom key actions go in actions table below
      ["--bind"]   = "ctrl-space:toggle,ctrl-a:toggle-all",
      ["--header"] = hints,
    },
    actions = {
      -- Ctrl+B: open base commit picker
      ["ctrl-b"] = function()
        open_base_picker(opts.refresh_picker)
      end,
      -- Ctrl+C: open settings/config panel
      ["ctrl-c"] = function()
        if opts.on_action then opts.on_action("config") end
      end,
      -- Ctrl+/: show help popup
      ["ctrl-/"] = function()
        if opts.on_action then opts.on_action("help") end
      end,

      -- <CR>: extract SHAs from selected lines and invoke callback (D-13)
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        -- Check if user selected one of the visible action rows
        local picked = sha_map[selected[1]]
        if picked == "__ACTION_BASE__" then
          open_base_picker(opts.refresh_picker)
          return
        end
        if picked == "__ACTION_CONFIG__" then
          if opts.on_action then opts.on_action("config") end
          return
        end
        if picked == "__ACTION_HELP__" then
          if opts.on_action then opts.on_action("help") end
          return
        end

        -- Normal commit selection
        local shas = {}
        for _, line in ipairs(selected) do
          local full_sha = sha_map[line]
          if full_sha and not full_sha:match("^__ACTION") then
            table.insert(shas, full_sha)
          else
            local short = line:gsub("\27%[[^m]*m", ""):match("^%[([%x]+)%]")
            if short then
              for d, sha in pairs(sha_map) do
                if (d:match("^%[" .. short .. "%]") or d:match(short)) and not sha:match("^__ACTION") then
                  table.insert(shas, sha)
                  break
                end
              end
            end
          end
        end
        if #shas > 0 and opts.on_select then opts.on_select(shas) end
      end,
    },

    -- Preview: scoped to this picker invocation (avoids stale data across reopen)
    preview = function(selected)
      if not selected or #selected == 0 then return "" end
      local line = type(selected) == "table" and selected[1] or selected
      local clean_line = line:gsub("\27%[[^m]*m", "")
      local sha = clean_line:match("^%[([%x]+)%]") or line:match("^%[([%x]+)%]")
      if sha then
        -- Prefer sha_map, fallback to extracted hex or original
        sha = sha_map[line] or sha_map[clean_line] or sha
      end
      if not sha or sha:match("^__ACTION") then return "" end

      if preview_cache[sha] then return preview_cache[sha] end

      -- Evict overflow
      local count = 0
      for _ in pairs(preview_cache) do count = count + 1 end
      if count >= PREVIEW_CACHE_MAX then
        local key = next(preview_cache)
        preview_cache[key] = nil
      end

      local result = vim.system({ "git", "show", sha, "--stat" }):wait()
      local output = result.stdout or ""
      preview_cache[sha] = output
      return output
    end,
  })
end

----------------------------------------------------------------------
-- M.close()
-- Closes picker (fzf-lua has no explicit close; no-op with notification)
----------------------------------------------------------------------
function M.close()
  -- fzf-lua pickers close on <Esc> by default (D-14)
  -- This function is a no-op stub for API completeness
end

return M
