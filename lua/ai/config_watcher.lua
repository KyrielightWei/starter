-- lua/ai/config_watcher.lua
-- 配置热更新：监听配置文件变化，自动重新生成

local M = {}

M.enabled = true
local debounce_timer = nil

local function should_trigger_update(filepath)
  local patterns = {
    "opencode.template.jsonc",
    "%.opencode.json$",
    "ai_keys.lua$",
  }

  for _, pattern in ipairs(patterns) do
    if filepath:match(pattern) then
      return true
    end
  end
  return false
end

local function do_sync()
  local ok, Sync = pcall(require, "ai.sync")
  if ok then
    Sync.sync_all({ silent = true })
  end

  local ok2, Resolver = pcall(require, "ai.config_resolver")
  if ok2 then
    Resolver.invalidate_cache()
  end
end

local function debounce_sync()
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
  end

  debounce_timer = vim.loop.new_timer()
  debounce_timer:start(500, 0, vim.schedule_wrap(function()
    do_sync()
    if debounce_timer then
      debounce_timer:close()
      debounce_timer = nil
    end
  end))
end

function M.watch()
  if M.enabled then
    return
  end
  M.enabled = true

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("AIConfigWatcher", { clear = true }),
    pattern = {
      "*/opencode.template.jsonc",
      "*/.opencode.json",
      "*/ai_keys.lua",
    },
    callback = function(event)
      if M.enabled and should_trigger_update(event.match) then
        debounce_sync()
      end
    end,
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("AIConfigWatcherDir", { clear = true }),
    pattern = "*",
    callback = function()
      if M.enabled then
        local ok, Resolver = pcall(require, "ai.config_resolver")
        if ok then
          Resolver.invalidate_cache()
        end
      end
    end,
  })

  vim.notify("AI config watcher enabled", vim.log.levels.INFO)
end

function M.unwatch()
  M.enabled = false
  pcall(vim.api.nvim_del_augroup_by_name, "AIConfigWatcher")
  pcall(vim.api.nvim_del_augroup_by_name, "AIConfigWatcherDir")

  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end

  vim.notify("AI config watcher disabled", vim.log.levels.INFO)
end

function M.toggle()
  if M.enabled then
    M.unwatch()
  else
    M.watch()
  end
end

function M.force_sync()
  do_sync()
  vim.notify("Config sync completed", vim.log.levels.INFO)
end

return M