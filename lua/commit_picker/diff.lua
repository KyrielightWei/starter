-- lua/commit_picker/diff.lua
-- Diff integration — opens diffview with selected commit range

local M = {}

----------------------------------------------------------------------
-- Validate SHA format: 7-40 hex characters (T-04-05 mitigation)
----------------------------------------------------------------------
function M.is_valid_sha(sha)
  return sha and sha:match("^%x%x%x%x%x%x%x+$")
end

----------------------------------------------------------------------
-- M.open_diff(shas)
-- 1 SHA  → DiffviewOpenEnhanced sha^..sha (single commit diff against parent)
-- 2 SHAs → DiffviewOpenEnhanced sha1..sha2 (range diff between commits)
-- Opens in current tab (D-07), uses existing diffview config (D-09)
----------------------------------------------------------------------
function M.open_diff(shas)
  if not shas or #shas == 0 then
    vim.notify("请先选择 commit", vim.log.levels.WARN)
    return
  end

  -- Validate all SHAs before passing to vim.cmd (T-04-05)
  for _, sha in ipairs(shas) do
    if not M.is_valid_sha(sha) then
      vim.notify("无效的 SHA 格式: " .. sha, vim.log.levels.ERROR)
      return
    end
  end

  -- Check if diffview.nvim is available
  local ok = pcall(require, "diffview")
  if not ok then
    vim.notify("diffview.nvim 未配置，请手动运行 :DiffviewOpen", vim.log.levels.WARN)
    return
  end

  -- Check if diffview is already open (WR-03 fix)
  -- Use vim.cmd to check — safer than direct API access across diffview versions
  local already_open = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local bufname = vim.api.nvim_buf_get_name(buf)
    if bufname:match("diffview") then
      already_open = true
      break
    end
  end
  if already_open then
    vim.notify("Diffview 已打开，请先关闭当前 diff", vim.log.levels.INFO)
    return
  end

   -- Skip secondary guard — the buffer-name check at lines 42-49 already handles
  -- the common case. The diffview.lib API varies across versions, so we avoid
  -- relying on it directly (UAT bug fix).

  local range

  if #shas == 1 then
    -- Single commit: diff against parent (D-03, D-08)
    local sha = shas[1]
    range = sha .. "^.." .. sha
  elseif #shas >= 2 then
    -- Range diff between two commits (D-03, D-08)
    -- Use first two selected
    range = shas[1] .. ".." .. shas[2]
  else
    vim.notify("请选择 1 或 2 个 commit", vim.log.levels.WARN)
    return
  end

  -- Use DiffviewOpenEnhanced to preserve worktree support (D-09)
  -- This command is defined in lua/plugins/git.lua with dynamic git_cmd
  local ok2, err = pcall(vim.cmd, "DiffviewOpenEnhanced " .. range)
  if not ok2 then
    vim.notify("打开 diffview 失败: " .. err, vim.log.levels.ERROR)
  end
end

return M
