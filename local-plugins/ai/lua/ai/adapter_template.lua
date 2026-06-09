-- lua/ai/adapter_template.lua
-- Adapter Template Documentation
--
-- This is a template for creating new backend adapters for the AI module.
-- Copy this file and modify it to create your own adapter.
--
-- ============================================================================
-- ADAPTER 开发指南
-- ============================================================================
--
-- 1. 文件命名: lua/ai/xxx_adapter.lua
-- 2. 注册方式: 在 lua/ai/init.lua 中设置 default_backend = "xxx"
-- 3. 必须实现的方法: 所有 backend_impl 中的方法
--
-- ============================================================================
-- 后端接口规范
-- ============================================================================
--
-- 所有适配器必须实现以下方法：
--
-- chat()           - 打开聊天窗口（侧边栏，复用之前的会话）
-- chat_new()       - 创建新聊天（侧边栏，全新会话）
-- edit()           - 编辑选中的代码
-- ask()            - 快速提问（显示浮动窗口）
-- model_switch()   - 模型切换
-- key_manager()    - Key 管理
-- sessions()       - 会话管理
-- toggle()         - 面板切换
-- diff()           - Diff 查看
-- suggestion_next() - 下一个 AI 建议（插入模式）
-- suggestion_prev() - 上一个 AI 建议（插入模式）
-- suggestion_accept() - 接受 AI 建议（插入模式）
--
-- ============================================================================

local M = {}

----------------------------------------------------------------------
-- 模块私有状态（根据你的后端需求定制）
----------------------------------------------------------------------
local is_initialized = false
local config = {}

----------------------------------------------------------------------
-- setup(): 初始化适配器
--
-- @return table: 后端实现表，包含所有必须的方法
----------------------------------------------------------------------
function M.setup()
  -- 检查依赖
  local ok, backend = pcall(require, "your-backend-plugin")
  if not ok then
    vim.notify("your-backend-plugin not found", vim.log.levels.ERROR)
    return nil
  end

  -- 初始化配置
  if not is_initialized then
    -- TODO: 设置你的后端配置
    backend.setup({
      -- 配置选项
    })
    is_initialized = true
  end

  -- 返回后端实现
  return {
    -- ======================================================================
    -- 核心交互方法
    -- ======================================================================

    -- chat(): 打开聊天窗口（侧边栏，复用之前的会话）
    chat = function()
      -- TODO: 实现聊天窗口打开逻辑
      -- 示例: backend.open_sidebar()
      vim.notify("chat() not implemented", vim.log.levels.WARN)
    end,

    -- chat_new(): 创建新聊天（侧边栏，全新会话）
    chat_new = function()
      -- TODO: 实现创建新聊天逻辑
      -- 示例: backend.close_sidebar(); backend.open_sidebar({ new = true })
      vim.notify("chat_new() not implemented", vim.log.levels.WARN)
    end,

    -- edit(): 编辑选中的代码
    edit = function()
      -- TODO: 实现编辑选中代码逻辑
      -- 示例: backend.edit_selection()
      vim.notify("edit() not implemented", vim.log.levels.WARN)
    end,

    -- ask(): 快速提问（显示浮动窗口）
    ask = function()
      -- TODO: 实现快速提问逻辑
      -- 示例: backend.open_floating_ask()
      vim.notify("ask() not implemented", vim.log.levels.WARN)
    end,

    -- ======================================================================
    -- 配置与管理方法
    -- ======================================================================

    -- model_switch(): 模型切换
    model_switch = function()
      -- TODO: 实现模型切换逻辑
      -- 建议使用 lua/ai/model_switch.lua
      local ModelSwitch = require("ai.model_switch")
      ModelSwitch.select(function(choice)
        -- 处理模型切换
        print("Switched to " .. choice.provider .. "/" .. choice.model)
      end)
    end,

    -- key_manager(): Key 管理
    key_manager = function()
      -- TODO: 实现 Key 管理界面
      -- 建议使用 lua/ai/keys.lua
      local Keys = require("ai.keys")
      Keys.edit()
    end,

    -- sessions(): 会话管理
    sessions = function()
      -- TODO: 实现会话管理逻辑
      -- 示例: backend.select_history()
      vim.notify("sessions() not implemented", vim.log.levels.WARN)
    end,

    -- ======================================================================
    -- UI 控制方法
    -- ======================================================================

    -- toggle(): 面板切换
    toggle = function()
      -- TODO: 实现面板切换逻辑
      -- 示例: backend.toggle()
      vim.notify("toggle() not implemented", vim.log.levels.WARN)
    end,

    -- diff(): Diff 查看
    diff = function()
      -- TODO: 实现 Diff 查看逻辑
      -- 示例: vim.cmd("Git diff") 或 backend.show_diff()
      vim.notify("diff() not implemented", vim.log.levels.WARN)
    end,

    -- ======================================================================
    -- Suggestion 方法（插入模式）
    -- ======================================================================

    -- suggestion_next(): 下一个 AI 建议
    suggestion_next = function()
      -- TODO: 实现下一个建议逻辑
      vim.notify("suggestion_next() not implemented", vim.log.levels.WARN)
    end,

    -- suggestion_prev(): 上一个 AI 建议
    suggestion_prev = function()
      -- TODO: 实现上一个建议逻辑
      vim.notify("suggestion_prev() not implemented", vim.log.levels.WARN)
    end,

    -- suggestion_accept(): 接受 AI 建议
    suggestion_accept = function()
      -- TODO: 实现接受建议逻辑
      vim.notify("suggestion_accept() not implemented", vim.log.levels.WARN)
    end,
  }
end

return M
