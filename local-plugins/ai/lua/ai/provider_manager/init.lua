-- lua/ai/provider_manager/init.lua
-- Provider Manager subsystem orchestrator
-- 命令和键映射在 plugin/ai.lua 中注册

local M = {}

local Picker = require("ai.provider_manager.picker")
local Detector = require("ai.provider_manager.detector")
local Results = require("ai.provider_manager.results")
local Status = require("ai.provider_manager.status")

----------------------------------------------------------------------
-- Setup (命令和键映射在 plugin/ai.lua 中注册)
----------------------------------------------------------------------
function M.setup(opts)
  return M
end

----------------------------------------------------------------------
-- Direct access for manual invocation
----------------------------------------------------------------------
M.open = Picker.open
M.show_help = Picker.show_help

-- Detection exports
M.check_provider = function(provider_name, callback)
  Detector.check_provider(provider_name, function(r)
    Results.show_single_result(r, "Detection Result: " .. provider_name)
    if callback then
      callback(r)
    end
  end)
end

M.check_all = function(callback)
  Detector.check_all_providers(function(results)
    Results.show_results(results, "All Providers Detection")
    if callback then
      callback(results)
    end
  end)
end

-- Status module exports
M.get_cached_status = Status.get_cached_status
M.trigger_async_check = Status.trigger_async_check
M.check_all_batch = Status.check_all_batch

return M
