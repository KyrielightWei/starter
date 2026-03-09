-- lua/ai/sync.lua
-- 配置同步中心：统一管理 API Key 和 Provider 配置，同步到各 CLI 工具

local M = {}

local sync_targets = {
  opencode = {
    name = "OpenCode",
    enabled = true,
    sync = function()
      local ok, OpenCode = pcall(require, "ai.opencode")
      if ok and OpenCode.write_config then
        return OpenCode.write_config()
      end
      return false, "OpenCode module not found"
    end,
    check = function()
      return vim.fn.executable("opencode") == 1
    end,
  },
  claude_code = {
    name = "Claude Code",
    enabled = true,
    sync = function()
      local ok, ClaudeCode = pcall(require, "ai.claude_code")
      if ok and ClaudeCode.write_settings then
        return ClaudeCode.write_settings()
      end
      return false, "Claude Code module not found"
    end,
    check = function()
      return vim.fn.executable("claude") == 1
    end,
  },
}

function M.register_target(name, config)
  sync_targets[name] = vim.tbl_deep_extend("force", {
    name = name,
    enabled = true,
    sync = function()
      return false, "Not implemented"
    end,
    check = function()
      return true
    end,
  }, config)
end

function M.sync_all(opts)
  opts = opts or {}
  local results = {}
  local success_count = 0
  local fail_count = 0

  for name, target in pairs(sync_targets) do
    if target.enabled then
      local ok, err
      if target.check and not target.check() then
        ok = false
        err = "Tool not installed"
      else
        ok, err = target.sync()
      end

      results[name] = {
        name = target.name,
        success = ok == true,
        error = err,
      }

      if ok then
        success_count = success_count + 1
      else
        fail_count = fail_count + 1
      end
    end
  end

  if opts.silent then
    return results
  end

  local lines = { "Sync Results:" }
  for name, result in pairs(results) do
    local status = result.success and "✓" or "✗"
    local msg = result.success and "OK" or (result.error or "Failed")
    table.insert(lines, string.format("  %s %s: %s", status, result.name, msg))
  end

  local level = fail_count > 0 and vim.log.levels.WARN or vim.log.levels.INFO
  vim.notify(table.concat(lines, "\n"), level)

  return results
end

function M.sync_one(name, opts)
  opts = opts or {}
  local target = sync_targets[name]

  if not target then
    vim.notify("Unknown sync target: " .. name, vim.log.levels.ERROR)
    return false
  end

  if not target.enabled then
    vim.notify(target.name .. " sync is disabled", vim.log.levels.WARN)
    return false
  end

  local ok, err = target.sync()

  if not opts.silent then
    if ok then
      vim.notify(target.name .. " config synced successfully", vim.log.levels.INFO)
    else
      vim.notify(target.name .. " sync failed: " .. (err or "Unknown error"), vim.log.levels.ERROR)
    end
  end

  return ok
end

function M.get_status()
  local status = {}

  for name, target in pairs(sync_targets) do
    status[name] = {
      name = target.name,
      enabled = target.enabled,
      installed = target.check and target.check() or true,
    }
  end

  return status
end

function M.enable_target(name)
  if sync_targets[name] then
    sync_targets[name].enabled = true
    return true
  end
  return false
end

function M.disable_target(name)
  if sync_targets[name] then
    sync_targets[name].enabled = false
    return true
  end
  return false
end

function M.select_and_sync()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not installed, syncing all", vim.log.levels.WARN)
    return M.sync_all()
  end

  local items = {}
  local name_map = {}

  for name, target in pairs(sync_targets) do
    if target.enabled then
      local installed = target.check and target.check() or true
      local status = installed and "installed" or "not installed"
      local display = string.format("%-20s │ %s", target.name, status)
      table.insert(items, display)
      name_map[display] = name
    end
  end

  if #items == 0 then
    vim.notify("No sync targets available", vim.log.levels.WARN)
    return
  end

  fzf.fzf_exec(items, {
    prompt = "Select tool to sync> ",
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          local name = name_map[selected[1]]
          if name then
            M.sync_one(name)
          end
        end
      end,
      ["ctrl-a"] = function()
        M.sync_all()
      end,
    },
  })
end

function M.export_keys()
  local Keys = require("ai.keys")
  local Providers = require("ai.providers")

  local keys_data = Keys.read() or {}
  local exported = {}

  for provider_name, provider_def in pairs(Providers) do
    if type(provider_def) == "table" and provider_def.api_key_name then
      local key = Keys.get_key(provider_name)
      if key and key ~= "" then
        exported[provider_def.api_key_name] = key
      end
    end
  end

  return exported
end

function M.export_to_env_file(path)
  local exported = M.export_keys()
  local lines = {}

  for env_var, value in pairs(exported) do
    table.insert(lines, string.format("export %s='%s'", env_var, value))
  end

  table.sort(lines)

  path = path or vim.fn.stdpath("config") .. "/ai_env.sh"
  vim.fn.writefile(lines, path)

  vim.notify("Exported " .. #lines .. " keys to " .. path, vim.log.levels.INFO)

  return path
end

return M