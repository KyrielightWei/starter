-- lua/ai/init.lua
-- AI 模块入口
--
-- 命令和键映射在 plugin/ai.lua 中注册（唯一注册点）。
-- 本模块只负责子系统初始化。

local M = {}

----------------------------------------------------------------------
-- 配置函数
----------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}

  -- 初始化路径模块
  local ok_paths, Paths = pcall(require, "ai.paths")
  if ok_paths then
    Paths.setup(opts)
  end

  -- Load Provider Manager subsystem
  local ok_pm, ProviderManager = pcall(require, "ai.provider_manager")
  if ok_pm then
    ProviderManager.setup()
  end

  -- Initialize Commit Picker
  local ok_cp, CommitPicker = pcall(require, "commit_picker.init")
  if ok_cp then
    CommitPicker.setup()
  end

  -- Ensure default prompt files exist
  local ok_sp, SystemPrompt = pcall(require, "ai.system_prompt")
  if ok_sp and SystemPrompt.ensure_default_files then
    SystemPrompt.ensure_default_files()
  end

  return M
end

return M
