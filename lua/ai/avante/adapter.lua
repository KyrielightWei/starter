-- lua/ai/avante/adapter.lua
-- Avante 适配器主模块（带构建检查）

local Config = require("ai.avante.config")
local Methods = require("ai.avante.methods")
local Builder = require("ai.avante.builder")
local State = require("ai.state")

local M = {}

-- 配置状态
local is_initialized = false

----------------------------------------------------------------------
-- initialize(): 初始化 Avante 后端
----------------------------------------------------------------------
function M.initialize(callback)
  -- 检查是否已构建
  if not Builder.check_built() then
    -- 未构建，弹出选择对话框
    Builder.prompt_build(function(built)
      if built then
        -- 构建完成，继续初始化
        M.do_initialize()
        if callback then callback(true) end
      else
        -- 用户跳过构建
        if callback then callback(false) end
      end
    end)
    return
  end
  
  -- 已构建，直接初始化
  M.do_initialize()
  if callback then callback(true) end
end

----------------------------------------------------------------------
-- do_initialize(): 执行实际初始化
----------------------------------------------------------------------
function M.do_initialize()
  if is_initialized then
    return
  end
  
  local ok, avante = pcall(require, "avante")
  if not ok then
    vim.notify("avante.nvim not found", vim.log.levels.ERROR)
    return
  end
  
  -- 构建配置
  local base_opts = Config.build()
  Methods.base_opts = base_opts
  
  -- 设置 avante
  local setup_ok, err = pcall(avante.setup, base_opts)
  if not setup_ok then
    vim.notify("Avante setup failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  
  -- 应用初始配置
  pcall(function()
    local Keys = require("ai.keys")
    local keys = Keys.read()
    if keys then
      local provider = base_opts.provider or "openai"
      local key = Keys.get_key(provider)
      local Util = require("ai.util")
      local env_var = Util.get_env_var(provider)
      vim.env[env_var] = key
      
      local final_model = base_opts.providers[provider] and base_opts.providers[provider].model
      State.set(provider, final_model)
    end
  end)
  
  is_initialized = true
end

----------------------------------------------------------------------
-- setup(): 主入口点
----------------------------------------------------------------------
function M.setup()
  -- 异步初始化（带构建检查）
  M.initialize(function(success)
    if success then
      vim.notify("Avante 后端初始化完成", vim.log.levels.INFO)
    end
  end)
  
  -- 返回包装后的方法
  return {
    -- 核心方法（需要构建）
    chat = Builder.wrap_function(Methods.chat, "chat"),
    chat_new = Builder.wrap_function(Methods.chat_new, "chat_new"),
    edit = Builder.wrap_function(Methods.edit, "edit"),
    ask = Builder.wrap_function(Methods.ask, "ask"),
    model_switch = Builder.wrap_function(Methods.model_switch, "model_switch"),
    sessions = Builder.wrap_function(Methods.sessions, "sessions"),
    
    -- 配置方法（不需要构建）
    key_manager = Methods.key_manager,
    toggle = function()
      if not Builder.check_built() then
        Builder.prompt_build(function(built)
          if built then Methods.toggle() end
        end)
        return
      end
      Methods.toggle()
    end,
    diff = Methods.diff,
    
    -- Suggestion 方法（需要构建）
    suggestion_next = Builder.wrap_function(Methods.suggestion_next, "suggestion_next"),
    suggestion_prev = Builder.wrap_function(Methods.suggestion_prev, "suggestion_prev"),
    suggestion_accept = Builder.wrap_function(Methods.suggestion_accept, "suggestion_accept"),
  }
end

return M
