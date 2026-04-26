-- lua/commit_picker/display.lua
-- fzf-lua commit picker with colored SHA, multi-select, and preview
-- Phase 5: adds base_commit highlighting

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
local RESET = "\27[0m"

----------------------------------------------------------------------
-- M.show_picker(commits, opts)
-- commits: array of { sha, short_sha, subject, date, refs }
-- opts: { prompt, on_select, base_commit } where on_select receives array of SHAs
--   base_commit: optional full SHA string for highlighting the base commit
----------------------------------------------------------------------
function M.show_picker(commits, opts)
  opts = opts or {}

  -- Empty state: show notification, do not open empty picker
  if not commits or #commits == 0 then
    vim.notify("没有可显示的提交", vim.log.levels.WARN)
    return
  end

  -- Build display lines with format: [short_sha] subject (date, refs)
  -- Embed ANSI color in display string for colored SHA (CR-01 fix)
  -- Phase 5: highlight base commit with ★ marker
  local display_lines = {}
  local sha_map = {}
  for _, c in ipairs(commits) do
    local sha_colored = SHA_COLOR .. "[" .. c.short_sha .. "]" .. RESET
    local refs_part = c.refs ~= "" and string.format(", %s", c.refs) or ""
    local display

    -- Check if this commit matches base_commit
    if opts.base_commit and c.sha == opts.base_commit then
      -- Highlight base commit with marker and different color
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
    -- Also map the plain version for SHA extraction fallback
    local plain = string.format("[%s]  %s  (%s%s)", c.short_sha, c.subject, c.date, refs_part)
    if plain ~= display then
      sha_map[plain] = c.sha
    end
  end

  -- fzf-lua picker with multi-select and preview
  fzf.fzf_exec(display_lines, {
    prompt = opts.prompt or " Commit Picker > ",
    winopts = {
      width = 0.6,     -- 60% width (D-12)
      height = 0.4,    -- 40% height (D-12)
      preview = {
        layout = "vertical",
        vertical = "down:40%",
      },
    },
    fzf_opts = {
      -- Multi-select bindings (D-11): ctrl-space toggles, ctrl-a toggles all
      ["--bind"] = "ctrl-space:toggle,ctrl-a:toggle-all",
    },
    actions = {
      -- <CR>: extract SHAs from selected lines and invoke callback (D-13)
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local shas = {}
        for _, line in ipairs(selected) do
          -- fzf-lua strips ANSI codes on selection, try direct lookup first
          local full_sha = sha_map[line]
          if full_sha then
            table.insert(shas, full_sha)
          else
            -- Fallback: extract SHA from ANSI-escaped line using pattern
            -- Line format: ESC[38;5;111m[abcd123]ESC[0m  subject  (date)
            local short = line:gsub("\27%[[^m]*m", ""):match("^%[([%x]+)%]")
            if short then
              -- We have the short SHA but need full SHA — find it by matching
              for display, sha in pairs(sha_map) do
                if display:match("^%[" .. short .. "%]") or display:match(short) then
                  full_sha = sha
                  table.insert(shas, full_sha)
                  break
                end
              end
            end
          end
        end
        if opts.on_select then
          opts.on_select(shas)
        end
      end,
    },
    -- Preview: show commit stat with caching for performance (WR-04 fix)
    preview = (function()
        local preview_cache = {}
        local PREVIEW_CACHE_MAX = 100
        return function(selected)
          if not selected or #selected == 0 then return "" end
          local line = type(selected) == "table" and selected[1] or selected
          local clean_line = line:gsub("\27%[[^m]*m", "")
          local sha = clean_line:match("^%[([%x]+)%]") or line:match("^%[([%x]+)%]")
          if sha then
            sha = sha_map[line] or sha_map[clean_line] or sha
          end
          if not sha then return "" end

          if preview_cache[sha] then
            return preview_cache[sha]
          end

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
        end
    end)(),
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
