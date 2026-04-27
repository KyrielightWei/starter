-- lua/ai/avante/methods.lua
-- Avante 后端方法实现

local Keys = require("ai.keys")
local State = require("ai.state")
local Util = require("ai.util")
local ModelSwitch = require("ai.model_switch")

local M = {}

-- 共享配置（由 adapter.lua 设置）
M.base_opts = nil

----------------------------------------------------------------------
-- apply_config(): 应用 API key 和 provider 配置
----------------------------------------------------------------------
function M.apply_config(avante, opts, force_setup)
  local keys = Keys.read()
  if not keys then return end

  local state = State.get()
  local provider = state.provider or opts.provider or "openai"

  local key = Keys.get_key(provider)
  local env_var = Util.get_env_var(provider)

  vim.env[env_var] = key

  local final_model = state.model
    or (opts.providers[provider] and opts.providers[provider].model)

  if force_setup then
    local new_opts = vim.deepcopy(opts)
    new_opts.provider = provider
    new_opts.providers[provider] = Util.merge_table(new_opts.providers[provider] or {}, {
      api_key = key,
      model = final_model,
    })
    avante.setup(new_opts)
  end

  State.set(provider, final_model)
end

----------------------------------------------------------------------
-- chat(): 打开聊天窗口
----------------------------------------------------------------------
function M.chat()
  local ok, avante = pcall(require, "avante")
  if not ok then
    vim.notify("avante.nvim not found", vim.log.levels.ERROR)
    return
  end
  
  local ok2, err = pcall(avante.open_sidebar, { ask = false })
  if not ok2 then
    -- 如果是构建相关错误，返回 false 让 wrapper 处理
    if tostring(err):find("avante_templates") then
      error("NEED_BUILD")
    end
    vim.notify("打开聊天窗口失败: " .. tostring(err), vim.log.levels.ERROR)
  end
end

----------------------------------------------------------------------
-- chat_new(): 创建新聊天
----------------------------------------------------------------------
function M.chat_new()
  local ok, avante = pcall(require, "avante")
  if not ok then
    vim.notify("avante.nvim not found", vim.log.levels.ERROR)
    return
  end
  
  pcall(avante.close_sidebar)
  vim.defer_fn(function()
    local ok2, err = pcall(avante.open_sidebar, { ask = false })
    if ok2 then
      vim.defer_fn(function()
        local sidebar = avante.get()
        if sidebar and sidebar.new_chat then
          sidebar:new_chat()
        end
      end, 100)
    elseif tostring(err):find("avante_templates") then
      error("NEED_BUILD")
    else
      vim.notify("打开聊天窗口失败: " .. tostring(err), vim.log.levels.ERROR)
    end
  end, 50)
end

----------------------------------------------------------------------
-- edit(): 编辑选中代码
----------------------------------------------------------------------
function M.edit()
  local ok, api = pcall(require, "avante.api")
  if not ok then
    vim.notify("avante.api not found", vim.log.levels.ERROR)
    return
  end
  
  local ok2, avante = pcall(require, "avante")
  if ok2 then
    M.apply_config(avante, M.base_opts)
    local ok3, err = pcall(api.edit)
    if not ok3 and tostring(err):find("avante_templates") then
      error("NEED_BUILD")
    end
  end
end

----------------------------------------------------------------------
-- ask(): 快速提问
----------------------------------------------------------------------
function M.ask()
  local ok, api = pcall(require, "avante.api")
  if not ok then
    vim.notify("avante.api not found", vim.log.levels.ERROR)
    return
  end
  
  local ok2, avante = pcall(require, "avante")
  if ok2 then
    M.apply_config(avante, M.base_opts)
    local ok3, err = pcall(api.ask)
    if not ok3 and tostring(err):find("avante_templates") then
      error("NEED_BUILD")
    end
  end
end

----------------------------------------------------------------------
-- model_switch(): 模型切换
----------------------------------------------------------------------
function M.model_switch()
  local ok, avante = pcall(require, "avante")
  if not ok then return end

  ModelSwitch.select(function(choice)
    if M.base_opts and M.base_opts.providers[choice.provider] then
      M.base_opts.providers[choice.provider].model = choice.model
      M.apply_config(avante, M.base_opts, true)
      vim.notify("已切换到 " .. choice.provider .. " / " .. choice.model, vim.log.levels.INFO)
    end
  end)
end

----------------------------------------------------------------------
-- key_manager(): API Key 管理
----------------------------------------------------------------------
function M.key_manager()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua not installed", vim.log.levels.WARN)
    Keys.edit()
    return
  end

  local tbl = Keys.ensure()
  local items = {}

  for provider, profiles in pairs(tbl) do
    if provider ~= "profile" and type(profiles) == "table" then
      for profile, config in pairs(profiles) do
        local has_key = type(config) == "table" and config.api_key and config.api_key ~= ""
        local status = has_key and "***" or "(empty)"
        table.insert(items, string.format("%-12s │ %-10s │ %s", provider, profile, status))
      end
    end
  end

  fzf.fzf_exec(items, {
    prompt = "AI Keys> ",
    actions = {
      ["default"] = function()
        vim.cmd("edit " .. vim.fn.stdpath("state") .. "/ai_keys.lua")
      end,
      ["ctrl-s"] = function(selected)
        if not selected or not selected[1] then return end
        local provider, profile = selected[1]:match("^(%S+)%s+│%s+(%S+)")
        if provider and profile then
          local read_tbl = Keys.read()
          if read_tbl then
            read_tbl.profile = profile
            Keys.write(read_tbl)
            vim.notify("已切换到 profile: " .. profile, vim.log.levels.INFO)
          end
        else
          vim.notify("无法解析选择项", vim.log.levels.WARN)
        end
      end,
    },
  })
end

----------------------------------------------------------------------
-- sessions(): 会话管理
----------------------------------------------------------------------
function M.sessions()
  local ok, api = pcall(require, "avante.api")
  if ok and api.select_history then
    local ok2, err = pcall(api.select_history)
    if not ok2 and tostring(err):find("avante_templates") then
      error("NEED_BUILD")
    end
    return
  end

  local ok2, fzf = pcall(require, "fzf-lua")
  if not ok2 then
    vim.notify("fzf-lua 不可用", vim.log.levels.WARN)
    return
  end

  local dir = vim.fn.stdpath("data") .. "/avante/sessions"
  if vim.fn.isdirectory(dir) == 0 then
    vim.notify("没有会话目录", vim.log.levels.INFO)
    return
  end

  local sessions = vim.fn.glob(dir .. "/*.json", false, true)
  if #sessions == 0 then
    vim.notify("没有找到会话", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, path in ipairs(sessions) do
    local name = vim.fn.fnamemodify(path, ":t:r")
    local time = os.date("%Y-%m-%d %H:%M", vim.fn.getftime(path))
    table.insert(items, string.format("%-30s │ %s │ %s", name, time, path))
  end

  fzf.fzf_exec(items, {
    prompt = "Sessions> ",
    actions = {
      ["default"] = function(selected)
        if not selected or not selected[1] then return end
        local path = selected[1]:match("│%s*(.+)$")
        if path then
          local avante = require("avante")
          avante.open_sidebar({ ask = false })
          pcall(avante.load_session, path)
        end
      end,
      ["ctrl-d"] = function(selected)
        if not selected or not selected[1] then return end
        local path = selected[1]:match("│%s*(.+)$")
        if path then
          os.remove(path)
          vim.notify("已删除会话: " .. path, vim.log.levels.INFO)
        end
      end,
    },
  })
end

----------------------------------------------------------------------
-- toggle(): 切换面板
----------------------------------------------------------------------
function M.toggle()
  local ok, err = pcall(vim.cmd, "AvanteToggle")
  if not ok and tostring(err):find("avante_templates") then
    error("NEED_BUILD")
  end
end

----------------------------------------------------------------------
-- diff(): 查看差异 — 使用 DiffviewOpenEnhanced 打开当前工作区变更
----------------------------------------------------------------------
function M.diff()
  -- 检查 diffview.nvim 是否可用
  local ok_dv = pcall(require, "diffview")
  if ok_dv then
    -- 使用 DiffviewOpenEnhanced（支持 worktree 和自定义 git 路径）
    local ok_cmd, err = pcall(vim.cmd, "DiffviewOpenEnhanced")
    if not ok_cmd then
      vim.notify("Diffview 打开失败: " .. tostring(err), vim.log.levels.ERROR)
    end
    return
  end

  -- fallback: 使用 vim-fugitive
  local ok_fug = pcall(vim.cmd, "Git diff")
  if not ok_fug then
    vim.notify("Git diff 不可用，请安装 diffview.nvim 或 vim-fugitive", vim.log.levels.WARN)
  end
end

----------------------------------------------------------------------
-- suggestion_next/prev/accept(): AI 建议
----------------------------------------------------------------------
function M.suggestion_next()
  local ok, err = pcall(vim.cmd, "AvanteSuggestionNext")
  if not ok and tostring(err):find("avante_templates") then
    error("NEED_BUILD")
  end
end

function M.suggestion_prev()
  local ok, err = pcall(vim.cmd, "AvanteSuggestionPrev")
  if not ok and tostring(err):find("avante_templates") then
    error("NEED_BUILD")
  end
end

function M.suggestion_accept()
  local ok, err = pcall(vim.cmd, "AvanteSuggestionAccept")
  if not ok and tostring(err):find("avante_templates") then
    error("NEED_BUILD")
  end
end

return M
