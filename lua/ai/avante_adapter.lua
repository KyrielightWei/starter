-- lua/ai/avante_adapter.lua
-- Avante.nvim 适配器入口
--
-- 使用模块化设计和构建管理器
-- 提供：
--   - 优雅的构建提示（弹出对话框选择）
--   - 构建进度显示
--   - 未构建时优雅降级

local Adapter = require("ai.avante.adapter")

local M = {}

----------------------------------------------------------------------
-- setup(): 初始化 Avante 后端
----------------------------------------------------------------------
function M.setup()
  return Adapter.setup()
end

return M
