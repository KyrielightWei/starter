-- lua/ai/avante_adapter.lua
-- Avante.nvim 适配器：实现 keymaps.lua 定义的后端接口

local Providers   = require("ai.providers")
local Keys        = require("ai.keys")
local Util        = require("ai.util")
local ModelSwitch = require("ai.model_switch")

local M = {}

-- 存储基础配置，供后续使用
local base_opts = nil

----------------------------------------------------------------------
-- 构建 Avante 配置
----------------------------------------------------------------------
local function build_opts()
  local providers_tbl = {}

  for name, def in pairs(Providers) do
    if type(def) == "table" and def.endpoint then
      providers_tbl[name] = {
        __inherited_from = def.inherited or "openai",
        api_key_name     = def.api_key_name,
        endpoint         = def.endpoint,
        model            = def.model,
        timeout          = def.timeout or 30000,
        static_models    = def.static_models,
      }
    end
  end

  return {
    provider      = "deepseek",
    providers     = providers_tbl,
    chat          = { persist = true },
    actions       = { enabled = true },
    completion    = { enabled = true, provider = "avante" },
    -- 窗口配置
    windows = {
      position = "right",
          width = 35, -- 侧边栏宽度（百分比），适中宽度
      height = 0.8, -- 侧边栏高度（百分比）
      fillchars = "eob: ", -- 美化空白字符
      wrap = true, -- 自动换行
      -- 侧边栏头部美化
      sidebar_header = {
        enabled = true,
        align = "center",
        rounded = true,
      },
      -- 输入区域配置
      input = {
        prefix = "> ", -- 使用简单前缀，避免表情符号错误
            height = 8, -- 输入区域高度
          },
          -- Ask 浮动窗口配置（更美观）
          ask = {
            floating = true,
            border = "rounded", -- 圆角边框
            start_insert = true,
            -- 窗口大小和位置
            width = 0.5, -- 宽度占屏幕50%
            height = 0.35, -- 高度占屏幕35%
            -- 窗口位置居中
            relative = "editor",
            row = 0.32, -- 距离顶部32%
            col = 0.25, -- 距离左侧25%
            -- 窗口样式
            style = "minimal",
            win_options = {
              winblend = 5, -- 轻微透明
              winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
            },
          },
          -- 编辑窗口配置
          edit = {
            border = "rounded",
            start_insert = true,
            -- 编辑窗口大小
            width = 0.6,
            height = 0.5,
            -- 窗口位置
            relative = "editor",
            row = 0.25,
            col = 0.2,
          },
          -- 聊天窗口配置（如果使用浮动模式）
          chat = {
            floating = false, -- 默认使用侧边栏
            border = "rounded",
            width = 0.5,
            height = 0.7,
            relative = "editor",
            row = 0.15,
            col = 0.25,
          },
          -- 加载动画美化
          spinner = {
            editing = { "⡀", "⠄", "⠂", "⠁", "⠈", "⠐", "⠠", "⢀", "⣀", "⢄", "⢂", "⢁", "⢈", "⢐", "⢠", "⣠", "⢤", "⢢", "⢡", "⢨", "⢰", "⣰", "⢴", "⢲", "⢱", "⢸", "⣸", "⢼", "⢺", "⢹", "⣹", "⢽", "⢻", "⣻", "⢿", "⣿" },
            generating = { "✨", "🌟", "💫", "⭐", "☄️", "🌠" },
            thinking = { "🤔", "🧠", "💭", "💡" },
      },
    },
    -- 行为配置
    behaviour = {
      auto_focus_sidebar = true,
      auto_set_keymaps = true,
      auto_set_highlight_group = true,
      enable_token_counting = true,
      auto_apply_diff_after_generation = false, -- 不自动应用 diff，让用户手动确认
      minimize_diff = true, -- 最小化 diff，只显示变化的部分
      auto_focus_on_diff_view = true, -- 自动聚焦到 diff 视图
    },
    -- Diff 配置
    diff = {
      autojump = true, -- 自动跳转到 diff 位置
      override_timeoutlen = 500, -- 避免进入 operator-pending 模式
    },
    -- 高亮配置
    highlights = {
      diff = {
        current = "DiffAdd", -- 当前内容高亮
        incoming = "DiffChange", -- 新内容高亮
      },
    },
    -- 选择配置
    selection = {
      enabled = true,
      hint_display = "delayed", -- 延迟显示提示
    },
  }
end

----------------------------------------------------------------------
-- 应用 API Key 和 Provider
----------------------------------------------------------------------
local function apply_ai_key_and_provider(avante, opts)
  local keys = Keys.read()
  if not keys then return end

  local provider = (_G.AI_MODEL and _G.AI_MODEL.provider)
                or opts.provider
                or "openai"

  local key = Keys.get_key(provider)
  local env_var = Util.get_env_var(provider)

  vim.env[env_var]       = key
  vim.env.OPENAI_API_KEY = key

  local final_model =
    (_G.AI_MODEL and _G.AI_MODEL.model)
    or (opts.providers[provider] and opts.providers[provider].model)

  local new_opts = vim.deepcopy(opts)
  new_opts.provider = provider
  new_opts.providers[provider] =
    Util.merge_table(new_opts.providers[provider] or {}, {
      api_key = key,
      model   = final_model,
    })

  avante.setup(new_opts)

  _G.AI_MODEL          = _G.AI_MODEL or {}
  _G.AI_MODEL.provider = provider
  _G.AI_MODEL.model    = final_model
end

----------------------------------------------------------------------
-- 后端实现：注册到 keymaps.lua
----------------------------------------------------------------------
local backend_impl = {
  -- 核心交互
  -- Chat: 打开聊天窗口（侧边栏）
  chat = function()
    local ok, avante = pcall(require, "avante")
    if not ok then
      vim.notify("avante.nvim not found", vim.log.levels.ERROR)
      return
    end
    apply_ai_key_and_provider(avante, base_opts)
    -- 直接打开侧边栏，不显示浮动窗口
    avante.open_sidebar({ ask = false })
  end,

  -- Chat New: 创建新聊天（侧边栏模式）
  chat_new = function()
      local ok, api = pcall(require, "avante.api")
      if not ok then
        vim.notify("avante.api not found", vim.log.levels.ERROR)
        return
      end
      local avante = require("avante")
      apply_ai_key_and_provider(avante, base_opts)
      -- 使用api.ask创建新聊天
      api.ask({ new_chat = true, ask = false })
  end,

  -- Edit: 编辑选中的代码
  edit = function()
    local ok, api = pcall(require, "avante.api")
    if not ok then
      vim.notify("avante.api not found", vim.log.levels.ERROR)
      return
    end
    local avante = require("avante")
    apply_ai_key_and_provider(avante, base_opts)
    api.edit()
  end,

  -- Ask: 快速提问（显示浮动窗口）
  ask = function()
    local ok, api = pcall(require, "avante.api")
    if not ok then
      vim.notify("avante.api not found", vim.log.levels.ERROR)
      return
    end
    local avante = require("avante")
    apply_ai_key_and_provider(avante, base_opts)
    -- 使用默认设置（浮动窗口）
    api.ask()
  end,

  -- 模型切换
  model_switch = function()
    local ok, avante = pcall(require, "avante")
    if not ok then return end

    ModelSwitch.select(function(choice)
      _G.AI_MODEL          = _G.AI_MODEL or {}
      _G.AI_MODEL.provider = choice.provider
      _G.AI_MODEL.model    = choice.model

      base_opts.providers[choice.provider].model = choice.model

      apply_ai_key_and_provider(avante, base_opts)
      vim.notify("Switched to " .. choice.provider .. " / " .. choice.model, vim.log.levels.INFO)
    end)
  end,

  -- Key 管理
  key_manager = function()
    local ok, fzf = pcall(require, "fzf-lua")
    if not ok then
      vim.notify("fzf-lua not installed", vim.log.levels.WARN)
      return
    end

    local tbl = Keys.ensure()
    local items = {}

    for provider, profiles in pairs(tbl) do
      if provider ~= "profile" then
        for profile, key in pairs(profiles) do
          local has = (key ~= "" and "***" or "(empty)")
          table.insert(items, string.format("%-12s │ %-10s │ %s", provider, profile, has))
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
          local provider, profile = selected[1]:match("^(%S+)%s+│%s+(%S+)")
          local tbl = Keys.read()
          tbl.profile = profile
          Keys.write(tbl)
          vim.notify("Switched profile to " .. profile, vim.log.levels.INFO)
        end,
      },
    })
  end,

  -- 会话管理（使用 Avante 内置的 history_selector）
    sessions = function()
      local ok, api = pcall(require, "avante.api")
      if ok and api.select_history then
        api.select_history()
        return
      end
  
      -- 回退：使用 fzf-lua 手动选择
      local ok2, fzf = pcall(require, "fzf-lua")
      if not ok2 then
        vim.notify("Neither avante.api.select_history nor fzf-lua is available", vim.log.levels.WARN)
      return
    end

    local dir = vim.fn.stdpath("data") .. "/avante/sessions"
    if vim.fn.isdirectory(dir) == 0 then
      vim.notify("No sessions directory", vim.log.levels.INFO)
      return
    end

    local sessions = vim.fn.glob(dir .. "/*.json", false, true)
    if #sessions == 0 then
      vim.notify("No sessions found", vim.log.levels.INFO)
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
          local path = selected[1]:match("│%s*(.+)$")
            if path then
              -- 先打开侧边栏
              local avante = require("avante")
              avante.open_sidebar({ ask = false })
              -- 加载会话
              pcall(function()
                avante.load_session(path)
              end)
            end
          end,
          ["ctrl-d"] = function(selected)
            local path = selected[1]:match("│%s*(.+)$")
            if path then
              os.remove(path)
              vim.notify("Session deleted: " .. path, vim.log.levels.INFO)
            end
        end,
      },
    })
  end,

  -- 面板切换（Avante 特有）
  toggle = function()
    pcall(vim.cmd, "AvanteToggle")
  end,

  -- Diff 查看（使用 codediff.nvim 美化显示）
    diff = function()
      -- 检查 codediff.nvim 是否可用
      local ok = pcall(require, "codediff")
      if ok then
        -- 使用 codediff.nvim 打开 git diff explorer
        vim.cmd("CodeDiff")
        return
      end
  
      -- 回退：检查是否有 Avante diff 命令
      local ok2, avante = pcall(require, "avante")
      if ok2 and avante.show_diff then
        avante.show_diff()
        return
      end
  
      -- 最后回退：使用 fzf-lua 选择文件并查看 diff
      local ok3, fzf = pcall(require, "fzf-lua")
      if not ok3 then
        vim.notify("Neither codediff.nvim nor fzf-lua is available", vim.log.levels.WARN)
      vim.cmd("Git diff")
      return
    end

    -- 获取最近的 git 修改
    local git_status = vim.fn.system("git status --porcelain 2>/dev/null")
    if git_status == "" then
      vim.notify("No git changes found", vim.log.levels.INFO)
      return
    end

    local items = {}
    for line in git_status:gmatch("[^\r\n]+") do
      local status = line:sub(1, 2)
      local file = line:sub(4)
      local status_text = ""
      if status:match("M") then
        status_text = "Modified"
      elseif status:match("A") then
        status_text = "Added"
      elseif status:match("D") then
        status_text = "Deleted"
      elseif status:match("R") then
        status_text = "Renamed"
      elseif status:match("?") then
        status_text = "Untracked"
      end
      table.insert(items, string.format("%-12s │ %s", status_text, file))
    end

    fzf.fzf_exec(items, {
      prompt = "Git Changes> ",
      actions = {
        ["default"] = function(selected)
          local file = selected[1]:match("│%s*(.+)$")
          if file then
            vim.cmd("Gvdiffsplit " .. vim.fn.fnameescape(file))
          end
        end,
        ["ctrl-v"] = function(selected)
          local file = selected[1]:match("│%s*(.+)$")
          if file then
            vim.cmd("vertical Gvdiffsplit " .. vim.fn.fnameescape(file))
          end
        end,
        ["ctrl-s"] = function(selected)
          local file = selected[1]:match("│%s*(.+)$")
          if file then
            vim.cmd("Gdiffsplit " .. vim.fn.fnameescape(file))
          end
        end,
      },
    })
  end,

  -- Suggestion 相关（Avante 特有）
  suggestion_next = function()
    pcall(vim.cmd, "AvanteSuggestionNext")
  end,

  suggestion_prev = function()
    pcall(vim.cmd, "AvanteSuggestionPrev")
  end,

  suggestion_accept = function()
    pcall(vim.cmd, "AvanteSuggestionAccept")
  end,
}

----------------------------------------------------------------------
-- 初始化
----------------------------------------------------------------------
function M.setup()
  local ok, avante = pcall(require, "avante")
  if not ok then
    vim.notify("avante.nvim not found", vim.log.levels.ERROR)
    return
  end

  -- 构建配置
  base_opts = build_opts()
  avante.setup(base_opts)

  -- 应用初始配置
  pcall(function()
    apply_ai_key_and_provider(avante, base_opts)
  end)

  -- 返回后端实现，由 ai/init.lua 注册
  return backend_impl
end

return M


