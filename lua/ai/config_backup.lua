-- lua/ai/config_backup.lua
-- Config Backup Manager - backup rotation and restore

local M = {}

----------------------------------------------------------------------
-- Private: Get backup directory for tool
----------------------------------------------------------------------
local function get_backup_dir(tool)
  if tool == "opencode" then
    local xdg_config = os.getenv("XDG_CONFIG_HOME") or vim.fn.expand("~/.config")
    return xdg_config .. "/opencode"
  elseif tool == "claude_code" then
    return vim.fn.expand("~/.claude")
  end
  return nil
end

----------------------------------------------------------------------
-- Private: Get config file path for tool
----------------------------------------------------------------------
local function get_config_path(tool)
  local dir = get_backup_dir(tool)
  if not dir then
    return nil
  end
  if tool == "opencode" then
    return dir .. "/opencode.json"
  elseif tool == "claude_code" then
    return dir .. "/settings.json"
  end
  return nil
end

----------------------------------------------------------------------
-- Private: Get backup file paths (bak1, bak2)
----------------------------------------------------------------------
local function get_backup_paths(tool)
  local config_path = get_config_path(tool)
  if not config_path then
    return {}
  end
  return {
    config_path .. ".bak1",
    config_path .. ".bak2",
  }
end

----------------------------------------------------------------------
-- backup(tool): 创建备份（最多保留 2 份）
-- @param tool string: 工具名称
-- @return boolean, string: 成功状态, 结果消息
----------------------------------------------------------------------
function M.backup(tool)
  local config_path = get_config_path(tool)
  if not config_path then
    return false, "Unknown tool: " .. tool
  end

  -- Check if config exists
  if vim.fn.filereadable(config_path) == 0 then
    return true, "No existing config to backup"
  end

  local bak1, bak2 = unpack(get_backup_paths(tool))

  -- Rotate backups: delete bak2, rename bak1 to bak2, create new bak1
  if vim.fn.filereadable(bak2) == 1 then
    vim.fn.delete(bak2)
  end
  if vim.fn.filereadable(bak1) == 1 then
    vim.fn.rename(bak1, bak2)
  end

  -- Copy current config to bak1
  vim.fn.writefile(vim.fn.readfile(config_path), bak1)

  return true, bak1
end

----------------------------------------------------------------------
-- restore(tool, backup_num): 从备份恢复配置
-- @param tool string: 工具名称
-- @param backup_num number: 备份编号 (1 或 2)
-- @return boolean, string: 成功状态, 结果消息
----------------------------------------------------------------------
function M.restore(tool, backup_num)
  backup_num = backup_num or 1
  local config_path = get_config_path(tool)
  local backup_paths = get_backup_paths(tool)
  local backup_path = backup_paths[backup_num]

  if not backup_path then
    return false, "Invalid backup number"
  end

  if vim.fn.filereadable(backup_path) == 0 then
    return false, "Backup not found: " .. backup_path
  end

  -- Restore backup to config path
  vim.fn.writefile(vim.fn.readfile(backup_path), config_path)

  return true, "Restored from backup " .. backup_num
end

----------------------------------------------------------------------
-- get_backup_info(tool): 获取备份信息
-- @param tool string: 工具名称
-- @return table|nil: 备份信息 { current, bak1, bak2 }
----------------------------------------------------------------------
function M.get_backup_info(tool)
  local config_path = get_config_path(tool)
  local bak1, bak2 = unpack(get_backup_paths(tool))

  if vim.fn.filereadable(config_path) == 0 then
    return nil
  end

  return {
    current = config_path,
    bak1 = vim.fn.filereadable(bak1) == 1 and bak1 or nil,
    bak2 = vim.fn.filereadable(bak2) == 1 and bak2 or nil,
  }
end

----------------------------------------------------------------------
-- show_overwrite_warning(tool): 显示覆盖警告
-- @param tool string: 工具名称
----------------------------------------------------------------------
function M.show_overwrite_warning(tool)
  local info = M.get_backup_info(tool)
  if info and info.bak1 then
    vim.notify(
      string.format(
        "Config backed up to: %s\nUse :%sRestoreBackup to restore",
        info.bak1,
        tool == "opencode" and "OpenCode" or "ClaudeCode"
      ),
      vim.log.levels.INFO
    )
  end
end

return M
